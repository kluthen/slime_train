extends GutTest
## QuotaDisplay (src/frontier/quota_display.gd), item 24.2: a basket's quota
## as slime outlines up to 10, as quota pies above (one per 10 of weight, the
## last holding the rest), filling in order in the caught slimes' colours;
## and on the test level, basket 3's pies fit within its width and each
## measures at least 6 mm on the reference phone's screen at
## `s3.frame.basket`'s zoom, while basket 1 still shows 6 outlines.

# @test-link [[req_switch_basket_gate_set]]

const LEVEL_SCENE := "res://levels/test/level.tscn"
const RED := 0
const BLUE := 1
const YELLOW := 2


## `count` slimes' worth of `value`, as a packed array.
func _repeat(value: int, count: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	out.resize(count)
	out.fill(value)
	return out


func test_a_quota_of_6_gives_6_outlines() -> void:
	assert_false(QuotaDisplay.uses_pies(6))
	assert_eq(QuotaDisplay.groups(6), _repeat(1, 6), "one outline per unit of weight")
	assert_eq(QuotaDisplay.centres(Rect2(0, 0, 300, 100), 6).size(), 6)
	assert_eq(QuotaDisplay.radius(6), QuotaDisplay.OUTLINE_RADIUS)


func test_a_quota_of_10_is_still_outlines_and_11_is_pies() -> void:
	assert_false(QuotaDisplay.uses_pies(10))
	assert_true(QuotaDisplay.uses_pies(11))
	assert_eq(QuotaDisplay.groups(11), PackedInt32Array([10, 1]))


func test_a_quota_of_15_gives_pies_of_10_and_5() -> void:
	assert_true(QuotaDisplay.uses_pies(15))
	assert_eq(QuotaDisplay.groups(15), PackedInt32Array([10, 5]))
	assert_eq(QuotaDisplay.radius(15), QuotaDisplay.PIE_RADIUS)


func test_a_quota_of_60_gives_6_pies_of_10() -> void:
	assert_eq(QuotaDisplay.groups(60), _repeat(10, 6))
	var centres := QuotaDisplay.centres(Rect2(0, 0, 700, 200), 60)
	assert_eq(centres.size(), 6)
	assert_almost_eq((centres[0].x + centres[5].x) * 0.5, 350.0, 0.001, "centred over the box")
	assert_eq(centres[0].y, -QuotaDisplay.PIE_LIFT, "above the box")


func test_at_23_of_60_two_full_pies_and_3_slices_of_the_third() -> void:
	assert_eq(QuotaDisplay.filled_per_group(60, 23), PackedInt32Array([10, 10, 3, 0, 0, 0]))


func test_a_size_3_slime_at_8_fills_the_first_pie_and_one_slice_of_the_second() -> void:
	var species := _repeat(RED, 8)
	species.append(BLUE)
	var sizes := _repeat(1, 8)
	sizes.append(3)
	assert_eq(QuotaDisplay.filled_per_group(15, 8), PackedInt32Array([8, 0]), "before")
	assert_eq(QuotaDisplay.filled_per_group(15, 11), PackedInt32Array([10, 1]), "after")
	var units := QuotaDisplay.unit_species(15, species, sizes)
	assert_eq(units.slice(0, 8), _repeat(RED, 8))
	assert_eq(units.slice(8, 11), _repeat(BLUE, 3), "its three slices in its colour, across both pies")
	assert_eq(units.slice(11), _repeat(-1, 4), "the rest empty")


func test_a_full_pie_stays_full_while_the_basket_fills() -> void:
	for weight in range(10, 61):
		assert_eq(QuotaDisplay.filled_per_group(60, weight)[0], 10, "at %d" % weight)


func test_the_units_past_the_quota_are_cut_off() -> void:
	var units := QuotaDisplay.unit_species(4, PackedInt32Array([RED, YELLOW]), PackedInt32Array([3, 3]))
	assert_eq(units, PackedInt32Array([RED, RED, RED, YELLOW]))
	assert_eq(QuotaDisplay.filled_per_group(15, 99), PackedInt32Array([10, 5]))


func test_a_pie_draws_a_fan_per_slice_in_its_slime_colour_then_its_dividers() -> void:
	var triangles := QuotaDisplay.Triangles.new()
	var units := PackedInt32Array([YELLOW, YELLOW, -1, -1, -1])
	triangles.add_pie(Vector2(100, 50), 40.0, 5, units, 0)
	var per_slice := ceili(float(QuotaDisplay.PIE_SEGMENTS) / 5)
	var fan_points := 5 * (per_slice + 2)
	assert_eq(triangles.points.size(), fan_points + 5 * 4, "5 fans, then 5 dividers")
	assert_eq(triangles.indices.size(), (5 * per_slice + 5 * 2) * 3)
	assert_eq(triangles.colors[0], Species.color(YELLOW), "slice 1: the slime's colour")
	assert_eq(triangles.colors[(per_slice + 2) * 2], QuotaDisplay.EMPTY_SLICE_COLOR, "slice 3: empty")
	assert_eq(triangles.colors[fan_points], QuotaDisplay.OUTLINE_COLOR, "the dividers")
	assert_almost_eq(triangles.points[1].distance_to(Vector2(100, 10)), 0.0, 0.001, "from the top")
	assert_gt(triangles.points[2].x, 100.0, "clockwise")
	var one := QuotaDisplay.Triangles.new()
	one.add_pie(Vector2.ZERO, 40.0, 1, PackedInt32Array([RED]), 0)
	assert_eq(one.colors[-1], Species.color(RED), "a pie of one slice has no divider")


func test_on_the_test_level_basket_3s_pies_fit_and_measure_at_least_6_mm() -> void:
	var level: Node = load(LEVEL_SCENE).instantiate()
	add_child_autofree(level)
	var basket: Basket = level.find("s3.basket")
	var frame: FramingZone = level.find("s3.frame.basket")
	assert_eq(basket.quota, 60, "the test level's stress case stays")
	assert_true(QuotaDisplay.uses_pies(basket.quota))
	assert_lte(QuotaDisplay.row_width(basket.quota), basket.size.x, "the row within the basket's width")
	# The reference phone's screen: 405 ppi, its 1080 px showing the
	# viewport's 648, so ScreenView.REFERENCE_PX_PER_MM viewport px a mm.
	var px_per_mm := ScreenView.REFERENCE_PHONE_PPI / ScreenView.MM_PER_INCH / ScreenView.REFERENCE_PHONE_SCALE
	assert_almost_eq(px_per_mm, ScreenView.REFERENCE_PX_PER_MM, 0.0001)
	var across_mm := QuotaDisplay.PIE_RADIUS * 2.0 * frame.zoom / px_per_mm
	assert_gte(across_mm, 6.0, "a pie at s3.frame.basket's zoom %.2f: %.2f mm" % [frame.zoom, across_mm])
	var basket_2: Basket = level.find("s2.basket")
	assert_eq(QuotaDisplay.groups(basket_2.quota), PackedInt32Array([10, 5]), "basket 2's 15")
	assert_lte(QuotaDisplay.row_width(basket_2.quota), basket_2.size.x)
	var basket_1: Basket = level.find("s1.basket")
	assert_false(QuotaDisplay.uses_pies(basket_1.quota))
	assert_eq(QuotaDisplay.groups(basket_1.quota).size(), 6, "basket 1 still shows 6 outlines")
	assert_lte(QuotaDisplay.row_width(basket_1.quota), basket_1.size.x)
