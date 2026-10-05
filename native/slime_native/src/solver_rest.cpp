// The rest pass of the native solver, with the local wake (D156): a line-for-
// line port of SlimeBodies._rest, _rest_piles and _wake_at
// (src/sim/slime_bodies.gd; see the resting-pile rule in its class doc).
// Piles rest whole: a group of touching active pile slimes (in a basket, or
// asleep at bedtime) rests together once every member has been supported
// and still for REST_TICKS. They wake locally: a resting slime touching an
// active slime that moves faster than WAKE_SPEED wakes alone, the rest of
// its pile rests on.
//
// Same arithmetic as the GDScript: the speed and drift tests are float32
// (Vector2) squared lengths compared with double thresholds, the rest is
// copies and integers, so the pass gives GDScript's result bit for bit.
//
// It reads only the fields it needs and writes back only the arrays it
// changed: in a crowd with no pile slime (no wake, no count) it writes
// nothing.

#include "slime_solver.h"

#include <godot_cpp/core/error_macros.hpp>

#include <algorithm>
#include <cstring>
#include <vector>

#include "solver_passes.h"
#include "solver_state.h"

namespace godot {

namespace {

using namespace slime_const;

// A read-write array of the pass: read through `r`; `w()` takes the write
// pointer on the first write (ptrw() copies the shared buffer once), and
// marks the array to be stored.
template <typename A, typename T>
struct RestArray {
	A arr;
	const T *r = nullptr;
	T *wp = nullptr;
	// False when bound to a whole tick's state (bind): never stored from here.
	bool own = true;

	// Takes the array; its read pointer.
	void take(const Variant &p_value) {
		arr = p_value;
		r = arr.ptr();
	}
	// Binds the array to `p_data`, already writable (a whole tick's state,
	// solver_passes.h): read and written in place, stored by its owner.
	void bind(T *p_data) {
		r = p_data;
		wp = p_data;
		own = false;
	}
	// The write pointer (the read pointer follows it).
	T *w() {
		if (wp == nullptr) {
			wp = arr.ptrw();
			r = wp;
		}
		return wp;
	}
	// Writes `p_value` at `p_i` when it differs bit for bit (an equal write
	// is invisible, so the array stays unstored).
	void put(int64_t p_i, const T &p_value) {
		if (std::memcmp(&r[p_i], &p_value, sizeof(T)) != 0) {
			w()[p_i] = p_value;
		}
	}
	// Writes the array back to `p_bodies` as `p_name` if it changed.
	void store(Object *p_bodies, const char *p_name) const {
		if (own && wp != nullptr) {
			p_bodies->set(StringName(p_name), arr);
		}
	}
};

// The fields of one rest pass (see the file header).
struct RestState {
	int64_t n = 0;
	bool rest_enabled = false;
	PackedInt32Array state_a, id_a, first_a, npts_a, supported_a, pairs_a;
	PackedByteArray pair_touch_a;
	PackedVector2Array centre_a, pos_a;
	const int32_t *state = nullptr;
	const int32_t *id = nullptr;
	const int32_t *first = nullptr;
	const int32_t *npts = nullptr;
	const int32_t *supported = nullptr;
	const int32_t *pairs = nullptr;
	const uint8_t *pair_touch = nullptr;
	const Vector2 *centre = nullptr;
	const Vector2 *pos = nullptr;
	int64_t pair_count = 0;

	RestArray<PackedByteArray, uint8_t> calm;
	RestArray<PackedInt32Array, int32_t> still_ticks;
	RestArray<PackedVector2Array, Vector2> rest_anchor;
	RestArray<PackedInt32Array, int32_t> pile;
	RestArray<PackedVector2Array, Vector2> drift;
	RestArray<PackedVector2Array, Vector2> prev;

