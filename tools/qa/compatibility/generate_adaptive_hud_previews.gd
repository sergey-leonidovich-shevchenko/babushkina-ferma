extends SceneTree

const HudLayoutSystem := preload("res://scripts/systems/hud_layout_system.gd")
const UiScaleSystem := preload("res://scripts/systems/ui_scale_system.gd")
const SOURCE_PATH := "res://assets/generated/ui/context_hud_ingame_preview.png"
const OUTPUT_DIRECTORY := "res://assets/generated/ui/adaptive_hud"
const MANIFEST_PATH := OUTPUT_DIRECTORY + "/manifest.json"


## Создаёт три физически разных эталона из нативного HUD и фиксирует их размеры и контрольные суммы.
func _initialize() -> void:
	var source := Image.load_from_file(ProjectSettings.globalize_path(SOURCE_PATH))
	if source == null:
		push_error("ADAPTIVE HUD: сначала создайте context_hud_ingame_preview.png")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIRECTORY))
	var entries: Array[Dictionary] = []
	for profile in HudLayoutSystem.DISPLAY_PROFILES:
		var size: Vector2i = profile.size
		var image := UiScaleSystem.compose_physical_preview(source,size)
		var file_name := "hud_%s_preview.png" % String(profile.id)
		var resource_path := OUTPUT_DIRECTORY.path_join(file_name)
		var error := image.save_png(ProjectSettings.globalize_path(resource_path))
		if error != OK:
			push_error("ADAPTIVE HUD: не удалось сохранить %s" % resource_path)
			quit(3)
			return
		entries.append({"id":profile.id,"label":profile.label,"file":file_name,"width":size.x,"height":size.y,"sha256":FileAccess.get_sha256(resource_path)})
	var manifest := {"schema":1,"source":"context_hud_ingame_preview.png","profiles":entries}
	var file := FileAccess.open(MANIFEST_PATH,FileAccess.WRITE)
	if file == null:
		push_error("ADAPTIVE HUD: не удалось сохранить manifest")
		quit(4)
		return
	file.store_string(JSON.stringify(manifest,"  ")+"\n"); file.close()
	print("ADAPTIVE HUD: создано %d физических эталона" % entries.size())
	quit(0)
