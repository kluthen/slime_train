// The marshalling between SlimeBodies and the native solver: see solver_state.h.

#include "solver_state.h"

#include <godot_cpp/classes/script.hpp>
#include <godot_cpp/core/error_macros.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/typed_array.hpp>

namespace godot {

const SolverField BODIES_FIELDS[] = {
	// Read only.
	{ "slime_count", Variant::INT, false },
	{ "first", Variant::PACKED_INT32_ARRAY, false },
	{ "npts", Variant::PACKED_INT32_ARRAY, false },
	{ "state", Variant::PACKED_INT32_ARRAY, false },
	{ "id", Variant::PACKED_INT32_ARRAY, false },
	{ "bound_r", Variant::PACKED_FLOAT32_ARRAY, false },
	{ "rest_edge", Variant::PACKED_FLOAT32_ARRAY, false },
	{ "rest_area", Variant::PACKED_FLOAT32_ARRAY, false },
	{ "rest_off", Variant::PACKED_VECTOR2_ARRAY, false },
	{ "gravity", Variant::VECTOR2, false },
	{ "free_down", Variant::VECTOR2, false },
	{ "substeps", Variant::INT, false },
	{ "iterations", Variant::INT, false },
	{ "edge_stiffness", Variant::FLOAT, false },
	{ "area_stiffness", Variant::FLOAT, false },
	{ "shape_stiffness", Variant::FLOAT, false },
	{ "internal_damping", Variant::FLOAT, false },
	{ "air_drag", Variant::FLOAT, false },
	{ "terrain_friction", Variant::FLOAT, false },
	{ "slime_friction", Variant::FLOAT, false },
	{ "terrain_skin", Variant::FLOAT, false },
	{ "max_speed", Variant::FLOAT, false },
	{ "rest_enabled", Variant::BOOL, false },
	{ "terrain", Variant::OBJECT, false },
	{ "doors", Variant::ARRAY, false },
	// Read and written.
	{ "pos", Variant::PACKED_VECTOR2_ARRAY, true },
	{ "prev", Variant::PACKED_VECTOR2_ARRAY, true },
	{ "centre", Variant::PACKED_VECTOR2_ARRAY, true },
	{ "angle0", Variant::PACKED_FLOAT32_ARRAY, true },
	{ "_drift", Variant::PACKED_VECTOR2_ARRAY, true },
	{ "supported", Variant::PACKED_INT32_ARRAY, true },
	{ "calm", Variant::PACKED_BYTE_ARRAY, true },
	{ "still_ticks", Variant::PACKED_INT32_ARRAY, true },
	{ "rest_anchor", Variant::PACKED_VECTOR2_ARRAY, true },
	{ "pile", Variant::PACKED_INT32_ARRAY, true },
	{ "_pairs", Variant::PACKED_INT32_ARRAY, true },
	{ "_pair_touch", Variant::PACKED_BYTE_ARRAY, true },
	{ "_touching", Variant::ARRAY, true },
	{ "_centre_cache", Variant::PACKED_VECTOR2_ARRAY, true },
	{ "_centre_ok", Variant::PACKED_BYTE_ARRAY, true },
};
const int BODIES_FIELD_COUNT = sizeof(BODIES_FIELDS) / sizeof(BODIES_FIELDS[0]);

const SolverField TERRAIN_FIELDS[] = {
	{ "seg_a", Variant::PACKED_VECTOR2_ARRAY, false },
	{ "seg_d", Variant::PACKED_VECTOR2_ARRAY, false },
	{ "seg_inv_len2", Variant::PACKED_FLOAT32_ARRAY, false },
	{ "seg_n", Variant::PACKED_VECTOR2_ARRAY, false },
	{ "seg_na", Variant::PACKED_VECTOR2_ARRAY, false },
	{ "seg_nb", Variant::PACKED_VECTOR2_ARRAY, false },
	{ "cell_start", Variant::PACKED_INT32_ARRAY, false },
	{ "cell_items", Variant::PACKED_INT32_ARRAY, false },
	{ "origin", Variant::VECTOR2, false },
	{ "inv_cell", Variant::FLOAT, false },
	{ "grid_w", Variant::INT, false },
	{ "grid_h", Variant::INT, false },
};
const int TERRAIN_FIELD_COUNT = sizeof(TERRAIN_FIELDS) / sizeof(TERRAIN_FIELDS[0]);

const SolverConstant BODIES_CONSTANTS[] = {
	{ "STATE_SLEEPER", double(slime_const::STATE_SLEEPER) },
	{ "STATE_TRAIN", double(slime_const::STATE_TRAIN) },
	{ "STATE_FREE", double(slime_const::STATE_FREE) },
	{ "STATE_BEDTIME_ASLEEP", double(slime_const::STATE_BEDTIME_ASLEEP) },
	{ "STATE_IN_BASKET", double(slime_const::STATE_IN_BASKET) },
	{ "ACTIVE", double(slime_const::ACTIVE) },
	{ "RESTING", double(slime_const::RESTING) },
	{ "PARKED", double(slime_const::PARKED) },
	{ "SUPPORT_NORMAL_Y", slime_const::SUPPORT_NORMAL_Y },
	{ "TOUCH_SKIN", slime_const::TOUCH_SKIN },
	{ "REST_DRIFT", slime_const::REST_DRIFT },
	{ "REST_TICKS", double(slime_const::REST_TICKS) },
	{ "WAKE_SPEED", slime_const::WAKE_SPEED },
};
const int BODIES_CONSTANT_COUNT = sizeof(BODIES_CONSTANTS) / sizeof(BODIES_CONSTANTS[0]);

namespace {

// The object's properties, name -> Variant type.
Dictionary property_types(Object *p_object) {
	Dictionary types;
	TypedArray<Dictionary> props = p_object->get_property_list();
	for (int64_t i = 0; i < props.size(); i++) {
		Dictionary prop = props[i];
		types[prop["name"]] = prop["type"];
	}
	return types;
}

// Appends to `r_problems` every field of `p_fields` that `p_object` lacks or
// holds with another type; each problem starts with `p_prefix`.
void check_fields(Object *p_object, const SolverField *p_fields, int p_count, const String &p_prefix,
		PackedStringArray &r_problems) {
	Dictionary types = property_types(p_object);
	for (int i = 0; i < p_count; i++) {
		const SolverField &field = p_fields[i];
		String name = field.name;
		String expected = Variant::get_type_name(field.type);
		if (!types.has(name)) {
			r_problems.push_back(p_prefix + name + ": missing (" + expected + ")");
			continue;
		}
		Variant::Type type = Variant::Type(int(types[name]));
		if (type != field.type) {
			r_problems.push_back(p_prefix + name + ": " + Variant::get_type_name(type) + ", expected " + expected);
		}
	}
}

// Appends the problems of one terrain piece (the terrain or a door).
void check_terrain(const Variant &p_value, const String &p_prefix, PackedStringArray &r_problems) {
	if (p_value.get_type() == Variant::NIL) {
		return;
	}
	Object *piece = p_value;
	if (piece == nullptr) {
		r_problems.push_back(p_prefix + String(": not an object"));
		return;
	}
	check_fields(piece, TERRAIN_FIELDS, TERRAIN_FIELD_COUNT, p_prefix + String("."), r_problems);
}

} // namespace

bool solver_fetch(Object *p_object, const char *p_where, const char *p_what, const char *p_name, Variant::Type p_type,
		Variant &r_value) {
	r_value = p_object->get(StringName(p_name));
	if (r_value.get_type() != p_type) {
		ERR_PRINT(String(p_where) + ": " + p_what + "." + p_name + " is " + Variant::get_type_name(r_value.get_type()) +
				", expected " + Variant::get_type_name(p_type) + " (see check_schema).");
		return false;
	}
	return true;
}

PackedStringArray solver_schema_problems(Object *p_bodies) {
	PackedStringArray problems;
	ERR_FAIL_NULL_V_MSG(p_bodies, PackedStringArray({ "bodies: null" }), "SlimeSolver: null bodies.");
	check_fields(p_bodies, BODIES_FIELDS, BODIES_FIELD_COUNT, "", problems);
	Object *script = p_bodies->get_script();
	Script *as_script = Object::cast_to<Script>(script);
	if (as_script == nullptr) {
		problems.push_back("script: none (expected SlimeBodies)");
	} else {
		Dictionary constants = as_script->get_script_constant_map();
		for (int i = 0; i < BODIES_CONSTANT_COUNT; i++) {
			const SolverConstant &constant = BODIES_CONSTANTS[i];
			if (!constants.has(constant.name)) {
				problems.push_back(String(constant.name) + ": constant missing");
				continue;
			}
			double value = constants[constant.name];
			if (value != constant.value) {
				problems.push_back(String(constant.name) + ": constant is " + String::num(value) + ", the solver has " +
						String::num(constant.value));
			}
		}
	}
	if (problems.is_empty()) {
		check_terrain(p_bodies->get("terrain"), "terrain", problems);
		Array doors = p_bodies->get("doors");
		for (int64_t i = 0; i < doors.size(); i++) {
			check_terrain(doors[i], "doors[" + String::num_int64(i) + "]", problems);
		}
	}
	return problems;
}

bool SolverState::load(Object *p_bodies) {
	ERR_FAIL_NULL_V_MSG(p_bodies, false, "SlimeSolver: null bodies.");
	Variant v;
#define SOLVER_FETCH(m_name, m_type, m_target) \
	if (!solver_fetch(p_bodies, "SlimeSolver", "SlimeBodies", m_name, Variant::m_type, v)) { \
		return false; \
	} \
	m_target = v;
	SOLVER_FETCH("slime_count", INT, slime_count)
	SOLVER_FETCH("first", PACKED_INT32_ARRAY, first_a)
	SOLVER_FETCH("npts", PACKED_INT32_ARRAY, npts_a)
	SOLVER_FETCH("state", PACKED_INT32_ARRAY, state_a)
	SOLVER_FETCH("id", PACKED_INT32_ARRAY, id_a)
	SOLVER_FETCH("bound_r", PACKED_FLOAT32_ARRAY, bound_r_a)
	SOLVER_FETCH("rest_edge", PACKED_FLOAT32_ARRAY, rest_edge_a)
	SOLVER_FETCH("rest_area", PACKED_FLOAT32_ARRAY, rest_area_a)
	SOLVER_FETCH("rest_off", PACKED_VECTOR2_ARRAY, rest_off_a)
	SOLVER_FETCH("gravity", VECTOR2, gravity)
	SOLVER_FETCH("free_down", VECTOR2, free_down)
	SOLVER_FETCH("substeps", INT, substeps)
	SOLVER_FETCH("iterations", INT, iterations)
	SOLVER_FETCH("edge_stiffness", FLOAT, edge_stiffness)
	SOLVER_FETCH("area_stiffness", FLOAT, area_stiffness)
	SOLVER_FETCH("shape_stiffness", FLOAT, shape_stiffness)
	SOLVER_FETCH("internal_damping", FLOAT, internal_damping)
	SOLVER_FETCH("air_drag", FLOAT, air_drag)
	SOLVER_FETCH("terrain_friction", FLOAT, terrain_friction)
	SOLVER_FETCH("slime_friction", FLOAT, slime_friction)
	SOLVER_FETCH("terrain_skin", FLOAT, terrain_skin)
	SOLVER_FETCH("max_speed", FLOAT, max_speed)
	SOLVER_FETCH("rest_enabled", BOOL, rest_enabled)
	SOLVER_FETCH("doors", ARRAY, doors)
	SOLVER_FETCH("pos", PACKED_VECTOR2_ARRAY, pos_a)
	SOLVER_FETCH("prev", PACKED_VECTOR2_ARRAY, prev_a)
	SOLVER_FETCH("centre", PACKED_VECTOR2_ARRAY, centre_a)
	SOLVER_FETCH("angle0", PACKED_FLOAT32_ARRAY, angle0_a)
	SOLVER_FETCH("_drift", PACKED_VECTOR2_ARRAY, drift_a)
	SOLVER_FETCH("supported", PACKED_INT32_ARRAY, supported_a)
	SOLVER_FETCH("calm", PACKED_BYTE_ARRAY, calm_a)
	SOLVER_FETCH("still_ticks", PACKED_INT32_ARRAY, still_ticks_a)
	SOLVER_FETCH("rest_anchor", PACKED_VECTOR2_ARRAY, rest_anchor_a)
	SOLVER_FETCH("pile", PACKED_INT32_ARRAY, pile_a)
	SOLVER_FETCH("_pairs", PACKED_INT32_ARRAY, pairs_a)
	SOLVER_FETCH("_pair_touch", PACKED_BYTE_ARRAY, pair_touch_a)
	SOLVER_FETCH("_touching", ARRAY, touching)
	SOLVER_FETCH("_centre_cache", PACKED_VECTOR2_ARRAY, centre_cache_a)
	SOLVER_FETCH("_centre_ok", PACKED_BYTE_ARRAY, centre_ok_a)
#undef SOLVER_FETCH
	// The terrain may be null (no terrain).
	v = p_bodies->get(StringName("terrain"));
	terrain_value = v;
	if (v.get_type() == Variant::NIL) {
		terrain = nullptr;
	} else if (v.get_type() == Variant::OBJECT) {
		terrain = v;
	} else {
		ERR_FAIL_V_MSG(false, "SlimeSolver: SlimeBodies.terrain is not an object.");
	}

	const int64_t n = slime_count;
	const int64_t points = pos_a.size();
	ERR_FAIL_COND_V_MSG(prev_a.size() != points || rest_off_a.size() != points, false,
			"SlimeSolver: pos, prev and rest_off differ in size.");
	const int64_t per_slime[] = { first_a.size(), npts_a.size(), state_a.size(), id_a.size(), bound_r_a.size(),
		rest_edge_a.size(), rest_area_a.size(), centre_a.size(), angle0_a.size(), drift_a.size(), supported_a.size(),
		calm_a.size(), still_ticks_a.size(), rest_anchor_a.size(), pile_a.size(), centre_cache_a.size(),
		centre_ok_a.size() };
	for (int64_t size : per_slime) {
		ERR_FAIL_COND_V_MSG(size != n, false, "SlimeSolver: a per-slime array doesn't hold slime_count entries.");
	}

	first = first_a.ptr();
	npts = npts_a.ptr();
	state = state_a.ptr();
	id = id_a.ptr();
	bound_r = bound_r_a.ptr();
	rest_edge = rest_edge_a.ptr();
	rest_area = rest_area_a.ptr();
	rest_off = rest_off_a.ptr();
	for (int64_t s = 0; s < n; s++) {
		ERR_FAIL_COND_V_MSG(first[s] < 0 || npts[s] < 0 || int64_t(first[s]) + npts[s] > points, false,
				"SlimeSolver: a slime's point range is outside the point arrays.");
	}

	pos = pos_a.ptrw();
	prev = prev_a.ptrw();
	centre = centre_a.ptrw();
	drift = drift_a.ptrw();
	rest_anchor = rest_anchor_a.ptrw();
	centre_cache = centre_cache_a.ptrw();
	angle0 = angle0_a.ptrw();
	supported = supported_a.ptrw();
	still_ticks = still_ticks_a.ptrw();
	pile = pile_a.ptrw();
	calm = calm_a.ptrw();
	centre_ok = centre_ok_a.ptrw();
	return true;
}

void SolverState::store(Object *p_bodies) const {
	ERR_FAIL_NULL_MSG(p_bodies, "SlimeSolver: null bodies.");
	p_bodies->set(StringName("pos"), pos_a);
	p_bodies->set(StringName("prev"), prev_a);
	p_bodies->set(StringName("centre"), centre_a);
	p_bodies->set(StringName("angle0"), angle0_a);
	p_bodies->set(StringName("_drift"), drift_a);
	p_bodies->set(StringName("supported"), supported_a);
	p_bodies->set(StringName("calm"), calm_a);
	p_bodies->set(StringName("still_ticks"), still_ticks_a);
	p_bodies->set(StringName("rest_anchor"), rest_anchor_a);
	p_bodies->set(StringName("pile"), pile_a);
	p_bodies->set(StringName("_pairs"), pairs_a);
	p_bodies->set(StringName("_pair_touch"), pair_touch_a);
	p_bodies->set(StringName("_touching"), touching);
	p_bodies->set(StringName("_centre_cache"), centre_cache_a);
	p_bodies->set(StringName("_centre_ok"), centre_ok_a);
}

} // namespace godot
