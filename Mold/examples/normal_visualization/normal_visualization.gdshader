shader_type spatial;
render_mode unshaded, cull_back;

varying vec3 object_normal;

void vertex() {
	object_normal = normalize(NORMAL);
}

void fragment() {
	ALBEDO = normalize(object_normal) * 0.5 + vec3(0.5);
}
