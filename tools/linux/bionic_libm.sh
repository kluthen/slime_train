#!/usr/bin/env bash
# Builds an LD_PRELOAD shim that gives a desktop run Android's atan2, atan2f,
# sin and cos (bionic's libm, FreeBSD msun) instead of glibc's, to reproduce
# a phone's state hashes on Linux x86_64 without the phone. The shim (sources
# in tools/linux/bionic_libm/) counts, per function, the calls whose result
# differs from glibc's and prints them at exit (see shim.c).
#
#   tools/linux/bionic_libm.sh     fetches bionic's msun sources (pinned
#                                  commit, needs the network once) and builds
#                                  build/bionic_libm/libbionic_libm.so
#
# Then, for example (seed 909, 600 ticks, as docs/dev/native.md's table):
#
#   LD_PRELOAD=build/bionic_libm/libbionic_libm.so godot --headless --path . \
#       -- --test-mode --fixture=s3-basket-59of60 --seed=909 --run-ticks=600
#   SHIM_FUNCS=atan2f LD_PRELOAD=...    replaces atan2f only
#
# Limits: on arm64, bionic takes sinf, cosf and sincosf from ARM's optimized
# routines, as glibc does, so they aren't replaced. Godot opens a GDExtension
# with RTLD_DEEPBIND, so the slime_native library keeps glibc's functions
# (its calls aren't counted either). Compiled without FMA contraction.

set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
here="$root/tools/linux/bionic_libm"
out="$root/build/bionic_libm"
commit=731631f300090436d7f5df80d50b6275c8c60a93
base="https://raw.githubusercontent.com/aosp-mirror/platform_bionic/$commit/libm/upstream-freebsd/lib/msun/src"
sources=(e_atan2 e_atan2f s_atan s_atanf s_sin s_cos k_sin k_cos k_rem_pio2)

mkdir -p "$out/src/machine"
for name in "${sources[@]}" e_rem_pio2 math_private; do
	case "$name" in math_private) file="$name.h" ;; *) file="$name.c" ;; esac
	[ -s "$out/src/$file" ] || curl -sSf "$base/$file" -o "$out/src/$file"
done
echo '#include <endian.h>' >"$out/src/machine/endian.h"

flags=(-O2 -fPIC -ffp-contract=off -fno-builtin -fno-math-errno -w)
objects=()
for name in "${sources[@]}"; do
	gcc "${flags[@]}" -include "$here/compat.h" -I"$out/src" -c "$out/src/$name.c" -o "$out/$name.o"
	objects+=("$out/$name.o")
done
gcc "${flags[@]}" -shared "$here/shim.c" "${objects[@]}" -o "$out/libbionic_libm.so" -ldl
echo "Built $out/libbionic_libm.so (bionic $commit)"
