// The pair grid and the slime contacts of the native solver:
// SlimeBodies._build_pairs() and _solve_contacts() (src/sim/slime_bodies.gd),
// ported line for line.
//
// The pair grid: a counting sort of the slimes into a uniform grid on their
// centres (parked slimes left out), then the candidate pairs (index s < t, at
// most one wall, the scan stopping at the last mover), in GDScript's order:
// _pairs is state GDScript reads after the solver (the touching list, the
// rest pass), so it must be the same list, element for element. The grid
// itself is native scratch (file-local, reused from call to call; the
// simulation runs on one thread); SlimeBodies' own grid fields are only the
// GDScript pass's scratch and are left as they are.
//
// The contacts: ring against ring for each candidate pair (see
// _solve_contacts' doc), writing pos, prev, supported and _pair_touch.
//
// Precision mirrors GDScript: Vector2 and the packed arrays are float32, a
// GDScript float is a double that turns float32 where it meets a Vector2
// (Vector2 * float, Vector2 / float, Vector2 / int), Vector2.length() and
// length_squared() are float32, and atan2 and sqrt of a float run in double.
//
// Each pass reads only the fields it needs, once per call, and writes back
// only the ones it changes (solver_state.h explains the copy-on-write
// boundary). A field it can't rely on (missing, retyped, sizes that don't
// agree, an index out of range) is an error: the pass returns false before
// writing anything, and SlimeBodies runs its GDScript pass instead.

// @spec-link [[req_waking_sleepers]]

#include "slime_solver.h"

#include <cmath>
#include <cstring>
#include <vector>

#include <godot_cpp/core/error_macros.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/packed_vector2_array.hpp>
#include <godot_cpp/variant/string_name.hpp>
#include <godot_cpp/variant/variant.hpp>

#include "solver_state.h"

