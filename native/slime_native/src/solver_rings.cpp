// The ring constraints of the native solver: SlimeBodies._solve_rings()
// (src/sim/slime_bodies.gd), ported line for line. Per ring of an active,
// awake slime: Jacobi edge springs, then the area (pressure) constraint and
// the shape-matching pull, both from one read pass over the ring.
//
// Precision mirrors GDScript's: a Vector2 (and every Vector2 operation) is
// 32-bit, a GDScript float is a double. So the sums of scalars (area, the
// gradient norm, the rotation's dot and cross sums), the edge factors and the
// Lagrange factor are doubles; a double meeting a Vector2 is rounded to a
// float first (Vector2 * real_t); the centre is summed as a Vector2. The
// rotated rest offset is computed in doubles from the float components, then
// rounded, as GDScript's `q.x * rot.x - q.y * rot.y` is. With
// -ffp-contract=off (SConstruct) nothing fuses, so this gives GDScript's
// result bit for bit on the same C library.
//
// The pass reads only what it needs, once per call, and writes back only the
// points (pos): it doesn't load the whole SolverState, whose load() takes a
// writable copy of every read-write array. It leaves the centre cache
// (_centre_cache, _centre_ok) alone, as the GDScript pass does.

#include "slime_solver.h"

#include <cmath>

#include <godot_cpp/core/error_macros.hpp>

#include "solver_state.h"

