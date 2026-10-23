extends RefCounted

const PATH := "res://tests/fixtures/item_export_contract/manifest.json"


## Загружает отдельное предложение контракта; старый игровой suite его пока не вызывает.
static func manifest() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(PATH))


## Проверяет полный реестр, прежний движок/fitter и реальные исходные файлы без допуска в пикселях.
static func environment(data: Dictionary, kinds: Array) -> Array[String]:
	var errors: Array[String] = []
	var registered := kinds.duplicate()
	registered.sort()
	var recorded: Array = data.entries.keys()
	recorded.sort()
	if recorded != registered:
		errors.append("complete item coverage differs")
	if String(Engine.get_version_info().hash) != data.engine_hash:
		errors.append("engine differs")
	if FileAccess.get_sha256("res://tools/item_ui_fitter.gd") != data.fitter_sha256:
		errors.append("fitter differs")
	if data["size"] != 160 or data.padding != 8:
		errors.append("export geometry differs")
	for path in data.physical_source_files:
		if FileAccess.get_sha256(path) != data.physical_source_files[path]:
			errors.append("source file differs: " + String(path))
	return errors


## Сверяет настоящий source, неизменный preview и целый повторный экспорт с конечным набором хешей.
static func inspect(
	entry: Dictionary,
	visual: Dictionary,
	source: Image,
	preview: Image,
	preview_bytes: PackedByteArray,
	derived: Image
) -> Array[String]:
	var errors: Array[String] = []
	var bounds := source.get_used_rect()
	if (
		source.get_size() != Vector2i(int(entry.source_size[0]), int(entry.source_size[1]))
		or source.get_format() != entry.source_format
		or (
			bounds
			!= Rect2i(
				int(entry.bounds[0]),
				int(entry.bounds[1]),
				int(entry.bounds[2]),
				int(entry.bounds[3])
			)
		)
		or digest(source.get_data()) != entry.source_rgba_sha256
	):
		errors.append("source RGBA/geometry differs")
	if (
		visual.texture.resource_path != entry.source_path
		or visual.provider != entry.provider
		or visual.tint.to_html() != entry.tint
	):
		errors.append("source identity differs")
	if (
		preview.get_size() != Vector2i(160, 160)
		or preview.get_format() != Image.FORMAT_RGBA8
		or digest(preview_bytes) != entry.preview_file_sha256
		or digest(preview.get_data()) != entry.preview_rgba_sha256
	):
		errors.append("actual preview file/RGBA differs")
	if (
		derived.get_size() != Vector2i(160, 160)
		or derived.get_format() != Image.FORMAT_RGBA8
		or digest(derived.get_data()) not in entry.derived_rgba_sha256
	):
		errors.append("unknown complete derived RGBA")
	return errors


## Хеширует ровно переданный файл или RGBA-буфер, не сериализуя изображение заново.
static func digest(bytes: PackedByteArray) -> String:
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(bytes)
	return hash.finish().hex_encode()
