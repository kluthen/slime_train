// The pair grid and the slime contacts of the native solver
// (SlimeBodies._build_pairs, _solve_contacts): not native yet, so
// SlimeBodies.tick() runs the GDScript passes.

#include "slime_solver.h"

namespace godot {

bool SlimeSolver::build_pairs(Object *p_bodies) {
	return false;
}

bool SlimeSolver::solve_contacts(Object *p_bodies) {
	return false;
}

} // namespace godot
