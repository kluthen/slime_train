// The slime contacts of the native solver: SlimeBodies._solve_contacts()
// (src/sim/slime_bodies.gd), ported line for line: ring against ring for
// each candidate pair of the pair grid (solver_pairs.cpp; see
// _solve_contacts' doc), writing pos, prev, supported and _pair_touch.
//
// Precision mirrors GDScript: Vector2 and the packed arrays are float32, a
// GDScript float is a double that turns float32 where it meets a Vector2
// (Vector2 * float, Vector2 / float, Vector2 / int), Vector2.length() and
// length_squared() are float32, and atan2 and sqrt of a float run in double.
//
// The pass reads only the fields it needs, once per call, and writes back
// only the ones it changes (solver_state.h explains the copy-on-write
// boundary); step() runs it on the whole tick's state (contacts_state,
// solver_passes.h). A field it can't rely on (missing, retyped, sizes that
// don't agree, an index out of range) is an error: the pass returns false
// before writing anything, and SlimeBodies runs its GDScript pass instead.

// @spec-link [[req_waking_sleepers]]

#include "slime_solver.h"

#include <cmath>
#include <vector>

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

// GDScript's TAU (Math_TAU), as a double.
constexpr double CONTACTS_TAU = 6.2831853071795864769252867666;
// The arrays _solve_contacts() reads (read only) and writes.
struct ContactArrays {
	const int32_t *first;
	const int32_t *npts;
	const int32_t *state;
	const uint8_t *calm;
	const float *bound_r;
	const Vector2 *centre;
	const float *angle0;
	const Vector2 *drift;
	const int32_t *pairs;
	Vector2 *pos;
	Vector2 *prev;
	int32_t *supported;
	uint8_t *pair_touch;
};

