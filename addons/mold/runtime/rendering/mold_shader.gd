class_name MoldShader
extends RefCounted

static var _preview_shaders: Dictionary = {}


static func preview_shader(mode: MoldStyle.BlendMode, state: MoldRenderState, coverage_output := false) -> Shader:
	coverage_output = coverage_output and mode == MoldStyle.BlendMode.OPAQUE
	var key := state.shader_key(mode) | (int(coverage_output) << 24)
	var cached: Shader = _preview_shaders.get(key)
	if is_instance_valid(cached): return cached
	var shader := Shader.new()
	shader.code = source(mode, state, false, coverage_output)
	_preview_shaders[key] = shader
	return shader


static func source(mode: MoldStyle.BlendMode, state: MoldRenderState, instanced: bool, coverage_output := false) -> String:
	var blend := "blend_mix"
	if mode in [MoldStyle.BlendMode.ADDITIVE, MoldStyle.BlendMode.SCREEN, MoldStyle.BlendMode.LIGHTEN, MoldStyle.BlendMode.COLOR_DODGE]: blend = "blend_add"
	elif mode == MoldStyle.BlendMode.SUBTRACTIVE: blend = "blend_sub"
	elif mode in [MoldStyle.BlendMode.MULTIPLICATIVE, MoldStyle.BlendMode.LINEAR_BURN, MoldStyle.BlendMode.DARKEN, MoldStyle.BlendMode.COLOR_BURN]: blend = "blend_mul"
	var stencil_read := bool(state.stencil_flags & MoldRenderState.StencilFlags.READ)
	var depth_write := state.effective_depth_write(mode)
	var depth := "depth_draw_never"
	if depth_write:
		depth = "depth_draw_opaque" if state.depth_write == MoldRenderState.DepthWrite.AUTO and not stencil_read else "depth_draw_always"
	var depth_test := "depth_test_default"
	if state.depth_test == MoldRenderState.DepthTest.GREATER: depth_test = "depth_test_inverted"
	elif state.depth_test == MoldRenderState.DepthTest.ALWAYS: depth_test = "depth_test_disabled"
	var cull := "cull_disabled"
	if state.face_cull == MoldRenderState.FaceCull.BACK: cull = "cull_back"
	elif state.face_cull == MoldRenderState.FaceCull.FRONT: cull = "cull_front"
	var opaque := mode in [MoldStyle.BlendMode.OPAQUE, MoldStyle.BlendMode.DITHER]
	coverage_output = coverage_output and mode == MoldStyle.BlendMode.OPAQUE
	if coverage_output:
		# Shapes writes opaque surviving samples after generating the sample mask.
		# Alpha-to-one prevents source-alpha blending from applying coverage twice.
		blend += ", alpha_to_coverage_and_one"
		if state.depth_write == MoldRenderState.DepthWrite.AUTO and depth_write: depth = "depth_draw_always"
	var alpha_write := "" if opaque and not coverage_output and not stencil_read else "\tALPHA = result.a;"
	var stencil := _stencil_source(state)
	var lod_fragment := """
	float lod_threshold = dither_threshold(FRAGCOORD.xy);
	if (lod_data.y > 0.5) lod_threshold = 1.0 - lod_threshold;
	if (lod_data.x < 0.99999 && lod_data.x < lod_threshold) discard;
""" if instanced else ""
	var declarations := ""
	var vertex_load := ""
	if instanced:
		# Reuse packed fields to stay within the Mobile renderer's varying budget.
		declarations = """
uniform int mold_instance_index = -1;
uniform sampler2D mold_instance_data : filter_nearest, repeat_disable;
varying flat vec4 primary_color;
varying flat vec4 secondary_color;
varying flat vec4 shape_data;
varying flat vec4 dash_data;
varying flat vec4 mold_flags;
varying flat vec4 gradient_data;
varying flat vec4 lod_data;
#define emission_strength mold_flags.x
#define angular_data lod_data.zw
vec4 mold_fetch(int instance_id, int slot) {
	int linear_index = instance_id * 7 + slot;
	int width = textureSize(mold_instance_data, 0).x;
	return texelFetch(mold_instance_data, ivec2(linear_index %% width, linear_index / width), 0);
}
"""
		vertex_load = """
	primary_color = mold_fetch(mold_instance_index >= 0 ? mold_instance_index : INSTANCE_ID, 0);
	secondary_color = mold_fetch(mold_instance_index >= 0 ? mold_instance_index : INSTANCE_ID, 1);
	shape_data = mold_fetch(mold_instance_index >= 0 ? mold_instance_index : INSTANCE_ID, 2);
	dash_data = mold_fetch(mold_instance_index >= 0 ? mold_instance_index : INSTANCE_ID, 3);
	mold_flags = mold_fetch(mold_instance_index >= 0 ? mold_instance_index : INSTANCE_ID, 4);
	gradient_data = mold_fetch(mold_instance_index >= 0 ? mold_instance_index : INSTANCE_ID, 5);
	lod_data = mold_fetch(mold_instance_index >= 0 ? mold_instance_index : INSTANCE_ID, 6);
"""
	else:
		declarations = """
uniform vec4 primary_color = vec4(1.0);
uniform vec4 secondary_color = vec4(1.0);
uniform float emission_strength = 0.0;
uniform vec4 shape_data = vec4(0.0);
uniform vec4 dash_data = vec4(0.0);
uniform vec4 mold_flags = vec4(0.0);
uniform vec4 gradient_data = vec4(0.0, 1.0, 0.0, 0.0);
uniform vec2 angular_data = vec2(0.0, 6.28318530718);
"""
	var shader := """
shader_type spatial;
render_mode unshaded, %s, %s, %s, %s;
%s
%s
uniform vec2 mold_viewport_size = vec2(1.0);
uniform bool mold_msaa_enabled = false;
varying float mold_gradient_t;
varying float mold_line_progress;
varying float mold_line_across;
varying float mold_line_edge;
varying float mold_line_along;
varying vec4 mold_polyline_coord;
// These shape categories are mutually exclusive. Sharing the scalar keeps the
// mobile renderer below its varying-component limit.
varying float mold_torus_cap_or_line_pixel_coverage;
varying vec4 mold_vertex_color;
const float MOLD_TAU = 6.28318530718;
const float MOLD_TORUS_BASE_MAJOR_RADIUS = 0.375;
const float MOLD_TORUS_BASE_TUBE_RADIUS = 0.125;
const float MOLD_AA_PADDING_PIXELS = 1.0;

vec3 mold_linear_to_srgb(vec3 color) {
	vec3 lower = color * 12.92;
	vec3 higher = 1.055 * pow(max(color, vec3(0.0)), vec3(1.0 / 2.4)) - 0.055;
	return mix(higher, lower, lessThanEqual(color, vec3(0.0031308)));
}

vec3 mold_output_color(vec3 linear_color) {
	return OUTPUT_IS_SRGB ? mold_linear_to_srgb(linear_color) : linear_color;
}

int mold_local_aa_quality() {
	int flags = int(round(mold_flags.w));
	return (flags & 1) == 0 ? 0 : ((flags & 32) != 0 ? 2 : 1);
}

float mold_partial_derivative(float value) {
	if (mold_local_aa_quality() == 1) return fwidth(value);
	vec2 derivative = vec2(dFdx(value), dFdy(value));
	return length(derivative);
}

float mold_aa(float d) {
	if (mold_local_aa_quality() == 0) return step(d, 0.0);
	float width = max(mold_partial_derivative(d), 0.00001);
	return clamp(0.5 - d / width, 0.0, 1.0);
}

float line_local_aa(float coordinate, float pixel_coverage) {
    if (mold_local_aa_quality() == 0) return step(abs(coordinate), 1.0);
	float derivative = max(mold_partial_derivative(coordinate), 0.00001);
	float signed_distance = abs(coordinate) - 1.0;
	float aa_offset = clamp(pixel_coverage / 1.1, 0.0, 1.0) * 0.5;
	return 1.0 - clamp(signed_distance / derivative + aa_offset, 0.0, 1.0);
}

// Polyline support meshes contain centerline vertices whose extrusion is zero,
// so recover the full stroke width from the analytic edge coordinate.
float polyline_pixel_coverage(float edge) {
	vec2 derivative = vec2(dFdx(edge), dFdy(edge));
	return 2.0 / max(length(derivative), 0.00001);
}

float polyline_cap_aa(float coordinate, float pixel_coverage) {
    if (mold_local_aa_quality() == 0) return step(coordinate, 1.0);
    float derivative = max(mold_partial_derivative(coordinate), 0.00001);
    float offset = clamp(pixel_coverage / 1.1, 0.0, 1.0) * 0.5;
    return 1.0 - clamp((coordinate - 1.0) / derivative + offset, 0.0, 1.0);
}

float projected_pixel_distance(vec4 from_clip, vec4 to_clip) {
	vec2 from_ndc = from_clip.xy / max(abs(from_clip.w), 0.00001);
	vec2 to_ndc = to_clip.xy / max(abs(to_clip.w), 0.00001);
	return length((to_ndc - from_ndc) * mold_viewport_size * 0.5);
}

float box_distance(vec2 p) { return max(abs(p.x), abs(p.y)) - 1.0; }

float rounded_box_distance(vec2 p, float roundness) {
	float radius = clamp(roundness, 0.0, 1.0);
	vec2 q = abs(p) - (vec2(1.0) - vec2(radius));
	return length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - radius;
}

vec2 local_rectangle_extent(float aspect_marker) {
	float aspect = max(-aspect_marker, 0.00001);
	return aspect >= 1.0 ? vec2(aspect, 1.0) : vec2(1.0, 1.0 / aspect);
}

float local_rounded_box_distance(vec2 p, float aspect_marker, float roundness) {
	vec2 extent = local_rectangle_extent(aspect_marker);
	float radius = clamp(roundness, 0.0, 1.0);
	vec2 q = abs(p * extent) - (extent - vec2(radius));
	return length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - radius;
}

float polygon_distance(vec2 p, float sides) {
	float angle = atan(p.x, -p.y);
	float sector = MOLD_TAU / max(sides, 3.0);
	return cos(floor(0.5 + angle / sector) * sector - angle) * length(p) / cos(3.14159265359 / max(sides, 3.0)) - 1.0;
}

float rounded_polygon(vec2 p, float sides, float roundness) {
	roundness = clamp(roundness, 0.0, 1.0);
	if (roundness <= 0.00001) return mold_aa(polygon_distance(p, sides));
	float count = floor(max(abs(sides), 3.0));
	float full_angle = MOLD_TAU / count;
	float half_angle = full_angle * 0.5;
	float diagonal = 1.0 / cos(half_angle);
	float chamfer = max(roundness * half_angle, 0.00001);
	float remaining = half_angle - chamfer;
	float ratio = tan(remaining) / tan(half_angle);
	vec2 center = vec2(cos(half_angle), sin(half_angle)) * ratio * diagonal;
	float distance_a = length(center);
	float distance_b = 1.0 - center.x;
	p *= diagonal;
	vec2 polar = vec2(atan(p.y, p.x), length(p));
	polar.x += 7.85398163397;
	polar.x = abs(mod(polar.x + half_angle, full_angle) - half_angle);
	p = vec2(cos(polar.x), sin(polar.x)) * polar.y;
	float angle_ratio = 1.0 - (polar.x - remaining) / chamfer;
	float distance_c = sqrt(distance_a * distance_a + distance_b * distance_b - 2.0 * distance_a * distance_b * cos(3.14159265359 - half_angle * angle_ratio));
	float normalized = p.x;
	if ((half_angle - polar.x) < chamfer) normalized = polar.y / max(distance_c, 0.00001);
	return mold_aa(normalized - 1.0);
}

float angular_mask(vec2 p, float start, float span) {
	span = clamp(span, 0.0, MOLD_TAU);
	if (span >= MOLD_TAU - 0.00001) return 1.0;
	if (span <= 0.00001) return 0.0;
	float angle = mod(atan(p.x, p.y) - start + MOLD_TAU * 2.0, MOLD_TAU);
	float delta = abs(mod(angle - span * 0.5 + 3.14159265359, MOLD_TAU) - 3.14159265359);
	return mold_aa((delta - span * 0.5) * max(length(p), 0.00001));
}

float angular_progress(vec2 p, float start, float span) {
	span = max(clamp(span, 0.0, MOLD_TAU), 0.00001);
	float angle = mod(atan(p.x, p.y) - start + MOLD_TAU * 2.0, MOLD_TAU);
	return clamp(angle / span, 0.0, 1.0);
}

float dash_aa(float signed_distance) {
	if (mold_local_aa_quality() == 0) return step(0.0, signed_distance);
	float width = max(mold_partial_derivative(signed_distance), 0.00001);
	return clamp(signed_distance / width + 0.5, 0.0, 1.0);
}

float dash_total_count(vec4 dash) {
	return dash.x < 0.0 ? -dash.x / max(dash.y + dash.z, 0.00001) : floor(dash.y);
}

float dash_shape_type(vec4 dash) {
	if (dash.x < 0.0) return 0.0;
	float code = fract(dash.y);
	return code < 0.25 ? 0.0 : (code < 0.55 ? 1.0 : 2.0);
}

float dash_shape_modifier(vec4 dash) {
	if (dash.x < 0.0) return 0.0;
	float type = dash_shape_type(dash);
	float center = 0.1 + type * 0.3;
	return clamp((fract(dash.y) - center) / 0.075, -1.0, 1.0);
}

float dash_fill_ratio(vec4 dash) {
	float total = dash_total_count(dash);
	if (total < 0.5) return 1.0;
	if (dash.x < 0.0) return 1.0;
	return clamp(dash.x / max(total, 1.0), 0.0, 1.0);
}

float dash_segment_mask(float progress, float across, vec4 dash) {
	float total = dash_total_count(dash);
	if (total < 0.5) return 1.0;
	bool fixed_size = dash.x < 0.0;
	float period = max(dash.y + dash.z, 0.00001);
	float visible_ratio = fixed_size ? clamp(dash.y / period, 0.0, 1.0) : 1.0 - clamp(dash.z, 0.0, 1.0);
	if (visible_ratio >= 0.99999) return 1.0;
	across = clamp(across, -1.0, 1.0);
	float type = dash_shape_type(dash);
	float modifier = dash_shape_modifier(dash);
	float coordinate = progress * total + (fixed_size ? dash.w / period : dash.w) + (1.0 - visible_ratio) * 0.5;
	if (type < 0.5)
		coordinate += modifier * across * visible_ratio * 0.25;
	else if (type < 1.5)
		coordinate += modifier * (1.0 - abs(across)) * visible_ratio * 0.5;
	float phase = fract(coordinate);
	float half_visible = visible_ratio * 0.5;
	float signed_distance = half_visible - abs(phase - 0.5);
	if (type > 1.5) {
		float phase_per_across = fwidth(coordinate) / max(fwidth(across), 0.00001);
		float cap = clamp(phase_per_across * (1.0 + modifier), 0.0, half_visible);
		float profile = sqrt(max(1.0 - across * across, 0.0));
		signed_distance = half_visible - cap * (1.0 - profile) - abs(phase - 0.5);
	}
	return dash_aa(signed_distance);
}

float dashed_mask(float progress, float across, vec4 dash) {
	if (dash_total_count(dash) < 0.5) return 1.0;
	if (dash.x >= 0.0 && dash.x < 0.5) return 0.0;
	float fill_ratio = dash_fill_ratio(dash);
	float fill_mask = fill_ratio >= 0.99999 ? 1.0 : dash_aa(fill_ratio - progress);
	return fill_mask * dash_segment_mask(progress, across, dash);
}

float rectangle_perimeter_progress(vec2 uv, vec2 rim_thickness) {
	vec2 distance_from_outer = min(uv, vec2(1.0) - uv);
	vec2 edge_depth = distance_from_outer / max(rim_thickness, vec2(0.00001));
	if (edge_depth.x < edge_depth.y)
		return uv.x < 0.5 ? (3.0 + uv.y) * 0.25 : (2.0 - uv.y) * 0.25;
	return uv.y < 0.5 ? (3.0 - uv.x) * 0.25 : uv.x * 0.25;
}

float rectangle_rim_across(vec2 uv, vec2 rim_thickness) {
	vec2 distance_from_outer = min(uv, vec2(1.0) - uv);
	vec2 edge_depth = distance_from_outer / max(rim_thickness, vec2(0.00001));
	float depth = edge_depth.x < edge_depth.y ? edge_depth.x : edge_depth.y;
	return clamp(depth * 2.0 - 1.0, -1.0, 1.0);
}

float local_rectangle_rim_across(vec2 uv, vec4 shape) {
	vec2 p = uv * 2.0 - 1.0;
	float distance_to_outer = local_rounded_box_distance(p, shape.y, shape.w);
	float thickness = max(shape.z * 2.0, 0.00001);
	return clamp((-distance_to_outer / thickness) * 2.0 - 1.0, -1.0, 1.0);
}

float local_rectangle_rim_coverage(vec2 uv, vec4 shape, vec4 dash) {
	vec2 p = uv * 2.0 - 1.0;
	vec2 extent = local_rectangle_extent(shape.y);
	float distance_to_outer = local_rounded_box_distance(p, shape.y, shape.w);
	float thickness = max(shape.z * 2.0, 0.00001);
	float outer = mold_aa(distance_to_outer);
	float inner = mold_aa(distance_to_outer + thickness);
	vec2 rim = clamp(vec2(shape.z) / extent, vec2(0.00001), vec2(0.5));
	return clamp(outer - inner, 0.0, 1.0) * dashed_mask(
		rectangle_perimeter_progress(uv, rim),
		local_rectangle_rim_across(uv, shape), dash);
}

float polygon_perimeter_progress(vec2 p, float sides) {
	float angle = atan(p.x, -p.y);
	return fract(angle / MOLD_TAU + 0.5 / max(sides, 3.0));
}

float ring_rim_across(vec2 p, float thickness) {
	float depth = (1.0 - length(p)) / max(thickness, 0.00001);
	return clamp(depth * 2.0 - 1.0, -1.0, 1.0);
}

float polygon_rim_across(vec2 p, float sides, float thickness) {
	float depth = -polygon_distance(p, sides) / max(thickness, 0.00001);
	return clamp(depth * 2.0 - 1.0, -1.0, 1.0);
}

int packed_gradient(int divisor, int modulus) {
	return (int(round(gradient_data.w)) / divisor) %% modulus;
}

vec3 oklab_to_linear(vec3 c) {
	vec3 lms = vec3(c.x + 0.3963377774 * c.y + 0.2158037573 * c.z, c.x - 0.1055613458 * c.y - 0.0638541728 * c.z, c.x - 0.0894841775 * c.y - 1.2914855480 * c.z);
	lms = lms * lms * lms;
	return vec3(4.0767416621 * lms.x - 3.3077115913 * lms.y + 0.2309699292 * lms.z, -1.2684380046 * lms.x + 2.6097574011 * lms.y - 0.3413193965 * lms.z, -0.0041960863 * lms.x - 0.7034186147 * lms.y + 1.7076147010 * lms.z);
}

float radial_bounds_progress(vec2 uv, vec4 shape) {
	vec2 p = uv * 2.0 - 1.0; float kind = shape.x;
	if (kind < 2.5) return clamp(max(abs(p.x), abs(p.y)), 0.0, 1.0);
	if (kind < 4.5) {
		float across = shape.y < 0.0
			? local_rectangle_rim_across(uv, shape)
			: rectangle_rim_across(uv, vec2(shape.y, shape.z));
		return clamp((1.0 - across) * 0.5, 0.0, 1.0);
	}
	if (kind < 5.5) return clamp(length(p), 0.0, 1.0);
	if (kind < 6.5) return clamp((1.0 - ring_rim_across(p, shape.z)) * 0.5, 0.0, 1.0);
	if (kind < 8.5) return clamp(polygon_distance(p, shape.y) + 1.0, 0.0, 1.0);
	return clamp((1.0 - polygon_rim_across(p, shape.y, shape.z)) * 0.5, 0.0, 1.0);
}

float radial_progress(vec2 uv, vec4 shape, vec2 extent) {
	vec2 p = uv * 2.0 - 1.0; float kind = shape.x;
	if (kind < 4.5 || kind > 6.5) return clamp(length(p * extent) / max(max(extent.x, extent.y), 0.00001), 0.0, 1.0);
	return clamp(length(p), 0.0, 1.0);
}

float spatial_color_progress(int color_mode, vec3 p) {
	int kind = int(round(gradient_data.w)) / 32;
	if (color_mode == 4) {
		// Local +X toward +Z, around +Y. Torus arcs fit their authored range.
		if (dot(p.xz, p.xz) < 0.0000000001) return 0.0;
		float start = kind == 13 ? shape_data.z : 0.0;
		float span = kind == 13 ? shape_data.w : MOLD_TAU;
		float angle = mod(atan(p.z, p.x) - start + MOLD_TAU * 2.0, MOLD_TAU);
		if (angle > MOLD_TAU - 0.00001) angle = 0.0;
		return clamp(angle / max(span, 0.00001), 0.0, 1.0);
	}
	if (color_mode == 3 && kind == 13) {
		float tube_radius = shape_data.y;
		return clamp((length(p.xz) - (0.5 - 2.0 * tube_radius))
			/ max(2.0 * tube_radius, 0.00001), 0.0, 1.0);
	}
	// Bounds mode intentionally uses the same center distance on other solids.
	vec3 half_extent = vec3(0.5);
	if (kind == 12) half_extent.y = max(0.00001, 1.0 + shape_data.y);
	else if (kind == 13) half_extent.y = shape_data.y;
	vec3 extent = half_extent * gradient_data.xyz;
	return clamp(length(p * gradient_data.xyz)
		/ max(max(extent.x, max(extent.y, extent.z)), 0.00001), 0.0, 1.0);
}

float color_progress(vec2 uv, vec2 extent) {
	int color_mode = packed_gradient(1, 8);
	if (int(round(gradient_data.w)) / 32 >= 6 && color_mode >= 2)
		return spatial_color_progress(color_mode, mold_polyline_coord.xyz);
	if (color_mode == 2) return radial_progress(uv, shape_data, extent);
	if (color_mode == 3) return radial_bounds_progress(uv, shape_data);
	if (color_mode == 4) {
		if (shape_data.x > 4.5 && shape_data.x < 6.5) return angular_progress(uv * 2.0 - 1.0, shape_data.y, shape_data.w);
		if ((shape_data.x > 0.5 && shape_data.x < 4.5) ||
				(shape_data.x > 6.5 && shape_data.x < 10.5))
			return angular_progress(uv * 2.0 - 1.0, angular_data.x, angular_data.y);
		return angular_progress(uv * 2.0 - 1.0, 0.0, MOLD_TAU);
	}
	return mold_gradient_t;
}

vec4 evaluated_color(vec2 uv, vec2 extent) {
	if (packed_gradient(1, 8) == 0) return primary_color;
	vec4 result = mix(primary_color, secondary_color, color_progress(uv, extent));
	if (packed_gradient(8, 2) == 1) result.rgb = oklab_to_linear(result.rgb);
	result.rgb *= 1.0 + max(emission_strength, 0.0) * 0.12;
	return result;
}

float shape_coverage(vec2 uv, vec4 shape, vec4 dash) {
	float kind = shape.x;
	vec2 p = uv * 2.0 - 1.0;
	float planar_angular = angular_mask(p, angular_data.x, angular_data.y);
	if (kind < 1.5) return mold_aa(box_distance(p)) * planar_angular;
	if (kind < 2.5) return mold_aa(shape.y < 0.0
		? local_rounded_box_distance(p, shape.y, shape.z)
		: rounded_box_distance(p, shape.z)) * planar_angular;
	if (kind < 3.5) {
		vec2 rim = clamp(vec2(shape.y, shape.z), vec2(0.00001), vec2(0.5));
		float outer = mold_aa(box_distance(p));
		float inner = mold_aa(box_distance(p / max(vec2(1.0) - rim * 2.0, vec2(0.00001))));
		return clamp(outer - inner, 0.0, 1.0) * dashed_mask(rectangle_perimeter_progress(uv, rim), rectangle_rim_across(uv, rim), dash) * planar_angular;
	}
	if (kind < 4.5) {
		if (shape.y < 0.0) return local_rectangle_rim_coverage(uv, shape, dash) * planar_angular;
		vec2 rim = clamp(vec2(shape.y, shape.z), vec2(0.00001), vec2(0.5));
		float outer = mold_aa(rounded_box_distance(p, shape.w));
		vec2 inner_scale = max(vec2(1.0) - rim * 2.0, vec2(0.00001));
		float inner = mold_aa(rounded_box_distance(p / inner_scale, clamp(shape.w / min(inner_scale.x, inner_scale.y), 0.0, 1.0)));
		return clamp(outer - inner, 0.0, 1.0) * dashed_mask(rectangle_perimeter_progress(uv, rim), rectangle_rim_across(uv, rim), dash) * planar_angular;
	}
	if (kind < 5.5) return mold_aa(length(p) - 1.0) * angular_mask(p, shape.y, shape.w);
	if (kind < 6.5) {
		float rim = max(shape.z, 0.00001);
		float coverage = clamp(mold_aa(length(p) - 1.0) - mold_aa(length(p) - max(1.0 - rim, 0.0)), 0.0, 1.0);
		float filled_span = shape.w * dash_fill_ratio(dash);
		float progress = angular_progress(p, shape.y, shape.w);
		return coverage * angular_mask(p, shape.y, filled_span) * dash_segment_mask(progress, ring_rim_across(p, rim), dash);
	}
	if (kind < 7.5) return mold_aa(polygon_distance(p, shape.y)) * planar_angular;
	if (kind < 8.5) return rounded_polygon(p, shape.y, shape.z) * planar_angular;
	if (kind < 9.5) {
		float outer = mold_aa(polygon_distance(p, shape.y));
		float scale = max(1.0 - shape.z, 0.00001);
		float inner = mold_aa(polygon_distance(p / scale, shape.y));
		return clamp(outer - inner, 0.0, 1.0) * dashed_mask(polygon_perimeter_progress(p, shape.y), polygon_rim_across(p, shape.y, shape.z), dash) * planar_angular;
	}
	float outer = rounded_polygon(p, shape.y, shape.w);
	float scale = max(1.0 - shape.z, 0.00001);
	float inner = rounded_polygon(p / scale, shape.y, clamp(shape.w / scale, 0.0, 1.0));
	return clamp(outer - inner, 0.0, 1.0) * dashed_mask(polygon_perimeter_progress(p, shape.y), polygon_rim_across(p, shape.y, shape.z), dash) * planar_angular;
}

int bayer_2x2(ivec2 p) {
	return p.x * 2 + p.y * 3 - p.x * p.y * 4;
}

float dither_threshold(vec2 position) {
	ivec2 p = ivec2(position) & ivec2(15);
	int rank = bayer_2x2(p & ivec2(1)) * 64;
	rank += bayer_2x2((p >> 1) & ivec2(1)) * 16;
	rank += bayer_2x2((p >> 2) & ivec2(1)) * 4;
	rank += bayer_2x2((p >> 3) & ivec2(1));
	return float(rank + 1) / 257.0;
}

void vertex() {
%s
	mold_vertex_color = COLOR;
	mold_torus_cap_or_line_pixel_coverage = 0.0;
	if (mold_flags.z > 0.5 && mold_flags.z < 1.5) VERTEX.y += sign(VERTEX.y) * shape_data.y;
	if (mold_flags.z > 1.5) {
		bool cap_vertex = UV.x < 0.0 || UV.x > 1.0;
		if (cap_vertex) {
			float cap_progress = UV.x > 1.0 ? 1.0 : 0.0;
			float cap_angle = shape_data.z + shape_data.w * cap_progress;
			float cap_cos = cos(cap_angle);
			float cap_sin = sin(cap_angle);
			float cap_scale = shape_data.y / MOLD_TORUS_BASE_TUBE_RADIUS;
			float cap_cross_x =
				(VERTEX.x - MOLD_TORUS_BASE_MAJOR_RADIUS) * cap_scale;
			vec3 cap_position = vec3(
				0.5 - shape_data.y + cap_cross_x,
				VERTEX.y * cap_scale,
				0.0);
			VERTEX = vec3(
				cap_position.x * cap_cos - cap_position.z * cap_sin,
				cap_position.y,
				cap_position.x * cap_sin + cap_position.z * cap_cos);
			NORMAL = vec3(
				NORMAL.x * cap_cos - NORMAL.z * cap_sin,
				NORMAL.y,
				NORMAL.x * cap_sin + NORMAL.z * cap_cos);
			UV.x = fract(-cap_angle / MOLD_TAU + 1.0);
			mold_torus_cap_or_line_pixel_coverage = 1.0;
		} else {
			float span = clamp(shape_data.w, 0.0, MOLD_TAU);
			float major_angle = span >= MOLD_TAU
				? -UV.x * MOLD_TAU
				: shape_data.z + span * (1.0 - UV.x);
			float minor_angle = UV.y * MOLD_TAU;
			vec3 radial = vec3(cos(major_angle), 0.0, sin(major_angle));
			vec3 tube_normal =
				radial * cos(minor_angle) + vec3(0.0, sin(minor_angle), 0.0);
			VERTEX = radial * (0.5 - shape_data.y) + tube_normal * shape_data.y;
			NORMAL = tube_normal;
			if (span < MOLD_TAU)
				UV.x = fract(-major_angle / MOLD_TAU + 1.0);
		}
	}
	mold_line_progress = 0.0;
	mold_line_across = 0.0;
	mold_line_edge = 0.0;
	mold_line_along = 0.0;
	mold_polyline_coord = vec4(0.0);
	if ((int(round(mold_flags.w)) & 4) != 0) {
		bool is_polyline = (int(round(mold_flags.w)) & 8) != 0;
		bool is_planar_line = mold_flags.y > 0.5 || is_polyline;
		bool local_aa = mold_local_aa_quality() > 0;
		if (is_planar_line) {
			mold_line_progress = clamp(UV.x, 0.0, 1.0);
			mold_line_across = clamp(UV.y, 0.0, 1.0) * 2.0 - 1.0;
			float padding_pixels = local_aa ? MOLD_AA_PADDING_PIXELS : 0.0;
			if (is_polyline) {
				vec2 extrusion = CUSTOM0.xy;
				float radius = CUSTOM0.w;
				bool is_segment = CUSTOM0.z < 0.5;
				vec2 width_direction = is_segment ? vec2(CUSTOM1.x, CUSTOM2.x)
					: extrusion / max(length(extrusion), 0.00001);
				vec4 center_clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
				vec4 edge_clip = PROJECTION_MATRIX * MODELVIEW_MATRIX
					* vec4(VERTEX + vec3(width_direction * radius, 0.0), 1.0);
				float half_width_pixels = projected_pixel_distance(center_clip, edge_clip);
				float target_width_pixels = half_width_pixels * 2.0;
				mold_torus_cap_or_line_pixel_coverage = target_width_pixels;
				float raster_width_pixels = max(1.0, target_width_pixels + padding_pixels * 2.0);
				float edge_scale = target_width_pixels > 0.0 ? raster_width_pixels / target_width_pixels : 1.0;
				VERTEX.xy += extrusion * (edge_scale - 1.0);
				vec4 analytic_coord = CUSTOM1;
				vec4 analytic_change = CUSTOM2;
				if (is_segment) { analytic_coord.x = 0.0; analytic_change.x = 0.0; }
				mold_polyline_coord = analytic_coord + analytic_change * (edge_scale - 1.0);
				mold_line_along = CUSTOM0.z;
				mold_line_edge = mold_polyline_coord.y;
			} else {
				vec3 center_view = (VIEW_MATRIX * MODEL_MATRIX[3]).xyz;
				vec3 length_view = (VIEW_MATRIX * vec4(MODEL_MATRIX[0].xyz, 0.0)).xyz;
				vec3 width_view = (VIEW_MATRIX * vec4(MODEL_MATRIX[1].xyz, 0.0)).xyz;
				vec3 anchor_view = center_view + length_view * (mold_line_progress - 0.5);
				if ((int(round(mold_flags.w)) & 2) != 0) {
					vec3 view_direction = PROJECTION_MATRIX[3][3] > 0.5
						? vec3(0.0, 0.0, -1.0) : anchor_view;
					vec3 side_view = cross(view_direction, length_view);
					float side_length = length(side_view);
					if (side_length < 0.00001) {
						side_view = cross(vec3(0.0, 0.0, -1.0), length_view);
						side_length = length(side_view);
					}
					width_view = (side_length < 0.00001 ? vec3(1.0, 0.0, 0.0)
						: side_view / side_length) * length(MODEL_MATRIX[1].xyz);
				}
				vec4 anchor_clip = PROJECTION_MATRIX * vec4(anchor_view, 1.0);
				float width_pixels = projected_pixel_distance(anchor_clip,
					PROJECTION_MATRIX * vec4(anchor_view + width_view, 1.0));
				mold_torus_cap_or_line_pixel_coverage = width_pixels;
				float length_pixels = projected_pixel_distance(
					PROJECTION_MATRIX * vec4(center_view - length_view * 0.5, 1.0),
					PROJECTION_MATRIX * vec4(center_view + length_view * 0.5, 1.0));
				float width_scale = max(1.0, width_pixels + padding_pixels * 2.0)
					/ max(width_pixels, 0.00001);
				float length_scale = (length_pixels + padding_pixels * 2.0)
					/ max(length_pixels, 0.00001);
				VERTEX.xy *= vec2(length_scale, width_scale);
				UV = (UV - vec2(0.5)) * vec2(length_scale, width_scale) + vec2(0.5);
				mold_line_edge = mold_line_across * width_scale;
				mold_line_along = (mold_line_progress * 2.0 - 1.0) * length_scale;
			}
		} else {
			float half_length = mold_flags.z > 0.5 && mold_flags.z < 1.5 ? max(0.5 + shape_data.y, 0.00001) : 0.5;
			mold_line_progress = clamp(VERTEX.y / (2.0 * half_length) + 0.5, 0.0, 1.0);
			vec3 center_view = (VIEW_MATRIX * MODEL_MATRIX[3]).xyz;
			vec3 line_axis_view = (VIEW_MATRIX * vec4(MODEL_MATRIX[1].xyz, 0.0)).xyz;
			vec3 width_x_view = (VIEW_MATRIX * vec4(MODEL_MATRIX[0].xyz, 0.0)).xyz;
			vec3 width_z_view = (VIEW_MATRIX * vec4(MODEL_MATRIX[2].xyz, 0.0)).xyz;
			vec3 anchor_view = center_view + line_axis_view * (mold_line_progress - 0.5);
			vec3 view_direction = PROJECTION_MATRIX[3][3] > 0.5
				? vec3(0.0, 0.0, -1.0) : anchor_view;
			vec3 screen_normal_view = cross(view_direction, line_axis_view);
			float normal_length = length(screen_normal_view);
			if (normal_length < 0.00001) {
				screen_normal_view = cross(vec3(0.0, 0.0, -1.0), line_axis_view);
				normal_length = length(screen_normal_view);
			}
			screen_normal_view = normal_length < 0.00001
				? vec3(1.0, 0.0, 0.0) : screen_normal_view / normal_length;
			float target_diameter = max(length(width_x_view), length(width_z_view));
			vec4 anchor_clip = PROJECTION_MATRIX * vec4(anchor_view, 1.0);
			float target_width_pixels = projected_pixel_distance(anchor_clip,
				PROJECTION_MATRIX * vec4(anchor_view + screen_normal_view * target_diameter, 1.0));
			mold_torus_cap_or_line_pixel_coverage = target_width_pixels;
			float raster_scale = max(target_width_pixels, 1.0)
				/ max(target_width_pixels, 0.00001);
			VERTEX.xz *= raster_scale;
		}
	}
	if ((int(round(mold_flags.w)) & 2) != 0) {
		vec3 billboard_center_view = (VIEW_MATRIX * MODEL_MATRIX[3]).xyz;
		vec3 billboard_vertex_view;
		if ((int(round(mold_flags.w)) & 4) != 0) {
			vec3 billboard_tangent_view = (VIEW_MATRIX * vec4(MODEL_MATRIX[0].xyz, 0.0)).xyz;
			vec3 billboard_centerline_view = billboard_center_view + billboard_tangent_view * VERTEX.x;
			vec3 billboard_view_direction = PROJECTION_MATRIX[3][3] > 0.5
				? vec3(0.0, 0.0, -1.0)
				: billboard_centerline_view;
			vec3 billboard_side_view = cross(billboard_view_direction, billboard_tangent_view);
			float billboard_side_length = length(billboard_side_view);
			if (billboard_side_length < 0.00001) {
				billboard_side_view = cross(vec3(0.0, 0.0, -1.0), billboard_tangent_view);
				billboard_side_length = length(billboard_side_view);
			}
			billboard_side_view = billboard_side_length < 0.00001
				? vec3(1.0, 0.0, 0.0)
				: billboard_side_view / billboard_side_length;
			billboard_vertex_view = billboard_centerline_view
				+ billboard_side_view * VERTEX.y * length(MODEL_MATRIX[1].xyz);
		} else if ((int(round(mold_flags.w)) & 16) != 0) {
			vec3 billboard_center_world = MODEL_MATRIX[3].xyz;
			vec3 billboard_facing_world = PROJECTION_MATRIX[3][3] > 0.5
				? INV_VIEW_MATRIX[2].xyz
				: INV_VIEW_MATRIX[3].xyz - billboard_center_world;
			vec3 billboard_horizontal_world = vec3(
				billboard_facing_world.x, 0.0, billboard_facing_world.z);
			float billboard_horizontal_length = length(billboard_horizontal_world);
			vec3 billboard_right_world;
			if (billboard_horizontal_length < 0.00001) {
				billboard_right_world = vec3(MODEL_MATRIX[0].x, 0.0, MODEL_MATRIX[0].z);
				float billboard_right_length = length(billboard_right_world);
				billboard_right_world = billboard_right_length < 0.00001
					? vec3(1.0, 0.0, 0.0)
					: billboard_right_world / billboard_right_length;
			} else {
				billboard_right_world = cross(
					vec3(0.0, 1.0, 0.0),
					billboard_horizontal_world / billboard_horizontal_length);
			}
			vec2 billboard_scale = vec2(
				length(MODEL_MATRIX[0].xyz),
				length(MODEL_MATRIX[1].xyz));
			vec3 billboard_vertex_world = billboard_center_world
				+ billboard_right_world * VERTEX.x * billboard_scale.x
				+ vec3(0.0, 1.0, 0.0) * VERTEX.y * billboard_scale.y;
			billboard_vertex_view = (VIEW_MATRIX * vec4(billboard_vertex_world, 1.0)).xyz;
		} else {
			vec2 billboard_scale = vec2(
				length(MODEL_MATRIX[0].xyz),
				length(MODEL_MATRIX[1].xyz));
			billboard_vertex_view = billboard_center_view
				+ vec3(VERTEX.xy * billboard_scale, 0.0);
		}
		POSITION = PROJECTION_MATRIX * vec4(billboard_vertex_view, 1.0);
	} else {
		POSITION = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	}
	// Reuse polyline coordinates for deformed primitive-local position.
	if (int(round(gradient_data.w)) / 32 >= 6) mold_polyline_coord.xyz = VERTEX;
	mold_gradient_t = 0.0;
	if (packed_gradient(1, 8) == 1) {
		int shape_kind = int(round(gradient_data.w)) / 32;
		vec3 center = vec3(0.0); vec3 half_extent = vec3(0.5);
		if (shape_kind == 11) { center.y = 0.25; half_extent.y = 0.25; }
		else if (shape_kind == 12) half_extent.y = max(0.0001, 0.5 + shape_data.y);
		else if (shape_kind == 13) half_extent.y = max(0.0001, shape_data.y);
		vec3 local_gradient = packed_gradient(16, 2) == 0 ? transpose(mat3(MODEL_MATRIX)) * gradient_data.xyz : gradient_data.xyz;
		float half_range = max(dot(abs(local_gradient), half_extent), 0.00001);
		mold_gradient_t = clamp(dot(VERTEX - center, local_gradient) / (2.0 * half_range) + 0.5, 0.0, 1.0);
	}
}

void fragment() {
%s
	int packed_flags = int(round(mold_flags.w));
	bool is_line = (packed_flags & 4) != 0;
	bool is_polyline = (packed_flags & 8) != 0;
	bool is_planar_line = is_line && (mold_flags.y > 0.5 || is_polyline);
	bool rounded_line_2d = is_planar_line && !is_polyline
		&& shape_data.x > 1.5 && shape_data.x < 2.5;
	bool local_aa = mold_local_aa_quality() > 0;
	float coverage = rounded_line_2d ? shape_coverage(UV, shape_data, dash_data)
		: is_planar_line ? 1.0
		: (mold_flags.y > 0.5 ? shape_coverage(UV, shape_data, dash_data) : 1.0);
	float thin_line_coverage = 1.0;
	if (is_line) {
		vec4 line_dash = dash_data;
		if (mold_flags.y < 0.5 && line_dash.x >= 0.0) line_dash.y = floor(line_dash.y) + 0.1;
		if (!is_polyline) coverage *= dashed_mask(mold_line_progress, mold_line_across, line_dash);
		if (is_planar_line) {
			if (is_polyline) {
				float edge = mold_line_along > 1.5 ? length(mold_polyline_coord.xy) : mold_polyline_coord.y;
				float pixel_coverage = polyline_pixel_coverage(edge);
				thin_line_coverage = clamp(pixel_coverage, 0.0, 1.0);
				if (local_aa) {
					float outline = line_local_aa(edge, pixel_coverage);
					float caps = min(polyline_cap_aa(mold_polyline_coord.z, pixel_coverage),
						polyline_cap_aa(mold_polyline_coord.w, pixel_coverage));
					coverage *= min(outline, caps);
				} else if (mold_line_along > 1.5)
					coverage *= step(length(mold_polyline_coord.xy), 1.0);
			} else {
				float pixel_coverage = mold_torus_cap_or_line_pixel_coverage;
				thin_line_coverage = clamp(pixel_coverage, 0.0, 1.0);
				if (local_aa && !rounded_line_2d) {
					coverage *= line_local_aa(mold_line_edge, pixel_coverage);
					coverage *= line_local_aa(mold_line_along, pixel_coverage);
				}
				coverage *= angular_mask(UV * 2.0 - vec2(1.0), angular_data.x, angular_data.y);
			}
		} else thin_line_coverage = clamp(
			mold_torus_cap_or_line_pixel_coverage, 0.0, 1.0);
	}
	if (mold_flags.z > 1.5) {
		float span = clamp(shape_data.w, 0.0, MOLD_TAU);
		if (mold_torus_cap_or_line_pixel_coverage > 0.5) {
			if (span <= 0.0 || span >= MOLD_TAU) coverage = 0.0;
		} else if (span <= 0.0) coverage = 0.0;
	}
	vec4 result = evaluated_color(UV, gradient_data.xy) * mold_vertex_color;
	if (%d == 4) {
		if (coverage * thin_line_coverage * result.a < dither_threshold(FRAGCOORD.xy)) discard;
		result.a = 1.0;
	} else if (%d == 0) {
		if (%s) {
			result.a *= coverage * thin_line_coverage;
			if (result.a <= 0.000001) discard;
		} else {
			if (thin_line_coverage < 0.99999) {
				if (coverage * thin_line_coverage * result.a < dither_threshold(FRAGCOORD.xy)) discard;
			} else if (coverage < 0.5) discard;
			result.a = %s;
		}
	} else {
		result.a *= coverage * thin_line_coverage;
		if (result.a <= 0.000001) discard;
	}
	ALBEDO = mold_output_color(result.rgb);
%s
}
""" % [cull, blend, depth, depth_test, stencil, declarations, vertex_load, lod_fragment, mode, mode, "true" if coverage_output else "false", "1.0", alpha_write]
	return shader.replace("%%", "%")


