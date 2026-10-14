extends SceneTree

const Prepared := preload("res://scripts/presentation/prepared_pixel_cache.gd")
const Matte := preload("res://scripts/systems/sprite_matte_system.gd")
const Grandmother := preload("res://scripts/systems/grandmother_visual_system.gd")
const Wildlife := preload("res://scripts/systems/wildlife_visual_system.gd")
const ROOT := "res://assets/game/prepared_pixels/"
const SOURCES := {
	"hero_walk":"res://assets/game/characters/hero_v3/walk_master.png",
	"hero_hoe":"res://assets/game/characters/hero_v3/hoe_master.png",
	"deer":"res://assets/game/wildlife/directional/deer_actions_8dir.png",
	"boar":"res://assets/game/wildlife/directional/boar_actions_8dir.png",
	"fox":"res://assets/game/wildlife/directional/fox_walk_4dir_v2.png",
	"bat":"res://assets/game/wildlife/directional/bat_flight_4dir_v2.png",
	"lizard":"res://assets/game/wildlife/directional/lizard_walk_4dir_v2.png",
	"portal":"res://assets/game/environment/moon/portal.png",
	"grandmother":"res://assets/game/characters/grandmother_v2/walk_master.png",
}

## Сериализует точные результаты уже принятой обработки прозрачности; исходные изображения не изменяет и новую графику не рисует.
func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ROOT)
	var entries:Dictionary={}
	for kind in SOURCES:
		var source:Texture2D=load(SOURCES[kind]); var image:=source.get_image()
		if image.is_compressed(): image.decompress()
		var algorithm:="grandmother-green-v1" if kind=="grandmother" else "service-matte-v1"
		var result:Image=Grandmother.clean_image(image) if kind=="grandmother" else Matte.clean_image(image)
		var texture:=ImageTexture.create_from_image(result)
		var target:String=ROOT+kind+".res"
		var source_hash:=Prepared.fingerprint(source); var output_hash:=Prepared.image_fingerprint(result)
		if source_hash==output_hash:
			if FileAccess.file_exists(target): DirAccess.remove_absolute(target)
			target=SOURCES[kind]
		elif ResourceSaver.save(texture,target,ResourceSaver.FLAG_COMPRESS)!=OK:
			push_error("Prepared pixel resource failed: "+target); quit(1); return
		var bounds:Dictionary={}
		if kind in ["fox","bat","lizard","deer","boar"]:
			for direction in 4:
				for column in (4 if kind in ["fox","bat","lizard"] else 6):
					var area:=Wildlife.frame_area(kind,direction,column)
					var measured:=Wildlife.measure_visible_bounds(result,area)
					bounds[Prepared.area_key(area)]=[measured.position.x,measured.position.y,measured.size.x,measured.size.y]
		entries[algorithm+"|"+SOURCES[kind]]={"resource":target,"source_sha256":source_hash,"output_sha256":output_hash,"width":image.get_width(),"height":image.get_height(),"bounds":bounds}
		print("PREPARED PIXELS: ",kind)
	FileAccess.open(ROOT+"catalog.gd",FileAccess.WRITE).store_string("extends RefCounted\n\nconst VERSION := "+str(Prepared.VERSION)+"\nconst ENTRIES := "+JSON.stringify(entries,"\t")+"\n")
	print("PREPARED PIXELS: ",entries.size()," exact source contracts; identity outputs reuse originals")
	quit()