namespace godot {

namespace {

// GDScript's TAU (Math_TAU), as a double.
constexpr double CONTACTS_TAU = 6.2831853071795864769252867666;
// _build_pairs' constants: the narrowest cell, the most cells across the
// crowd's extent, and the margin a pair's distance test adds (slimes may close
// in during the tick's substeps).
constexpr double PAIR_MIN_CELL = 104.0;
constexpr double PAIR_GRID_SPAN = 256.0;
constexpr double PAIR_MARGIN = 8.0;

// The pair grid's scratch, reused from call to call (see the file header).
struct PairScratch {
	std::vector<int32_t> cell_start;
	std::vector<int32_t> cell_items;
	std::vector<int32_t> slime_cell;
	std::vector<int32_t> fill;
	std::vector<int32_t> pairs;
};
PairScratch pair_scratch;

// The field `p_name` of `p_bodies` into `r_value`, which must be of
// `p_type`; prints an error naming the pass `p_pass` and returns false
// otherwise.
template <typename T>
bool contacts_fetch(Object *p_bodies, const char *p_pass, const char *p_name, Variant::Type p_type, T &r_value) {
	Variant value = p_bodies->get(StringName(p_name));
	if (value.get_type() != p_type) {
		ERR_PRINT(String("SlimeSolver.") + p_pass + ": SlimeBodies." + p_name + " is " +
				Variant::get_type_name(value.get_type()) + ", expected " + Variant::get_type_name(p_type) +
				" (see check_schema).");
		return false;
	}
	r_value = value;
	return true;
}

// SlimeBodies._is_wall(): a sleeper, or a resting slime.
inline bool is_wall(int32_t p_state, uint8_t p_calm) {
	return p_state == slime_const::STATE_SLEEPER || p_calm == slime_const::RESTING;
}

// GDScript's maxf(): MAX(a, b).
inline double max_double(double p_a, double p_b) {
	return p_a > p_b ? p_a : p_b;
}

// GDScript's mini().
inline int64_t min_int(int64_t p_a, int64_t p_b) {
	return p_a < p_b ? p_a : p_b;
}

// GDScript's maxi().
inline int64_t max_int(int64_t p_a, int64_t p_b) {
	return p_a > p_b ? p_a : p_b;
}

// The candidate pairs of _build_pairs() into `r_pairs` (two slime indices
// per pair), from the slimes' calm, state, centre and bound radius. False,
// with an error, when the crowd's extent isn't finite (a NaN or infinite
// centre: no grid can hold it).
bool find_pairs(int64_t p_count, const uint8_t *p_calm, const int32_t *p_state, const Vector2 *p_centre,
		const float *p_bound_r, PairScratch &r_scratch) {
	using namespace slime_const;
	std::vector<int32_t> &pairs = r_scratch.pairs;
	pairs.clear();
	int64_t placed = 0;
	Vector2 low(INFINITY, INFINITY);
	Vector2 high(-INFINITY, -INFINITY);
	// The highest index of a slime in the grid that isn't a wall (-1: none).
	int64_t last_mover = -1;
	for (int64_t s = 0; s < p_count; s++) {
		if (p_calm[s] == PARKED) {
			continue;
		}
		placed++;
		low = low.min(p_centre[s]);
		high = high.max(p_centre[s]);
		if (p_state[s] != STATE_SLEEPER && p_calm[s] == ACTIVE) {
			last_mover = s;
		}
	}
	if (placed < 2) {
		return true;
	}
	const Vector2 extent = high - low;
	if (!std::isfinite(extent.x) || !std::isfinite(extent.y)) {
		ERR_PRINT("SlimeSolver.build_pairs: a slime's centre isn't finite.");
		return false;
	}
	const double cell_size = max_double(PAIR_MIN_CELL, max_double(extent.x, extent.y) / PAIR_GRID_SPAN);
	const int64_t grid_w = int64_t(double(extent.x) / cell_size) + 1;
	const int64_t grid_h = int64_t(double(extent.y) / cell_size) + 1;
	const int64_t cells = grid_w * grid_h;
	std::vector<int32_t> &cell_start = r_scratch.cell_start;
	std::vector<int32_t> &cell_items = r_scratch.cell_items;
	std::vector<int32_t> &slime_cell = r_scratch.slime_cell;
	std::vector<int32_t> &fill = r_scratch.fill;
	cell_start.assign(size_t(cells + 1), 0);
	cell_items.resize(size_t(placed));
	slime_cell.resize(size_t(p_count));
	const double inv = 1.0 / cell_size;
	for (int64_t s = 0; s < p_count; s++) {
		if (p_calm[s] == PARKED) {
			slime_cell[s] = -1;
			continue;
		}
		const Vector2 c = p_centre[s] - low;
		const int64_t cell = min_int(int64_t(c.y * inv), grid_h - 1) * grid_w + min_int(int64_t(c.x * inv), grid_w - 1);
		slime_cell[s] = int32_t(cell);
		cell_start[cell + 1] += 1;
	}
	for (int64_t k = 0; k < cells; k++) {
		cell_start[k + 1] += cell_start[k];
	}
	fill.assign(cell_start.begin(), cell_start.begin() + cells);
	for (int64_t s = 0; s < p_count; s++) {
		const int32_t cell = slime_cell[s];
		if (cell < 0) {
			continue;
		}
		cell_items[fill[cell]] = int32_t(s);
		fill[cell] += 1;
	}
	// A pair (s, t) has s < t and at most one wall. A slime after the last
	// mover is a wall with only walls after it: it pairs with nothing, so the
	// scan stops at the last mover (none: no pairs).
	for (int64_t s = 0; s <= last_mover; s++) {
		const int64_t cell = slime_cell[s];
		if (cell < 0) {
			continue;
		}
		const bool wall_s = is_wall(p_state[s], p_calm[s]);
		const int64_t cx = cell % grid_w;
		const int64_t cy = cell / grid_w;
		const Vector2 cs = p_centre[s];
		const double rs = p_bound_r[s];
		const int64_t gy_end = min_int(cy + 2, grid_h);
		const int64_t gx_end = min_int(cx + 2, grid_w);
		for (int64_t gy = max_int(cy - 1, 0); gy < gy_end; gy++) {
			for (int64_t gx = max_int(cx - 1, 0); gx < gx_end; gx++) {
				const int64_t gc = gy * grid_w + gx;
				for (int32_t q = cell_start[gc]; q < cell_start[gc + 1]; q++) {
					const int32_t t = cell_items[q];
					// Two walls (sleepers, resting slimes) are never paired.
					if (t <= s || (wall_s && is_wall(p_state[t], p_calm[t]))) {
						continue;
					}
					const double rr = rs + double(p_bound_r[t]) + PAIR_MARGIN;
					if (double((p_centre[t] - cs).length_squared()) < rr * rr) {
						pairs.push_back(int32_t(s));
						pairs.push_back(t);
					}
				}
			}
		}
	}
	return true;
}

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
			const Vector2 push = rel * real_t((r - d) * share / d);
			const Vector2 moved = p[j] + push;
			p[j] = moved;
			react -= push;
			// Friction: slow the point's sliding along b's surface.
			const Vector2 nrm = rel / real_t(d);
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

// SlimeBodies._build_pairs(): the pair grid, then _pairs and a cleared
// _pair_touch (see the file header).
// @spec-link [[req_waking_sleepers]]
bool SlimeSolver::build_pairs(Object *p_bodies) {
	ERR_FAIL_NULL_V_MSG(p_bodies, false, "SlimeSolver.build_pairs: null bodies.");
	const char *pass = "build_pairs";
	int64_t count = 0;
	PackedByteArray calm_a;
	PackedInt32Array state_a;
	PackedVector2Array centre_a;
	PackedFloat32Array bound_r_a;
	if (!contacts_fetch(p_bodies, pass, "slime_count", Variant::INT, count) ||
			!contacts_fetch(p_bodies, pass, "calm", Variant::PACKED_BYTE_ARRAY, calm_a) ||
			!contacts_fetch(p_bodies, pass, "state", Variant::PACKED_INT32_ARRAY, state_a) ||
			!contacts_fetch(p_bodies, pass, "centre", Variant::PACKED_VECTOR2_ARRAY, centre_a) ||
			!contacts_fetch(p_bodies, pass, "bound_r", Variant::PACKED_FLOAT32_ARRAY, bound_r_a)) {
		return false;
	}
	ERR_FAIL_COND_V_MSG(count < 0 || calm_a.size() != count || state_a.size() != count ||
					centre_a.size() != count || bound_r_a.size() != count,
			false, "SlimeSolver.build_pairs: a per-slime array doesn't hold slime_count entries.");
	if (!find_pairs(count, calm_a.ptr(), state_a.ptr(), centre_a.ptr(), bound_r_a.ptr(), pair_scratch)) {
		return false;
	}
	const std::vector<int32_t> &found = pair_scratch.pairs;
	PackedInt32Array pairs_a;
	pairs_a.resize(int64_t(found.size()));
	if (!found.empty()) {
		std::memcpy(pairs_a.ptrw(), found.data(), found.size() * sizeof(int32_t));
	}
	PackedByteArray touch_a;
	touch_a.resize(int64_t(found.size() / 2));
	touch_a.fill(0);
	p_bodies->set(StringName("_pairs"), pairs_a);
	p_bodies->set(StringName("_pair_touch"), touch_a);
	return true;
}

// SlimeBodies._solve_contacts(): ring against ring for every candidate pair
// whose bound circles overlap, both sides in turn (see contact_side).
// @spec-link [[req_waking_sleepers]]
bool SlimeSolver::solve_contacts(Object *p_bodies) {
	ERR_FAIL_NULL_V_MSG(p_bodies, false, "SlimeSolver.solve_contacts: null bodies.");
	const char *pass = "solve_contacts";
	int64_t count = 0;
	PackedInt32Array pairs_a;
	if (!contacts_fetch(p_bodies, pass, "slime_count", Variant::INT, count) ||
			!contacts_fetch(p_bodies, pass, "_pairs", Variant::PACKED_INT32_ARRAY, pairs_a)) {
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
	if (!contacts_fetch(p_bodies, pass, "slime_friction", Variant::FLOAT, mu) ||
			!contacts_fetch(p_bodies, pass, "first", Variant::PACKED_INT32_ARRAY, first_a) ||
			!contacts_fetch(p_bodies, pass, "npts", Variant::PACKED_INT32_ARRAY, npts_a) ||
			!contacts_fetch(p_bodies, pass, "state", Variant::PACKED_INT32_ARRAY, state_a) ||
			!contacts_fetch(p_bodies, pass, "calm", Variant::PACKED_BYTE_ARRAY, calm_a) ||
			!contacts_fetch(p_bodies, pass, "bound_r", Variant::PACKED_FLOAT32_ARRAY, bound_r_a) ||
			!contacts_fetch(p_bodies, pass, "centre", Variant::PACKED_VECTOR2_ARRAY, centre_a) ||
			!contacts_fetch(p_bodies, pass, "angle0", Variant::PACKED_FLOAT32_ARRAY, angle0_a) ||
			!contacts_fetch(p_bodies, pass, "_drift", Variant::PACKED_VECTOR2_ARRAY, drift_a) ||
			!contacts_fetch(p_bodies, pass, "supported", Variant::PACKED_INT32_ARRAY, supported_a) ||
			!contacts_fetch(p_bodies, pass, "_pair_touch", Variant::PACKED_BYTE_ARRAY, pair_touch_a) ||
			!contacts_fetch(p_bodies, pass, "pos", Variant::PACKED_VECTOR2_ARRAY, pos_a) ||
			!contacts_fetch(p_bodies, pass, "prev", Variant::PACKED_VECTOR2_ARRAY, prev_a)) {
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
	for (int64_t i = 0; i < pair_values; i += 2) {
		const int64_t s0 = arr.pairs[i];
		const int64_t s1 = arr.pairs[i + 1];
		const double rr = double(arr.bound_r[s0]) + double(arr.bound_r[s1]);
		if (double((arr.centre[s1] - arr.centre[s0]).length_squared()) >= rr * rr) {
			continue;
		}
		bool touched = false;
		if (!contact_side(arr, s0, s1, mu, touched) || !contact_side(arr, s1, s0, mu, touched)) {
			return false;
		}
		if (touched) {
			arr.pair_touch[i / 2] = 1;
		}
	}
	p_bodies->set(StringName("pos"), pos_a);
	p_bodies->set(StringName("prev"), prev_a);
	p_bodies->set(StringName("supported"), supported_a);
	p_bodies->set(StringName("_pair_touch"), pair_touch_a);
	return true;
}

} // namespace godot
