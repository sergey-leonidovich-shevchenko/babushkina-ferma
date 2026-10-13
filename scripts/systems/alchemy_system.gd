extends RefCounted

const Products := preload("res://scripts/systems/alchemy_product_data.gd")
const Recipes := preload("res://scripts/systems/alchemy_recipe_data.gd")
const STATION := Vector2(700,490)
const RANK_XP := [0,40,120,240]
const FILTERS := ["all","juice","dried","powder","tincture","essence","potions","supplies"]

## Возвращает сохраняемую память открытий и временных эффектов без повторного обхода каталогов в кадре.
static func state(game: Node) -> Dictionary:
	var expansion:Dictionary=game.state.world.estate.expansion
	if not expansion.has("alchemy"): expansion.alchemy={"xp":0,"discovered":[],"crafted":0,"effects":{"repellent":0.0,"mining":0.0}}
	return expansion.alchemy

## Нормализует новые и старые слоты, отбрасывая неизвестные открытия и невозможные длительности.
static func restore(game: Node) -> void:
	var value:=state(game); var known:=[]
	for recipe in Recipes.recipes(): known.append(recipe.id)
	var discoveries:=[]
	for id in value.get("discovered",[]):
		if id in known and id not in discoveries: discoveries.append(id)
	value.discovered=discoveries; value.xp=discoveries.size()*4; value.crafted=maxi(0,int(value.get("crafted",0)))
	var effects:Dictionary=value.get("effects",{})
	value.effects={"repellent":clampf(float(effects.get("repellent",0.0)),0,120),"mining":clampf(float(effects.get("mining",0.0)),0,120)}

## Повышает ранг за различные открытия, не позволяя бесконечно получать опыт из одной дешёвой обработки.
static func rank(game: Node) -> int:
	var xp:=int(state(game).xp); var result:=1
	for index in RANK_XP.size():
		if xp>=RANK_XP[index]: result=index+1
	return result

## Проверяет все ограничения производства до расхода материалов.
static func unlocked(game: Node, recipe: Dictionary) -> bool:
	return rank(game)>=int(recipe.get("alchemy_rank",1)) and (not recipe.get("laboratory",false) or game.state.world.estate.level>=4)

## Сохраняет привязку обработки к рабочей стороне настоящего домашнего или деревенского стола.
static func at_station(game: Node) -> bool:
	if not preload("res://scripts/systems/basement_station_system.gd").active(game,"alchemy").is_empty(): return true
	if game.current_location=="village_garden": return game.player.distance_to(preload("res://scripts/systems/village_region_data.gd").SERVICES.village_garden.alchemy)<=92
	return game.current_location=="cottage_interior" and game.player.distance_to(STATION)<=92.0

## Проводит одну точную партию с побочным жмыхом и опытом только за новое открытие.
static func record_craft(game: Node, recipe: Dictionary) -> void:
	for kind in recipe.get("byproducts",{}): game.change_inventory_count(kind,int(recipe.byproducts[kind]))
	var value:=state(game); value.crafted+=1
	if recipe.id not in value.discovered:
		value.discovered.append(recipe.id); value.xp+=4; game.award_xp(2)
	game.notify_tutorial("alchemy_processing")
	if recipe.id=="alchemy:honey": game.notify_tutorial("apiary_alchemy")
	if recipe.get("alchemy_group","")=="potions": game.notify_tutorial("alchemy_brewing")

## Обновляет длительности только реальным игровым временем; игровые окна приостанавливают этот вызов.
static func update(game: Node, delta: float) -> void:
	var effects:Dictionary=state(game).effects
	for effect in effects: effects[effect]=maxf(0.0,float(effects[effect])-maxf(delta,0.0))

## Возвращает оставшуюся длительность поддерживаемого эффекта с безопасным запасным значением.
static func remaining(game: Node, effect: String) -> float:
	return float(state(game).effects.get(effect,0.0))

## Применяет реальные ресурсы, привычные семейства бафов, очистку укусов и две хозяйственные поддержки.
static func apply_potion(game: Node, kind: String) -> void:
	var data:Dictionary=Products.POTIONS[kind]
	game.heal_player(int(data.get("heal",0)))
	game.player_mana=mini(game.player_max_mana,game.player_mana+int(data.get("mana",0)))
	game.energy=mini(game.SkillSystem.max_stamina(game),game.energy+int(data.get("energy",0)))
	if data.has("timer"):
		game.set(data.timer,maxf(float(game.get(data.timer)),float(data.duration)*game.EstateSystem.potion_multiplier(game)))
		if data.timer=="regeneration_timer": game.regeneration_tick_timer=0.0
	if data.has("effect"):
		var effects:Dictionary=state(game).effects
		effects[data.effect]=maxf(float(effects[data.effect]),float(data.duration)*game.EstateSystem.potion_multiplier(game))
	if data.get("cleanse",false): game.state.world.cave_boss.fly_timer=0.0; game.state.world.cave_boss.fly_tick=0.0
	game.message=game.inventory_item_name(kind)+": "+preload("res://scripts/systems/alchemy_locale.gd").effect_text(game,kind)
	game.notify_tutorial("alchemy_effects")

## Переключает раздел рецептов в существующем окне без открытия второго интерфейса поверх игры.
static func cycle_filter(game: Node, offset: int=1) -> void:
	var current:=String(game.get_meta("alchemy_filter","all"))
	game.set_meta("alchemy_filter",FILTERS[posmod(FILTERS.find(current)+offset,FILTERS.size())])
	game.CraftingSystem.open(game,"alchemy"); game.queue_redraw()
