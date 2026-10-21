extends RefCounted

const VERSION := 1
const LAYERS := ["ground", "behind_actors", "actors", "foreground"]
const LOCAL_UV := Rect2(0, 0, 1, 1)
const KEYS := ["version", "id", "world", "space", "anchor", "bounds", "texture", "source", "material", "modulate", "local_uv", "layer"]

## Создаёт закрытый снимок команды; общие ресурсы сохраняют идентичность и не копируются.
static func create(spec: Dictionary) -> Dictionary:
	if not valid(spec): return {}
	var packet := spec.duplicate(false)
	packet.make_read_only()
	return packet

## Принимает только одну осевую мировую картинку с явным материалом и отдельным локальным UV.
static func valid(spec: Dictionary) -> bool:
	if spec.size()!=KEYS.size(): return false
	for key: String in KEYS:
		if not spec.has(key): return false
	if typeof(spec.version)!=TYPE_INT or spec.version!=VERSION or typeof(spec.space)!=TYPE_STRING or spec.space!="world": return false
	for key in ["id", "world"]:
		if typeof(spec[key])!=TYPE_STRING or spec[key].strip_edges().is_empty() or spec[key].length()>128: return false
	if typeof(spec.layer)!=TYPE_STRING or spec.layer not in LAYERS: return false
	if typeof(spec.anchor)!=TYPE_VECTOR2 or not spec.anchor.is_finite(): return false
	if typeof(spec.bounds)!=TYPE_RECT2 or not _positive_rect(spec.bounds): return false
	if typeof(spec.local_uv)!=TYPE_RECT2 or spec.local_uv!=LOCAL_UV: return false
	if typeof(spec.modulate)!=TYPE_COLOR: return false
	var tint: Color=spec.modulate
	if not is_finite(tint.r) or not is_finite(tint.g) or not is_finite(tint.b) or not is_finite(tint.a): return false
	if tint.r<0 or tint.g<0 or tint.b<0 or tint.a<0 or tint.a>1: return false
	if not spec.texture is Texture2D or not is_instance_valid(spec.texture): return false
	var size: Vector2=spec.texture.get_size()
	if not size.is_finite() or size.x<=0 or size.y<=0: return false
	if typeof(spec.source)!=TYPE_RECT2 or not _positive_rect(spec.source): return false
	if not Rect2(Vector2.ZERO,size).encloses(spec.source): return false
	if spec.material!=null:
		if spec.material is ShaderMaterial:
			if spec.material.shader==null or spec.material.shader.get_mode()!=Shader.MODE_CANVAS_ITEM: return false
		elif not spec.material is CanvasItemMaterial: return false
	return true

## Отвергает вырожденные, обратные и нечисловые границы до любой команды рисования.
static func _positive_rect(rect: Rect2) -> bool:
	return rect.position.is_finite() and rect.size.is_finite() and rect.end.is_finite() and rect.size.x>0 and rect.size.y>0
