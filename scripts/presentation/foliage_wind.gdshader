shader_type canvas_item;
render_mode unshaded, blend_disabled;

uniform sampler2D source_atlas : source_color, filter_linear, repeat_disable;
uniform vec2 atlas_size = vec2(1448.0, 1086.0);
uniform vec4 source_rect = vec4(0.0, 0.0, 362.0, 362.0);
uniform float lock_v = 1.0;
uniform float top_v = 0.0;
uniform float seconds = 0.0;
uniform float amplitude = 1.35;
varying vec2 region_min;
varying vec2 region_size;

void vertex() {
	float weight = pow(clamp((lock_v - UV.y) / max(lock_v - top_v, 0.0001), 0.0, 1.0), 2.0);
	float phase = INSTANCE_CUSTOM.x;
	float wave = 0.78 * sin(seconds * 0.95 + phase) + 0.22 * sin(seconds * 1.61 + phase * 1.7);
	VERTEX.x += wave * amplitude * weight;
	region_min = source_rect.xy;
	region_size = source_rect.zw;
}

void fragment() {
	vec2 pixel = clamp(UV * region_size, vec2(0.5), region_size - vec2(0.5));
	COLOR = texture(source_atlas, (region_min + pixel) / atlas_size);
}
