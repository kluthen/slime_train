extends GutTest
## Species: six species, A to F, each with a colour. The six colours differ
## clearly in lightness, not only in hue, so a colour-blind child can still
## tell them apart (master spec §5.2).
# @test-link [[req_species_and_colour]]

## The smallest lightness gap allowed between two species colours, in CIE L*
## units (0 is black, 100 is white). About 10 is a step anyone can see.
const MIN_LIGHTNESS_GAP := 10.0


func test_there_are_six_species_a_to_f() -> void:
	assert_eq(Species.COUNT, 6)
	assert_eq(Species.COLORS.size(), 6)
	var letters := PackedStringArray()
	for species in Species.COUNT:
		letters.append(Species.letter(species))
	assert_eq(letters, PackedStringArray(["A", "B", "C", "D", "E", "F"]))
	assert_eq(Species.from_letter("C"), 2)
	assert_eq(Species.from_letter("Z"), -1)


func test_colours_follow_the_test_level_placeholders() -> void:
	# specs/levels/test/README.md: A red, B blue, C yellow, D green, E purple.
	var a := Species.color(0)
	var b := Species.color(1)
	var c := Species.color(2)
	var d := Species.color(3)
	var e := Species.color(4)
	assert_true(a.r > a.g and a.r > a.b, "A is red")
	assert_true(b.b > b.r and b.b > b.g, "B is blue")
	assert_true(c.r > c.b and c.g > c.b and c.r > 0.8 and c.g > 0.8, "C is yellow")
	assert_true(d.g > d.r and d.g > d.b, "D is green")
	assert_true(e.b > e.g and e.r > e.g, "E is purple")


func test_relative_luminance_of_black_and_white() -> void:
	assert_almost_eq(Species.relative_luminance(Color.BLACK), 0.0, 1e-6)
	assert_almost_eq(Species.relative_luminance(Color.WHITE), 1.0, 1e-6)
	assert_almost_eq(Species.lightness(Color.WHITE), 100.0, 1e-3)
	# sRGB mid grey (#777777) is about L* 50.
	assert_almost_eq(Species.lightness(Color("777777")), 50.0, 1.0)


func test_the_six_colours_differ_clearly_in_lightness() -> void:
	var values: Array[float] = []
	for species in Species.COUNT:
		values.append(Species.lightness(Species.color(species)))
	gut.p("L* per species A-F: %s" % [values])
	for i in values.size():
		for j in range(i + 1, values.size()):
			assert_true(absf(values[i] - values[j]) >= MIN_LIGHTNESS_GAP,
					"%s (L* %.1f) and %s (L* %.1f) are too close in lightness"
					% [Species.letter(i), values[i], Species.letter(j), values[j]])
