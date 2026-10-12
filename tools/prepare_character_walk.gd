extends SceneTree

const SOURCE := "res://assets/game/characters/"
const OUT := "res://assets/game/characters/walk_v2/"
const REGIONS := "res://docs/concepts/character-polish-2026-10-12/regions.json"
const Matte := preload("res://scripts/systems/sprite_matte_system.gd")

## Собирает пять безопасных атласов целых фигур с единым экранным ростом и измеренными стопами.
func _initialize() -> void:
	var regions: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(REGIONS))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	for kind in regions:
		var original:=Image.load_from_file(ProjectSettings.globalize_path(SOURCE+regions[kind].source))
		var result:=Image.create(512,1024,false,Image.FORMAT_RGBA8)
		for index in 32:
			var entry: Dictionary=regions[kind].frames[index]
			var b: Array=entry.box; var region:=Rect2i(b[0],b[1],b[2],b[3])
			var sprite:=Matte.clean_image(original.get_region(region))
			var scale_value:=float(entry.scale)
			sprite.resize(roundi(region.size.x*scale_value),roundi(region.size.y*scale_value),Image.INTERPOLATE_LANCZOS)
			var pivot:=(Vector2(entry.pivot[0],entry.pivot[1])-Vector2(region.position))*scale_value
			var offset:=Vector2i(roundi(64-pivot.x),roundi(120-pivot.y))
			assert(Rect2i(2,2,124,124).encloses(Rect2i(offset,sprite.get_size())))
			result.blit_rect(sprite,Rect2i(Vector2i.ZERO,sprite.get_size()),Vector2i((index%4)*128,(index/4)*128)+offset)
		for pair in [[1,7],[2,6],[3,5]]:
			for column in 4:
				var mirrored:=result.get_region(Rect2i(column*128,pair[0]*128,128,128)); mirrored.flip_x()
				result.blit_rect(mirrored,Rect2i(0,0,128,128),Vector2i(column*128,pair[1]*128))
		assert(result.save_png(ProjectSettings.globalize_path(OUT+kind+".png"))==OK)
	print("CHARACTERS: 160 isolated native-size frames in five small atlases")
	quit()