// One side of a pair in _solve_contacts(): the points of ring `p_a` facing
// ring `p_b` against b's radial profile; marks the pair touching
// (`r_touched`) and a's support. False, with an error, when b's profile is
// read off an index outside its ring (an angle0 out of [-PI, PI]).
// @spec-link [[rule_contact_pushes_slimes_apart]]
bool contact_side(const ContactArrays &p_arr, int64_t p_a, int64_t p_b, double p_mu, bool &r_touched) {
	using namespace slime_const;
	const double inv_tau = 1.0 / CONTACTS_TAU;
	const double skin = TOUCH_SKIN;
	Vector2 *p = p_arr.pos;
	Vector2 *o = p_arr.prev;
	const Vector2 ca = p_arr.centre[p_a];
	const Vector2 cb = p_arr.centre[p_b];
	const double rb = double(p_arr.bound_r[p_b]) + skin;
	const double rb2 = rb * rb;
	const int64_t nb = p_arr.npts[p_b];
	const int64_t fb = p_arr.first[p_b];
	const double b0 = p_arr.angle0[p_b];
	const int64_t na = p_arr.npts[p_a];
	const int64_t fa = p_arr.first[p_a];
	const Vector2 dir = cb - ca;
	double ta = (std::atan2(double(dir.y), double(dir.x)) - double(p_arr.angle0[p_a])) * inv_tau;
	if (ta < 0.0) {
		ta += 1.0;
	}
	const int64_t mid = int64_t(ta * double(na) + 0.5);
	const int64_t half = na / 4 + 1;
	const double kb = double(nb) * inv_tau;
	Vector2 react;
	Vector2 drag;
	const Vector2 vb = p_arr.drift[p_b];
	bool touched = false;
	bool rests = false;
	// A sleeper (or a resting slime) is a wall: its points only feel the
	// touch, and a slime against it takes the whole overlap.
	const bool still = is_wall(p_arr.state[p_a], p_arr.calm[p_a]);
	const bool against_still = is_wall(p_arr.state[p_b], p_arr.calm[p_b]);
	const double share = against_still ? 1.0 : 0.5;
	for (int64_t m = mid - half; m < mid + half + 1; m++) {
		const int64_t j = fa + (m % na + na) % na;
		const Vector2 rel = p[j] - cb;
		const double d2 = rel.length_squared();
		if (d2 >= rb2 || d2 < 1e-6) {
			continue;
		}
		double t = (std::atan2(double(rel.y), double(rel.x)) - b0) * kb;
		if (t < 0.0) {
			t += double(nb);
		}
		int64_t k = int64_t(t);
		if (k >= nb) {
			k -= nb;
		}
		if (k < 0 || k >= nb) {
			ERR_PRINT("SlimeSolver.solve_contacts: a ring's angle0 is out of [-PI, PI].");
			return false;
		}
		const double fr = t - double(k);
		const int64_t k2 = k + 1 < nb ? k + 1 : 0;
		const double r0 = (p[fb + k] - cb).length();
		const double r = r0 + (double((p[fb + k2] - cb).length()) - r0) * fr;
		const double rs = r + skin;
		if (d2 >= rs * rs) {
			continue;
		}
		touched = true;
		const double d = std::sqrt(d2);
		if (double(rel.y) < -SUPPORT_NORMAL_Y * d) {
			rests = true;
		}
		if (d < r && !still) {
			// Past b's centre: mirrored back to a's side (see
			// _solve_contacts' doc).
			Vector2 out = rel;
			const double along = rel.dot(dir);
			if (along > 0.0) {
				out = rel - dir * real_t(2.0 * along / double(dir.length_squared()));
			}
			const Vector2 push = out * real_t((r - d) * share / d);
			const Vector2 moved = p[j] + push;
			p[j] = moved;
			react -= push;
			// Friction: slow the point's sliding along b's surface.
			const Vector2 nrm = out / real_t(d);
			Vector2 slide = moved - o[j] - vb;
			slide = (slide - nrm * slide.dot(nrm)) * real_t(p_mu);
			o[j] += slide;
			drag += slide;
		}
	}
	if (touched) {
		r_touched = true;
	}
	if (rests && !still) {
		p_arr.supported[p_a] = 1;
	}
	if (react != Vector2() && !against_still) {
		react /= real_t(nb);
		drag /= real_t(nb);
		for (int64_t q = fb; q < fb + nb; q++) {
			p[q] += react;
			o[q] -= drag;
		}
	}
	return true;
}

// The contacts of every candidate pair (`p_values` indices in
// `p_arr.pairs`) whose bound circles overlap, both sides in turn (see
// contact_side), with slime friction `p_mu`. False when a side can't be read.
bool solve_pairs(const ContactArrays &p_arr, int64_t p_values, double p_mu) {
	for (int64_t i = 0; i < p_values; i += 2) {
		const int64_t s0 = p_arr.pairs[i];
		const int64_t s1 = p_arr.pairs[i + 1];
		const double rr = double(p_arr.bound_r[s0]) + double(p_arr.bound_r[s1]);
		if (double((p_arr.centre[s1] - p_arr.centre[s0]).length_squared()) >= rr * rr) {
			continue;
		}
		bool touched = false;
		if (!contact_side(p_arr, s0, s1, p_mu, touched) || !contact_side(p_arr, s1, s0, p_mu, touched)) {
			return false;
		}
		if (touched) {
			p_arr.pair_touch[i / 2] = 1;
		}
	}
	return true;
}

// Whether every index of `p_pairs` (`p_values` of them) is a slime index
// below `p_count`, two different ones per pair; prints an error otherwise.
bool pairs_valid(const int32_t *p_pairs, int64_t p_values, int64_t p_count) {
	for (int64_t i = 0; i < p_values; i += 2) {
		const int32_t s0 = p_pairs[i];
		const int32_t s1 = p_pairs[i + 1];
		if (s0 < 0 || s1 < 0 || s0 >= p_count || s1 >= p_count || s0 == s1) {
			ERR_PRINT("SlimeSolver.solve_contacts: _pairs holds a pair that isn't two slime indices.");
			return false;
		}
	}
	return true;
}

