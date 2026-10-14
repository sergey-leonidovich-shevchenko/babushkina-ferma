extends SceneTree

const ROOT := "res://docs/concepts/watering-drop-2026-10-14/v1/"

## Готовит компактные копии нарисованных кадров для просмотра, не изменяя мастера и игровые ресурсы.
func _initialize() -> void:
	var meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ROOT+"source.json"))
	var cell := int(meta.preview_cell)
	var height := int(meta.preview_height)
	for variant in meta.variants:
		var master := Image.load_from_file(ROOT+String(variant.source))
		if master==null: push_error("Не удалось прочитать мастер капли"); quit(1); return
		master.convert(Image.FORMAT_RGBA8)
		var atlas := Image.create(cell*3,cell*2,false,Image.FORMAT_RGBA8)
		atlas.fill(Color.TRANSPARENT)
		for index in variant.regions.size():
			var region: Array = variant.regions[index]
			var image := master.get_region(Rect2i(int(region[0]),int(region[1]),int(region[2]),int(region[3])))
			var width := maxi(1,roundi(float(image.get_width())*height/image.get_height()))
			if width>cell-8: push_error("Кадр капли не помещается в просмотр"); quit(1); return
			image.resize(width,height,Image.INTERPOLATE_LANCZOS)
			atlas.blit_rect(image,Rect2i(Vector2i.ZERO,image.get_size()),Vector2i((index%3)*cell+(cell-width)/2,(index/3)*cell+cell-8-height))
		if atlas.save_png(ROOT+String(variant.preview_atlas))!=OK: push_error("Не удалось сохранить просмотр капли"); quit(1); return
		print("WATERING PREVIEW: "+String(variant.id)+" · "+str(atlas.get_size()))
	quit()
