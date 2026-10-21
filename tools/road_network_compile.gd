extends SceneTree

const Builder := preload("res://tools/road_network_builder.gd")
const Map := preload("res://scripts/systems/village_map_data.gd")
const Regions := preload("res://scripts/systems/village_region_data.gd")
const SOURCES := ["scripts/systems/village_map_data.gd","scripts/systems/village_region_data.gd","scripts/systems/cardinal_path_system.gd","tools/road_network_builder.gd","tools/axial_road_field.gd","tools/ground_edge_field.gd"]
var output := "res://assets/game/locations/overworld/road_network_masks/"

## Компилирует оба владельца одного дорожного поля атомарно в свежий каталог без изменения старых масок.
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output=arg.trim_prefix("--output=").trim_suffix("/")+"/"
	for id in ["main","connectors"]:
		if FileAccess.file_exists(output+id+".res"): push_error("Refusing to overwrite network"); quit(2); return
	DirAccess.make_dir_recursive_absolute(output)
	var sources := {}
	for name in SOURCES: sources[name]=FileAccess.get_sha256("res://"+name)
	var masks := Builder.build(Map.routes(),Regions.routes("overworld"),Map.WORLD_SIZE,Map.PATH_HALF_WIDTH)
	for id in masks:
		var mesh: ArrayMesh=masks[id]; mesh.set_meta("source_sha256",sources)
		if ResourceSaver.save(mesh,output+id+".res",ResourceSaver.FLAG_COMPRESS)!=OK: push_error("Cannot save network"); quit(2); return
		print(id," ",JSON.stringify(mesh.get_meta("mask_spec")))
	quit()
