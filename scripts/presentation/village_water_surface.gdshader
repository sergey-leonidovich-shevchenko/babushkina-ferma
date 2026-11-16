shader_type canvas_item;
render_mode unshaded;

uniform vec2 ripple_offset = vec2(0.0);
uniform bool fine_ripples = true;

void fragment() {
	// The retained polygon UVs are expressed in world pixels divided by the material size.
	vec2 world = UV / TEXTURE_PIXEL_SIZE;
	float curve = sin(dot(world, vec2(0.027, 0.043)));
	float broad = sin(dot(world, vec2(0.057, 0.119)) + curve * 0.82 + ripple_offset.x);
	float crest = smoothstep(0.28, 0.99, broad);
	float shimmer = broad * 0.063 + (crest - 0.28) * 0.038;

	if (fine_ripples) {
		float fine = sin(dot(world, vec2(-0.137, 0.326)) + broad * 0.63 + ripple_offset.y);
		shimmer += fine * 0.023 + crest * smoothstep(0.52, 1.0, fine) * 0.024;
	}

	// Preserve the depth-dependent alpha and the silhouette of the retained surface.
	COLOR.rgb *= 1.0 + shimmer;
}
