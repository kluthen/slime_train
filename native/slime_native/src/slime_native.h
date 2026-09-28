#pragma once

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
#include <godot_cpp/variant/string.hpp>

namespace godot {

// Toolchain check for the native simulation tick (chunk 5N). The tick itself
// (SlimeBodies, TerrainSegments) moves here next; see docs/dev/native.md.
class SlimeNative : public RefCounted {
	GDCLASS(SlimeNative, RefCounted)

protected:
	static void _bind_methods();

public:
	// "slime_native <version> (<platform>.<target>.<arch>)".
	String version() const;
	// Sum of the values, accumulated in double precision.
	double sum(const PackedFloat32Array &p_values) const;
	// a * b + c, written so a compiler allowed to contract would emit one
	// fused multiply-add. With -ffp-contract=off it rounds twice, like
	// GDScript does: the probe that the determinism flag is in effect.
	double mul_add(double p_a, double p_b, double p_c) const;
};

} // namespace godot
