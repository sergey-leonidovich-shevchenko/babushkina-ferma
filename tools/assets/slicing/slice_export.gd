extends "res://wiki/scripts/export_catalog.gd"

var slice_textures: Dictionary={}
var slice_frames: Dictionary={}
var slice_ids: Dictionary={}
var atlas_paths: Array=[]
var file_hashes: Dictionary={}
var chain_cache: Dictionary={}

## Требует отдельный профиль и новый каталог вне игровых ресурсов.
func _initialize() -> void:
	output=OS.get_environment("VSLICE_OUTPUT").trim_suffix("/")+"/"
	var profile:=OS.get_environment("VSLICE_PROFILE")
	if output=="/" or DirAccess.dir_exists_absolute(output) or ProjectSettings.localize_path(output).begins_with("res://assets/") or not profile.begins_with("Codex-VPIPELINE-008-") or "/" in profile or "\\" in profile: quit(2);return
	ProjectSettings.set_setting("application/config/use_custom_user_dir",true)
	ProjectSettings.set_setting("application/config/custom_user_dir_name",profile)
	_export.call_deferred()

## Вызывает настоящие API поз и каталогов, не запускает симуляцию и не открывает игровые слоты.
func _export() -> void:
	var started:=Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(output+"pixels")
	game=Game.new();game._ready();game.LocaleSystem.current="ru"
	Actors.export_all(self);Content.items(self);World.buildings(self);World.stations(self)
	for entry in entries:
		if entry.has("icon"): slice_frames[entry.category+"/"+entry.id+"/icon"]=entry.icon
		for clip in entry.get("animation",{}).get("clips",[]):
			for side in clip.frames:
				for index in clip.frames[side].size(): slice_frames[entry.category+"/"+entry.id+"/"+clip.id+"/"+side+"/"+str(index)]=clip.frames[side][index]
	prepared_items();world_frames();additional_families();preload("res://tools/assets/slicing/slice_catalogs.gd").append(self);scan_atlases("res://assets/game")
	atlas_paths.sort()
	var expected:Array=["hero","grandmother","deep_guardian","summon-skeleton","summon-zombie","summon-vampire","slime"]
	expected.append_array(game.QuestSystem.NPCS.keys());expected.append_array(game.CompanionSystem.COMPANIONS.keys());expected.append_array(game.CombatSystem.TYPES.keys());expected.append_array(game.WildlifeSystem.TYPES.keys())
	for animal in preload("res://scripts/systems/livestock_data.gd").ANIMALS:expected.append(animal.id)
	var data:={"schema_version":1,"engine":Engine.get_version_info().string,"profile":OS.get_user_data_dir().get_file(),"game_version":ProjectSettings.get_setting("application/config/version"),"textures":slice_textures,"frames":slice_frames,"atlas_resources":atlas_paths,"expected_characters":expected,"performance_eligible":false,"tool_source_paths":{"tools/slice_export.gd":"tools/assets/slicing/slice_export.gd","tools/slice_catalogs.gd":"tools/assets/slicing/slice_catalogs.gd"},"export_seconds":float(Time.get_ticks_usec()-started)/1000000.0,"source_sha256":FileAccess.get_sha256("res://tools/assets/slicing/slice_export.gd")}
	FileAccess.open(output+"inventory.json",FileAccess.WRITE).store_string(JSON.stringify(data,"\t")+"\n")
	game.free();print("SLICE EXPORT: ",slice_frames.size()," frames / ",slice_textures.size()," effective textures / ",atlas_paths.size()," atlas resources");quit(1 if failed else 0)

## Сохраняет геометрию фактической позы до любых браузерных преобразований.
func frame(pose: Dictionary) -> Dictionary:
	var texture:Texture2D=pose.texture
	if not pose.get("preserve_alpha",false): texture=Matte.clean_texture(texture)
	var source:Rect2=pose.source;var pivot:Vector2=pose.pivot
	return {"image":slice_image(texture),"rect":[source.position.x,source.position.y,source.size.x,source.size.y],"pivot":[pivot.x,pivot.y],"scale":float(pose.get("scale",1)),"flip":bool(pose.get("flip",false)),"origin":texture_chain(pose.texture)}

