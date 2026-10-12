extends SceneTree

const SOURCE := "res://docs/concepts/hero-actions-2026-10-12/v2/"
const DEST := "res://assets/game/characters/hero_v3/actions_v2/"

## Нарезает измеренные фигуры в самостоятельные экранные кадры, сохраняя опору ботинок отдельно от инструмента.
func _initialize() -> void:
	var regions: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SOURCE+"regions.json"))
	var catalog := {}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DEST+"frames"))
	for kind in regions:
		var frames := []
		for index in 16:
			var entry: Dictionary = regions[kind].frames[index]
			var original := Image.load_from_file(ProjectSettings.globalize_path(SOURCE+"sources/"+entry.source))
			var box: Array = entry.box
			var source := Rect2i(box[0],box[1],box[2]-box[0],box[3]-box[1])
			var sprite := original.get_region(source)
			var scale_value := float(entry.scale)
			sprite.resize(roundi(source.size.x*scale_value),roundi(source.size.y*scale_value),Image.INTERPOLATE_LANCZOS)
			var padded := Image.create(sprite.get_width()+4,sprite.get_height()+4,false,Image.FORMAT_RGBA8)
			padded.blit_rect(sprite,Rect2i(Vector2i.ZERO,sprite.get_size()),Vector2i(2,2))
			var name := "frames/%s-%02d.png" % [kind,index]
			assert(padded.save_png(ProjectSettings.globalize_path(DEST+name)) == OK)
			var pivot := (Vector2(entry.pivot[0],entry.pivot[1])-Vector2(source.position))*scale_value+Vector2(2,2)
			var record := {"sprite":name,"draw_pivot":[pivot.x,pivot.y],"draw_scale":1.0,"source":entry.source,"region":[source.position.x,source.position.y,source.size.x,source.size.y],"scale":scale_value}
			if entry.has("tip"):
				var tip := (Vector2(entry.tip[0],entry.tip[1])-Vector2(source.position))*scale_value+Vector2(2,2)
				record.draw_tip = [tip.x,tip.y]
			frames.append(record)
		catalog[kind] = {"frames":frames,"directions":regions[kind].directions}
	var file := FileAccess.open(DEST+"frames.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(catalog,"\t")+"\n")
	print("HERO ACTIONS: 96 standalone RGBA frames at native display size")
	quit()
