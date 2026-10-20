shader_type canvas_item;
render_mode unshaded;

uniform float wind_time = 0.0;
uniform bool gpu_wind = true;
uniform float amplitude = 2.4;

void vertex() {
	float weight = pow(clamp(1.0 - UV.y / (490.0 / 512.0), 0.0, 1.0), 2.0);
	if (gpu_wind) VERTEX.x += sin(wind_time * 1.8 + COLOR.r * TAU) * amplitude * weight;
}

void fragment() {
	// Vertex COLOR carries phase, not a material tint. The accepted PNG stays unchanged.
	COLOR = texture(TEXTURE, UV);
}
