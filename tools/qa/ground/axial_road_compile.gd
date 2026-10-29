extends SceneTree

const Sources := preload("res://tools/qa/ground/compiled_sources.gd")

const Builder := preload("res://tools/qa/ground/axial_road_builder.gd")
const Map := preload("res://scripts/systems/village_map_data.gd")
const Regions := preload("res://scripts/systems/village_region_data.gd")
const FOLDER := "res://assets/game/locations/overworld/axial_road_masks/"
var output := FOLDER

## Строит отдельно основные и выходные дорожки, сохраняя их штатное место в очереди рендера.
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output=arg.trim_prefix("--output=").trim_suffix("/")+"/"
	DirAccess.make_dir_recursive_absolute(output)
	var inputs := Sources.hashes(["scripts/systems/village_map_data.gd","scripts/systems/village_region_data.gd","scripts/systems/cardinal_path_system.gd","tools/axial_road_builder.gd","tools/axial_road_field.gd","tools/ground_edge_field.gd"])
	if inputs.is_empty(): push_error("Missing canonical source"); quit(2); return
	for id in ["main","connectors"]:
		var target: String=output+id+".res"
		if FileAccess.file_exists(target): push_error("Refusing to replace compiled mask"); quit(2); return
		var paths: Array=Map.routes() if id=="main" else Regions.routes("overworld")
		var mesh := Builder.build(paths,Map.WORLD_SIZE,Map.PATH_HALF_WIDTH)
		mesh.set_meta("source_sha256",inputs)
		var spec: Dictionary=mesh.get_meta("mask_spec"); spec["shape"]="axial-rounded-box"; spec["corner"]=4.0; mesh.set_meta("mask_spec",spec)
		var error := ResourceSaver.save(mesh,target,ResourceSaver.FLAG_COMPRESS)
		print("GROUND MASK ",id," ",mesh.get_meta("mask_spec")," error=",error)
		if error!=OK: quit(2); return
	quit(0)
