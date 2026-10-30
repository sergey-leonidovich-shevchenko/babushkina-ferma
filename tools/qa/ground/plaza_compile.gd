extends SceneTree

const Sources := preload("res://tools/qa/ground/compiled_sources.gd")

const Builder := preload("res://tools/qa/ground/plaza_builder.gd")
const SOURCES := ["scripts/systems/village_map_data.gd","tools/plaza_builder.gd","tools/plaza_field.gd","scripts/presentation/meadow_ground.gd","tools/ground_edge_field.gd"]
var output := "res://assets/game/locations/overworld/plaza_masks/"

## Записывает три готовых слоя в свежий каталог; обычная игра не выполняет компиляцию поля.
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output=arg.trim_prefix("--output=").trim_suffix("/")+"/"
	for id in ["apron","contact","stone"]:
		if FileAccess.file_exists(output+id+".res"): push_error("Refusing to overwrite plaza"); quit(2); return
	DirAccess.make_dir_recursive_absolute(output)
	var sources := Sources.hashes(SOURCES)
	if sources.is_empty(): push_error("Missing canonical source"); quit(2); return
	for id in ["apron","contact","stone"]:
		var mesh := Builder.build(id); mesh.set_meta("source_sha256",sources)
		if ResourceSaver.save(mesh,output+id+".res",ResourceSaver.FLAG_COMPRESS)!=OK: push_error("Cannot save plaza"); quit(2); return
		print(id," ",JSON.stringify(mesh.get_meta("mask_spec")))
	quit()
