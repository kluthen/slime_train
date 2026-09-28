// Spike 1 (throwaway): the same ring-of-springs step as slime_sim.gd, ported
// line for line to C++, standalone (no Godot), to estimate what the
// simulation would cost as native code (e.g. a GDExtension) instead of
// GDScript. Same setup as the benchmark: 200 slimes, 60/25/15% sizes 1/2/3,
// shelf-packed from the floor, 2 substeps, 1 iteration.
//
// Build and run:
//   g++ -O2 -std=c++17 -o /tmp/native_estimate spikes/soft-slimes/native_estimate.cpp
//   /tmp/native_estimate [points] [moving 0|1]
#include <algorithm>
#include <chrono>
#include <cmath>
#include <cstdio>
#include <cstdlib>
#include <random>
#include <vector>

struct V2 {
	float x = 0, y = 0;
	V2() {}
	V2(float a, float b) : x(a), y(b) {}
	V2 operator+(V2 o) const { return {x + o.x, y + o.y}; }
	V2 operator-(V2 o) const { return {x - o.x, y - o.y}; }
	V2 operator*(float k) const { return {x * k, y * k}; }
	V2 operator/(float k) const { return {x / k, y / k}; }
	V2 &operator+=(V2 o) { x += o.x; y += o.y; return *this; }
	V2 &operator-=(V2 o) { x -= o.x; y -= o.y; return *this; }
	float len2() const { return x * x + y * y; }
	float len() const { return std::sqrt(len2()); }
	float dot(V2 o) const { return x * o.x + y * o.y; }
	float cross(V2 o) const { return x * o.y - y * o.x; }
	V2 limit(float m) const { float l = len(); return l > m && l > 0 ? *this * (m / l) : *this; }
	V2 norm() const { float l = len(); return l > 0 ? *this / l : V2(); }
};

static const float TAU = 6.28318530718f;
static const float PI = 3.14159265359f;

struct Sim {
	float dt = 1.0f / 60.0f;
	int substeps = 2, iterations = 1;
	float edge_stiffness = 0.8f, area_stiffness = 0.6f, shape_stiffness = 0.3f;
	float damping = 0.996f, internal_damping = 0.1f, floor_friction = 0.4f, max_speed = 1200.0f;
	bool hopping = false;
	float floor_y = 600, wall_left = 0, wall_right = 1152;
	std::vector<V2> pos, prev, rest_off;
	int slime_count = 0;
	std::vector<int> first, npts, size_of, slime_cell, cell_start, cell_items, pairs;
	std::vector<float> ring_radius, bound_r, rest_area, rest_edge, hop_timer, angle0;
	std::vector<V2> centre;
	float cell_size = 80;
	int grid_w = 1, grid_h = 1;
	std::mt19937 rng{20260928};
	float randf(float a, float b) { return std::uniform_real_distribution<float>(a, b)(rng); }
	int contact_tests = 0;

