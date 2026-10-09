shader_type spatial;
render_mode unshaded, cull_disabled;
uniform vec4 floor_color : source_color = vec4(0.60, 0.612, 0.584, 1.0);
varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = vec2(world_position.x / 0.24, (world_position.z - 0.025) / 0.46);
	float contact_shadow = exp(-dot(p, p) * 1.6) * 0.34;
	ALBEDO = floor_color.rgb * (1.0 - contact_shadow);
}