namespace godot {

namespace {

// What the ring pass reads, as raw pointers into the arrays of one call.
struct RingsInput {
	int64_t slime_count = 0;
	const int32_t *first = nullptr;
	const int32_t *npts = nullptr;
	const int32_t *state = nullptr;
	const uint8_t *calm = nullptr;
	const float *rest_edge = nullptr;
	const float *rest_area = nullptr;
	const Vector2 *rest_off = nullptr;
	double edge_stiffness = 0.0;
	double area_stiffness = 0.0;
	double shape_stiffness = 0.0;
};

// The length of `p_v`, as Vector2.length() computes it (in floats).
inline double length_of(const Vector2 &p_v) {
	return double(std::sqrt(p_v.x * p_v.x + p_v.y * p_v.y));
}

// `p_v` scaled by the GDScript float `p_k` (Vector2 * float: `p_k` rounded
// to a float first).
inline Vector2 scaled(const Vector2 &p_v, double p_k) {
	const float k = float(p_k);
	return Vector2(p_v.x * k, p_v.y * k);
}

// The edge-spring factor of an edge of length `p_l` (a float's value) and
// rest length `p_rest`: (l - rest) / l, 0 for a collapsed edge.
inline double edge_factor(double p_l, double p_rest) {
	return p_l > 1e-5 ? (p_l - p_rest) / p_l : 0.0;
}

// The ring pass (SlimeBodies._solve_rings) on the points `p_pos`.
void solve_rings_on(const RingsInput &p_in, Vector2 *p_pos) {
	Vector2 *p = p_pos;
	const double ks = p_in.edge_stiffness * 0.5;
	const double ka = p_in.area_stiffness;
	const double kshape = p_in.shape_stiffness;
	for (int64_t s = 0; s < p_in.slime_count; s++) {
		if (p_in.state[s] == slime_const::STATE_SLEEPER || p_in.calm[s] != slime_const::ACTIVE) {
			continue;
		}
		const int64_t f = p_in.first[s];
		const int64_t cnt = p_in.npts[s];
		if (cnt <= 0) {
			continue;
		}
		const int64_t last = f + cnt - 1;
		const double rest = p_in.rest_edge[s];
		// Edge springs, Jacobi style: every correction comes from the positions
		// before the pass (each point's two edges, in ring order).
		Vector2 pp = p[last];
		Vector2 cur = p[f];
		Vector2 first_p = cur;
		Vector2 d_prev = cur - pp;
		double e_prev = edge_factor(length_of(d_prev), rest);
		for (int64_t j = f; j <= last; j++) {
			const Vector2 nx = j < last ? p[j + 1] : first_p;
			const Vector2 d_next = nx - cur;
			const double e_next = edge_factor(length_of(d_next), rest);
			p[j] = cur + scaled(scaled(d_next, e_next) - scaled(d_prev, e_prev), ks);
			d_prev = d_next;
			e_prev = e_next;
			cur = nx;
		}
		// One read pass: area, area-gradient norm, centre, and the rotation
		// that best fits the rest circle.
		double area = 0.0;
		double grad_sq = 0.0;
		Vector2 c;
		double sd = 0.0;
		double sc = 0.0;
		pp = p[last];
		cur = p[f];
		for (int64_t j = f; j <= last; j++) {
			const Vector2 nx = j < last ? p[j + 1] : p[f];
			area += double(pp.x * cur.y - pp.y * cur.x);
			const Vector2 g = nx - pp;
			grad_sq += double(g.x * g.x + g.y * g.y);
			c += cur;
			const Vector2 q = p_in.rest_off[j];
			sd += double(q.x * cur.x + q.y * cur.y);
			sc += double(q.x * cur.y - q.y * cur.x);
			pp = cur;
			cur = nx;
		}
		area *= 0.5;
		grad_sq *= 0.25;
		const float count = float(cnt);
		c = Vector2(c.x / count, c.y / count);
		double lam = 0.0;
		if (grad_sq > 1e-6) {
			lam = (double(p_in.rest_area[s]) - area) / grad_sq * ka;
		}
		// Vector2(sd, sc).normalized(), in floats.
		Vector2 rot = Vector2(float(sd), float(sc));
		const float rot_l2 = rot.x * rot.x + rot.y * rot.y;
		if (rot_l2 != 0.0f) {
			const float rot_l = std::sqrt(rot_l2);
			rot = Vector2(rot.x / rot_l, rot.y / rot_l);
		}
		// Apply pass: area gradient, then the shape-matching pull, from the
		// neighbours' positions before the pass.
		const double half_lam = 0.5 * lam;
		pp = p[last];
		cur = p[f];
		first_p = cur;
		for (int64_t j = f; j <= last; j++) {
			const Vector2 nx = j < last ? p[j + 1] : first_p;
			const Vector2 moved = cur + scaled(Vector2(nx.y - pp.y, pp.x - nx.x), half_lam);
			const Vector2 q = p_in.rest_off[j];
			const double qx = q.x;
			const double qy = q.y;
			const Vector2 turned(float(qx * double(rot.x) - qy * double(rot.y)),
					float(qx * double(rot.y) + qy * double(rot.x)));
			const Vector2 goal = c + turned;
			p[j] = moved + scaled(goal - moved, kshape);
			pp = cur;
			cur = nx;
		}
	}
}

// The field `p_name` of `p_bodies` into `r_value`, which must be of
// `p_type`; prints an error and returns false otherwise.
bool fetch_field(Object *p_bodies, const char *p_name, Variant::Type p_type, Variant &r_value) {
	r_value = p_bodies->get(StringName(p_name));
	if (r_value.get_type() != p_type) {
		ERR_PRINT(String("SlimeSolver.solve_rings: SlimeBodies.") + p_name + " is " +
				Variant::get_type_name(r_value.get_type()) + ", expected " + Variant::get_type_name(p_type) +
				" (see check_schema).");
		return false;
	}
	return true;
}

} // namespace

// The ring constraints: SlimeBodies._solve_rings() natively. Reads the point
// ranges, states, calms, rest shapes and stiffnesses, writes the points back.
// False, with an error printed, when a field is missing, of another type, or
// sized inconsistently (the GDScript pass then runs instead).
bool SlimeSolver::solve_rings(Object *p_bodies) {
	ERR_FAIL_NULL_V_MSG(p_bodies, false, "SlimeSolver.solve_rings: null bodies.");
	Variant v;
	int64_t slime_count = 0;
	PackedInt32Array first_a, npts_a, state_a;
	PackedByteArray calm_a;
	PackedFloat32Array rest_edge_a, rest_area_a;
	PackedVector2Array rest_off_a, pos_a;
	RingsInput in;
#define RINGS_FETCH(m_name, m_type, m_target) \
	if (!fetch_field(p_bodies, m_name, Variant::m_type, v)) { \
		return false; \
	} \
	m_target = v;
	RINGS_FETCH("slime_count", INT, slime_count)
	RINGS_FETCH("first", PACKED_INT32_ARRAY, first_a)
	RINGS_FETCH("npts", PACKED_INT32_ARRAY, npts_a)
	RINGS_FETCH("state", PACKED_INT32_ARRAY, state_a)
	RINGS_FETCH("calm", PACKED_BYTE_ARRAY, calm_a)
	RINGS_FETCH("rest_edge", PACKED_FLOAT32_ARRAY, rest_edge_a)
	RINGS_FETCH("rest_area", PACKED_FLOAT32_ARRAY, rest_area_a)
	RINGS_FETCH("rest_off", PACKED_VECTOR2_ARRAY, rest_off_a)
	RINGS_FETCH("pos", PACKED_VECTOR2_ARRAY, pos_a)
	RINGS_FETCH("edge_stiffness", FLOAT, in.edge_stiffness)
	RINGS_FETCH("area_stiffness", FLOAT, in.area_stiffness)
	RINGS_FETCH("shape_stiffness", FLOAT, in.shape_stiffness)
#undef RINGS_FETCH

	const int64_t n = slime_count;
	const int64_t points = pos_a.size();
	ERR_FAIL_COND_V_MSG(rest_off_a.size() != points, false, "SlimeSolver.solve_rings: pos and rest_off differ in size.");
	ERR_FAIL_COND_V_MSG(first_a.size() != n || npts_a.size() != n || state_a.size() != n || calm_a.size() != n ||
					rest_edge_a.size() != n || rest_area_a.size() != n,
			false, "SlimeSolver.solve_rings: a per-slime array doesn't hold slime_count entries.");
	in.slime_count = n;
	in.first = first_a.ptr();
	in.npts = npts_a.ptr();
	in.state = state_a.ptr();
	in.calm = calm_a.ptr();
	in.rest_edge = rest_edge_a.ptr();
	in.rest_area = rest_area_a.ptr();
	in.rest_off = rest_off_a.ptr();
	for (int64_t s = 0; s < n; s++) {
		ERR_FAIL_COND_V_MSG(in.first[s] < 0 || in.npts[s] < 0 || int64_t(in.first[s]) + in.npts[s] > points, false,
				"SlimeSolver.solve_rings: a slime's point range is outside the point arrays.");
	}

	solve_rings_on(in, pos_a.ptrw());
	p_bodies->set(StringName("pos"), pos_a);
	return true;
}

} // namespace godot
