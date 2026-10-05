// The native solver's class, its bindings and step(), the whole solver part
// of a tick in one call (slime_solver.h). The passes live one per file:
// solver_integrate.cpp, solver_pairs.cpp (the pair grid),
// solver_contacts.cpp, solver_rings.cpp, solver_terrain.cpp,
// solver_rest.cpp; step() and the one-pass methods share them through
// solver_passes.h.

// @spec-link [[req_waking_sleepers]]
// @spec-link [[req_slime_states]]

#include "slime_solver.h"

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/vector2i.hpp>

#include "solver_passes.h"
#include "solver_state.h"

namespace godot {

void SlimeSolver::_bind_methods() {
	ClassDB::bind_method(D_METHOD("step", "bodies", "h"), &SlimeSolver::step);
	ClassDB::bind_method(D_METHOD("integrate", "bodies", "h"), &SlimeSolver::integrate);
	ClassDB::bind_method(D_METHOD("build_pairs", "bodies"), &SlimeSolver::build_pairs);
	ClassDB::bind_method(D_METHOD("solve_contacts", "bodies"), &SlimeSolver::solve_contacts);
	ClassDB::bind_method(D_METHOD("solve_rings", "bodies"), &SlimeSolver::solve_rings);
	ClassDB::bind_method(D_METHOD("solve_terrain", "bodies"), &SlimeSolver::solve_terrain);
	ClassDB::bind_method(D_METHOD("rest", "bodies", "h"), &SlimeSolver::rest);
	ClassDB::bind_method(D_METHOD("check_schema", "bodies"), &SlimeSolver::check_schema);
	ClassDB::bind_method(D_METHOD("probe_marshal", "bodies", "delta"), &SlimeSolver::probe_marshal);
}

namespace {

// SlimeBodies._solve()'s touching list: the slime ids of every pair that
// touched (_pair_touch), in pair order, as Vector2i(id a, id b). Rewritten in
// place in the bodies' own Array (shared, not a copy): resized only when the
// count changes.
void build_touching(SolverState &r_st) {
	const int64_t pair_count = r_st.pair_touch_a.size();
	const uint8_t *touch = r_st.pair_touch_a.ptr();
	const int32_t *pairs = r_st.pairs_a.ptr();
	int64_t count = 0;
	for (int64_t k = 0; k < pair_count; k++) {
		count += touch[k] != 0 ? 1 : 0;
	}
	r_st.touching.resize(count);
	int64_t at = 0;
	for (int64_t k = 0; k < pair_count; k++) {
		if (touch[k] != 0) {
			r_st.touching[at] = Vector2i(r_st.id[pairs[2 * k]], r_st.id[pairs[2 * k + 1]]);
			at++;
		}
	}
}

} // namespace

// SlimeBodies._solve() in one call, in its order: `substeps` times
// integrate, the pair grid (first substep), then `iterations` times the
// contacts, rings and terrain (the shut doors included); then the centre
// cache cleared (_centre_ok), the touching list and the rest pass. Every
// field is read once (SolverState::load) and the terrain and doors once,
// the passes run on that state, and it is written back once at the end
// (store). Anything it can't read (a field, a size, a pair, a ring, a grid)
// is an error: it returns false before anything reaches the bodies (the
// touching list is rebuilt after the last pass that can fail), and
// SlimeBodies runs the tick pass by pass instead.
// @spec-link [[req_tilt_input]]
// @spec-link [[req_slime_states]]
// @spec-link [[req_waking_sleepers]]
// @spec-link [[req_offscreen_simulation]]
bool SlimeSolver::step(Object *p_bodies, double p_h) {
	SolverState st;
	if (!st.load(p_bodies)) {
		return false;
	}
	TerrainPieces pieces;
	if (!read_terrain_pieces(st.terrain_value, st.doors, pieces)) {
		return false;
	}
	for (int64_t sub = 0; sub < st.substeps; sub++) {
		integrate_state(st, p_h);
		if (sub == 0 && !build_pairs_state(st)) {
			return false;
		}
		for (int64_t it = 0; it < st.iterations; it++) {
			if (!contacts_state(st)) {
				return false;
			}
			rings_state(st);
			if (!terrain_state(st, pieces)) {
				return false;
			}
		}
	}
	// As _solve: every centre-cache entry stale (the points moved); the
	// cached centres themselves are left as they are.
	const int64_t n = st.slime_count;
	for (int64_t s = 0; s < n; s++) {
		st.centre_ok[s] = 0;
	}
	if (!rest_state(st, p_h)) {
		return false;
	}
	// The rest pass reads neither the touching list nor changes the pairs,
	// so building it after (it's written in place) gives _solve's list.
	build_touching(st);
	st.store(p_bodies);
	return true;
}

PackedStringArray SlimeSolver::check_schema(Object *p_bodies) const {
	return solver_schema_problems(p_bodies);
}

bool SlimeSolver::probe_marshal(Object *p_bodies, const Vector2 &p_delta) {
	SolverState st;
	if (!st.load(p_bodies)) {
		return false;
	}
	const int64_t points = st.pos_a.size();
	for (int64_t i = 0; i < points; i++) {
		st.pos[i] += p_delta;
		st.prev[i] += p_delta;
	}
	st.store(p_bodies);
	return true;
}

} // namespace godot
