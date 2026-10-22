extends Node

const Ambient:=preload("res://scripts/systems/village_ambient_renderer.gd")
const Roots:=preload("res://scripts/presentation/foliage_root_profile.gd")
const Batch:=preload("res://scripts/presentation/foliage_wind_batch.gd")
const Clock:=preload("res://scripts/presentation/village_ground_clock.gd")
const WorldProjection:=preload("res://scripts/systems/world_projection_system.gd")
const Visibility:=preload("res://scripts/systems/world_visibility_system.gd")
const FLAG:=&"foliage_wind_enabled"
const QUALITY:=&"foliage_wind_quality"
const NAME:="FoliageWind"
var batch:={}
var visible_rows:=[]
var mesh_builds:=0
var uploads:=0
var last_seconds:=-1.0

## Выбирает только восемь уже существующих наземных растений, без добавления декора или новой карты.
static func placements()->Array:
	var result:=[]
	for placement in Ambient.PLACEMENTS:
		if not Roots.profile(placement.kind).flexible:continue
		var rect:Rect2=Ambient.destination_rect(placement.position)
		result.append({"kind":placement.kind,"position":placement.position,"source":Ambient.source_rect(placement.kind),"rect":rect,"anchor":Roots.world_anchor(placement.kind,rect)})
	return result

## Разрешает локальный эффект; некорректный флаг, low, эталон и доступность дают неподвижный прежний спрайт.
static func allowed(game:Node)->bool:
	var flag:Variant=game.get_meta(FLAG,true)
	return typeof(flag)==TYPE_BOOL and flag and game.get_meta(QUALITY,"normal")=="normal" and game.current_location=="overworld" and not game.title_screen and not game.language_screen and not game.LevelEditorSystem.active(game) and not game.settings_state.reduced_motion and preload("res://scripts/presentation/visual_reference_mode.gd").effects_enabled(game)

## Готовит визуальные ресурсы вне draw; часы читает из завершённой симуляции, включая остановленную паузу.
static func update(game:Node2D)->void:
	if not game.is_inside_tree():return
	var owner:Node=game.get_node_or_null(NAME)
	var visible:=[]
	if allowed(game):
		var view:=Visibility.visible_rect(game);var season:String=game.WorldEventSystem.season(game.day)
		var rows:=placements()
		for index in rows.size():
			var row:Dictionary=rows[index]
			if Ambient.is_visible_in_season(row.kind,season) and view.intersects(row.rect.grow(Batch.PAD)):visible.append(index)
	if visible.is_empty():
		if owner!=null:owner.visible_rows.clear();owner.batch.viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
		return
	if owner==null:owner=new();owner.name=NAME;game.add_child(owner)
	owner.prepare(game,visible)

## Хранит одну ограниченную группу видов; при DPI меняет старый target синхронно и не накапливает viewport.
func prepare(game:Node2D,visible:Array)->void:
	var scale:=clampi(ceili(game.get_viewport().get_texture().get_size().x/1152.0*WorldProjection.zoom(game)),1,4)
	if batch.is_empty() or batch.scale!=scale:
		if not batch.is_empty():remove_child(batch.viewport);batch.viewport.free()
		batch=Batch.build(placements(),Ambient.ATLAS,scale);add_child(batch.viewport);mesh_builds+=1;last_seconds=-1
	var returning:=visible_rows.is_empty()
	visible_rows=visible
	var seconds:=Clock.seconds(game)
	if seconds==last_seconds:
		if returning:batch.viewport.render_target_update_mode=SubViewport.UPDATE_ONCE
		return
	for group in batch.groups:group.material.set_shader_parameter("seconds",seconds)
	batch.viewport.render_target_update_mode=SubViewport.UPDATE_ONCE;last_seconds=seconds;uploads+=1

## Выводит подготовленный слот в прежней фазе ambient; ни материал мира, ни HUD не меняются.
static func draw(game:Node2D,kind:String,position:Vector2,tint:Color)->bool:
	if not allowed(game):return false
	var owner:Node=game.get_node_or_null(NAME)
	if owner==null or owner.batch.is_empty():return false
	for index in owner.visible_rows:
		var row:Dictionary=owner.batch.rows[index]
		if row.kind!=kind or row.position!=position:continue
		var region:=Batch.slot(index)
		region=Rect2(region.position*owner.batch.scale,region.size*owner.batch.scale)
		game.draw_texture_rect_region(owner.batch.viewport.get_texture(),row.rect.grow(Batch.PAD),region,tint)
		return true
	return false

## Возвращает ограниченные счётчики для QA без создания узлов, массива кадров или игрового состояния.
static func statistics(game:Node)->Dictionary:
	var owner:Node=game.get_node_or_null(NAME)
	if owner==null:return {"active":0,"owners":0,"groups":0,"builds":0,"uploads":0}
	return {"active":owner.visible_rows.size(),"owners":1,"groups":owner.batch.groups.size(),"builds":owner.mesh_builds,"uploads":owner.uploads,"seconds":owner.last_seconds,"scale":owner.batch.scale}
