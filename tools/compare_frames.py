#!/usr/bin/env python3
"""Compares two sets of movie frames pixel by pixel (Godot's --write-movie PNGs).

    tools/compare_frames.py DIR_A DIR_B [--ignore X0,Y0,X1,Y1]... [--ignore-hud]

Every PNG under DIR_A (searched recursively) is compared with the file at the
same relative path under DIR_B. For each it prints one line: "bytes-identical",
"pixel-identical" (different bytes, same pixels), or "DIFFERENT" with the
bounding box of the differing pixels, then the largest difference on any one
channel (0 to 255) and how many pixels differ. A file missing from DIR_B is
reported as MISSING; files only in DIR_B are not looked at.

--ignore X0,Y0,X1,Y1 leaves out a rectangle of pixels, its corners included
(repeatable). --ignore-hud leaves out the debug-button row, y 80 to 102 across
a 1152-wide window: its fps counter follows the real clock, so it differs from
run to run (and the text after it shifts when its digit count changes).

For example, the look before and after a drawing change: capture each with

    xvfb-run -a -s "-screen 0 1152x648x24" godot --path . --write-movie DIR/f.png \\
        --fixed-fps 60 --quit-after 301 -- --test-mode --fixture=NAME --seed=1

then `tools/compare_frames.py BEFORE AFTER --ignore-hud`.

Pure Python (zlib; no imaging library needed): reads 8-bit, non-interlaced
PNGs in grey, grey with alpha, RGB or RGBA, which is what Godot writes; any
other PNG stops it with an error.
Exit: 0 when every frame's pixels match outside the ignored rectangles; 1 when
one differs or is missing; 2 on bad arguments.
"""
# @spec-link [[req_platform_and_performance_targets]]

import argparse
import os
import struct
import sys
import zlib

PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"
# Bytes per pixel by PNG colour type: grey, RGB, grey + alpha, RGBA.
BYTES_PER_PIXEL = {0: 1, 2: 3, 4: 2, 6: 4}
# The debug-button row holding the wall-clock fps counter, in a 1152 x 648
# window: x0, y0, x1, y1, corners included.
HUD_ROW = (0, 80, 1151, 102)


def decode(path):
    """The PNG at `path` as (width, height, bytes per pixel, pixel bytes row by
    row); fails on a PNG this reader doesn't handle."""
    with open(path, "rb") as png:
        data = png.read()
    if data[:8] != PNG_SIGNATURE:
        raise ValueError("%s: not a PNG" % path)
    pos, idat = 8, []
    width = height = colour = None
    while pos < len(data):
        length, kind = struct.unpack(">I4s", data[pos:pos + 8])
        body = data[pos + 8:pos + 8 + length]
        if kind == b"IHDR":
            width, height, depth, colour, _, _, interlace = struct.unpack(">IIBBBBB", body)
            if depth != 8 or interlace != 0 or colour not in BYTES_PER_PIXEL:
                raise ValueError("%s: unsupported PNG (depth %d, colour type %d, interlace %d)"
                                 % (path, depth, colour, interlace))
        elif kind == b"IDAT":
            idat.append(body)
        pos += 12 + length
    if width is None:
        raise ValueError("%s: PNG without a header" % path)
    return width, height, BYTES_PER_PIXEL[colour], unfilter(zlib.decompress(b"".join(idat)), width, height,
                                                             BYTES_PER_PIXEL[colour])


def unfilter(raw, width, height, bpp):
    """The pixel bytes of `raw` (a PNG's inflated data: each row a filter byte,
    then the row) with each row's filter undone."""
    stride = width * bpp
    out = bytearray(height * stride)
    prev = bytearray(stride)
    i = 0
    for y in range(height):
        kind = raw[i]
        i += 1
        line = bytearray(raw[i:i + stride])
        i += stride
        if kind == 1:
            for x in range(bpp, stride):
                line[x] = (line[x] + line[x - bpp]) & 255
        elif kind == 2:
            for x in range(stride):
                line[x] = (line[x] + prev[x]) & 255
        elif kind == 3:
            for x in range(stride):
                left = line[x - bpp] if x >= bpp else 0
                line[x] = (line[x] + ((left + prev[x]) >> 1)) & 255
        elif kind == 4:
            for x in range(stride):
                left = line[x - bpp] if x >= bpp else 0
                up = prev[x]
                up_left = prev[x - bpp] if x >= bpp else 0
                guess = left + up - up_left
                d_left, d_up, d_up_left = abs(guess - left), abs(guess - up), abs(guess - up_left)
                if d_left <= d_up and d_left <= d_up_left:
                    predictor = left
                elif d_up <= d_up_left:
                    predictor = up
                else:
                    predictor = up_left
                line[x] = (line[x] + predictor) & 255
        elif kind != 0:
            raise ValueError("unknown PNG filter %d on row %d" % (kind, y))
        out[y * stride:(y + 1) * stride] = line
        prev = line
    return bytes(out)


