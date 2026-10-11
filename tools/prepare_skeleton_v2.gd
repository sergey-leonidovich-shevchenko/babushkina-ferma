extends SceneTree

const SOURCE := "res://docs/concepts/skeleton-2026-10-12/v2/"
const DEST := "res://assets/game/enemies/skeleton_v2/"

## Собирает два безопасных атласа из измеренных целых фигур, а не из произвольных ячеек генерации.
func _initialize() -> void:
	var regions: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(SOURCE+"regions.json"))
	for name in ["walk","actions"]:
		var original:=Image.load_from_file(ProjectSettings.globalize_path(SOURCE+"sources/"+name+".png"))
		var result:=Image.create(384,1024,false,Image.FORMAT_RGBA8)
		var largest:=Vector2.ZERO
		for region in regions[name]: largest=largest.max(Vector2(region[2],region[3]))
		var scale:=minf(112.0/largest.x,112.0/largest.y)
		for index in 24:
			var b: Array=regions[name][index]; var sprite:=original.get_region(Rect2i(b[0],b[1],b[2],b[3]))
			sprite.resize(roundi(sprite.get_width()*scale),roundi(sprite.get_height()*scale),Image.INTERPOLATE_LANCZOS)
			result.blit_rect(sprite,Rect2i(Vector2i.ZERO,sprite.get_size()),Vector2i((index%3)*128+(128-sprite.get_width())/2,(index/3)*128+120-sprite.get_height()))
		assert(result.save_png(ProjectSettings.globalize_path(DEST+("walk" if name=="walk" else "actions")+".png"))==OK)
	print("SKELETON V2: 48 complete isolated directional frames")
	quit()
