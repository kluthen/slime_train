// The terrain contacts of the native solver, the shut doors included: a
// port of SlimeBodies._solve_terrain and _solve_against
// (src/sim/slime_bodies.gd), which stay as the fallback.
//
// Marshalling (solver_state.h): this pass reads only what it uses, once per
// call (the per-slime ranges, states and calms, the points, the support
// flags, two tunables, the terrain and the doors) and writes back the three
// arrays it changes: pos, prev and supported.
//
// The terrain and the doors (TerrainSegments) are read afresh on every
// call, nothing of them is kept between calls: their arrays come from get()
// as copy-on-write handles on the GDScript buffers (no copy), so a door that
// opens or shuts (FrontierSets rewrites SlimeBodies.doors every tick) or a
// new terrain is seen at the next call, with nothing to invalidate.
//
// Float types mirror GDScript's: Vector2 math in float32, scalars in double
// (the grid cell, the clamp of t, the skin tests, the support test).

#include "slime_solver.h"

#include <cmath>
#include <utility>
#include <vector>

#include <godot_cpp/core/error_macros.hpp>
#include <godot_cpp/core/math.hpp>
#include <godot_cpp/variant/array.hpp>
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

// Reads the TerrainSegments `p_value` (null: an empty piece). False, with an
// error, when a field is missing or the arrays don't agree; the GDScript
// pass then runs.
bool read_piece(const Variant &p_value, const char *p_what, TerrainPiece &r_piece) {
	r_piece.empty = true;
	if (p_value.get_type() == Variant::NIL) {
		return true;
	}
	ERR_FAIL_COND_V_MSG(p_value.get_type() != Variant::OBJECT, false,
			String("SlimeSolver.solve_terrain: ") + p_what + " is not an object.");
	Object *tf = p_value;
	if (tf == nullptr) {
		return true;
	}
	Variant v;
#define TERRAIN_FETCH(m_name, m_type, m_target) \
	if (!solver_fetch(tf, "SlimeSolver.solve_terrain", p_what, m_name, Variant::m_type, v)) { \
		return false; \
	} \
	m_target = v;
	TERRAIN_FETCH("seg_a", PACKED_VECTOR2_ARRAY, r_piece.seg_a_a)
	if (r_piece.seg_a_a.is_empty()) {
		// TerrainSegments.is_empty(): skipped, whatever its other fields.
		return true;
	}
	TERRAIN_FETCH("seg_d", PACKED_VECTOR2_ARRAY, r_piece.seg_d_a)
	TERRAIN_FETCH("seg_inv_len2", PACKED_FLOAT32_ARRAY, r_piece.seg_inv_len2_a)
	TERRAIN_FETCH("seg_n", PACKED_VECTOR2_ARRAY, r_piece.seg_n_a)
	TERRAIN_FETCH("seg_na", PACKED_VECTOR2_ARRAY, r_piece.seg_na_a)
	TERRAIN_FETCH("seg_nb", PACKED_VECTOR2_ARRAY, r_piece.seg_nb_a)
	TERRAIN_FETCH("cell_start", PACKED_INT32_ARRAY, r_piece.cell_start_a)
	TERRAIN_FETCH("cell_items", PACKED_INT32_ARRAY, r_piece.cell_items_a)
	Vector2 origin;
	TERRAIN_FETCH("origin", VECTOR2, origin)
	TERRAIN_FETCH("inv_cell", FLOAT, r_piece.inv)
	TERRAIN_FETCH("grid_w", INT, r_piece.gw)
	TERRAIN_FETCH("grid_h", INT, r_piece.gh)
#undef TERRAIN_FETCH
	r_piece.ox = origin.x;
	r_piece.oy = origin.y;

	// The shapes the pass relies on: one entry per segment, a start per cell
	// plus one (the items each cell lists are checked as the pass reads them).
	const int64_t segments = r_piece.seg_a_a.size();
	ERR_FAIL_COND_V_MSG(r_piece.seg_d_a.size() != segments || r_piece.seg_inv_len2_a.size() != segments ||
					r_piece.seg_n_a.size() != segments || r_piece.seg_na_a.size() != segments ||
					r_piece.seg_nb_a.size() != segments,
			false, String("SlimeSolver.solve_terrain: ") + p_what + "'s segment arrays differ in size.");
	const int64_t cells = r_piece.gw * r_piece.gh;
	ERR_FAIL_COND_V_MSG(r_piece.gw < 0 || r_piece.gh < 0 || r_piece.cell_start_a.size() < cells + 1, false,
			String("SlimeSolver.solve_terrain: ") + p_what + "'s grid doesn't hold grid_w * grid_h + 1 starts.");
	r_piece.cell_start = r_piece.cell_start_a.ptr();
	r_piece.cell_items = r_piece.cell_items_a.ptr();
	r_piece.segments = segments;
	r_piece.items = r_piece.cell_items_a.size();
	r_piece.seg_a = r_piece.seg_a_a.ptr();
	r_piece.seg_d = r_piece.seg_d_a.ptr();
	r_piece.seg_n = r_piece.seg_n_a.ptr();
	r_piece.seg_na = r_piece.seg_na_a.ptr();
	r_piece.seg_nb = r_piece.seg_nb_a.ptr();
	r_piece.seg_inv_len2 = r_piece.seg_inv_len2_a.ptr();
	r_piece.empty = false;
	return true;
}