def compare(path_a, path_b, ignore=()):
    """How the PNGs `path_a` and `path_b` differ outside the `ignore`
    rectangles: (status text, largest channel difference, differing pixels;
    -1 pixels when their size or format differs)."""
    with open(path_a, "rb") as a, open(path_b, "rb") as b:
        if a.read() == b.read():
            return "bytes-identical", 0, 0
    width, height, bpp, pixels_a = decode(path_a)
    width_b, height_b, bpp_b, pixels_b = decode(path_b)
    if (width, height, bpp) != (width_b, height_b, bpp_b):
        return ("size/format differs %sx%sx%s vs %sx%sx%s" % (width, height, bpp, width_b, height_b, bpp_b),
                255, -1)
    largest, count = 0, 0
    x0, y0, x1, y1 = width, height, -1, -1
    for p in range(width * height):
        o = p * bpp
        diff = max(abs(pixels_a[o + k] - pixels_b[o + k]) for k in range(bpp))
        if diff:
            x, y = p % width, p // width
            if any(r[0] <= x <= r[2] and r[1] <= y <= r[3] for r in ignore):
                continue
            count += 1
            largest = max(largest, diff)
            x0, y0, x1, y1 = min(x0, x), min(y0, y), max(x1, x), max(y1, y)
    if count == 0:
        return "pixel-identical", 0, 0
    return "DIFFERENT bbox=(%d,%d)-(%d,%d)" % (x0, y0, x1, y1), largest, count


def rectangle(text):
    """An --ignore value "X0,Y0,X1,Y1" as a tuple of four whole numbers."""
    parts = text.split(",")
    if len(parts) != 4:
        raise argparse.ArgumentTypeError("expects X0,Y0,X1,Y1, got '%s'" % text)
    try:
        return tuple(int(v) for v in parts)
    except ValueError:
        raise argparse.ArgumentTypeError("expects whole numbers X0,Y0,X1,Y1, got '%s'" % text)


def main(argv):
    """Compares the two folders named in `argv`, prints a line per frame and
    returns the exit code (see the module doc)."""
    parser = argparse.ArgumentParser(description="Compares two sets of movie frames pixel by pixel.")
    parser.add_argument("dir_a", help="the reference frames")
    parser.add_argument("dir_b", help="the frames to compare with them")
    parser.add_argument("--ignore", type=rectangle, action="append", default=[], metavar="X0,Y0,X1,Y1",
                        help="leave out this rectangle, corners included (repeatable)")
    parser.add_argument("--ignore-hud", action="store_true",
                        help="leave out the debug-button row (y 80 to 102), whose fps counter is wall-clock")
    args = parser.parse_args(argv)
    ignore = list(args.ignore) + ([HUD_ROW] if args.ignore_hud else [])
    for folder in (args.dir_a, args.dir_b):
        if not os.path.isdir(folder):
            parser.error("'%s' is not a folder" % folder)
    bad = 0
    for root, dirs, files in os.walk(args.dir_a):
        dirs.sort()
        for name in sorted(files):
            if not name.lower().endswith(".png"):
                continue
            rel = os.path.relpath(os.path.join(root, name), args.dir_a)
            other = os.path.join(args.dir_b, rel)
            if not os.path.exists(other):
                print("%s: MISSING in %s" % (rel, args.dir_b))
                bad = 1
                continue
            status, largest, count = compare(os.path.join(args.dir_a, rel), other, ignore)
            print("%s: %s max_channel_diff=%d differing_pixels=%d" % (rel, status, largest, count))
            if count:
                bad = 1
    return bad


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
