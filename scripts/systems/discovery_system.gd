extends RefCounted

const RANGE := 144.0
const CARD_DURATION := 6.0
const SCAN_INTERVAL := 0.25

const STATIC_HINTS := {
	"grandmother": {"title":"Бабушка","text":"Даёт первое фермерское задание. Подойди и нажми E для разговора."},
	"guild_master": {"title":"Староста Мирон","text":"Выдаёт сюжетные миссии. Маркер ! означает новое задание, ? — цель выполнена."},
	"herbalist": {"title":"Травница Агафья","text":"Выдаёт побочные задания на лесные растения и редкие ингредиенты."},
	"shop": {"title":"Сельская лавка","text":"Здесь можно покупать и продавать товары. Подойди и нажми E или B."},
	"workbench": {"title":"Верстак","text":"Открывает рецепты. Выбери рецепт стрелками и создай его клавишей Enter."},
	"farm": {"title":"Грядки","text":"Мотыга → семена → лейка → повторный полив → сбор руками. Инструменты находятся на панели 1–0."},
	"pond": {"title":"Рыбное место","text":"Возьми удочку [6], нажми E, дождись поклёвки и нажми E ещё раз."},
	"cave": {"title":"Кристальная пещера","text":"Внутри есть руды, скелеты и сюжетный босс. Возьми кирку и оружие."},
	"world_gate": {"title":"Золотые врата","text":"Переносят в следующую область мира. Подойди к свечению и нажми E."},
	"bridge": {"title":"Мост","text":"Воду нельзя пересечь пешком. Ищи мосты — только по ним можно перейти реку."},
	"slime": {"title":"Слизень","text":"Враг ближнего боя. Атакуй клавишей F; выпавшие ресурсы подбираются через E."},
}

const LOCATION_HINTS := {
	"overworld": {"title":"Деревня и ферма","text":"Поговори с жителями, выращивай урожай и подготовься к путешествию."},
	"forest": {"title":"Обычный лес","text":"Здесь водятся хищные растения и растут съедобные ягоды, грибы и орехи."},
	"rocky": {"title":"Каменистая область","text":"Ищи залежи для кирки и проходы в более опасные земли."},
	"ruins": {"title":"Орочьи руины","text":"Орки оставляют монеты, металл и оружие. Перед боем проверь здоровье."},
	"cave": {"title":"Кристальная пещера","text":"Синие и зелёные жилы, нежить и Хранитель глубин ждут внутри."},
	"cursed": {"title":"Проклятая земля","text":"Сильная нежить оставляет кости, ключи и редкие самоцветы."},
	"glassworks": {"title":"Мастерская стеклодува","text":"Безопасная ремесленная точка для будущих рецептов из цветных кристаллов."},
}

static func update(game: Node, delta: float) -> void:
	if game.discovery_timer > 0.0:
		game.discovery_timer = maxf(game.discovery_timer - delta, 0.0)
		if game.discovery_timer <= 0.0:
			game.discovery_current.clear()
	game.discovery_scan_timer -= delta
	if game.discovery_scan_timer > 0.0 or not game.discovery_current.is_empty():
		return
	game.discovery_scan_timer = SCAN_INTERVAL
	scan_nearby(game)

static func show_location(game: Node, location: String) -> bool:
	if not LOCATION_HINTS.has(location):
		return false
	return show(game, "location:%s" % location, {"title":game.LocaleSystem.location(location),"text":game.LocaleSystem.ui("hint_location")})

static func dismiss(game: Node) -> void:
	game.discovery_timer = 0.0
	game.discovery_current.clear()

