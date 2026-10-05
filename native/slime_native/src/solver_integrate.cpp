// The integrate pass of the native solver: SlimeBodies._integrate(h)
// (src/sim/slime_bodies.gd), with SlimeBodies.gravity_for() inlined. A Verlet
// step per point (gravity by the slime's state, air drag, internal damping
// toward the slime's mean velocity, the max_speed clamp), then each slime's
// centre, drift and point-0 angle. A sleeper, a resting and a parked slime
// don't move: only their point-0 angle is refreshed and their drift zeroed.
//
// Precision mirrors GDScript: Vector2 and the packed arrays are float32, a
// GDScript float is a double that turns float32 where it meets a Vector2
// (Vector2 * float, limit_length), and atan2 runs in double.
//
// The pass reads only the fields it needs and writes back only the ones it
// changes (pos and prev only when a slime simulates), each read once per call
// (solver_state.h explains the copy-on-write boundary).

// @spec-link [[req_tilt_input]]
// @spec-link [[req_slime_states]]

#include "slime_solver.h"

#include <cmath>

#include <godot_cpp/core/error_macros.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/packed_vector2_array.hpp>
#include <godot_cpp/variant/string_name.hpp>
#include <godot_cpp/variant/variant.hpp>

#include "solver_passes.h"
#include "solver_state.h"

