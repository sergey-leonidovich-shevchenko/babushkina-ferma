extends RefCounted

const WorldLootVisualSystem := preload("res://scripts/systems/world_loot_visual_system.gd")


## Преобразует тематический пиратский сундук в общий визуальный профиль сундука.
static func resolved_kind(kind:String)->String:
	return WorldLootVisualSystem.resolved_kind(kind)


## Возвращает отдельную текстуру контейнера без дробного source-rect.
static func texture(kind:String)->Texture2D:
	return WorldLootVisualSystem.texture(kind)


## Возвращает независимый профиль видимого размера и основания контейнера.
static func profile(kind:String)->Dictionary:
	return WorldLootVisualSystem.profile(kind)


## Возвращает видимую область контейнера вокруг совместимой логической позиции.
static func visual_rect(kind:String,position:Vector2)->Rect2:
	return WorldLootVisualSystem.visual_rect(kind,position)


## Возвращает прямоугольное основание контейнера из того же профиля.
static func collision_rect(kind:String,position:Vector2)->Rect2:
	return WorldLootVisualSystem.collision_rect(kind,position)


## Проверяет восемь независимых PNG и кратность всех размеров базовой сетке 24 px.
static func profiles_are_valid()->bool:
	return WorldLootVisualSystem.validation_errors().is_empty()


## Рисует контейнеры текущей локации и сохраняет читаемое состояние опустошения.
static func draw(game:Node2D)->void:
	for container in game.world_loot_nodes:
		if container.location!=game.current_location: continue
		var position:Vector2=container.position.round(); var alpha:=0.38 if container.opened else 1.0
		var tint:=Color(0.82,0.92,1.0,alpha) if container.kind=="pirate_chest" else Color(1.0,1.0,1.0,alpha)
		game.draw_texture_rect(texture(container.kind),visual_rect(container.kind,position),false,tint)
		if container.opened: game.draw_ui_string(game.UI_FONT,position+Vector2(-35,44),game.LocaleSystem.ui("empty"),HORIZONTAL_ALIGNMENT_CENTER,70,12,Color(0.8,0.8,0.75,0.55))


## Готовит игровую витрину восьми контейнеров без врагов и случайного расположения.
static func configure_preview(game:Node,arguments:PackedStringArray)->bool:
	if "--capture-world-loot" not in arguments: return false
	game.language_screen=false; game.title_screen=false; game.current_location="cottage_interior"; game.player=Vector2(576,200); game.tutorial_visible=false; game.enemy_nodes=[]; game.hazard_nodes=[]; game.wildlife_nodes=[]
	game.world_loot_nodes=[]; var kinds:=WorldLootVisualSystem.kinds()
	for index in kinds.size(): game.world_loot_nodes.append({"id":"preview_%d"%index,"kind":kinds[index],"location":"cottage_interior","position":Vector2(330+(index%4)*160,310+(index/4)*150),"contents":{},"opened":false})
	game.set_meta("capture_first_level_clean",true); game.set_meta("capture_world_loot_frames",8)
	return true


## Сохраняет контрольный игровой кадр всех контейнеров после полноценных кадров отрисовки.
static func update_preview_capture(game:Node)->bool:
	if not game.has_meta("capture_world_loot_frames"): return false
	var frames_left:=int(game.get_meta("capture_world_loot_frames"))-1; game.set_meta("capture_world_loot_frames",frames_left)
	if frames_left>0: return false
	game.remove_meta("capture_world_loot_frames"); var image:=game.get_viewport().get_texture().get_image()
	if image==null: game.get_tree().quit(); return true
	var output:=ProjectSettings.globalize_path("res://assets/generated/level_drafts/world_loot_ingame_preview.png"); var error:=image.save_png(output)
	if error!=OK: push_error("Не удалось сохранить предпросмотр мировых контейнеров: %s"%error)
	game.get_tree().quit(); return true
