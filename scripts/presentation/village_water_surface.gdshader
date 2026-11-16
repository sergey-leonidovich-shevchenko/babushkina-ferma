shader_type canvas_item;
render_mode unshaded;

uniform vec2 ripple_offset = vec2(0.0);
uniform bool fine_ripples = true;
uniform bool directed = false;
uniform sampler2D flow_coordinates : filter_linear, repeat_disable;
uniform vec4 flow_bounds = vec4(0.0, 0.0, 1.0, 1.0);
uniform float flow_phase = 0.0;

float standing_ripples(vec2 world) {
	float curve = sin(dot(world, vec2(0.027, 0.043)));
	float broad = sin(dot(world, vec2(0.057, 0.119)) + curve * 0.82 + ripple_offset.x);
	float crest = smoothstep(0.28, 0.99, broad);
	float shimmer = broad * 0.063 + (crest - 0.28) * 0.038;

	if (fine_ripples) {
		float fine = sin(dot(world, vec2(-0.137, 0.326)) + broad * 0.63 + ripple_offset.y);
		shimmer += fine * 0.023 + crest * smoothstep(0.52, 1.0, fine) * 0.024;
	}

	return shimmer;
}

float river_ripples(vec2 world) {
	// High and low bytes interpolate linearly when decoded without rounding.
	vec4 encoded = texture(flow_coordinates, (world - flow_bounds.xy) / flow_bounds.zw);
	vec2 channels = vec2(dot(encoded.rg, vec2(256.0, 1.0)), dot(encoded.ba, vec2(256.0, 1.0)));
	vec2 river = channels * (255.0 / 16.0) - vec2(8.0, 128.0);
	float travel = river.x * (TAU / 96.0) - flow_phase;
	float curl = sin(travel + river.y * 0.044);
	float broad = sin(travel * 2.0 + river.y * 0.102 + curl * 0.53);
	float crest = smoothstep(0.28, 0.99, broad);
	float shimmer = broad * 0.063 + (crest - 0.28) * 0.038;
	if (fine_ripples) {
		float fine = sin(travel * 5.0 + river.y * 0.326 + broad * 0.63);
		shimmer += fine * 0.023 + crest * smoothstep(0.52, 1.0, fine) * 0.024;
	}
	// Soften the ripple at the banks and around the inner point of a curve.
	return shimmer * (1.0 - 0.78 * smoothstep(33.0, 48.0, abs(river.y)));
}

void fragment() {
	// The retained polygon UVs are expressed in world pixels divided by the material size.
	vec2 world = UV / TEXTURE_PIXEL_SIZE;
	float shimmer = directed ? river_ripples(world) : standing_ripples(world);
	// Preserve the depth-dependent alpha and the silhouette of the retained surface.
	COLOR.rgb *= 1.0 + shimmer;
}
