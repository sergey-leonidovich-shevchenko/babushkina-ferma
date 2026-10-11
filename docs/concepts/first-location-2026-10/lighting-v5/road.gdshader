shader_type canvas_item;

uniform sampler2D earth : filter_linear, repeat_enable;
uniform vec2 world_size = vec2(2400.0, 1350.0);
uniform float texture_period = 288.0;
uniform float edge_width = 2.0;

void fragment() {
	vec2 step_uv = vec2(edge_width) / world_size;
	float center = texture(TEXTURE, UV).a;
	float north = texture(TEXTURE, UV + vec2(0.0, step_uv.y)).a;
	float south = texture(TEXTURE, UV - vec2(0.0, step_uv.y)).a;
	float east = texture(TEXTURE, UV + vec2(step_uv.x, 0.0)).a;
	float west = texture(TEXTURE, UV - vec2(step_uv.x, 0.0)).a;
	float outer = max(center, max(max(north, south), max(east, west)));
	float inner = min(center, min(min(north, south), min(east, west)));
	vec3 soil = texture(earth, UV * world_size / texture_period).rgb;
	vec3 rim = mix(soil, vec3(0.40, 0.44, 0.23), 0.35);
	vec3 color = mix(soil, rim, clamp(center - inner, 0.0, 1.0) * 0.5);
	color = mix(rim, color, center);
	COLOR = vec4(color, max(center, (outer - center) * 0.30));
}