static func _stencil_source(state: MoldRenderState) -> String:
	if state.stencil_flags == MoldRenderState.StencilFlags.DISABLED: return ""
	var modes := PackedStringArray()
	if state.stencil_flags & MoldRenderState.StencilFlags.READ: modes.append("read")
	if state.stencil_flags & MoldRenderState.StencilFlags.WRITE: modes.append("write")
	if state.stencil_flags & MoldRenderState.StencilFlags.WRITE_DEPTH_FAIL:
		modes.append("write_if_depth_fail")
	var comparison := state.stencil_compare if state.stencil_flags & MoldRenderState.StencilFlags.READ else MoldRenderState.StencilCompare.ALWAYS
	match comparison:
		MoldRenderState.StencilCompare.LESS: modes.append("compare_less")
		MoldRenderState.StencilCompare.EQUAL: modes.append("compare_equal")
		MoldRenderState.StencilCompare.LESS_OR_EQUAL: modes.append("compare_less_or_equal")
		MoldRenderState.StencilCompare.GREATER: modes.append("compare_greater")
		MoldRenderState.StencilCompare.NOT_EQUAL: modes.append("compare_not_equal")
		MoldRenderState.StencilCompare.GREATER_OR_EQUAL: modes.append("compare_greater_or_equal")
		_: modes.append("compare_always")
	return "stencil_mode %s, %d;" % [", ".join(modes), state.stencil_reference]