// What one pass reads and writes of the SlimeBodies.
struct TerrainBodies {
	int64_t slime_count = 0;
	const int32_t *first = nullptr;
	const int32_t *npts = nullptr;
	const int32_t *state = nullptr;
	const uint8_t *calm = nullptr;
	Vector2 *pos = nullptr;
	Vector2 *prev = nullptr;
	int32_t *supported = nullptr;
	double keep = 0.0;
	double skin = 0.0;
	// Per slime, the box holding its points (_box_lo, _box_hi), this
	// call's scratch.
	Vector2 *box_lo = nullptr;
	Vector2 *box_hi = nullptr;
};

// The boxes' storage, kept between calls only so it isn't allocated again.
thread_local std::vector<Vector2> box_scratch;

// SlimeBodies._solve_against: one pass of ring points against `p_tf`.
// `p_measure`: sets each simulated slime's box to hold its points before
// and after the pass. `p_by_box`: skips the slimes whose box (set by an
// earlier pass of this call) is outside the piece's grid, and grows the box
// by every point it moves. False when the piece's grid lists an item or a
// segment it doesn't have (nothing is written back then).
bool solve_against(TerrainBodies &b, const TerrainPiece &tf, bool p_measure, bool p_by_box) {
	const Vector2 *sa = tf.seg_a;
	const Vector2 *sdir = tf.seg_d;
	const float *sil = tf.seg_inv_len2;
	const Vector2 *sn = tf.seg_n;
	const Vector2 *sna = tf.seg_na;
	const Vector2 *snb = tf.seg_nb;
	const int32_t *starts = tf.cell_start;
	const int32_t *items = tf.cell_items;
	const double ox = tf.ox;
	const double oy = tf.oy;
	const double inv = tf.inv;
	const double gw = double(tf.gw);
	const double gh = double(tf.gh);
	const int64_t gw_i = tf.gw;
	const int64_t item_count = tf.items;
	const int64_t segment_count = tf.segments;
	const real_t keep = real_t(b.keep);
	const double skin = b.skin;
	const real_t skin_f = real_t(skin);
	const double skin2 = skin * skin;
	const bool track = p_measure || p_by_box;
	Vector2 *p = b.pos;
	Vector2 *o = b.prev;
	for (int64_t s = 0; s < b.slime_count; s++) {
		if (b.state[s] == slime_const::STATE_SLEEPER || b.calm[s] != slime_const::ACTIVE) {
			continue;
		}
		Vector2 lo(INFINITY, INFINITY);
		Vector2 hi(-INFINITY, -INFINITY);
		if (p_by_box) {
			lo = b.box_lo[s];
			hi = b.box_hi[s];
			// The per-point grid test is monotonic in x and y: when the box's
			// far corner is off one side of the grid, so is every point.
			// (Written as "not inside" so a NaN is off the grid, as GDScript's
			// int(NaN) is.)
			if (!(Math::floor((double(hi.x) - ox) * inv) >= 0.0) || !(Math::floor((double(hi.y) - oy) * inv) >= 0.0) ||
					!(Math::floor((double(lo.x) - ox) * inv) < gw) || !(Math::floor((double(lo.y) - oy) * inv) < gh)) {
				continue;
			}
		}
		const int64_t f = b.first[s];
		const int64_t end = f + b.npts[s];
		bool carried = false;
		for (int64_t i = f; i < end; i++) {
			const Vector2 c = p[i];
			if (p_measure) {
				lo = lo.min(c);
				hi = hi.max(c);
			}
			const double fx = Math::floor((double(c.x) - ox) * inv);
			const double fy = Math::floor((double(c.y) - oy) * inv);
			if (!(fx >= 0.0 && fy >= 0.0 && fx < gw && fy < gh)) {
				continue;
			}
			const int64_t cell = int64_t(fy) * gw_i + int64_t(fx);
			int64_t best = -1;
			double best_d2 = INFINITY;
			Vector2 best_q;
			double best_t = 0.0;
			const int32_t q_start = starts[cell];
			const int32_t q_end = starts[cell + 1];
			if (q_start < 0 || q_end > item_count) {
				ERR_FAIL_V_MSG(false, "SlimeSolver.solve_terrain: a cell lists items the grid doesn't have.");
			}
			for (int32_t qi = q_start; qi < q_end; qi++) {
				const int32_t k = items[qi];
				if (k < 0 || k >= segment_count) {
					ERR_FAIL_V_MSG(false, "SlimeSolver.solve_terrain: a cell lists a segment the piece doesn't have.");
				}
				const Vector2 a = sa[k];
				const Vector2 d = sdir[k];
				const double t = CLAMP(double((c - a).dot(d)) * double(sil[k]), 0.0, 1.0);
				const Vector2 q = a + d * real_t(t);
				const double d2 = c.distance_squared_to(q);
				if (d2 < best_d2) {
					best_d2 = d2;
					best = k;
					best_q = q;
					best_t = t;
				}
			}
			if (best < 0) {
				continue;
			}
			Vector2 n = sn[best];
			const Vector2 off = c - best_q;
			// Inside or out: at a segment's end, by the vertex's normal
			// (TerrainSegments.side_normal).
			Vector2 side = n;
			if (best_t <= 0.0) {
				side = sna[best];
			} else if (best_t >= 1.0) {
				side = snb[best];
			}
			if (double(off.dot(side)) >= 0.0) {
				// Outside: only within the skin, pushed away from the nearest
				// surface point (round around convex corners).
				if (best_d2 >= skin2) {
					continue;
				}
				if (best_d2 > 1e-8) {
					n = off / real_t(std::sqrt(best_d2));
				}
			}
			const Vector2 target = best_q + n * skin_f;
			p[i] = target;
			if (track) {
				lo = lo.min(target);
				hi = hi.max(target);
			}
			const Vector2 v = target - o[i];
			const double vn = v.dot(n);
			const Vector2 vt = v - n * real_t(vn);
			o[i] = target - (vt * keep + n * real_t(MAX(vn, 0.0)));
			if (double(n.y) < -slime_const::SUPPORT_NORMAL_Y) {
				carried = true;
			}
		}
		if (carried) {
			b.supported[s] = 1;
		}
		if (track) {
			b.box_lo[s] = lo;
			b.box_hi[s] = hi;
		}
	}
	return true;
}

