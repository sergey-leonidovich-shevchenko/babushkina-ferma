extends SceneTree

## Выполняет только стандартный импорт-размер мастера; не дорисовывает и не перекрашивает изображение.
func _initialize() -> void:
	var source := Image.load_from_file("res://docs/reports/visual-overhaul/vground-006/masters/quiet-limestone-v1.png")
	if source == null: quit(2); return
	source.convert(Image.FORMAT_RGBA8)
	source.resize(512,512,Image.INTERPOLATE_LANCZOS)
	var target := "res://assets/game/locations/overworld/modular/plaza_limestone_v1.png"
	if FileAccess.file_exists(target): push_error("Refusing to replace existing material"); quit(2); return
	quit(source.save_png(target))
