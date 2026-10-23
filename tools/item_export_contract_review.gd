extends SceneTree

const Game := preload("res://scripts/game.gd")
const Assets := preload("res://scripts/systems/visual_asset_system.gd")
const Fitter := preload("res://tools/item_ui_fitter.gd")
const Contract := preload("res://tools/item_export_contract.gd")
var checks := 0
var failures: Array[String] = []


## Выполняет предложение отдельно от неизменного item_sizes_suite и портит только копии настоящих ресурсов.
func _initialize() -> void:
	ProjectSettings.set_setting("application/config/use_custom_user_dir", true)
	ProjectSettings.set_setting(
		"application/config/custom_user_dir_name",
		"Codex-Export-Review-" + str(Time.get_ticks_usec())
	)
	var game := Game.new()
	game._ready()
	Assets.initialize_item_icons(game.InventorySystem.ITEM_DATA.keys())
	var data := Contract.manifest()
	check(
		Contract.environment(data, game.InventorySystem.ITEM_DATA.keys()).is_empty(), "environment"
	)
	for kind in game.InventorySystem.ITEM_DATA:
		var visual := Assets.item_visual(kind)
		var source: Image = visual.texture.get_image()
		if source.is_compressed():
			source.decompress()
		var path := "res://assets/game/items/ui/preview/" + String(kind) + ".png"
		var actual := Image.load_from_file(ProjectSettings.globalize_path(path))
		var bytes := FileAccess.get_file_as_bytes(path)
		var derived := Fitter.fitted(source, source.get_used_rect(), 160, 8)
		var entry: Dictionary = data.entries[kind]
		var errors := Contract.inspect(entry, visual, source, actual, bytes, derived)
		check(errors.is_empty(), kind + ": " + str(errors))
		if entry.derived_rgba_sha256.size() == 2:
			negative_controls(kind, entry, visual, source, actual, bytes, derived)
	game.free()
	print("EXPORT CONTRACT PROPOSAL: ", checks, " checks; failures=", failures)
	quit(0 if failures.is_empty() else 1)


## Для каждого спорного предмета отвергает 1/255 в source/preview/derived и подмену PNG известным Linux-выводом.
func negative_controls(
	kind: String,
	entry: Dictionary,
	visual: Dictionary,
	source: Image,
	actual: Image,
	bytes: PackedByteArray,
	derived: Image
) -> void:
	var changed_source := changed(source)
	check(
		not Contract.inspect(entry, visual, changed_source, actual, bytes, derived).is_empty(),
		kind + " rejects one source byte"
	)
	var changed_actual := changed(actual)
	check(
		not Contract.inspect(entry, visual, source, changed_actual, bytes, derived).is_empty(),
		kind + " rejects one preview byte"
	)
	check(
		not (
			Contract
			. inspect(
				entry, visual, source, changed_actual, changed_actual.save_png_to_buffer(), derived
			)
			. is_empty()
		),
		kind + " rejects edited PNG even after serialization"
	)
	check(
		not Contract.inspect(entry, visual, source, actual, bytes, changed(derived)).is_empty(),
		kind + " rejects an unknown one-byte derived variant"
	)
	var linux_path := (
		"res://docs/reports/visual-overhaul/vfoliage-006/ci-repro/linux-x64/preview/"
		+ kind
		+ "-resized.png"
	)
	var linux_image := Image.load_from_file(ProjectSettings.globalize_path(linux_path))
	check(
		Contract.inspect(entry, visual, source, actual, bytes, linux_image).is_empty(),
		kind + " accepts evidenced whole Linux derived output"
	)
	check(
		not (
			Contract
			. inspect(
				entry,
				visual,
				source,
				linux_image,
				FileAccess.get_file_as_bytes(linux_path),
				derived
			)
			. is_empty()
		),
		kind + " rejects replacing actual preview with Linux derived output"
	)


## Меняет ровно один RGBA-байт копии, включая невидимый RGB, без записи игрового файла.
func changed(image: Image) -> Image:
	var bytes := image.get_data()
	bytes[0] = int(bytes[0]) ^ 1
	return Image.create_from_data(
		image.get_width(), image.get_height(), false, image.get_format(), bytes
	)


## Сохраняет каждый отказ для полного отчёта и ненулевого кода процесса.
func check(passed: bool, label: String) -> void:
	checks += 1
	if not passed:
		failures.append(label)
