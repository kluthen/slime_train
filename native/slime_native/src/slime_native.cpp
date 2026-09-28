#include "slime_native.h"

#include <godot_cpp/core/class_db.hpp>

#ifndef SLIME_NATIVE_BUILD
#define SLIME_NATIVE_BUILD "unknown"
#endif

namespace godot {

static const char *SLIME_NATIVE_VERSION = "0.1.0";

void SlimeNative::_bind_methods() {
	ClassDB::bind_method(D_METHOD("version"), &SlimeNative::version);
	ClassDB::bind_method(D_METHOD("sum", "values"), &SlimeNative::sum);
	ClassDB::bind_method(D_METHOD("mul_add", "a", "b", "c"), &SlimeNative::mul_add);
}

String SlimeNative::version() const {
	return String("slime_native ") + SLIME_NATIVE_VERSION + " (" + SLIME_NATIVE_BUILD + ")";
}

double SlimeNative::sum(const PackedFloat32Array &p_values) const {
	double total = 0.0;
	const float *values = p_values.ptr();
	const int64_t count = p_values.size();
	for (int64_t i = 0; i < count; i++) {
		total += values[i];
	}
	return total;
}

double SlimeNative::mul_add(double p_a, double p_b, double p_c) const {
	return p_a * p_b + p_c;
}

} // namespace godot
