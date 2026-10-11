extends SceneTree

const OUT := "res://assets/game/ui/celestial_dial_v1/"
const CONCEPT := "res://docs/concepts/day-night-dial-2026-10/"
const Matte := preload("res://scripts/systems/sprite_matte_system.gd")

## Подготавливает небольшие повторно используемые слои, сохраняя нетронутые оригиналы в каталоге концептов.
func _initialize() -> void:
	for kind in ["sky", "frame", "landscape"]:
		var source: String = CONCEPT+"v2/sources/sky.png" if kind=="sky" else CONCEPT+"v1/assets/"+("frame-wood" if kind=="frame" else kind)+".png"
		var image := Image.load_from_file(ProjectSettings.globalize_path(source))
		assert(image!=null and not image.is_empty(),source)
		image=Matte.clean_image(image)
		image.resize(512,512,Image.INTERPOLATE_LANCZOS)
		assert(image.save_png(ProjectSettings.globalize_path(OUT+kind+".png"))==OK)
		print("DIAL ASSET: ",kind," 512x512")
	quit()
