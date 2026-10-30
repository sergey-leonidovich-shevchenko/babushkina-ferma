extends SceneTree

## Собирает фактическую стартовую загрузку и полный динамический каталог редактора в отдельном профиле.
func _initialize() -> void:
	ProjectSettings.set_setting("application/config/use_custom_user_dir",true)
	ProjectSettings.set_setting("application/config/custom_user_dir_name","Codex-Sprite-Usage-20261014")
	_start.call_deferred()

## Проверяет реальные ресурсы без открытия пользовательского слота и сохраняет данные для безопасной очистки.
func _start() -> void:
	var game:Node=load("res://scripts/game.gd").new(); game.world_loot_seed=20261014; game._ready()
	var files:Array=JSON.parse_string(FileAccess.get_file_as_string("/private/tmp/moon-valley-sprite-files.json"))
	var loaded:Array=[]
	for path in files:
		if ResourceLoader.has_cached("res://"+path): loaded.append(path)
	var dynamic:Array=[]
	for kind in game.InventorySystem.ITEM_DATA:
		for size in [48,120]:
			var visual:Dictionary=game.VisualAssetSystem.item_draw_visual(kind,size)
			var texture:Texture2D=visual.texture
			if texture==null: push_error("Missing item visual: "+kind); game.free(); quit(1); return
			var path:String=texture.resource_path
			if texture is AtlasTexture: path=texture.atlas.resource_path
			path=path.trim_prefix("res://")
			if not path.is_empty() and path not in dynamic: dynamic.append(path)
	var poses:Dictionary={}
	var basement=load("res://scripts/presentation/basement_visual_system.gd")
	for kind in load("res://scripts/systems/basement_data.gd").STATIONS:
		for level in range(1,5):
			for direction in 4:
				var texture:Texture2D=basement.texture(kind,mini(level,3),direction,level==4)
				poses["%s:%d:%d"%[kind,level,direction]]=pose(texture)
	var furniture=load("res://scripts/presentation/house_furniture_visual_system.gd")
	for kind in furniture.SPRITES:
		for direction in 4: poses["furniture:%s:%d"%[kind,direction]]=pose(furniture.texture(kind,direction))
	var entries:Array=load("res://scripts/systems/level_editor_asset_catalog_system.gd").scan("res://assets/game")
	var editor:Array=[]
	for entry in entries: editor.append(String(entry.path).trim_prefix("res://"))
	var result:Dictionary={"schema":1,"version":ProjectSettings.get_setting("application/config/version"),"loaded":loaded,"dynamic":dynamic,"poses":poses,"editor":editor,"items":game.InventorySystem.ITEM_DATA.size(),"sources":"Real Game._ready; public editor scan; both icon sizes of all items; station levels/piles/furniture including legacy direction 2."}
	FileAccess.open("/private/tmp/moon-valley-sprite-usage.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t")+"\n")
	game.free()
	print("SPRITE USAGE: loaded=",loaded.size()," editor=",editor.size()," items=",result.items)
	quit()

## Записывает точный источник и геометрию отображаемого ракурса для сравнения до и после удаления.
func pose(texture:Texture2D) -> Dictionary:
	if texture is AtlasTexture: return {"texture":texture.resource_path,"atlas":texture.atlas.resource_path,"region":str(texture.region)}
	return {"texture":texture.resource_path,"size":str(texture.get_size())}