// Whether every slime's point range (first, npts) is a non-empty slice of
// the `p_points` points; prints an error otherwise.
bool rings_valid(const int32_t *p_first, const int32_t *p_npts, int64_t p_count, int64_t p_points) {
	for (int64_t s = 0; s < p_count; s++) {
		if (p_first[s] < 0 || p_npts[s] <= 0 || int64_t(p_first[s]) + p_npts[s] > p_points) {
			ERR_PRINT("SlimeSolver.solve_contacts: a slime's point range is empty or outside the point arrays.");
			return false;
		}
	}
	return true;
}

} // namespace

// The contacts on a whole tick's state (solver_passes.h), with the checks
// solve_contacts makes on what it reads.
bool contacts_state(SolverState &r_st) {
	const int64_t pair_values = r_st.pairs_a.size();
	ERR_FAIL_COND_V_MSG(pair_values % 2 != 0, false, "SlimeSolver.step: _pairs holds an odd count.");
	if (pair_values == 0) {
		return true;
	}
	ERR_FAIL_COND_V_MSG(r_st.pair_touch_a.size() != pair_values / 2, false,
			"SlimeSolver.step: _pair_touch doesn't hold one entry per pair of _pairs.");
	if (!pairs_valid(r_st.pairs_a.ptr(), pair_values, r_st.slime_count) ||
			!rings_valid(r_st.first, r_st.npts, r_st.slime_count, r_st.pos_a.size())) {
		return false;
	}
	ContactArrays arr;
	arr.first = r_st.first;
	arr.npts = r_st.npts;
	arr.state = r_st.state;
	arr.calm = r_st.calm;
	arr.bound_r = r_st.bound_r;
	arr.centre = r_st.centre;
	arr.angle0 = r_st.angle0;
	arr.drift = r_st.drift;
	arr.pairs = r_st.pairs_a.ptr();
	arr.pos = r_st.pos;
	arr.prev = r_st.prev;
	arr.supported = r_st.supported;
	// Already this call's own buffer after build_pairs_state (no copy).
	arr.pair_touch = r_st.pair_touch_a.ptrw();
	return solve_pairs(arr, pair_values, r_st.slime_friction);
}

