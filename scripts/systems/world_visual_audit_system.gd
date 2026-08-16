extends RefCounted

const WorldVisualProfileSystem := preload("res://scripts/systems/world_visual_profile_system.gd")
const WorldLootVisualSystem := preload("res://scripts/systems/world_loot_visual_system.gd")
const BuildingVisualSystem := preload("res://scripts/systems/building_visual_system.gd")
const CreatureVisualProfileSystem := preload("res://scripts/systems/creature_visual_profile_system.gd")
const EnvironmentVisualSystem := preload("res://scripts/systems/environment_visual_system.gd")
const FarmLifeVisualSystem := preload("res://scripts/systems/farm_life_visual_system.gd")
const InteriorVisualSystem := preload("res://scripts/systems/interior_visual_system.gd")
const WaterVisualSystem := preload("res://scripts/systems/water_visual_system.gd")


## Возвращает нормализованные профили всех мигрированных мировых каталогов для отчётов и content validation.
static func profiles() -> Dictionary:
	var result: Dictionary = {}
	_append_catalog(result,"core",WorldVisualProfileSystem.PROFILES)
	_append_catalog(result,"loot",WorldLootVisualSystem.PROFILES)
	_append_catalog(result,"buildings",BuildingVisualSystem.PROFILES,"visual_size","foundation_size","bottom_center")
	_append_catalog(result,"environment",EnvironmentVisualSystem.PROFILES,"size","collision","ground_center")
	_append_catalog(result,"farm_life",FarmLifeVisualSystem.PROFILES,"visual","collision","bottom_center")
	_append_catalog(result,"interiors",InteriorVisualSystem.PROFILES,"visual_size","collision_size","bottom_center")
	for rank in CreatureVisualProfileSystem.ENEMY_RANK_SIZES.size():
		result["creatures.enemy_rank_%d"%rank]={"visual_size":CreatureVisualProfileSystem.ENEMY_RANK_SIZES[rank],"anchor":"ground_center","anchor_ratio":CreatureVisualProfileSystem.GROUND_RATIO,"collision_size":Vector2.ZERO,"collision_offset":Vector2.ZERO}
	result["creatures.wildlife"]={"visual_size":CreatureVisualProfileSystem.WILDLIFE_SIZE,"anchor":"ground_center","anchor_ratio":CreatureVisualProfileSystem.GROUND_RATIO,"collision_size":Vector2.ZERO,"collision_offset":Vector2.ZERO}
	for kind in CreatureVisualProfileSystem.HAZARD_SIZES:
		result["creatures.hazard.%s"%kind]={"visual_size":CreatureVisualProfileSystem.HAZARD_SIZES[kind],"anchor":"ground_center","anchor_ratio":CreatureVisualProfileSystem.GROUND_RATIO,"collision_size":Vector2.ZERO,"collision_offset":Vector2.ZERO}
	var water_profile:Dictionary=WaterVisualSystem.profile(); water_profile.collision_size=Vector2.ZERO; water_profile.collision_offset=Vector2.ZERO
	result["water.tile"]=WorldVisualProfileSystem.normalized_profile(water_profile,"visual_size","collision_size","top_left")
	for kind in WaterVisualSystem.EFFECT_PROFILES:
		var effect:Dictionary=WaterVisualSystem.EFFECT_PROFILES[kind].duplicate(true); effect.collision_size=Vector2.ZERO; effect.collision_offset=Vector2.ZERO
		result["water.effect.%s"%kind]=WorldVisualProfileSystem.normalized_profile(effect,"visual_size","collision_size","center")
	return result


## Формирует компактный runtime-отчёт по владельцам и фактическим модульным размерам профилей.
static func report() -> Dictionary:
	var catalog:=profiles(); var provider_counts: Dictionary = {}; var sizes: Dictionary = {}
	for profile_id in catalog:
		var provider:=String(profile_id).get_slice(".",0); provider_counts[provider]=int(provider_counts.get(provider,0))+1
		var size:=Vector2(catalog[profile_id].visual_size); sizes["%dx%d"%[int(size.x),int(size.y)]]=true
	var ordered_sizes:=sizes.keys(); ordered_sizes.sort()
	return {"profile_count":catalog.size(),"providers":provider_counts,"runtime_sizes":ordered_sizes}


## Проверяет общий контракт, соответствие PNG и специализированные ограничения всех владельцев профилей.
static func validation_errors() -> Array[String]:
	var errors: Array[String] = []; var catalog:=profiles()
	for profile_id in catalog: errors.append_array(WorldVisualProfileSystem.profile_validation_errors(profile_id,catalog[profile_id]))
	for building_id in BuildingVisualSystem.PROFILES:
		if not BuildingVisualSystem.profile_is_valid(building_id): errors.append("buildings.%s: PNG или профиль невалиден"%building_id)
	for kind in EnvironmentVisualSystem.PROFILES:
		if not EnvironmentVisualSystem.profile_is_valid(kind): errors.append("environment.%s: PNG или профиль невалиден"%kind)
	if not FarmLifeVisualSystem.profiles_are_valid(): errors.append("farm_life: атлас или профиль невалиден")
	if not CreatureVisualProfileSystem.profiles_are_valid(): errors.append("creatures: профиль невалиден")
	errors.append_array(WorldLootVisualSystem.validation_errors())
	return errors


## Добавляет локальный каталог в общий реестр, преобразуя его названия полей к пространственному контракту.
static func _append_catalog(result: Dictionary, provider: String, catalog: Dictionary, visual_key: String = "visual_size", collision_key: String = "collision_size", default_anchor: String = "bottom_center") -> void:
	for profile_id in catalog:
		result["%s.%s"%[provider,profile_id]]=WorldVisualProfileSystem.normalized_profile(catalog[profile_id],visual_key,collision_key,default_anchor)
