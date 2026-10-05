// The pair grid of the native solver: SlimeBodies._build_pairs()
// (src/sim/slime_bodies.gd), ported line for line. A counting sort of the
// slimes into a uniform grid on their centres (parked slimes left out), then
// the candidate pairs (index s < t, at most one wall, the scan stopping at
// the last mover), in GDScript's order: _pairs is state GDScript reads after
// the solver (the touching list, the rest pass), so it must be the same
// list, element for element. The grid itself is native scratch (file-local,
// reused from call to call; the simulation runs on one thread);
// SlimeBodies' own grid fields are only the GDScript pass's scratch and are
// left as they are. The contacts that use the pairs: solver_contacts.cpp.
//
// Precision mirrors GDScript: the centres are float32 (Vector2), the cell
// size and the distance test doubles.
//
// The pass reads only the fields it needs, once per call, and writes back
// _pairs and _pair_touch; step() runs it on the whole tick's state
// (build_pairs_state, solver_passes.h). A field it can't rely on (missing,
// retyped, sizes that don't agree, a centre that isn't finite) is an error:
// the pass returns false before writing anything, and SlimeBodies runs its
// GDScript pass instead.

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

#include "solver_passes.h"
#include "solver_state.h"

namespace godot {

namespace {

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
// with an error, when a centre in the grid (not parked) or the crowd's
// extent isn't finite (a NaN or infinite centre: no grid can hold it).
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
		// A NaN would slip through min() and max() (every comparison with it
		// is false) and then make a cell index out of nothing: refused here.
		if (!std::isfinite(p_centre[s].x) || !std::isfinite(p_centre[s].y)) {
			ERR_PRINT("SlimeSolver.build_pairs: a slime's centre isn't finite.");
			return false;
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

// `p_found` (two slime indices per pair) as _pairs into `r_pairs`, and a
// cleared _pair_touch (one entry per pair) into `r_touch`.
void store_pairs(const std::vector<int32_t> &p_found, PackedInt32Array &r_pairs, PackedByteArray &r_touch) {
	r_pairs.resize(int64_t(p_found.size()));
	if (!p_found.empty()) {
		std::memcpy(r_pairs.ptrw(), p_found.data(), p_found.size() * sizeof(int32_t));
	}
	r_touch.resize(int64_t(p_found.size() / 2));
	r_touch.fill(0);
}

} // namespace

// The pair grid on a whole tick's state (solver_passes.h): the state's
// _pairs and _pair_touch replaced.
bool build_pairs_state(SolverState &r_st) {
	if (!find_pairs(r_st.slime_count, r_st.calm, r_st.state, r_st.centre, r_st.bound_r, pair_scratch)) {
		return false;
	}
	store_pairs(pair_scratch.pairs, r_st.pairs_a, r_st.pair_touch_a);
	return true;
}

// SlimeBodies._build_pairs(): the pair grid, then _pairs and a cleared
// _pair_touch (see the file header).
// @spec-link [[req_waking_sleepers]]
bool SlimeSolver::build_pairs(Object *p_bodies) {
	ERR_FAIL_NULL_V_MSG(p_bodies, false, "SlimeSolver.build_pairs: null bodies.");
	const char *pass = "SlimeSolver.build_pairs";
	int64_t count = 0;
	PackedByteArray calm_a;
	PackedInt32Array state_a;
	PackedVector2Array centre_a;
	PackedFloat32Array bound_r_a;
	if (!solver_fetch_as(p_bodies, pass, "SlimeBodies", "slime_count", Variant::INT, count) ||
			!solver_fetch_as(p_bodies, pass, "SlimeBodies", "calm", Variant::PACKED_BYTE_ARRAY, calm_a) ||
			!solver_fetch_as(p_bodies, pass, "SlimeBodies", "state", Variant::PACKED_INT32_ARRAY, state_a) ||
			!solver_fetch_as(p_bodies, pass, "SlimeBodies", "centre", Variant::PACKED_VECTOR2_ARRAY, centre_a) ||
			!solver_fetch_as(p_bodies, pass, "SlimeBodies", "bound_r", Variant::PACKED_FLOAT32_ARRAY, bound_r_a)) {
		return false;
	}
	ERR_FAIL_COND_V_MSG(count < 0 || calm_a.size() != count || state_a.size() != count ||
					centre_a.size() != count || bound_r_a.size() != count,
			false, "SlimeSolver.build_pairs: a per-slime array doesn't hold slime_count entries.");
	if (!find_pairs(count, calm_a.ptr(), state_a.ptr(), centre_a.ptr(), bound_r_a.ptr(), pair_scratch)) {
		return false;
	}
	PackedInt32Array pairs_a;
	PackedByteArray touch_a;
	store_pairs(pair_scratch.pairs, pairs_a, touch_a);
	p_bodies->set(StringName("_pairs"), pairs_a);
	p_bodies->set(StringName("_pair_touch"), touch_a);
	return true;
}

} // namespace godot