// SlimeBodies._solve_contacts(): ring against ring for every candidate pair
// whose bound circles overlap, both sides in turn (see contact_side).
// @spec-link [[req_waking_sleepers]]
bool SlimeSolver::solve_contacts(Object *p_bodies) {
	ERR_FAIL_NULL_V_MSG(p_bodies, false, "SlimeSolver.solve_contacts: null bodies.");
	const char *pass = "SlimeSolver.solve_contacts";
	int64_t count = 0;
	PackedInt32Array pairs_a;
	if (!solver_fetch_as(p_bodies, pass, "SlimeBodies", "slime_count", Variant::INT, count) ||
			!solver_fetch_as(p_bodies, pass, "SlimeBodies", "_pairs", Variant::PACKED_INT32_ARRAY, pairs_a)) {
		return false;
	}
	const int64_t pair_values = pairs_a.size();
	ERR_FAIL_COND_V_MSG(count < 0 || pair_values % 2 != 0, false,
			"SlimeSolver.solve_contacts: slime_count is negative or _pairs holds an odd count.");
	// No pair: nothing to read, nothing changes.
	if (pair_values == 0) {
		return true;
	}
	double mu = 0.0;
	PackedInt32Array first_a, npts_a, state_a, supported_a;
	PackedByteArray calm_a, pair_touch_a;
	PackedFloat32Array bound_r_a, angle0_a;
	PackedVector2Array centre_a, drift_a, pos_a, prev_a;
	if (!solver_fetch_as(p_bodies, pass, "SlimeBodies", "slime_friction", Variant::FLOAT, mu) ||
			!solver_fetch_as(p_bodies, pass, "SlimeBodies", "first", Variant::PACKED_INT32_ARRAY, first_a) ||
			!solver_fetch_as(p_bodies, pass, "SlimeBodies", "npts", Variant::PACKED_INT32_ARRAY, npts_a) ||
			!solver_fetch_as(p_bodies, pass, "SlimeBodies", "state", Variant::PACKED_INT32_ARRAY, state_a) ||
			!solver_fetch_as(p_bodies, pass, "SlimeBodies", "calm", Variant::PACKED_BYTE_ARRAY, calm_a) ||
			!solver_fetch_as(p_bodies, pass, "SlimeBodies", "bound_r", Variant::PACKED_FLOAT32_ARRAY, bound_r_a) ||
			!solver_fetch_as(p_bodies, pass, "SlimeBodies", "centre", Variant::PACKED_VECTOR2_ARRAY, centre_a) ||
			!solver_fetch_as(p_bodies, pass, "SlimeBodies", "angle0", Variant::PACKED_FLOAT32_ARRAY, angle0_a) ||
			!solver_fetch_as(p_bodies, pass, "SlimeBodies", "_drift", Variant::PACKED_VECTOR2_ARRAY, drift_a) ||
			!solver_fetch_as(p_bodies, pass, "SlimeBodies", "supported", Variant::PACKED_INT32_ARRAY, supported_a) ||
			!solver_fetch_as(p_bodies, pass, "SlimeBodies", "_pair_touch", Variant::PACKED_BYTE_ARRAY, pair_touch_a) ||
			!solver_fetch_as(p_bodies, pass, "SlimeBodies", "pos", Variant::PACKED_VECTOR2_ARRAY, pos_a) ||
			!solver_fetch_as(p_bodies, pass, "SlimeBodies", "prev", Variant::PACKED_VECTOR2_ARRAY, prev_a)) {
		return false;
	}
	const int64_t per_slime[] = { first_a.size(), npts_a.size(), state_a.size(), calm_a.size(), bound_r_a.size(),
		centre_a.size(), angle0_a.size(), drift_a.size(), supported_a.size() };
	for (int64_t size : per_slime) {
		ERR_FAIL_COND_V_MSG(size != count, false,
				"SlimeSolver.solve_contacts: a per-slime array doesn't hold slime_count entries.");
	}
	ERR_FAIL_COND_V_MSG(prev_a.size() != pos_a.size(), false, "SlimeSolver.solve_contacts: pos and prev differ in size.");
	ERR_FAIL_COND_V_MSG(pair_touch_a.size() != pair_values / 2, false,
			"SlimeSolver.solve_contacts: _pair_touch doesn't hold one entry per pair of _pairs.");
	if (!pairs_valid(pairs_a.ptr(), pair_values, count) ||
			!rings_valid(first_a.ptr(), npts_a.ptr(), count, pos_a.size())) {
		return false;
	}
	ContactArrays arr;
	arr.first = first_a.ptr();
	arr.npts = npts_a.ptr();
	arr.state = state_a.ptr();
	arr.calm = calm_a.ptr();
	arr.bound_r = bound_r_a.ptr();
	arr.centre = centre_a.ptr();
	arr.angle0 = angle0_a.ptr();
	arr.drift = drift_a.ptr();
	arr.pairs = pairs_a.ptr();
	// One copy each of the written arrays (copy-on-write): nothing reaches the
	// bodies before store below, so an error leaves them as they were.
	arr.pos = pos_a.ptrw();
	arr.prev = prev_a.ptrw();
	arr.supported = supported_a.ptrw();
	arr.pair_touch = pair_touch_a.ptrw();
	if (!solve_pairs(arr, pair_values, mu)) {
		return false;
	}
	p_bodies->set(StringName("pos"), pos_a);
	p_bodies->set(StringName("prev"), prev_a);
	p_bodies->set(StringName("supported"), supported_a);
	p_bodies->set(StringName("_pair_touch"), pair_touch_a);
	return true;
}

} // namespace godot
