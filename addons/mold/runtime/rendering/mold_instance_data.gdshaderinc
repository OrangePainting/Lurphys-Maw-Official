// Mold Godot custom material contract.
// Include this file after "shader_type spatial" and the material's render_mode.
uniform sampler2D mold_instance_data : filter_nearest, repeat_disable;

const int MOLD_INSTANCE_PRIMARY_COLOR = 0;
const int MOLD_INSTANCE_SECONDARY_COLOR = 1;
const int MOLD_INSTANCE_SHAPE_DATA = 2;
const int MOLD_INSTANCE_DASH_DATA = 3;
const int MOLD_INSTANCE_FLAGS = 4;
const int MOLD_INSTANCE_GRADIENT_DATA = 5;
const int MOLD_INSTANCE_LOD_DATA = 6;
const int MOLD_INSTANCE_TEXELS = 7;
const int MOLD_LOCAL_AA_ENABLED_FLAG = 1;
const int MOLD_LOCAL_AA_HIGH_QUALITY_FLAG = 32;

vec4 mold_instance_fetch(int instance_id, int slot) {
	int linear_index = instance_id * MOLD_INSTANCE_TEXELS + slot;
	int width = textureSize(mold_instance_data, 0).x;
	return texelFetch(
		mold_instance_data,
		ivec2(linear_index % width, linear_index / width),
		0);
}

int mold_local_aa_quality(vec4 flags_data) {
	int flags = int(round(flags_data.w));
	return (flags & MOLD_LOCAL_AA_ENABLED_FLAG) == 0 ? 0
		: ((flags & MOLD_LOCAL_AA_HIGH_QUALITY_FLAG) != 0 ? 2 : 1);
}

int mold_bayer_2x2(ivec2 p) {
	return p.x * 2 + p.y * 3 - p.x * p.y * 4;
}

float mold_dither_threshold(vec2 position) {
	ivec2 p = ivec2(position) & ivec2(15);
	int rank = mold_bayer_2x2(p & ivec2(1)) * 64;
	rank += mold_bayer_2x2((p >> 1) & ivec2(1)) * 16;
	rank += mold_bayer_2x2((p >> 2) & ivec2(1)) * 4;
	rank += mold_bayer_2x2((p >> 3) & ivec2(1));
	return float(rank + 1) / 257.0;
}

bool mold_lod_visible(vec4 lod_data, vec2 fragment_position) {
	float threshold = mold_dither_threshold(fragment_position);
	if (lod_data.y > 0.5) threshold = 1.0 - threshold;
	return lod_data.x >= 0.99999 || lod_data.x >= threshold;
}

vec3 mold_linear_to_srgb(vec3 color) {
	vec3 lower = color * 12.92;
	vec3 higher = 1.055 * pow(max(color, vec3(0.0)), vec3(1.0 / 2.4)) - 0.055;
	return mix(higher, lower, lessThanEqual(color, vec3(0.0031308)));
}

vec3 mold_output_color(vec3 linear_color) {
	return OUTPUT_IS_SRGB ? mold_linear_to_srgb(linear_color) : linear_color;
}
