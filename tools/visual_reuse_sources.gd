extends RefCounted

const Sys := "res://scripts/systems/"
const Pres := "res://scripts/presentation/"
const Profile := preload("res://scripts/systems/world_visual_profile_system.gd")
const Hero := preload("res://scripts/systems/hero_visual_system.gd")
const Matte := preload("res://scripts/systems/sprite_matte_system.gd")
const Trees := preload("res://scripts/systems/tree_system.gd")
const Cave := preload("res://scripts/systems/cave_asset_system.gd")
const Farm := preload("res://scripts/systems/farm_visual_system.gd")
const Life := preload("res://scripts/systems/farm_life_visual_system.gd")
const Env := preload("res://scripts/systems/environment_visual_system.gd")
const Basement := preload("res://scripts/presentation/basement_visual_system.gd")

## Читает действительный ресурс и геометрию выбранного представителя семейства; не создаёт Game.
static func sample(id: String) -> Dictionary:
	var tex: Texture2D
	var rect: Rect2
	match id:
		"WS-001":return _full(load("res://assets/game/locations/overworld/overworld_master_24_v2.png"),Rect2(-192,-192,384,192),Sys+"first_level_art_system.gd","Архив целиком; обзор, не мировой размер",false)
		"WS-002":return _tile(load("res://assets/game/tiles/grass.png"),"res://scripts/world_background.gd")
		"WS-003":return _tile(preload("res://scripts/systems/road_visual_system.gd").texture("dirt_path","horizontal"),Sys+"road_visual_system.gd")
		"WS-004":return _tile(load("res://assets/game/tiles/cave-floor.png"),"res://scripts/world_background.gd")
		"WS-005":return _tile(preload("res://scripts/systems/water_visual_system.gd").texture("water_clear"),Sys+"water_visual_system.gd")
		"WS-006":return _cut(Farm.crop_texture("carrot"),Farm.crop_source(4,"carrot"),Rect2(-24,-24,48,48),Sys+"farm_visual_system.gd","Морковь, зрелая стадия; без почвы")
		"WS-007":
			tex=load("res://assets/game/environment/bridges/bridge_stone_vertical.png")
			return _full(tex,Rect2(-48,-192,96,192),Sys+"level_editor_asset_catalog_system.gd","Мост редактора; не топология игрового прохода")
		"WS-008":return _cut(load("res://assets/game/environment/forest_tree_growth_atlas_v1.png"),Trees.source_rect(3),Trees.destination_rect({"position":Vector2.ZERO,"stage":3}),Sys+"tree_system.gd","Взрослая стадия; логическая позиция выше земли на 48")
		"WS-009":return _cut(preload("res://scripts/systems/fence_renderer.gd").ATLAS,preload("res://scripts/systems/fence_renderer.gd").source(0,1),Profile.visual_rect("fence_section",Vector2.ZERO),Sys+"fence_renderer.gd","Прямая секция, один материал")
		"WS-010":return _full(Cave.texture("ore_metal"),Cave.destination_rect("ore_metal",Vector2.ZERO),Sys+"cave_asset_system.gd","Добываемая металлическая жила")
		"WS-011":return _full(load("res://assets/game/environment/red_mushrooms.png"),preload("res://scripts/systems/forage_system.gd").destination_rect({"kind":"mushroom","position":Vector2.ZERO}),"res://scripts/game_renderer.gd","Грибы; плодовые деревья проверяются отдельными исходниками")
		"WS-012":return _full(preload("res://scripts/systems/building_visual_system.gd").texture("cottage"),preload("res://scripts/systems/building_visual_system.gd").destination_rect("cottage",Vector2.ZERO),Sys+"building_visual_system.gd","Фасад cottage; привязка по двери")
		"WS-013":return _full(Env.texture("tree_spring"),Env.visual_rect("tree_spring",Vector2.ZERO),Sys+"environment_visual_system.gd","Весеннее дерево; не вся сезонная серия")
		"WS-014":return _full(Env.texture("rocky_landmark"),Env.visual_rect("rocky_landmark",Vector2.ZERO),Sys+"environment_visual_system.gd","Скальный ориентир одного биома")
		"WS-015":
			var loot:=preload("res://scripts/systems/world_loot_visual_system.gd")
			return _full(loot.texture("chest"),loot.visual_rect("chest",Vector2.ZERO),Sys+"world_loot_visual_system.gd","Случайный сундук, не домашний")
		"WS-016":
			var fx:=preload("res://scripts/systems/action_effect_visual_system.gd")
			return _full(fx.texture(0),fx.effect_rect(Vector2.ZERO),Sys+"action_effect_visual_system.gd","Один статичный эффект; движение не проверяется")
		"WS-017":
			var livestock:=preload("res://scripts/systems/livestock_visual_system.gd")
			var frame:=livestock.frame("pig",0)
			return _full(load(livestock.ROOT+frame.sprite),livestock.destination_rect("pig",0,Vector2.ZERO),Sys+"livestock_visual_system.gd","Действительная свинья; не старый общий expansion atlas")
		"WS-018":
			var pose:=Hero.walk_pose(Vector2.DOWN,0,false)
			var value:=_cut(Matte.clean_texture(pose.texture),pose.source,Hero.destination(Vector2.ZERO,pose),Sys+"hero_visual_system.gd","Текущий герой, вниз, покой; применяется runtime-очистка")
			value.master_path=Hero.WALK_MASTER.resource_path;return value
		"WS-019":
			var enemies:=preload("res://scripts/systems/enemy_animation_library.gd")
			return _cut(enemies.walk_texture("cave_guardian"),enemies.source_rect("cave_guardian",Vector2.DOWN,0),enemies.actor_rect({"kind":"cave_guardian","level":2,"position":Vector2.ZERO}),Sys+"enemy_animation_library.gd","Обычный кристальный хранитель; не босс deep_guardian")
		"WS-020":
			var wildlife:=preload("res://scripts/systems/wildlife_visual_system.gd")
			tex=Matte.clean_texture(wildlife.FOX)
			var area:=Rect2(wildlife.visible_bounds(tex,wildlife.frame_area("fox",0,0)));var size:=area.size*.245
			var value:=_cut(tex,area,Rect2(-Vector2(size.x*.5,size.y),size),Sys+"wildlife_visual_system.gd","Лиса, первая фаза вниз; runtime-очистка и измеренная область")
			value.master_path=wildlife.FOX.resource_path;return value
		"WS-021":return _cut(load("res://assets/game/environment/hazard_rank_atlas.png"),Rect2(0,0,418,418),preload("res://scripts/systems/creature_visual_profile_system.gd").actor_rect(Vector2.ZERO,Vector2(96,96)),"res://scripts/game_renderer.gd","Первое опасное растение, первый ранг; без процедурного дыхания")
		"WS-022":
			var interior:=preload("res://scripts/systems/interior_visual_system.gd")
			return _cut(interior.ATLAS,interior.source_rect("home_chest"),interior.destination_rect("home_chest",Vector2.ZERO),Sys+"interior_visual_system.gd","Настоящий домашний сундук; источник отличается от старого манифеста")
		"WS-023":return _cut(preload("res://scripts/systems/animation_renderer.gd").SLIME_IDLE,Rect2(0,0,64,64),Profile.visual_rect("story_slime",Vector2.ZERO),Sys+"animation_renderer.gd","Один кадр сюжетного слизня; не вся анимация")
		"WS-024":return _full(preload("res://scripts/systems/village_prop_renderer.gd").Props.well,preload("res://scripts/systems/village_layout_system.gd").prop_rect({"kind":"well","position":Vector2.ZERO}),Sys+"village_prop_renderer.gd","Действительный колодец основной деревни")
		"WS-025":
			var workshop:=preload("res://scripts/presentation/workshop_visual_system.gd")
			return _full(workshop.texture("sawmill",1),workshop.destination("sawmill",Vector2.ZERO,1),Pres+"workshop_visual_system.gd","Лесопилка сервиса; уже делегирует в Basement, старый atlas не выбран")
		"WS-026","WS-027","WS-029":
			var kind: String={"WS-026":"workbench","WS-027":"cauldron","WS-029":"loom"}[id]
			var item:={"kind":kind,"level":1,"direction":0,"x":0,"y":0}
			rect=Basement.destination(item)
			var base: Rect2=preload("res://scripts/systems/basement_layout_system.gd").rect(item)
			rect.position-=Vector2(base.get_center().x,base.end.y)
			return _full(Basement.texture(kind,1,0),rect,Pres+"basement_visual_system.gd",kind+", уровень 1, вниз; без кучи и огня")
		"WS-028":
			var apiary:=preload("res://scripts/presentation/apiary_visual_system.gd")
			return _full(apiary.TEXTURES.hive_1,apiary.destination("hive_1",Vector2.ZERO),Pres+"apiary_visual_system.gd","Улей уровня 1, вниз; без процедурных пчёл")
	return {}

## Повторяет настоящий маленький тайл четырежды по каждой оси, не увеличивая его мировой размер.
static func _tile(texture: Texture2D, owner: String) -> Dictionary:
	var result:=_full(texture,Rect2(-48,-96,24,24),owner,"Фрагмент 4×4 тайла по 24 мировых единицы")
	result.repeat=4;return result

## Разворачивает AtlasTexture в точную область исходного мастера без равной слепой нарезки.
static func _full(texture: Texture2D, destination: Rect2, owner: String, note: String, world_size := true) -> Dictionary:
	return _cut(texture,Rect2(Vector2.ZERO,texture.get_size()),destination,owner,note,world_size)

## Хранит действительную текстуру и источник; координаты мастера вычисляются только один раз.
static func _cut(texture: Texture2D, source: Rect2, destination: Rect2, owner: String, note: String, world_size := true) -> Dictionary:
	var master:=texture;var region:=source
	if texture is AtlasTexture:master=texture.atlas;region.position+=texture.region.position
	return {"texture":texture,"source":source,"destination":destination,"master_path":master.resource_path,"master_region":region,"owner":owner,"note":note,"world_size":world_size,"repeat":1}
