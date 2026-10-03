// The terrain contacts of the native solver, the shut doors included
// (SlimeBodies._solve_terrain, _solve_against): not native yet, so
// SlimeBodies.tick() runs the GDScript pass.

#include "slime_solver.h"

namespace godot {

bool SlimeSolver::solve_terrain(Object *p_bodies) {
	return false;
}

} // namespace godot