static func scan_nearby(game: Node) -> bool:
	var candidates: Array[Dictionary] = []
	if game.current_location == "overworld":
		add_candidate(candidates, "grandmother", game.npc_position, static_hint(game, "grandmother"))
		add_candidate(candidates, "guild_master", game.guild_master_position, static_hint(game, "guild_master"))
		add_candidate(candidates, "herbalist", game.herbalist_position, static_hint(game, "herbalist"))
		add_candidate(candidates, "shop", Vector2(972, 278), static_hint(game, "shop"))
		add_candidate(candidates, "workbench", game.workbench_position, static_hint(game, "workbench"))
		add_candidate(candidates, "farm", Vector2(game.FARM_ORIGIN) + Vector2(game.FARM_SIZE * game.TILE) * 0.5, static_hint(game, "farm"))
		add_candidate(candidates, "pond", game.pond_position, static_hint(game, "pond"))
		add_candidate(candidates, "cave", game.cave_entrance_position, static_hint(game, "cave"))
		add_candidate(candidates, "bridge", game.BRIDGE_RECT.get_center(), static_hint(game, "bridge"))
		if game.slime_alive:
			add_candidate(candidates, "slime", game.slime_position, static_hint(game, "slime"))
	for food in game.food_nodes:
		if food.active and food.get("location", "overworld") == game.current_location:
			add_candidate(candidates, "food:%s" % food.kind, food.position, food_hint(game, food.kind))
	add_candidate(candidates, "world_gate", game.world_gate_position, static_hint(game, "world_gate"))
	for resource in game.resource_nodes:
		if resource.hits > 0 and resource.location == game.current_location:
			add_candidate(candidates, "resource:%s" % resource.kind, resource.position, resource_hint(game, resource.kind))
	for enemy in game.enemy_nodes:
		if enemy.alive and enemy.location == game.current_location:
			add_candidate(candidates, "enemy:%s" % enemy.kind, enemy.position, enemy_hint(game, enemy.kind))
	for animal in game.wildlife_nodes:
		if animal.alive and animal.location == game.current_location:
			add_candidate(candidates, "wildlife:%s" % animal.kind, animal.position, wildlife_hint(game, animal.kind))
	for item in game.dropped_items:
		add_candidate(candidates, "item:%s" % item.kind, item.position, item_hint(game, item.kind))
	for container in game.world_loot_nodes:
		if not container.opened and container.location == game.current_location:
			add_candidate(candidates, "container:%s" % container.kind, container.position, container_hint(game, container.kind))
	var nearest: Dictionary = {}
	var nearest_distance := RANGE
	for candidate in candidates:
		if game.seen_discoveries.has(candidate.id):
			continue
		var distance: float = game.player.distance_to(candidate.position)
		if distance <= nearest_distance:
			nearest_distance = distance
			nearest = candidate
	if nearest.is_empty():
		return false
	return show(game, nearest.id, nearest.hint)

static func show(game: Node, id: String, hint: Dictionary) -> bool:
	if game.seen_discoveries.has(id):
		return false
	game.seen_discoveries[id] = true
	game.discovery_current = {"id":id,"title":hint.title,"text":hint.text}
	game.discovery_timer = CARD_DURATION
	return true

static func add_candidate(candidates: Array[Dictionary], id: String, position: Vector2, hint: Dictionary) -> void:
	candidates.append({"id":id,"position":position,"hint":hint})

static func static_hint(game: Node, kind: String) -> Dictionary:
	var tutorial_key: String = {"grandmother":"talk","guild_master":"mission_accept","herbalist":"side_mission","shop":"trade","workbench":"craft_window","farm":"plant","pond":"fish","cave":"travel","bridge":"collision","slime":"fight","world_gate":"locations"}.get(kind, "move")
	var title: String = game.LocaleSystem.entity(kind)
	if kind == "guild_master": title = game.LocaleSystem.quest("story_relic", "giver")
	if kind == "herbalist": title = game.LocaleSystem.quest("side_seed", "giver")
	if kind == "shop": title = game.LocaleSystem.ui("shop")
	if kind == "cave": title = game.LocaleSystem.location("cave")
	return {"title":title,"text":game.LocaleSystem.tutorial(tutorial_key)}

static func resource_hint(game: Node, kind: String) -> Dictionary:
	return {"title":game.LocaleSystem.item(kind),"text":game.LocaleSystem.tutorial("mine")}

static func enemy_hint(game: Node, kind: String) -> Dictionary:
	return {"title":game.LocaleSystem.entity(kind),"text":game.LocaleSystem.ui("hint_enemy")}

static func food_hint(game: Node, kind: String) -> Dictionary:
	return {"title":game.LocaleSystem.entity(kind),"text":game.LocaleSystem.ui("hint_forage")}

static func wildlife_hint(game: Node, kind: String) -> Dictionary:
	return {"title":game.LocaleSystem.entity(kind),"text":game.LocaleSystem.ui("hint_wildlife")}

static func item_hint(game: Node, kind: String) -> Dictionary:
	var item: Dictionary = game.InventorySystem.data(kind)
	var action: String = game.LocaleSystem.ui("hint_quest_item" if kind == "moon_relic" else "hint_item")
	return {"title":game.LocaleSystem.ui("new_item", [item.name]),"text":action}

static func container_hint(game: Node, kind: String) -> Dictionary:
	var title: String = game.LocaleSystem.entity(kind)
	return {"title":title,"text":game.LocaleSystem.ui("hint_container")}
