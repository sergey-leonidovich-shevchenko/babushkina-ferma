extends SceneTree

## Уменьшает выбранный мастер стандартным фильтром, сохраняя исходный рисунок отдельно.
func _initialize() -> void:
	var image := Image.load_from_file("res://docs/reports/visual-overhaul/vground-007/masters/garden-loam-v1.png")
	var path := "res://assets/game/locations/overworld/modular/garden_loam_v1.png"
	if image==null or FileAccess.file_exists(path): push_error("Missing master or existing destination"); quit(2); return
	image.convert(Image.FORMAT_RGBA8)
	image.resize(512,512,Image.INTERPOLATE_LANCZOS)
	quit(image.save_png(path))
