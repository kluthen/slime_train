#pragma once

// @spec-link [[req_waking_sleepers]]
// @spec-link [[req_slime_states]]

#include <godot_cpp/classes/object.hpp>
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/packed_string_array.hpp>
#include <godot_cpp/variant/vector2.hpp>

namespace godot {

// The native simulation tick (chunk 5N, D158): the solver passes of
// SlimeBodies.tick() (src/sim/slime_bodies.gd), run on a SlimeBodies object
// whose arrays it reads and writes by name (solver_state.h). It holds no
// state between calls but scratch, so a save doesn't depend on the tick that
// wrote it. Created and called by SlimeBodies only through ClassDB, so the
// scripts parse without the extension (src/sim/tick_choice.gd picks the
// tick).
//
// SlimeBodies.tick() calls step(), the whole solver part of the tick in one
// call. It and every one-pass method return true when they ran natively and
// false, with an error and before writing anything, when they can't read
// the bodies: tick() then runs the passes one by one (SlimeBodies._solve),
// each native pass that returns false replaced by its GDScript pass. The
// one-pass methods share step()'s passes (solver_passes.h); the equivalence
// tests check each of them against its GDScript pass.
class SlimeSolver : public RefCounted {
	GDCLASS(SlimeSolver, RefCounted)

protected:
	static void _bind_methods();

public:
	// The whole solver part of one tick (substeps: integrate, the pair grid on
	// the first, iterations of contacts, rings and terrain; then the centre
	// cache cleared, the touching list and the rest pass), with substep
	// length `p_h` in seconds: SlimeBodies._solve in one call, every field
	// read once and written back once.
	bool step(Object *p_bodies, double p_h);
	// One pass each (SlimeBodies' _integrate, _build_pairs, _solve_contacts,
	// _solve_rings, _solve_terrain with the doors, _rest).
	bool integrate(Object *p_bodies, double p_h);
	bool build_pairs(Object *p_bodies);
	bool solve_contacts(Object *p_bodies);
	bool solve_rings(Object *p_bodies);
	bool solve_terrain(Object *p_bodies);
	bool rest(Object *p_bodies, double p_h);

	// What keeps the solver from reading and writing `p_bodies`: a missing or
	// retyped field, a missing or changed constant, a terrain or door missing
	// a field. Empty when it can.
	PackedStringArray check_schema(Object *p_bodies) const;

	// The marshalling probe: reads `p_bodies` the way every pass does, moves
	// every point (pos and prev) by `p_delta`, and writes the arrays back.
	// False, with an error printed, when it can't read them. It proves a
	// native write reaches the GDScript arrays, since a packed array passed as
	// an argument would only be a copy (solver_state.h).
	bool probe_marshal(Object *p_bodies, const Vector2 &p_delta);
};

} // namespace godot
