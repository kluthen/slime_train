#pragma once

// The solver passes as the native solver runs them, shared by
// SlimeSolver::step() (the whole solver part of a tick in one call,
// slime_solver.cpp) and the one-pass methods (integrate, build_pairs,
// solve_contacts, solve_rings, solve_terrain, rest: each in its pass's file),
// so both run one implementation of each pass.
//
// The *_state functions run one pass on a SolverState loaded once for the
// whole tick (solver_state.h): they read and write its arrays in place, and
// nothing reaches the SlimeBodies before SolverState::store(). A pass that
// returns false has printed an error; step() then returns false without
// storing anything, and SlimeBodies runs the tick pass by pass instead.

#include <vector>

#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/packed_vector2_array.hpp>
#include <godot_cpp/variant/variant.hpp>
#include <godot_cpp/variant/vector2.hpp>

#include "solver_state.h"

namespace godot {

// SlimeBodies._is_wall(): a sleeper, or a resting slime (the pair grid and
// the contacts).
inline bool is_wall(int32_t p_state, uint8_t p_calm) {
	return p_state == slime_const::STATE_SLEEPER || p_calm == slime_const::RESTING;
}

// One TerrainSegments (the terrain or a door), read for one call
// (solver_terrain.cpp).
struct TerrainPiece {
	PackedVector2Array seg_a_a, seg_d_a, seg_n_a, seg_na_a, seg_nb_a;
	PackedFloat32Array seg_inv_len2_a;
	PackedInt32Array cell_start_a, cell_items_a;
	const Vector2 *seg_a = nullptr;
	const Vector2 *seg_d = nullptr;
	const Vector2 *seg_n = nullptr;
	const Vector2 *seg_na = nullptr;
	const Vector2 *seg_nb = nullptr;
	const float *seg_inv_len2 = nullptr;
	const int32_t *cell_start = nullptr;
	const int32_t *cell_items = nullptr;
	double ox = 0.0;
	double oy = 0.0;
	double inv = 0.0;
	int64_t gw = 0;
	int64_t gh = 0;
	// The sizes the pass checks its reads against (a cell's range of
	// items, an item's segment): checked as read, not up front, so a call
	// costs nothing per cell of the grid.
	int64_t segments = 0;
	int64_t items = 0;
	bool empty = true;
};

// The terrain and the shut doors (the doors with segments, in order; the
// empty and null ones do nothing), read once per call.
struct TerrainPieces {
	TerrainPiece terrain;
	std::vector<TerrainPiece> shut;

	// Whether there is nothing to collide with.
	bool empty() const {
		return terrain.empty && shut.empty();
	}
};

// Reads the terrain `p_terrain` (a TerrainSegments or null) and the doors
// `p_doors` into `r_pieces`. False, with an error, when a piece is missing a
// field or its arrays don't agree.
bool read_terrain_pieces(const Variant &p_terrain, const Array &p_doors, TerrainPieces &r_pieces);

// SlimeBodies._integrate(h) (solver_integrate.cpp).
void integrate_state(SolverState &r_st, double p_h);
// SlimeBodies._build_pairs(): _pairs and a cleared _pair_touch
// (solver_pairs.cpp). False when a centre isn't finite.
bool build_pairs_state(SolverState &r_st);
// SlimeBodies._solve_contacts() (solver_contacts.cpp). False when _pairs or
// a ring can't be read (a pair that isn't two slimes, an empty ring, an
// angle0 out of [-PI, PI]).
bool contacts_state(SolverState &r_st);
// SlimeBodies._solve_rings() (solver_rings.cpp).
void rings_state(SolverState &r_st);
// SlimeBodies._solve_terrain(), the shut doors included, against `p_pieces`
// (solver_terrain.cpp). False when a piece's grid lists an item or a
// segment it doesn't have.
bool terrain_state(SolverState &r_st, const TerrainPieces &p_pieces);
// SlimeBodies._rest() with the local wake, `p_h` the substep length
// (solver_rest.cpp). False, before any change, when _pairs and _pair_touch
// don't agree or a pair names no slime.
bool rest_state(SolverState &r_st, double p_h);

} // namespace godot
