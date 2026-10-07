class_name Species
extends RefCounted
## The six slime species of v1, A to F (0 to 5), and their colours. In v1
## species differ by colour only, and the six colours also differ clearly in
## lightness (at least 10 CIE L* units apart), so a colour-blind child can
## tell them apart (master spec §5.2). tests/unit/test_species.gd checks it.
##
## Placeholder colours, following the test level's conventions
## (specs/levels/test/README.md: A red, B blue, C yellow, D green, E purple);
## F, not placed in the test level yet, is pink. The real palette comes with
## the art. Lightness, darkest to lightest: E, B, A, D, F, C.

const COUNT := 6
const LETTERS := "ABCDEF"
## Species colour by index, sRGB.
const COLORS: Array[Color] = [
	Color("f0402f"), # A red,     L* 54
	Color("2a52c0"), # B blue,    L* 38
	Color("fce94f"), # C yellow,  L* 92
	Color("4db545"), # D green,   L* 66
	Color("56268f"), # E purple,  L* 28
	Color("f9b3d6"), # F pink,    L* 80
]


## "A" to "F".
# @spec-link [[req_species_and_colour]]
static func letter(species: int) -> String:
	return LETTERS[species]


## 0 to 5, or -1 for anything else.
static func from_letter(text: String) -> int:
	if text.length() != 1:
		return -1
	return LETTERS.find(text)


## The colour of `species` (an index into LETTERS).
# @spec-link [[req_species_and_colour]]
static func color(species: int) -> Color:
	return COLORS[species]


## WCAG relative luminance of an sRGB colour: 0 for black, 1 for white.
static func relative_luminance(c: Color) -> float:
	return 0.2126 * _linear(c.r) + 0.7152 * _linear(c.g) + 0.0722 * _linear(c.b)


## CIE L* lightness (0 black, 100 white), from the relative luminance. Equal
## steps of L* look like equal steps of lightness.
static func lightness(c: Color) -> float:
	var y := relative_luminance(c)
	var f := pow(y, 1.0 / 3.0) if y > 216.0 / 24389.0 else (24389.0 / 27.0 * y + 16.0) / 116.0
	return 116.0 * f - 16.0


static func _linear(channel: float) -> float:
	if channel <= 0.04045:
		return channel / 12.92
	return pow((channel + 0.055) / 1.055, 2.4)