## Вычисляет хеш реальных импортированных пикселей и сохраняет только диагностическую копию.
func slice_image(texture: Texture2D) -> String:
	var instance:=str(texture.get_instance_id())
	if slice_ids.has(instance): return slice_ids[instance]
	var pixels:=texture.get_image()
	if pixels.is_compressed(): pixels.decompress()
	pixels.convert(Image.FORMAT_RGBA8)
	var digest:=HashingContext.new();digest.start(HashingContext.HASH_SHA256);digest.update(pixels.get_data())
	var rgba:=digest.finish().hex_encode();var key:=str(slice_textures.size())
	var path:="pixels/"+rgba+".png"
	if not FileAccess.file_exists(output+path) and pixels.save_png(output+path)!=OK:failed=true
	slice_textures[key]={"file":path,"pixels":[pixels.get_width(),pixels.get_height()],"rgba_sha256":rgba,"png_sha256":FileAccess.get_sha256(output+path),"chain":texture_chain(texture)}
	slice_ids[instance]=key;return key

## Раскрывает вложенные AtlasTexture и CanvasTexture с настоящими областями и полями.
func texture_chain(texture: Texture2D) -> Array:
	var original_id:=texture.get_instance_id()
	if chain_cache.has(original_id):return chain_cache[original_id]
	var result:Array=[];var seen:={}
	while texture!=null and not seen.has(texture.get_instance_id()):
		seen[texture.get_instance_id()]=true
		var row:={"class":texture.get_class(),"path":texture.resource_path,"pixels":[texture.get_width(),texture.get_height()]}
		if not texture.resource_path.is_empty() and FileAccess.file_exists(texture.resource_path):
			if not file_hashes.has(texture.resource_path):file_hashes[texture.resource_path]=FileAccess.get_sha256(texture.resource_path)
			row.sha256=file_hashes[texture.resource_path]
		if texture is AtlasTexture:
			row.region=[texture.region.position.x,texture.region.position.y,texture.region.size.x,texture.region.size.y]
			row.margin=[texture.margin.position.x,texture.margin.position.y,texture.margin.size.x,texture.margin.size.y]
			row.filter_clip=texture.filter_clip
			result.append(row);texture=texture.atlas
		elif texture is CanvasTexture:result.append(row);texture=texture.diffuse_texture
		else:result.append(row);break
	chain_cache[original_id]=result;return result

## Передаёт регион, опору и масштаб дополнительного семейства в единый измеряемый список.
func append_frame(id: String, texture: Texture2D, source: Rect2, pivot: Vector2, scale_value: float=1.0, flip: bool=false) -> void:
	slice_frames[id]=frame({"texture":texture,"source":source,"pivot":pivot,"scale":scale_value,"preserve_alpha":true,"flip":flip})

## Проверяет все четыре защищённых уровня и отдельное превью каждого предмета по настоящему поставщику.
func prepared_items() -> void:
	for kind in game.InventorySystem.ITEM_DATA:
		for size in [64,32,16,8,160]:
			var packet:Dictionary=game.VisualAssetSystem.item_draw_visual(kind,size)
			if packet.texture==null:failed=true;continue
			var texture:Texture2D=packet.texture
			append_frame("ui/"+kind+"/"+str(size),texture,Rect2(Vector2.ZERO,texture.get_size()),texture.get_size()*0.5)

## Дополняет Wiki-позы водой, деревьями, паспортами и всеми кадрами отдельного эффекта босса.
func world_frames() -> void:
	var resources:=preload("res://scripts/systems/visual_resource_catalog.gd")
	for id in resources.catalog().resources:
		for side in resources.catalog().resources[id].views:
			var view:Dictionary=resources.describe(id,side)
			append_frame("passport/"+id+"/"+side,resources.texture(id,side),view.source,view.source.size*Vector2(view.pivot))
	var water:=preload("res://scripts/systems/water_visual_system.gd")
	for kind in water.EFFECT_PROFILES:
		for index in int(water.EFFECT_PROFILES[kind].frames):append_frame("water/"+kind+"/"+str(index),water.EFFECT_SHEETS[kind],water.effect_source_rect(kind,index),Vector2(8,8))
	var trees:=preload("res://scripts/systems/tree_system.gd")
	for stage in 4:append_frame("trees/"+str(stage),preload("res://scripts/systems/village_prop_renderer.gd").TreeTexture,trees.source_rect(stage),trees.source_rect(stage).size*Vector2(0.5,1))
	var boss:=preload("res://scripts/systems/cave_boss_art_system.gd")
	for kind in boss.catalog():
		for entry in boss.catalog()[kind].frames:
			var value:Dictionary=boss.frame(kind,int(entry.row),int(entry.column))
			append_frame("boss/"+kind+"/"+str(entry.row)+"/"+str(entry.column),boss.texture(kind),value.source,Rect2(value.source).size*Vector2(value.pivot))