// The terrain pass, then one pass per shut door (see
// SlimeSolver::solve_terrain), on `b` against `p_pieces` (not empty). False
// when a piece's grid can't be read.
bool terrain_passes(TerrainBodies &b, const TerrainPieces &p_pieces) {
	const bool door_shut = !p_pieces.shut.empty();
	if (door_shut) {
		const size_t n = size_t(b.slime_count);
		if (box_scratch.size() < 2 * n) {
			box_scratch.resize(2 * n);
		}
		b.box_lo = box_scratch.data();
		b.box_hi = box_scratch.data() + n;
	}
	bool measured = false;
	if (!p_pieces.terrain.empty) {
		if (!solve_against(b, p_pieces.terrain, door_shut, false)) {
			return false;
		}
		measured = door_shut;
	}
	for (const TerrainPiece &door : p_pieces.shut) {
		if (!solve_against(b, door, !measured, measured)) {
			return false;
		}
		measured = true;
	}
	return true;
}

} // namespace

bool read_terrain_pieces(const Variant &p_terrain, const Array &p_doors, TerrainPieces &r_pieces) {
	r_pieces.shut.clear();
	if (!read_piece(p_terrain, "terrain", r_pieces.terrain)) {
		return false;
	}
	const int64_t door_count = p_doors.size();
	r_pieces.shut.reserve(door_count);
	for (int64_t k = 0; k < door_count; k++) {
		TerrainPiece door;
		if (!read_piece(p_doors[k], "a door", door)) {
			return false;
		}
		if (!door.empty) {
			r_pieces.shut.push_back(std::move(door));
		}
	}
	return true;
}

