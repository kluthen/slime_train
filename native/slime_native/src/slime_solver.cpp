// The native solver's class and its bindings (slime_solver.h). The passes
// live one per file: solver_integrate.cpp, solver_contacts.cpp (the pair
// grid and the contacts), solver_rings.cpp, solver_terrain.cpp,
// solver_rest.cpp.

// @spec-link [[req_waking_sleepers]]
// @spec-link [[req_slime_states]]

#include "slime_solver.h"

#include <godot_cpp/core/class_db.hpp>

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

// Not native yet: every pass runs in GDScript.
bool SlimeSolver::step(Object *p_bodies, double p_h) {
	return false;
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