	// Reads the fields; false, with an error, when one is missing, retyped,
	// or the sizes don't agree.
	bool load(Object *p_bodies);
	// Takes the fields from a whole tick's state (its arrays written in
	// place); false, with an error, when _pairs and _pair_touch don't agree
	// or a pair names no slime (SolverState::load checked the rest).
	bool bind(SolverState &r_st);
	// The checks load() and bind() share on the pairs.
	bool pairs_valid() const;
	// Writes back the arrays that changed.
	void store(Object *p_bodies) const;

	// Whether slime `s` may rest (SlimeBodies._can_rest): the pile states.
	bool can_rest(int64_t s) const {
		return state[s] == STATE_IN_BASKET || state[s] == STATE_BEDTIME_ASLEEP;
	}
	// SlimeBodies._wake_at: wakes slime `s` alone when it rests (it leaves
	// its pile); an active slime starts its still count again.
	void wake_at(int64_t s) {
		if (calm.r[s] == RESTING) {
			calm.w()[s] = ACTIVE;
			pile.put(s, 0);
		}
		if (calm.r[s] == ACTIVE) {
			still_ticks.put(s, 0);
			rest_anchor.put(s, centre[s]);
		}
	}
};

bool RestState::load(Object *p_bodies) {
	ERR_FAIL_NULL_V_MSG(p_bodies, false, "SlimeSolver.rest: null bodies.");
	Variant v;
#define REST_FETCH(m_name, m_type) \
	if (!solver_fetch(p_bodies, "SlimeSolver.rest", "SlimeBodies", m_name, Variant::m_type, v)) { \
		return false; \
	}
	REST_FETCH("slime_count", INT)
	n = v;
	REST_FETCH("rest_enabled", BOOL)
	rest_enabled = v;
	REST_FETCH("state", PACKED_INT32_ARRAY)
	state_a = v;
	REST_FETCH("id", PACKED_INT32_ARRAY)
	id_a = v;
	REST_FETCH("first", PACKED_INT32_ARRAY)
	first_a = v;
	REST_FETCH("npts", PACKED_INT32_ARRAY)
	npts_a = v;
	REST_FETCH("supported", PACKED_INT32_ARRAY)
	supported_a = v;
	REST_FETCH("_pairs", PACKED_INT32_ARRAY)
	pairs_a = v;
	REST_FETCH("_pair_touch", PACKED_BYTE_ARRAY)
	pair_touch_a = v;
	REST_FETCH("centre", PACKED_VECTOR2_ARRAY)
	centre_a = v;
	REST_FETCH("pos", PACKED_VECTOR2_ARRAY)
	pos_a = v;
	REST_FETCH("calm", PACKED_BYTE_ARRAY)
	calm.take(v);
	REST_FETCH("still_ticks", PACKED_INT32_ARRAY)
	still_ticks.take(v);
	REST_FETCH("rest_anchor", PACKED_VECTOR2_ARRAY)
	rest_anchor.take(v);
	REST_FETCH("pile", PACKED_INT32_ARRAY)
	pile.take(v);
	REST_FETCH("_drift", PACKED_VECTOR2_ARRAY)
	drift.take(v);
	REST_FETCH("prev", PACKED_VECTOR2_ARRAY)
	prev.take(v);
#undef REST_FETCH

	const int64_t per_slime[] = { state_a.size(), id_a.size(), first_a.size(), npts_a.size(), supported_a.size(),
		centre_a.size(), calm.arr.size(), still_ticks.arr.size(), rest_anchor.arr.size(), pile.arr.size(),
		drift.arr.size() };
	for (int64_t size : per_slime) {
		ERR_FAIL_COND_V_MSG(size != n, false, "SlimeSolver.rest: a per-slime array doesn't hold slime_count entries.");
	}
	const int64_t points = pos_a.size();
	ERR_FAIL_COND_V_MSG(prev.arr.size() != points, false, "SlimeSolver.rest: pos and prev differ in size.");
	pair_count = pair_touch_a.size();

	state = state_a.ptr();
	id = id_a.ptr();
	first = first_a.ptr();
	npts = npts_a.ptr();
	supported = supported_a.ptr();
	pairs = pairs_a.ptr();
	pair_touch = pair_touch_a.ptr();
	centre = centre_a.ptr();
	pos = pos_a.ptr();
	for (int64_t s = 0; s < n; s++) {
		ERR_FAIL_COND_V_MSG(first[s] < 0 || npts[s] < 0 || int64_t(first[s]) + npts[s] > points, false,
				"SlimeSolver.rest: a slime's point range is outside the point arrays.");
	}
	return pairs_valid();
}

bool RestState::pairs_valid() const {
	ERR_FAIL_COND_V_MSG(pairs_a.size() < 2 * pair_count, false,
			"SlimeSolver.rest: _pairs holds fewer than two slimes per _pair_touch entry.");
	const int32_t *p = pairs_a.ptr();
	for (int64_t k = 0; k < 2 * pair_count; k++) {
		ERR_FAIL_COND_V_MSG(p[k] < 0 || p[k] >= n, false, "SlimeSolver.rest: a pair names no slime.");
	}
	return true;
}

bool RestState::bind(SolverState &r_st) {
	n = r_st.slime_count;
	rest_enabled = r_st.rest_enabled;
	pairs_a = r_st.pairs_a;
	pair_touch_a = r_st.pair_touch_a;
	pair_count = pair_touch_a.size();
	if (!pairs_valid()) {
		return false;
	}
	state = r_st.state;
	id = r_st.id;
	first = r_st.first;
	npts = r_st.npts;
	supported = r_st.supported;
	pairs = pairs_a.ptr();
	pair_touch = pair_touch_a.ptr();
	centre = r_st.centre;
	pos = r_st.pos;
	calm.bind(r_st.calm);
	still_ticks.bind(r_st.still_ticks);
	rest_anchor.bind(r_st.rest_anchor);
	pile.bind(r_st.pile);
	drift.bind(r_st.drift);
	prev.bind(r_st.prev);
	return true;
}

void RestState::store(Object *p_bodies) const {
	calm.store(p_bodies, "calm");
	still_ticks.store(p_bodies, "still_ticks");
	rest_anchor.store(p_bodies, "rest_anchor");
	pile.store(p_bodies, "pile");
	drift.store(p_bodies, "_drift");
	prev.store(p_bodies, "prev");
}

// rest_piles' union-find and its groups short of REST_TICKS, reused from
// call to call (the simulation runs on one thread).
struct RestScratch {
	std::vector<int32_t> root;
	std::vector<uint8_t> is_short;
};
RestScratch rest_scratch;

// SlimeBodies._find: the root of `s` in the union-find `root`, halving the
// path on the way.
int32_t find_root(int32_t *root, int32_t s) {
	while (root[s] != s) {
		root[s] = root[root[s]];
		s = root[s];
	}
	return s;
}

// SlimeBodies._rest_piles: rests every group of touching active pile slimes
// whose members have all been still for REST_TICKS (union-find over the
// touching pairs); a group's `pile` is its lowest id (slimes are stored in
// ascending id order, so the root, the group's lowest index, holds it).
void rest_piles(RestState &st) {
	const int64_t n = st.n;
	std::vector<int32_t> &root_v = rest_scratch.root;
	root_v.resize(size_t(n));
	int32_t *root = root_v.data();
	for (int64_t s = 0; s < n; s++) {
		root[s] = int32_t(s);
	}
	const uint8_t *calm = st.calm.r;
	for (int64_t k = 0; k < st.pair_count; k++) {
		if (st.pair_touch[k] == 0) {
			continue;
		}
		const int32_t a = st.pairs[2 * k];
		const int32_t b = st.pairs[2 * k + 1];
		if (calm[a] != ACTIVE || calm[b] != ACTIVE || !st.can_rest(a) || !st.can_rest(b)) {
			continue;
		}
		const int32_t ra = find_root(root, a);
		const int32_t rb = find_root(root, b);
		if (ra != rb) {
			root[std::max(ra, rb)] = std::min(ra, rb);
		}
	}
	// A group rests when none of its members is short of REST_TICKS.
	std::vector<uint8_t> &short_v = rest_scratch.is_short;
	short_v.assign(size_t(n), 0);
	for (int64_t s = 0; s < n; s++) {
		if (calm[s] == ACTIVE && st.can_rest(s) && st.still_ticks.r[s] < REST_TICKS) {
			short_v[find_root(root, int32_t(s))] = 1;
		}
	}
	for (int64_t s = 0; s < n; s++) {
		if (st.calm.r[s] != ACTIVE || !st.can_rest(s)) {
			continue;
		}
		const int32_t r = find_root(root, int32_t(s));
		if (short_v[r] != 0) {
			continue;
		}
		st.calm.w()[s] = RESTING;
		st.still_ticks.put(s, 0);
		st.pile.put(s, st.id[r]);
		// _set_velocity_at(s, Vector2.ZERO): prev = pos - ZERO * h, the step
		// being (0, 0).
		const int64_t f = st.first[s];
		const int64_t end = f + st.npts[s];
		for (int64_t i = f; i < end; i++) {
			st.prev.put(i, st.pos[i] - Vector2());
		}
		st.drift.put(s, Vector2());
	}
}

// The pass on `st` once read (see the file header): the local wake, the
// still counts, the groups that come to rest. rest_enabled off: every slime
// wakes (no slime rests).
void run_rest(RestState &st, double p_h) {
	const int64_t n = st.n;
	if (!st.rest_enabled) {
		for (int64_t s = 0; s < n; s++) {
			st.wake_at(s);
		}
		return;
	}
	const double drift2 = REST_DRIFT * REST_DRIFT;
	const double fast2 = WAKE_SPEED * p_h * WAKE_SPEED * p_h;
	for (int64_t k = 0; k < st.pair_count; k++) {
		if (st.pair_touch[k] == 0) {
			continue;
		}
		const int32_t a = st.pairs[2 * k];
		const int32_t b = st.pairs[2 * k + 1];
		const uint8_t *calm = st.calm.r;
		if (calm[a] == RESTING && calm[b] == ACTIVE && st.state[b] != STATE_SLEEPER) {
			if (st.drift.r[b].length_squared() > fast2) {
				st.wake_at(a);
			}
		} else if (calm[b] == RESTING && calm[a] == ACTIVE && st.state[a] != STATE_SLEEPER) {
			if (st.drift.r[a].length_squared() > fast2) {
				st.wake_at(b);
			}
		}
	}
	bool ready = false;
	for (int64_t s = 0; s < n; s++) {
		if (st.calm.r[s] != ACTIVE || !st.can_rest(s)) {
			continue;
		}
		const Vector2 c = st.centre[s];
		if (st.supported[s] == 0 || c.distance_squared_to(st.rest_anchor.r[s]) > drift2) {
			st.still_ticks.put(s, 0);
			st.rest_anchor.put(s, c);
			continue;
		}
		const int32_t count = std::min(st.still_ticks.r[s] + 1, int32_t(REST_TICKS));
		st.still_ticks.put(s, count);
		ready = ready || count == REST_TICKS;
	}
	if (ready) {
		rest_piles(st);
	}
}

} // namespace

// SlimeBodies._rest, after the tick: the local wake, the still counts, and
// the groups that come to rest (see the file header). `p_h` is the substep
// length (SlimeBodies._h), which turns WAKE_SPEED into a drift per substep.
// rest_enabled off: every slime wakes (no slime rests).
// @spec-link [[req_offscreen_simulation]]
bool SlimeSolver::rest(Object *p_bodies, double p_h) {
	RestState st;
	if (!st.load(p_bodies)) {
		return false;
	}
	run_rest(st, p_h);
	st.store(p_bodies);
	return true;
}

// The rest pass on a whole tick's state (solver_passes.h).
bool rest_state(SolverState &r_st, double p_h) {
	RestState st;
	if (!st.bind(r_st)) {
		return false;
	}
	run_rest(st, p_h);
	return true;
}

} // namespace godot