// The terrain contacts on a whole tick's state (solver_passes.h), against
// the pieces step() read once for the tick.
bool terrain_state(SolverState &r_st, const TerrainPieces &p_pieces) {
	if (p_pieces.empty()) {
		return true;
	}
	TerrainBodies b;
	b.slime_count = r_st.slime_count;
	b.first = r_st.first;
	b.npts = r_st.npts;
	b.state = r_st.state;
	b.calm = r_st.calm;
	b.keep = 1.0 - r_st.terrain_friction;
	b.skin = r_st.terrain_skin;
	b.pos = r_st.pos;
	b.prev = r_st.prev;
	b.supported = r_st.supported;
	return terrain_passes(b, p_pieces);
}

// SlimeBodies._solve_terrain: the terrain pass, then one pass per shut door
// (a door with segments). The first pass (the terrain's, else the first
// door's) measures each slime's box when a door pass follows; the door
// passes after it skip the slimes whose box lies outside the door's grid.
bool SlimeSolver::solve_terrain(Object *p_bodies) {
	ERR_FAIL_NULL_V_MSG(p_bodies, false, "SlimeSolver.solve_terrain: null bodies.");
	Variant v;
	int64_t slime_count = 0;
	PackedInt32Array first_a, npts_a, state_a, supported_a;
	PackedByteArray calm_a;
	PackedVector2Array pos_a, prev_a;
	double terrain_friction = 0.0;
	double terrain_skin = 0.0;
	Array doors;
#define BODIES_FETCH(m_name, m_type, m_target) \
	if (!solver_fetch(p_bodies, "SlimeSolver.solve_terrain", "SlimeBodies", m_name, Variant::m_type, v)) { \
		return false; \
	} \
	m_target = v;
	BODIES_FETCH("slime_count", INT, slime_count)
	BODIES_FETCH("first", PACKED_INT32_ARRAY, first_a)
	BODIES_FETCH("npts", PACKED_INT32_ARRAY, npts_a)
	BODIES_FETCH("state", PACKED_INT32_ARRAY, state_a)
	BODIES_FETCH("calm", PACKED_BYTE_ARRAY, calm_a)
	BODIES_FETCH("supported", PACKED_INT32_ARRAY, supported_a)
	BODIES_FETCH("pos", PACKED_VECTOR2_ARRAY, pos_a)
	BODIES_FETCH("prev", PACKED_VECTOR2_ARRAY, prev_a)
	BODIES_FETCH("terrain_friction", FLOAT, terrain_friction)
	BODIES_FETCH("terrain_skin", FLOAT, terrain_skin)
	BODIES_FETCH("doors", ARRAY, doors)
#undef BODIES_FETCH

	TerrainPieces pieces;
	if (!read_terrain_pieces(p_bodies->get(StringName("terrain")), doors, pieces)) {
		return false;
	}
	if (pieces.empty()) {
		// Nothing to collide with: nothing changes (as in GDScript).
		return true;
	}

	const int64_t n = slime_count;
	const int64_t points = pos_a.size();
	ERR_FAIL_COND_V_MSG(prev_a.size() != points, false, "SlimeSolver.solve_terrain: pos and prev differ in size.");
	ERR_FAIL_COND_V_MSG(n < 0 || first_a.size() != n || npts_a.size() != n || state_a.size() != n ||
					calm_a.size() != n || supported_a.size() != n,
			false, "SlimeSolver.solve_terrain: a per-slime array doesn't hold slime_count entries.");
	TerrainBodies b;
	b.slime_count = n;
	b.first = first_a.ptr();
	b.npts = npts_a.ptr();
	b.state = state_a.ptr();
	b.calm = calm_a.ptr();
	for (int64_t s = 0; s < n; s++) {
		ERR_FAIL_COND_V_MSG(b.first[s] < 0 || b.npts[s] < 0 || int64_t(b.first[s]) + b.npts[s] > points, false,
				"SlimeSolver.solve_terrain: a slime's point range is outside the point arrays.");
	}
	b.keep = 1.0 - terrain_friction;
	b.skin = terrain_skin;
	b.pos = pos_a.ptrw();
	b.prev = prev_a.ptrw();
	b.supported = supported_a.ptrw();
	if (!terrain_passes(b, pieces)) {
		return false;
	}

	p_bodies->set(StringName("pos"), pos_a);
	p_bodies->set(StringName("prev"), prev_a);
	p_bodies->set(StringName("supported"), supported_a);
	return true;
}

} // namespace godot
