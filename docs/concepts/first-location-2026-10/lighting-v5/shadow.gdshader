shader_type canvas_item;

uniform vec4 shadow_color : source_color = vec4(0.149, 0.243, 0.204, 1.0);
uniform float softness = 12.0;
uniform vec2 cast_direction = vec2(0.48, 0.32);
varying float strength;
varying float projected;

void vertex() {
	strength = COLOR.a;
	projected = COLOR.r;
}

float silhouette(sampler2D mask_texture, vec2 uv) {
	if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) return 0.0;
	return texture(mask_texture, uv).a;
}

void fragment() {
	vec2 dx = TEXTURE_PIXEL_SIZE * vec2(softness, 0.0);
	vec2 dy = TEXTURE_PIXEL_SIZE * mix(vec2(0.0, softness), vec2(-cast_direction.x, -1.0) * softness / max(0.1, cast_direction.y), projected);
	float alpha = silhouette(TEXTURE, UV) * 0.20;
	alpha += silhouette(TEXTURE, UV + dx) * 0.10;
	alpha += silhouette(TEXTURE, UV - dx) * 0.10;
	alpha += silhouette(TEXTURE, UV + dy) * 0.10;
	alpha += silhouette(TEXTURE, UV - dy) * 0.10;
	alpha += silhouette(TEXTURE, UV + (dx + dy) * 0.7) * 0.07;
	alpha += silhouette(TEXTURE, UV + (-dx + dy) * 0.7) * 0.07;
	alpha += silhouette(TEXTURE, UV + (dx - dy) * 0.7) * 0.07;
	alpha += silhouette(TEXTURE, UV - (dx + dy) * 0.7) * 0.07;
	alpha += silhouette(TEXTURE, UV + dx * 1.6) * 0.03;
	alpha += silhouette(TEXTURE, UV - dx * 1.6) * 0.03;
	alpha += silhouette(TEXTURE, UV + dy * 1.6) * 0.03;
	alpha += silhouette(TEXTURE, UV - dy * 1.6) * 0.03;
	COLOR = vec4(shadow_color.rgb, alpha * strength * mix(0.82, 1.0, UV.y));
}