	void setup(float width, float floor_at) {
		wall_right = width;
		floor_y = floor_at;
		grid_w = int(std::ceil(width / cell_size)) + 1;
		grid_h = int(std::ceil((floor_at + 2000) / cell_size)) + 1;
	}
	void add(V2 at, int size, int points, float r) {
		slime_count++;
		first.push_back(pos.size()); npts.push_back(points); size_of.push_back(size);
		ring_radius.push_back(r); bound_r.push_back(r * 1.3f);
		rest_area.push_back(0.5f * points * r * r * std::sin(TAU / points));
		rest_edge.push_back(2 * r * std::sin(PI / points));
		hop_timer.push_back(randf(0.2f, 3.0f));
		centre.push_back(at); angle0.push_back(0); slime_cell.push_back(0);
		for (int i = 0; i < points; i++) {
			float a = TAU * i / points;
			V2 off(std::cos(a) * r, std::sin(a) * r);
			pos.push_back(at + off); prev.push_back(at + off); rest_off.push_back(off);
		}
	}
	void step() {
		float h = dt / substeps;
		for (int sub = 0; sub < substeps; sub++) {
			integrate(h, sub == 0);
			if (sub == 0) build_grid();
			for (int it = 0; it < iterations; it++) { contacts(); rings(); bounds(); }
		}
	}
	V2 hop_kick(int s, float h) {
		float t = hop_timer[s] - dt;
		if (t > 0) { hop_timer[s] = t; return V2(); }
		int size = size_of[s];
		hop_timer[s] = randf(1.5f, 3.0f) * (1 + 0.15f * (size - 1));
		float up = -randf(520, 680) * (1 + 0.12f * (size - 1));
		float side = randf(-160, 160);
		return V2(side, up) * h;
	}
	void integrate(float h, bool first_sub) {
		V2 g = V2(0, 1400) * (h * h);
		float ms = max_speed * h;
		bool hop = hopping && first_sub;
		for (int s = 0; s < slime_count; s++) {
			int f = first[s], cnt = npts[s], end = f + cnt;
			V2 mean;
			for (int i = f; i < end; i++) mean += pos[i] - prev[i];
			mean = mean / float(cnt);
			V2 kick = hop ? hop_kick(s, h) : V2();
			V2 c;
			for (int i = f; i < end; i++) {
				V2 cur = pos[i];
				V2 v = cur - prev[i];
				v = ((v + (mean - v) * internal_damping) * damping).limit(ms) + g + kick;
				prev[i] = cur;
				pos[i] = cur + v;
				c += pos[i];
			}
			c = c / float(cnt);
			centre[s] = c;
			V2 r0 = pos[f] - c;
			angle0[s] = std::atan2(r0.y, r0.x);
		}
	}
	void build_grid() {
		int cells = grid_w * grid_h;
		cell_start.assign(cells + 1, 0);
		cell_items.resize(slime_count);
		float top = floor_y - (grid_h - 1) * cell_size;
		for (int s = 0; s < slime_count; s++) {
			int cx = std::clamp(int((centre[s].x - wall_left) / cell_size), 0, grid_w - 1);
			int cy = std::clamp(int((centre[s].y - top) / cell_size), 0, grid_h - 1);
			slime_cell[s] = cy * grid_w + cx;
			cell_start[slime_cell[s] + 1]++;
		}
		for (int k = 0; k < cells; k++) cell_start[k + 1] += cell_start[k];
		std::vector<int> fill(cell_start.begin(), cell_start.end() - 1);
		for (int s = 0; s < slime_count; s++) cell_items[fill[slime_cell[s]]++] = s;
		pairs.clear();
		for (int s = 0; s < slime_count; s++) {
			int cx = slime_cell[s] % grid_w, cy = slime_cell[s] / grid_w;
			for (int gy = std::max(cy - 1, 0); gy < std::min(cy + 2, grid_h); gy++)
				for (int gx = std::max(cx - 1, 0); gx < std::min(cx + 2, grid_w); gx++) {
					int gc = gy * grid_w + gx;
					for (int q = cell_start[gc]; q < cell_start[gc + 1]; q++) {
						int t = cell_items[q];
						if (t <= s) continue;
						float rr = bound_r[s] + bound_r[t] + 8;
						if ((centre[t] - centre[s]).len2() < rr * rr) { pairs.push_back(s); pairs.push_back(t); }
					}
				}
		}
	}
	void contacts() {
		int tests = 0;
		for (size_t i = 0; i < pairs.size(); i += 2) {
			int s0 = pairs[i], s1 = pairs[i + 1];
			float rr = bound_r[s0] + bound_r[s1];
			if ((centre[s1] - centre[s0]).len2() >= rr * rr) continue;
			for (int side = 0; side < 2; side++) {
				int a = side == 0 ? s0 : s1, b = side == 0 ? s1 : s0;
				V2 ca = centre[a], cb = centre[b];
				float rb2 = bound_r[b] * bound_r[b];
				int nb = npts[b], fb = first[b], na = npts[a], fa = first[a];
				float b0 = angle0[b];
				V2 dir = cb - ca;
				float ta = (std::atan2(dir.y, dir.x) - angle0[a]) / TAU;
				if (ta < 0) ta += 1;
				int mid = int(ta * na + 0.5f), half = na / 4 + 1;
				float kb = nb / TAU;
				V2 react;
				for (int m = mid - half; m <= mid + half; m++) {
					int j = fa + ((m % na) + na) % na;
					V2 rel = pos[j] - cb;
					float d2 = rel.len2();
					if (d2 >= rb2 || d2 < 1e-6f) continue;
					tests++;
					float t = (std::atan2(rel.y, rel.x) - b0) * kb;
					if (t < 0) t += nb;
					int k = int(t);
					if (k >= nb) k -= nb;
					float fr = t - k;
					int k2 = k + 1 < nb ? k + 1 : 0;
					float r0 = (pos[fb + k] - cb).len();
					float r = r0 + ((pos[fb + k2] - cb).len() - r0) * fr;
					if (d2 < r * r) {
						float d = std::sqrt(d2);
						V2 push = rel * ((r - d) * 0.5f / d);
						pos[j] += push;
						react -= push;
					}
				}
				if (react.x != 0 || react.y != 0) {
					react = react / float(nb);
					for (int q = fb; q < fb + nb; q++) pos[q] += react;
				}
			}
		}
		contact_tests = tests;
	}
	void rings() {
		float ks = edge_stiffness * 0.5f;
		for (int s = 0; s < slime_count; s++) {
			int f = first[s], cnt = npts[s], last = f + cnt - 1;
			float rest = rest_edge[s];
			for (int j = f; j <= last; j++) {
				int k = j < last ? j + 1 : f;
				V2 d = pos[k] - pos[j];
				float l = d.len();
				if (l > 1e-5f) { V2 corr = d * ((l - rest) / l * ks); pos[j] += corr; pos[k] -= corr; }
			}
			float area = 0, grad_sq = 0, sd = 0, sc = 0;
			V2 c, pp = pos[last], cur = pos[f];
			for (int j = f; j <= last; j++) {
				V2 nx = j < last ? pos[j + 1] : pos[f];
				area += pp.cross(cur);
				grad_sq += (nx - pp).len2();
				c += cur;
				sd += rest_off[j].dot(cur);
				sc += rest_off[j].cross(cur);
				pp = cur; cur = nx;
			}
			area *= 0.5f; grad_sq *= 0.25f; c = c / float(cnt);
			float lam = grad_sq > 1e-6f ? (rest_area[s] - area) / grad_sq * area_stiffness : 0;
			V2 rot = V2(sd, sc).norm();
			pp = pos[last]; cur = pos[f];
			V2 first_p = cur;
			for (int j = f; j <= last; j++) {
				V2 nx = j < last ? pos[j + 1] : first_p;
				V2 moved = cur + V2(nx.y - pp.y, pp.x - nx.x) * (0.5f * lam);
				V2 q = rest_off[j];
				V2 goal = c + V2(q.x * rot.x - q.y * rot.y, q.x * rot.y + q.y * rot.x);
				pos[j] = moved + (goal - moved) * shape_stiffness;
				pp = cur; cur = nx;
			}
		}
	}
	void bounds() {
		for (size_t i = 0; i < pos.size(); i++) {
			V2 c = pos[i];
			if (c.y <= floor_y && c.x >= wall_left && c.x <= wall_right) continue;
			if (c.y > floor_y) { c.y = floor_y; prev[i].x += (c.x - prev[i].x) * floor_friction; }
			c.x = std::clamp(c.x, wall_left, wall_right);
			pos[i] = c;
		}
	}
};

