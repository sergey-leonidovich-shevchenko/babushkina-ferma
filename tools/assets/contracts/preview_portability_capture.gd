extends SceneTree

const Fitter := preload("res://tools/assets/contracts/item_ui_fitter.gd")
const SOURCE_PATHS := {
	"tools/item_ui_fitter.gd": "tools/assets/contracts/item_ui_fitter.gd",
	"tools/preview_portability_capture.gd": "tools/assets/contracts/preview_portability_capture.gd",
}
const INPUT := "res://tests/fixtures/preview_portability/manifest.json"
const CHANNELS := ["r", "g", "b", "a"]
var output := ""


## Собирает диагностические результаты на фиксированных PNG без игрового мира, импорта текстур и изменения эталонов.
func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output = ProjectSettings.globalize_path(argument.trim_prefix("--output="))
	if not _check(
		not output.is_empty() and not DirAccess.dir_exists_absolute(output),
		"new output directory required"
	):
		return
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(INPUT))
	var engine := Engine.get_version_info()
	if not _check(
		(
			engine.major == 4
			and engine.minor == 7
			and engine.patch == 1
			and String(engine.hash) == manifest.engine_hash
		),
		"unexpected engine"
	):
		return
	if not _check(manifest.fitter_file == "tools/item_ui_fitter.gd", "unknown fitter source"):
		return
	if not _check(
		file_digest("res://" + String(SOURCE_PATHS[manifest.fitter_file])) == manifest.fitter_sha256,
		"fitter differs from fixed experiment"
	):
		return
	DirAccess.make_dir_recursive_absolute(output)
	var records: Array[Dictionary] = []
	for entry in manifest.cases:
		var record := collect_case(entry)
		if record.is_empty():
			return
		records.append(record)
	var report := {
		"schema": 1,
		"purpose": "diagnostics_only_not_acceptance",
		"engine": engine,
		"os": OS.get_name(),
		"architecture": Engine.get_architecture_name(),
		"revision": OS.get_environment("GITHUB_SHA"),
		"input_manifest_sha256": file_digest(INPUT),
		"collector_sha256": file_digest("res://tools/assets/contracts/preview_portability_capture.gd"),
		"fitter_sha256": file_digest("res://" + String(SOURCE_PATHS[manifest.fitter_file])),
		"source_paths": SOURCE_PATHS,
		"cases": records,
	}
	var file := FileAccess.open(output.path_join("report.json"), FileAccess.WRITE)
	if not _check(file != null, "cannot create report"):
		return
	file.store_string(JSON.stringify(report, "  ") + "\n")
	file.close()
	print("PREVIEW REPRO: ", JSON.stringify(report))
	quit()


## Проверяет входные байты и bounds, повторяет прежний экспорт и сохраняет точную координату каждого отличия.
func collect_case(entry: Dictionary) -> Dictionary:
	var source_path := "res://" + String(entry.source_file)
	var reference_path := "res://" + String(entry.reference_file)
	var raw := FileAccess.get_file_as_bytes("res://" + String(entry.source_rgba_file))
	var source := Image.create_from_data(
		entry.source_size[0], entry.source_size[1], false, Image.FORMAT_RGBA8, raw
	)
	var decoded := Image.load_from_file(ProjectSettings.globalize_path(source_path))
	var reference := Image.load_from_file(ProjectSettings.globalize_path(reference_path))
	var bounds := Rect2i(entry.bounds[0], entry.bounds[1], entry.bounds[2], entry.bounds[3])
	if not _check(
		(
			file_digest(source_path) == entry.source_file_sha256
			and byte_digest(raw) == entry.source_rgba_sha256
			and decoded.get_data() == raw
		),
		"source file/raw RGBA/PNG decode differs: " + entry.id
	):
		return {}
	if not _check(
		(
			file_digest(reference_path) == entry.reference_file_sha256
			and byte_digest(reference.get_data()) == entry.reference_rgba_sha256
		),
		"reference file/RGBA differs: " + entry.id
	):
		return {}
	if not _check(
		source.get_used_rect() == bounds and source.get_format() == Image.FORMAT_RGBA8,
		"source bounds/format differs: " + entry.id
	):
		return {}
	var expected := Fitter.fitted(source, bounds, entry.size, entry.padding)
	var name := String(entry.id) + "-resized.png"
	if not _check(expected.save_png(output.path_join(name)) == OK, "cannot save derived image"):
		return {}
	var record := differences(reference.get_data(), expected.get_data(), entry.size)
	(
		record
		. merge(
			{
				"id": entry.id,
				"source_file_sha256": file_digest(source_path),
				"source_rgba_sha256": byte_digest(source.get_data()),
				"source_png_serialized_sha256": byte_digest(source.save_png_to_buffer()),
				"reference_file_sha256": file_digest(reference_path),
				"reference_rgba_sha256": byte_digest(reference.get_data()),
				"reference_png_serialized_sha256": byte_digest(reference.save_png_to_buffer()),
				"derived_file": name,
				"derived_file_sha256": file_digest(output.path_join(name)),
				"derived_rgba_sha256": byte_digest(expected.get_data()),
				"derived_png_serialized_sha256": byte_digest(expected.save_png_to_buffer()),
				"bounds": entry.bounds,
				"size": entry.size,
				"padding": entry.padding,
			}
		)
	)
	return record


## Считает все отличающиеся каналы; первые шестнадцать образцов содержат точные offset, x/y и значения RGBA.
func differences(actual: PackedByteArray, expected: PackedByteArray, width: int) -> Dictionary:
	var count := 0
	var max_delta := 0
	var samples: Array[Dictionary] = []
	for offset in mini(actual.size(), expected.size()):
		var delta := absi(int(actual[offset]) - int(expected[offset]))
		if delta == 0:
			continue
		count += 1
		max_delta = maxi(max_delta, delta)
		if samples.size() < 16:
			var pixel := int(offset / 4)
			var sample := {
				"offset": offset,
				"x": pixel % width,
				"y": int(pixel / width),
				"channel": CHANNELS[offset % 4],
				"actual": int(actual[offset]),
				"expected": int(expected[offset]),
			}
			samples.append(sample)
	return {
		"actual_bytes": actual.size(),
		"derived_bytes": expected.size(),
		"differing_bytes": count,
		"max_delta": max_delta,
		"samples": samples
	}


## Хеширует именно файл, сохраняя отличие от декодированных RGBA и новой PNG-сериализации.
func file_digest(path: String) -> String:
	return byte_digest(FileAccess.get_file_as_bytes(path))


## Вычисляет SHA-256 конкретного переданного буфера без преобразования изображения.
func byte_digest(bytes: PackedByteArray) -> String:
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(bytes)
	return hash.finish().hex_encode()


## Останавливает сбор при неверном входе; отличия ресемплинга остаются данными, а не разрешением на приёмку.
func _check(condition: bool, message: String) -> bool:
	if not condition:
		push_error("PREVIEW REPRO: " + message)
		quit(2)
	return condition
