extends SceneTree

const Store:=preload("res://scripts/systems/atomic_json_store.gd")
var output:=""

## Проверяет настоящую запись на отдельном пути; ресурс передаётся в общий JSON writer без валидатора игры.
static func exercise(path:String)->Dictionary:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path).get_base_dir())
	var material:=ShaderMaterial.new()
	var first:=Store.write(path,{"value":11},Callable(),true)
	var second:=Store.write(path,{"value":22},Callable(),true)
	var original:=FileAccess.get_sha256(path);var backup:=FileAccess.get_sha256(path+".bak")
	var accepted:=Store.write(path,{"visual":{"material":material}},Callable(),true)
	var value:Dictionary=Store.read(path)
	return {"healthy_writes":first and second,"unsafe_accepted":accepted,"primary_unchanged":FileAccess.get_sha256(path)==original,"backup_unchanged":FileAccess.get_sha256(path+".bak")==backup,"resource_became_string":typeof(value.get("visual",{}).get("material",null))==TYPE_STRING,"material_rid_valid":material.get_rid().is_valid(),"temporary_exists":FileAccess.file_exists(path+".tmp")}

## Использует новый пользовательский каталог и не открывает обычные слоты.
func _initialize()->void:
	ProjectSettings.set_setting("application/config/use_custom_user_dir",true)
	ProjectSettings.set_setting("application/config/custom_user_dir_name","Codex-VCOMPAT-001-probe-"+str(Time.get_ticks_usec()))
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
	if output.is_empty() or FileAccess.file_exists(output):quit(2);return
	var result:=exercise("user://transient-boundary.json")
	result.task="VCOMPAT-001";result.engine=Engine.get_version_info().string;result.display=DisplayServer.get_name()
	FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(result)+"\n")
	print("TRANSIENT SAVE PROBE: ",result);quit(0 if result.healthy_writes else 2)