namespace godot {

namespace {

// The pass on raw arrays (see the file header). `p_pos` and `p_prev` may be
// null when no slime is ACTIVE and awake (they are then only read through
// `p_pos_read`), and so may `p_centre` (read through `p_centre_read`).
void integrate_slimes(int64_t p_count, const int32_t *p_first, const int32_t *p_npts, const int32_t *p_state,
		const uint8_t *p_calm, const Vector2 *p_pos_read, Vector2 *p_pos, Vector2 *p_prev,
		const Vector2 *p_centre_read, Vector2 *p_centre, float *p_angle0, Vector2 *p_drift,
		const Vector2 &p_gravity, const Vector2 &p_free_down, double p_h, double p_internal_damping, double p_air_drag, double p_max_speed) {
	using namespace slime_const;
	// GDScript: `gravity * h * h` (Vector2 * float rounds h to float32).
	const real_t hf = real_t(p_h);
	const Vector2 g = p_gravity * hf * hf;
	// gravity_for(STATE_FREE): `gravity`, or `free_down * gravity.length()`.
	const Vector2 gravity_free = p_free_down == Vector2(0, 1) ? p_gravity : p_free_down * p_gravity.length();
	const Vector2 g_free = gravity_free * hf * hf;
	const real_t ms = real_t(p_max_speed * p_h);
	const real_t idamp = real_t(p_internal_damping);
	const real_t damp = real_t(1.0 - p_air_drag * p_h);
	for (int64_t s = 0; s < p_count; s++) {
		const int64_t f = p_first[s];
		const int64_t cnt = p_npts[s];
		const int64_t end = f + cnt;
		if (cnt <= 0) {
			continue;
		}
		if (p_state[s] == STATE_SLEEPER || p_calm[s] != ACTIVE) {
			// Asleep, resting or parked: it doesn't simulate (its points stay
			// put), but its point-0 angle is kept right for the contacts.
			const Vector2 r_sleep = p_pos_read[f] - p_centre_read[s];
			p_angle0[s] = float(std::atan2(double(r_sleep.y), double(r_sleep.x)));
			p_drift[s] = Vector2();
			continue;
		}
		const Vector2 gs = p_state[s] == STATE_FREE ? g_free : g;
		Vector2 mean;
		for (int64_t i = f; i < end; i++) {
			mean += p_pos[i] - p_prev[i];
		}
		mean /= real_t(cnt);
		Vector2 c;
		for (int64_t i = f; i < end; i++) {
			const Vector2 cur = p_pos[i];
			Vector2 v = cur - p_prev[i];
			v = ((v + (mean - v) * idamp) * damp).limit_length(ms) + gs;
			p_prev[i] = cur;
			const Vector2 nxt = cur + v;
			p_pos[i] = nxt;
			c += nxt;
		}
		c /= real_t(cnt);
		p_drift[s] = c - p_centre[s];
		p_centre[s] = c;
		const Vector2 r0 = p_pos[f] - c;
		p_angle0[s] = float(std::atan2(double(r0.y), double(r0.x)));
	}
}

} // namespace

// The pass on a whole tick's state (solver_passes.h): every array already
// writable, so pos, prev and centre are read and written in place.
void integrate_state(SolverState &r_st, double p_h) {
	integrate_slimes(r_st.slime_count, r_st.first, r_st.npts, r_st.state, r_st.calm, r_st.pos, r_st.pos, r_st.prev,
			r_st.centre, r_st.centre, r_st.angle0, r_st.drift, r_st.gravity, r_st.free_down, p_h, r_st.internal_damping,
			r_st.air_drag, r_st.max_speed);
}

// SlimeBodies._integrate(h) on its own: reads the fields it needs, writes
// back what changed (see the file header).
bool SlimeSolver::integrate(Object *p_bodies, double p_h) {
	using namespace slime_const;
	ERR_FAIL_NULL_V_MSG(p_bodies, false, "SlimeSolver.integrate: null bodies.");
	Variant v;
#define INTEGRATE_FETCH(m_name, m_type, m_target) \
	if (!solver_fetch(p_bodies, "SlimeSolver.integrate", "SlimeBodies", m_name, Variant::m_type, v)) { \
		return false; \
	} \
	m_target = v;
	int64_t n = 0;
	PackedInt32Array first_a, npts_a, state_a;
	PackedByteArray calm_a;
	PackedVector2Array pos_a, prev_a, centre_a, drift_a;
	PackedFloat32Array angle0_a;
	Vector2 gravity, free_down;
	double internal_damping = 0.0, air_drag = 0.0, max_speed = 0.0;
	INTEGRATE_FETCH("slime_count", INT, n)
	INTEGRATE_FETCH("first", PACKED_INT32_ARRAY, first_a)
	INTEGRATE_FETCH("npts", PACKED_INT32_ARRAY, npts_a)
	INTEGRATE_FETCH("state", PACKED_INT32_ARRAY, state_a)
	INTEGRATE_FETCH("calm", PACKED_BYTE_ARRAY, calm_a)
	INTEGRATE_FETCH("gravity", VECTOR2, gravity)
	INTEGRATE_FETCH("free_down", VECTOR2, free_down)
	INTEGRATE_FETCH("internal_damping", FLOAT, internal_damping)
	INTEGRATE_FETCH("air_drag", FLOAT, air_drag)
	INTEGRATE_FETCH("max_speed", FLOAT, max_speed)
	INTEGRATE_FETCH("pos", PACKED_VECTOR2_ARRAY, pos_a)
	INTEGRATE_FETCH("prev", PACKED_VECTOR2_ARRAY, prev_a)
	INTEGRATE_FETCH("centre", PACKED_VECTOR2_ARRAY, centre_a)
	INTEGRATE_FETCH("angle0", PACKED_FLOAT32_ARRAY, angle0_a)
	INTEGRATE_FETCH("_drift", PACKED_VECTOR2_ARRAY, drift_a)
#undef INTEGRATE_FETCH

	const int64_t points = pos_a.size();
	ERR_FAIL_COND_V_MSG(prev_a.size() != points, false, "SlimeSolver.integrate: pos and prev differ in size.");
	ERR_FAIL_COND_V_MSG(first_a.size() != n || npts_a.size() != n || state_a.size() != n || calm_a.size() != n ||
					centre_a.size() != n || angle0_a.size() != n || drift_a.size() != n,
			false, "SlimeSolver.integrate: a per-slime array doesn't hold slime_count entries.");
	const int32_t *first = first_a.ptr();
	const int32_t *npts = npts_a.ptr();
	const int32_t *state = state_a.ptr();
	const uint8_t *calm = calm_a.ptr();
	// Whether any slime simulates: if none does, pos, prev and centre stay as
	// they are (no copy, no write-back).
	bool moves = false;
	for (int64_t s = 0; s < n; s++) {
		ERR_FAIL_COND_V_MSG(first[s] < 0 || npts[s] < 0 || int64_t(first[s]) + npts[s] > points, false,
				"SlimeSolver.integrate: a slime's point range is outside the point arrays.");
		if (npts[s] > 0 && state[s] != STATE_SLEEPER && calm[s] == ACTIVE) {
			moves = true;
		}
	}

	Vector2 *pos = moves ? pos_a.ptrw() : nullptr;
	Vector2 *prev = moves ? prev_a.ptrw() : nullptr;
	Vector2 *centre = moves ? centre_a.ptrw() : nullptr;
	const Vector2 *pos_read = moves ? pos : pos_a.ptr();
	const Vector2 *centre_read = moves ? centre : centre_a.ptr();
	integrate_slimes(n, first, npts, state, calm, pos_read, pos, prev, centre_read, centre, angle0_a.ptrw(),
			drift_a.ptrw(), gravity, free_down, p_h, internal_damping, air_drag, max_speed);

	if (moves) {
		p_bodies->set(StringName("pos"), pos_a);
		p_bodies->set(StringName("prev"), prev_a);
		p_bodies->set(StringName("centre"), centre_a);
	}
	p_bodies->set(StringName("angle0"), angle0_a);
	p_bodies->set(StringName("_drift"), drift_a);
	return true;
}

} // namespace godot
