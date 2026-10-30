extends SceneTree

const Facing := preload("res://scripts/systems/furniture_facing_system.gd")
const House := preload("res://scripts/presentation/house_furniture_visual_system.gd")
const Farm := preload("res://scripts/systems/farm_life_visual_system.gd")
const Stations := preload("res://scripts/presentation/basement_visual_system.gd")
const Layout := preload("res://scripts/systems/basement_layout_system.gd")
const Data := preload("res://scripts/systems/basement_data.gd")
const Workbench := preload("res://scripts/presentation/world_workbench_visual_system.gd")

## Экспортирует настоящие выбранные ресурсы и геометрию без создания игры или чтения сохранений.
func _initialize() -> void:
	var output:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output=arg.trim_prefix("--output=")
	if output.is_empty() or FileAccess.file_exists(output):
		push_error("Нужен новый --output; прежний паспорт не перезаписывается"); quit(2); return
	var families:=[]
	for kind in ["workbench","rustic_table","wooden_wardrobe"]:
		var poses:=[]
		for direction in Facing.SELECTABLE:
			var texture:Texture2D=Stations.texture(kind,1,direction) if kind=="workbench" else House.texture(kind,direction)
			var master:Texture2D=texture.atlas if texture is AtlasTexture else texture
			var source:Rect2=texture.region if texture is AtlasTexture else House.source(kind,direction)
			var item:={"kind":kind,"direction":direction,"level":1,"x":0,"y":0}
			var collision:Vector2=Vector2(Layout.dimensions(kind,direction))*Data.GRID if kind=="workbench" else Farm.profile(kind,direction).collision
			var actual:Rect2=Stations.destination(item) if kind=="workbench" else House.destination(kind,Vector2.ZERO,Farm.profile(kind,direction).visual,direction)
			poses.append({"direction":direction,"name":Facing.NAMES[direction],"file":master.resource_path.trim_prefix("res://"),"source_rect":_rect(source),"master_size":_pair(master.get_size()),
				"footprint":_pair(collision),"runtime_visual_size":_pair(actual.size),"next":Facing.next(direction),"previous":Facing.next(direction,-1),"legacy_up_alias":Facing.visible(2)})
		families.append({"kind":kind,"poses":poses})
	var result:={"kind":"headless-resource-metadata","native_game_frame":false,"engine":Engine.get_version_info().string,"base_grid":Data.GRID,"selectable":Facing.SELECTABLE,"families":families,
		"world_workbench_common_scale":Workbench.FRONT_WIDTH/Workbench.texture(0).get_width(),"profile_unchanged":true}
	var file:=FileAccess.open(output,FileAccess.WRITE)
	if file==null: push_error("Не удалось создать новый паспорт"); quit(2); return
	file.store_string(JSON.stringify(result,"\t")+"\n")
	print("PERSPECTIVE EXPORT: 3 families, 9 selected sources; metadata only")
	quit()

## Кодирует исходные координаты без округления экспортируемой геометрии.
func _pair(value: Vector2) -> Array:
	return [value.x,value.y]

## Сохраняет измеренный прямоугольник ровно в системе координат владельца.
func _rect(value: Rect2) -> Array:
	return [value.position.x,value.position.y,value.size.x,value.size.y]