## Перебирает все сезоны культур, состояния зверей и самостоятельные семейства окружения по их игровым API.
func additional_families() -> void:
	var farm:=preload("res://scripts/systems/farm_visual_system.gd")
	for kind in farm.CROP_LAYOUT:
		for season in farm.SEASON_ROWS:
			for stage in farm.CROP_STAGE_COUNT:append_frame("crops/"+kind+"/"+season+"/"+str(stage),farm.crop_texture(kind),farm.crop_source(stage,kind,season),Vector2(32,64))
	var orchard:=preload("res://scripts/systems/orchard_system.gd")
	for kind in orchard.SPECIES_ROWS:
		for winter in [false,true]:
			for stage in 4:append_frame("orchard/"+kind+"/"+str(winter)+"/"+str(stage),orchard.TREE_ATLAS,orchard.source_rect(kind,stage,winter),Vector2(128,256))
	var wildlife:=preload("res://scripts/systems/wildlife_visual_system.gd")
	for kind in game.WildlifeSystem.TYPES:
		for side in Actors.CARDINAL:
			for state in ["idle","walk","flee","attack","hurt","death"]:
				for index in 4:
					var packet:Dictionary=wildlife.frame_packet(game,{"kind":kind,"position":Vector2.ZERO,"direction":Actors.DIRECTIONS[side],"animation":(index+0.05)/(9.0 if state=="flee" or kind=="bat" else 6.0),"moving":state in ["walk","flee"],"visual_state":state})
					append_frame("wildlife/"+kind+"/"+state+"/"+side+"/"+str(index),packet.texture,packet.source,Rect2(packet.source).size*Vector2(0.5,1),packet.scale,Rect2(packet.destination).size.x<0)
	var environment:=preload("res://scripts/systems/environment_visual_system.gd")
	for kind in environment.PROFILES:
		var texture:Texture2D=environment.texture(kind);var profile:Dictionary=environment.profile(kind)
		append_frame("environment/"+kind,texture,Rect2(Vector2.ZERO,texture.get_size()),texture.get_size()*Vector2(0.5,profile.pivot_y))
	var cave:=preload("res://scripts/systems/cave_asset_system.gd")
	for kind in cave.CATALOG:
		var texture:Texture2D=cave.texture(kind)
		append_frame("cave/"+kind,texture,Rect2(Vector2.ZERO,texture.get_size()),texture.get_size()*Vector2(0.5,1))
	var loot:=preload("res://scripts/systems/world_loot_visual_system.gd")
	for kind in loot.kinds():
		var texture:Texture2D=loot.texture(kind)
		append_frame("loot/"+kind,texture,Rect2(Vector2.ZERO,texture.get_size()),texture.get_size()*0.5)

## Рекурсивно проверяет все зарегистрированные AtlasTexture, сохраняя вложенность вместо догадки о размерах PNG.
func scan_atlases(directory: String) -> void:
	if FileAccess.file_exists(directory+"/.gdignore"):return
	for name in DirAccess.get_directories_at(directory):scan_atlases(directory+"/"+name)
	for name in DirAccess.get_files_at(directory):
		if not name.ends_with(".tres"):continue
		var path:=directory+"/"+name
		var resource=load(path)
		if resource is AtlasTexture:
			atlas_paths.append(path)
			# У самого ресурса нет физической опоры: её нельзя выдумывать по размеру PNG.
			var size:Vector2=resource.get_size()
			slice_frames["atlas/"+path.trim_prefix("res://")]={"image":slice_image(resource),"rect":[0,0,size.x,size.y],"pivot":null,"scale":1.0,"flip":false,"resource_only":true}
