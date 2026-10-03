// The rest pass of the native solver, with the local wake (SlimeBodies._rest,
// _rest_piles, _wake_at): not native yet, so SlimeBodies.tick() runs the
// GDScript pass.

#include "slime_solver.h"

namespace godot {

// @spec-link [[req_offscreen_simulation]]
bool SlimeSolver::rest(Object *p_bodies, double p_h) {
	return false;
}

} // namespace godot
