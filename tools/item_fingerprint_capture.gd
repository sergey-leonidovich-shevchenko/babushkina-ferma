extends SceneTree

const Game := preload("res://scripts/game.gd")
const Assets := preload("res://scripts/systems/visual_asset_system.gd")
const Fitter := preload("res://tools/item_ui_fitter.gd")
var output := ""
var files: Dictionary = {}


## Собирает точные отпечатки всего каталога отдельным процессом, не меняя минимальный эксперимент.
func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output = ProjectSettings.globalize_path(argument.trim_prefix("--output="))
	if output.is_empty() or DirAccess.dir_exists_absolute(output):
		quit(2)
		return
	ProjectSettings.set_setting("application/config/use_custom_user_dir", true)
	ProjectSettings.set_setting(
		"application/config/custom_user_dir_name",
		"Codex-Item-Fingerprints-" + str(Time.get_ticks_usec())
	)
	DirAccess.make_dir_recursive_absolute(output)
	var game := Game.new()
	game._ready()
	Assets.initialize_item_icons(game.InventorySystem.ITEM_DATA.keys())
	var kinds: Array = game.InventorySystem.ITEM_DATA.keys()
	kinds.sort()
	var entries: Dictionary = {}
	var different: Array[String] = []
	for kind in kinds:
		var visual := Assets.item_visual(kind)
		var source: Image = visual.texture.get_image()
		if source.is_compressed():
			source.decompress()
		if source.get_format() != Image.FORMAT_RGBA8:
			push_error("ITEM FINGERPRINTS: expected source RGBA8: " + String(kind))
			game.free()
			quit(2)
			return
		remember_texture(visual.texture)
		var path := "res://assets/game/items/ui/preview/" + String(kind) + ".png"
		var reference := Image.load_from_file(ProjectSettings.globalize_path(path))
		var derived := Fitter.fitted(source, source.get_used_rect(), 160, 8)
		var bounds := source.get_used_rect()
		var same := digest(reference.get_data()) == digest(derived.get_data())
		if not same:
			different.append(kind)
		entries[kind] = {
			"source_path": visual.texture.resource_path,
			"provider": visual.provider,
			"tint": visual.tint.to_html(),
			"source_size": [source.get_width(), source.get_height()],
			"source_format": source.get_format(),
			"bounds": [bounds.position.x, bounds.position.y, bounds.size.x, bounds.size.y],
			"source_rgba_sha256": digest(source.get_data()),
			"source_png_serialized_sha256": digest(source.save_png_to_buffer()),
			"preview_file_sha256": digest(FileAccess.get_file_as_bytes(path)),
			"preview_rgba_sha256": digest(reference.get_data()),
			"derived_rgba_sha256": digest(derived.get_data()),
			"same_rgba": same,
		}
	var report := {
		"schema": 1,
		"purpose": "catalogue_fingerprints_for_contract_review_not_acceptance",
		"engine": Engine.get_version_info(),
		"os": OS.get_name(),
		"architecture": Engine.get_architecture_name(),
		"entries": entries,
		"physical_source_files": files,
		"different_ids": different,
	}
	var file := FileAccess.open(output.path_join("report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  ") + "\n")
	file.close()
	print("ITEM FINGERPRINTS: ", JSON.stringify(report))
	game.free()
	quit()


## Фиксирует исходный tres и вложенные PNG по файловым байтам, без Image.save_png.
func remember_texture(texture: Texture2D) -> void:
	if texture == null:
		return
	if not texture.resource_path.is_empty():
		var path := texture.resource_path.get_slice("::", 0)
		if not files.has(path):
			files[path] = digest(FileAccess.get_file_as_bytes(path))
	if texture is AtlasTexture:
		remember_texture(texture.atlas)
	elif texture is CanvasTexture:
		remember_texture(texture.diffuse_texture)


## Хеширует ровно переданные файловые или пиксельные байты.
func digest(bytes: PackedByteArray) -> String:
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(bytes)
	return hash.finish().hex_encode()
