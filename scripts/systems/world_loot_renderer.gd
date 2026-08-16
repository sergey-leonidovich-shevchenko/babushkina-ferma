extends RefCounted

const TEXTURES:={
	"sack":preload("res://assets/game/world_loot/containers/sack.png"),"trash":preload("res://assets/game/world_loot/containers/trash.png"),
	"chest":preload("res://assets/game/world_loot/containers/chest.png"),"bone_pile":preload("res://assets/game/world_loot/containers/bone_pile.png"),
	"supply_crate":preload("res://assets/game/world_loot/containers/supply_crate.png"),"barrel":preload("res://assets/game/world_loot/containers/barrel.png"),
	"hollow_log":preload("res://assets/game/world_loot/containers/hollow_log.png"),"fairy_cache":preload("res://assets/game/world_loot/containers/fairy_cache.png"),
}
const PROFILES:={
	"sack":{"visual":Vector2(72,72),"collision":Vector2(48,24)},"trash":{"visual":Vector2(96,72),"collision":Vector2(72,24)},
	"chest":{"visual":Vector2(96,72),"collision":Vector2(72,48)},"bone_pile":{"visual":Vector2(96,72),"collision":Vector2(72,24)},
	"supply_crate":{"visual":Vector2(72,72),"collision":Vector2(48,48)},"barrel":{"visual":Vector2(72,72),"collision":Vector2(48,48)},
	"hollow_log":{"visual":Vector2(96,72),"collision":Vector2(72,24)},"fairy_cache":{"visual":Vector2(72,72),"collision":Vector2(48,48)},
}


## Преобразует тематический пиратский сундук в общий визуальный профиль сундука.
static func resolved_kind(kind:String)->String:
	return "chest" if kind=="pirate_chest" else kind


## Возвращает отдельную текстуру контейнера без дробного source-rect.
static func texture(kind:String)->Texture2D:
	return TEXTURES.get(resolved_kind(kind),TEXTURES.chest) as Texture2D


## Возвращает независимый профиль видимого размера и основания контейнера.
static func profile(kind:String)->Dictionary:
	return Dictionary(PROFILES.get(resolved_kind(kind),PROFILES.chest)).duplicate(true)


## Возвращает видимую область контейнера вокруг совместимой логической позиции.
static func visual_rect(kind:String,position:Vector2)->Rect2:
	var size:=Vector2(profile(kind).visual)
	return Rect2(position-size*0.5,size)


## Возвращает прямоугольное основание контейнера из того же профиля.
static func collision_rect(kind:String,position:Vector2)->Rect2:
	var size:=Vector2(profile(kind).collision)
	return Rect2(position-size*0.5,size)


## Проверяет восемь независимых PNG и кратность всех размеров базовой сетке 24 px.
static func profiles_are_valid()->bool:
	if TEXTURES.size()!=8 or PROFILES.size()!=8: return false
	for kind in TEXTURES:
		var data:=profile(kind); var visual:=Vector2(data.visual); var collision:=Vector2(data.collision)
		if texture(kind).get_size()!=visual or int(visual.x)%24!=0 or int(visual.y)%24!=0 or int(collision.x)%24!=0 or int(collision.y)%24!=0: return false
	return true


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
	game.world_loot_nodes=[]; var kinds:=TEXTURES.keys()
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
