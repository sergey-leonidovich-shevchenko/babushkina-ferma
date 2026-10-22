shader_type canvas_item;
render_mode unshaded;

uniform sampler2D source_atlas : source_color, filter_linear, repeat_disable;
uniform sampler2D root_mask : filter_linear, repeat_disable;
uniform vec2 atlas_size = vec2(1.0);
uniform vec4 source_rect = vec4(0.0, 0.0, 1.0, 1.0);
uniform bool mirror_x = false;
uniform float lock_v = 1.0;
uniform float top_v = 0.0;
uniform bool flexible = false;
uniform vec2 bend = vec2(0.0);
uniform bool show_weights = false;
uniform vec4 tint : source_color = vec4(1.0);

void vertex() {
	float weight = flexible ? pow(clamp((lock_v - UV.y) / max(lock_v - top_v, 0.0001), 0.0, 1.0), 2.0) : 0.0;
	VERTEX += clamp(bend, vec2(-8.0), vec2(8.0)) * weight;
}

void fragment() {
	vec2 local_uv = vec2(mirror_x ? 1.0 - UV.x : UV.x, UV.y);
	vec2 pixel = clamp(local_uv * source_rect.zw, vec2(0.5), source_rect.zw - vec2(0.5));
	vec4 original = texture(source_atlas, (source_rect.xy + pixel) / atlas_size);
	float weight = texture(root_mask, pixel / source_rect.zw).r;
	COLOR = (show_weights ? vec4(vec3(weight), original.a) : original) * tint;
}