int main(int argc, char **argv) {
	int pts = argc > 1 ? std::atoi(argv[1]) : 16;
	bool moving = argc > 2 && std::atoi(argv[2]) != 0;
	Sim sim;
	sim.hopping = moving;
	sim.setup(1152, 608);
	float x = 4, y = 608, row_h = 0;
	for (int i = 0; i < 200; i++) {
		int r = i % 20, size = r < 12 ? 1 : (r < 17 ? 2 : 3);
		float vis = 18 * std::sqrt(float(size)), d = vis * 2 + 2;
		if (x + d > 1148) { x = 4; y -= row_h; row_h = 0; }
		sim.add(V2(x + d * 0.5f, y - d * 0.5f), size, pts + int(std::lround(pts * 0.25 * (size - 1))), vis - 3);
		x += d;
		row_h = std::max(row_h, d);
	}
	for (int s = 0; s < 540; s++) sim.step();
	auto t0 = std::chrono::steady_clock::now();
	const int N = 600;
	for (int s = 0; s < N; s++) sim.step();
	double ms = std::chrono::duration<double, std::milli>(std::chrono::steady_clock::now() - t0).count() / N;
	float top = 1e9f, meanv = 0;
	for (int s = 0; s < sim.slime_count; s++) top = std::min(top, sim.centre[s].y);
	for (size_t i = 0; i < sim.pos.size(); i++) meanv += (sim.pos[i] - sim.prev[i]).len() / sim.pos.size();
	std::printf("NATIVE points=%d moving=%d total_points=%zu step_ms=%.4f top=%.1f meanv=%.3f contact_tests=%d\n",
			pts, moving ? 1 : 0, sim.pos.size(), ms, top, meanv, sim.contact_tests);
}
