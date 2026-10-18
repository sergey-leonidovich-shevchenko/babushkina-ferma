extends RefCounted

const POLICY := preload("res://assets/game/visual_texture_intents.json")
const HINTS := ["source_color","filter_nearest","filter_linear","repeat_disable"]


## Возвращает независимый профиль назначения без изменения политики через внешнюю ссылку.
static func profile(id: String) -> Dictionary:
	return POLICY.data.profiles.get(id,{}).duplicate(true)


## Связывает целую самостоятельную текстуру с явным назначением без копии или преобразования пикселей.
static func binding(texture: Texture2D, intent: String) -> Dictionary:
	if texture==null or texture is AtlasTexture or texture is CanvasTexture or profile(intent).is_empty(): return {}
	var result := {"texture":texture,"intent":intent}
	result.make_read_only(); return result


## Проверяет простые двумерные sampler-uniform до создания материала, включая пропуски и лишние привязки.
static func errors(code: String, bindings: Dictionary) -> Array[String]:
	var result: Array[String]=[]
	var comments := RegEx.new(); comments.compile("(?s)/\\*.*?\\*/|//[^\\n]*")
	var source := comments.sub(code,"",true)
	if "#" in source: result.append("preprocessor directives require a separately expanded contract"); return result
	var type_regex := RegEx.new(); type_regex.compile("\\bshader_type\\s+canvas_item\\s*;")
	if type_regex.search(source)==null: result.append("only canvas_item bindings are supported"); return result
	var declarations := RegEx.new(); declarations.compile("\\buniform\\s+sampler2D\\s+(\\w+)\\s*(:[^;]*)?;")
	var samplers := RegEx.new(); samplers.compile("\\buniform\\s+[^;]*\\b[iu]?sampler\\w*\\b[^;]*;")
	var matches := declarations.search_all(source)
	if matches.size()!=samplers.search_all(source).size(): result.append("unsupported sampler declaration")
	var seen: Dictionary={}
	for match in matches:
		var name := match.get_string(1)
		if seen.has(name): result.append(name+": duplicate sampler")
		seen[name]=true
		var entry: Dictionary=bindings.get(name,{}) if bindings.get(name) is Dictionary else {}
		var settings := profile(String(entry.get("intent","")))
		if settings.is_empty() or binding(entry.get("texture") as Texture2D,String(entry.get("intent",""))).is_empty():
			result.append(name+": missing texture or unknown intent"); continue
		var hints: Array[String]=[]
		for token in match.get_string(2).trim_prefix(":").split(",",false): hints.append(token.strip_edges())
		var unique_hints: Dictionary={}
		for hint in hints: unique_hints[hint]=true
		if hints.size()!=unique_hints.size(): result.append(name+": duplicate sampler hint")
		if hints.has("source_color")!=bool(settings.source_color): result.append(name+": source_color conflicts with "+String(entry.intent))
		if not hints.has("repeat_disable"): result.append(name+": repeat must be explicit and disabled")
		if int(hints.has("filter_nearest"))+int(hints.has("filter_linear"))!=1: result.append(name+": choose one explicit non-mip filter")
		for hint in hints:
			if hint not in HINTS: result.append(name+": unsupported sampler hint "+hint)
	for name in bindings:
		if not seen.has(name): result.append(String(name)+": binding has no sampler")
	return result


## Создаёт материал только после согласования всех назначений; владелец удерживает его вне покадрового цикла.
static func material(shader: Shader, bindings: Dictionary) -> ShaderMaterial:
	if shader==null or not errors(shader.code,bindings).is_empty(): return null
	var result := ShaderMaterial.new(); result.shader=shader
	for name in bindings: result.set_shader_parameter(name,bindings[name].texture)
	return result
