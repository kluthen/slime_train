#pragma once

// The marshalling between a GDScript SlimeBodies (src/sim/slime_bodies.gd)
// and the native solver (SlimeSolver, chunk 5N, docs/dev/native.md).
//
// godot-cpp hands a method its packed-array arguments as copies, so the
// solver never takes the arrays as arguments: it takes the SlimeBodies object
// and reads each array once per call with Object::get(), then writes back the
// ones it changed with Object::set(). A packed array is copy-on-write: the one
// read shares the GDScript member's buffer until the solver writes to it
// (ptrw() copies it once), and set() makes the member hold the new buffer.
// No alias of a SlimeBodies array outlives a call, so nothing is kept across
// ticks (the solver holds no state between calls but scratch).

#include <godot_cpp/classes/object.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/packed_string_array.hpp>
#include <godot_cpp/variant/packed_vector2_array.hpp>
#include <godot_cpp/variant/string_name.hpp>
#include <godot_cpp/variant/variant.hpp>
#include <godot_cpp/variant/vector2.hpp>

namespace godot {

// SlimeBodies' constants the solver depends on. SlimeSolver::check_schema
// compares them with the script's own values.
namespace slime_const {
constexpr int64_t STATE_SLEEPER = 0;
constexpr int64_t STATE_TRAIN = 1;
constexpr int64_t STATE_FREE = 2;
constexpr int64_t STATE_BEDTIME_ASLEEP = 3;
constexpr int64_t STATE_IN_BASKET = 4;
constexpr int64_t ACTIVE = 0;
constexpr int64_t RESTING = 1;
constexpr int64_t PARKED = 2;
constexpr double SUPPORT_NORMAL_Y = 0.3;
constexpr double TOUCH_SKIN = 2.0;
constexpr double REST_DRIFT = 1.0;
constexpr int64_t REST_TICKS = 30;
constexpr double WAKE_SPEED = 30.0;
} // namespace slime_const

// One field the solver reads (and, if `written`, writes back) by name.
struct SolverField {
	const char *name;
	Variant::Type type;
	bool written;
};

// One constant the solver relies on: its name and native value.
struct SolverConstant {
	const char *name;
	double value;
};

// The SlimeBodies fields the solver reads and writes (the schema).
extern const SolverField BODIES_FIELDS[];
extern const int BODIES_FIELD_COUNT;
// The TerrainSegments fields (the terrain and every door), read only.
extern const SolverField TERRAIN_FIELDS[];
extern const int TERRAIN_FIELD_COUNT;
// SlimeBodies' constants, as the solver has them (slime_const).
extern const SolverConstant BODIES_CONSTANTS[];
extern const int BODIES_CONSTANT_COUNT;

// The field `p_name` of `p_object` into `r_value`, which must be of `p_type`;
// prints an error ("<p_where>: <p_what>.<p_name> is <type>, expected
// <type>", for example p_where "SlimeSolver.integrate" and p_what
// "SlimeBodies") and returns false otherwise. Every read of the solver goes
// through it.
bool solver_fetch(Object *p_object, const char *p_where, const char *p_what, const char *p_name, Variant::Type p_type,
		Variant &r_value);

// solver_fetch() into a value of the field's type (an int64_t, a double, a
// packed array...).
template <typename T>
bool solver_fetch_as(Object *p_object, const char *p_where, const char *p_what, const char *p_name,
		Variant::Type p_type, T &r_value) {
	Variant value;
	if (!solver_fetch(p_object, p_where, p_what, p_name, p_type, value)) {
		return false;
	}
	r_value = value;
	return true;
}

// The problems with `bodies` as the solver's input: a missing field, a field
// of another type, a missing or changed constant, a terrain or door missing
// a field. Empty when the solver can read and write it.
PackedStringArray solver_schema_problems(Object *p_bodies);

// The state of one SlimeBodies for one solver call: the arrays read with
// get(), raw pointers into them, and the scalars. load() fills it; store()
// writes the read-write arrays back with set(). The pointers of the
// read-write arrays come from ptrw() (one copy each, see the file header);
// a phase that resizes an array (_pairs, _pair_touch) takes its pointer
// again afterwards.
struct SolverState {
	// Read only.
	int64_t slime_count = 0;
	PackedInt32Array first_a, npts_a, state_a, id_a;
	PackedFloat32Array bound_r_a, rest_edge_a, rest_area_a;
	PackedVector2Array rest_off_a;
	const int32_t *first = nullptr;
	const int32_t *npts = nullptr;
	const int32_t *state = nullptr;
	const int32_t *id = nullptr;
	const float *bound_r = nullptr;
	const float *rest_edge = nullptr;
	const float *rest_area = nullptr;
	const Vector2 *rest_off = nullptr;
	Vector2 gravity;
	Vector2 free_down;
	int64_t substeps = 0;
	int64_t iterations = 0;
	double edge_stiffness = 0.0;
	double area_stiffness = 0.0;
	double shape_stiffness = 0.0;
	double internal_damping = 0.0;
	double air_drag = 0.0;
	double terrain_friction = 0.0;
	double slime_friction = 0.0;
	double terrain_skin = 0.0;
	double max_speed = 0.0;
	bool rest_enabled = false;
	// The TerrainSegments (or null) and the doors (Array of TerrainSegments);
	// `terrain_value` is the terrain as read (a Variant, NIL for none).
	Object *terrain = nullptr;
	Variant terrain_value;
	Array doors;

	// Read and written.
	PackedVector2Array pos_a, prev_a, centre_a, drift_a, rest_anchor_a, centre_cache_a;
	PackedFloat32Array angle0_a;
	PackedInt32Array supported_a, still_ticks_a, pile_a, pairs_a;
	PackedByteArray calm_a, pair_touch_a, centre_ok_a;
	Array touching;
	Vector2 *pos = nullptr;
	Vector2 *prev = nullptr;
	Vector2 *centre = nullptr;
	Vector2 *drift = nullptr;
	Vector2 *rest_anchor = nullptr;
	Vector2 *centre_cache = nullptr;
	float *angle0 = nullptr;
	int32_t *supported = nullptr;
	int32_t *still_ticks = nullptr;
	int32_t *pile = nullptr;
	uint8_t *calm = nullptr;
	uint8_t *centre_ok = nullptr;

	// Reads every field of `p_bodies`. False, with an error printed, when a
	// field is missing or of another type, or the array sizes don't agree
	// (per point: pos, prev, rest_off; per slime: the rest).
	bool load(Object *p_bodies);
	// Writes the read-write fields back to `p_bodies`.
	void store(Object *p_bodies) const;
};

} // namespace godot
