extends RefCounted

const LocaleSystem := preload("res://scripts/systems/locale_system.gd")

const AVAILABLE := "available"
const ACTIVE := "active"
const COMPLETED := "completed"
const LOCKED := "locked"

const MISSIONS := {
	"story_relic": {
		"type": "СЮЖЕТ",
		"title": "Сердце пещеры",
		"giver": "Староста Мирон",
		"description": "Победи Хранителя глубин в Кристальной пещере и принеси Лунную реликвию.",
		"item": "moon_relic",
		"count": 1,
		"coins": 120,
		"xp": 50,
		"reward_item": "guardian_armor",
		"reward_count": 1,
	},
	"story_ancient_key": {"type":"СЮЖЕТ","title":"Шёпот руин","giver":"Архивариус Елизар","description":"Найди древний ключ среди скелетов и принеси его архивариусу.","item":"ancient_key","count":1,"coins":90,"xp":55,"reward_item":"blue_gem","reward_count":1,"requires":"story_relic"},
	"story_orc_blade": {"type":"СЮЖЕТ","title":"Клеймо налётчиков","giver":"Капитан Радомир","description":"Добудь клинок орка, чтобы узнать знак разрушителей печати.","item":"orc_blade","count":1,"coins":110,"xp":65,"reward_item":"metal","reward_count":4,"requires":"story_ancient_key"},
	"story_cursed_gem": {"type":"СЮЖЕТ","title":"Синий огонь","giver":"Ведунья Лада","description":"Принеси два синих алмаза из проклятой земли для обряда очищения.","item":"blue_gem","count":2,"coins":140,"xp":80,"reward_item":"healing_potion","reward_count":2,"requires":"story_orc_blade"},
	"story_moon_seal": {"type":"СЮЖЕТ","title":"Печать Лунной долины","giver":"Староста Мирон","description":"Собери три кристалла и восстанови защитную печать долины.","item":"crystal","count":3,"coins":300,"xp":150,"reward_item":"crystal_ring","reward_count":1,"requires":"story_cursed_gem"},
	"side_seed": {
		"type": "ПОБОЧНОЕ",
		"title": "Редкий росток",
		"giver": "Травница Агафья",
		"description": "Победи хищное растение в лесу и принеси одно редкое семя.",
		"item": "rare_seeds",
		"count": 1,
		"coins": 35,
		"xp": 20,
		"reward_item": "berries",
		"reward_count": 3,
	},
	"side_fisher": {"type":"ПОБОЧНОЕ","title":"Уха для переправы","giver":"Рыбачка Варвара","description":"Поймай пять рыб для рабочих, ремонтирующих мост.","item":"fish","count":5,"coins":55,"xp":25,"reward_item":"watermelon","reward_count":2},
	"side_smith": {"type":"ПОБОЧНОЕ","title":"Первый заказ кузнеца","giver":"Кузнец Гаврила","description":"Принеси четыре куска металла для деревенской кузницы.","item":"metal","count":4,"coins":70,"xp":35,"reward_item":"iron_helmet","reward_count":1},
	"side_miner": {"type":"ПОБОЧНОЕ","title":"Красная жила","giver":"Шахтёр Злата","description":"Добудь два красных кристалла на каменистой окраине.","item":"red_crystal","count":2,"coins":75,"xp":40,"reward_item":"crystal","reward_count":2},
	"side_hunter": {"type":"ПОБОЧНОЕ","title":"Тёплые плащи","giver":"Охотник Савелий","description":"Принеси две оленьи шкуры для зимних плащей.","item":"hide","count":2,"coins":65,"xp":35,"reward_item":"oak_shield","reward_count":1},
	"side_bones": {"type":"ПОБОЧНОЕ","title":"Память стражей","giver":"Архивариус Елизар","description":"Собери восемь костей, чтобы восстановить летопись гарнизона.","item":"bones","count":8,"coins":80,"xp":45,"reward_item":"ancient_key","reward_count":1},
	"side_wings": {"type":"ПОБОЧНОЕ","title":"Ночное лекарство","giver":"Ведунья Лада","description":"Принеси четыре крыла летучих мышей для защитного настоя.","item":"bat_wing","count":4,"coins":60,"xp":35,"reward_item":"healing_potion","reward_count":2},
	"side_glass": {"type":"ПОБОЧНОЕ","title":"Хрустальная плавка","giver":"Стеклодув Тихон","description":"Принеси четыре кристалла для новой партии лунного стекла.","item":"crystal","count":4,"coins":95,"xp":45,"reward_item":"orange","reward_count":3},
	"side_feast": {"type":"ПОБОЧНОЕ","title":"Праздник урожая","giver":"Повариха Дуня","description":"Собери три гриба для общего деревенского стола.","item":"mushroom","count":3,"coins":45,"xp":25,"reward_item":"apple","reward_count":5},
}

const NPCS := {
	"miron":{"location":"overworld","position":Vector2(1450,520),"sprite":1,"tint":Color("fff3d8"),"missions":["story_relic","story_moon_seal"]},
	"agafya":{"location":"overworld","position":Vector2(1220,535),"sprite":2,"tint":Color("dff2d2"),"missions":["side_seed"]},
	"varvara":{"location":"overworld","position":Vector2(720,760),"sprite":2,"tint":Color("d7efff"),"missions":["side_fisher"]},
	"gavrila":{"location":"overworld","position":Vector2(1545,535),"sprite":1,"tint":Color("ffd8c2"),"missions":["side_smith"]},
	"dunya":{"location":"overworld","position":Vector2(865,535),"sprite":0,"tint":Color("fff0c4"),"missions":["side_feast"]},
	"saveliy":{"location":"forest","position":Vector2(350,520),"sprite":1,"tint":Color("d5e6bd"),"missions":["side_hunter"]},
	"zlata":{"location":"rocky","position":Vector2(410,520),"sprite":2,"tint":Color("ffe0b5"),"missions":["side_miner"]},
	"elizar":{"location":"ruins","position":Vector2(350,440),"sprite":0,"tint":Color("e6ddff"),"missions":["story_ancient_key","side_bones"]},
	"radomir":{"location":"ruins","position":Vector2(650,440),"sprite":1,"tint":Color("e4e8ef"),"missions":["story_orc_blade"]},
	"lada":{"location":"cursed","position":Vector2(410,500),"sprite":2,"tint":Color("eacfff"),"missions":["story_cursed_gem","side_wings"]},
	"tikhon":{"location":"glassworks","position":Vector2(480,500),"sprite":0,"tint":Color("cceeff"),"missions":["side_glass"]},
}

## Создаёт полный набор начальных состояний, включая контент новых версий игры.
static func default_states() -> Dictionary:
	var result := {}
	for mission_id in MISSIONS: result[mission_id] = AVAILABLE
	return result

## Дополняет загруженные состояния заданиями, которых не было в старом сохранении.
static func merge_states(saved: Dictionary) -> Dictionary:
	var result := default_states()
	for mission_id in saved:
		if MISSIONS.has(mission_id): result[mission_id] = saved[mission_id]
	return result

## Возвращает фактическое состояние с учётом завершения предыдущей главы.
static func mission_state(game: Node, mission_id: String) -> String:
	var stored: String = game.mission_states.get(mission_id, AVAILABLE)
	var requirement: String = MISSIONS.get(mission_id, {}).get("requires", "")
	if stored == AVAILABLE and not requirement.is_empty() and game.mission_states.get(requirement, AVAILABLE) != COMPLETED:
		return LOCKED
	return stored

## Возвращает мировую позицию NPC, сохраняя совместимость с витриной анимаций.
static func npc_position(game: Node, npc_id: String) -> Vector2:
	if npc_id == "miron": return game.guild_master_position
	if npc_id == "agafya": return game.herbalist_position
	return NPCS.get(npc_id, {}).get("position", Vector2.ZERO)

## Возвращает локализованное имя жителя по первому связанному заданию.
static func npc_name(npc_id: String) -> String:
	var missions: Array = NPCS.get(npc_id, {}).get("missions", [])
	return LocaleSystem.quest(missions[0], "giver") if not missions.is_empty() else npc_id

## Находит ближайшего жителя активной локации для контекстного взаимодействия.
static func nearest_npc(game: Node, distance_limit: float = 92.0) -> String:
	var nearest := ""
	for npc_id in NPCS:
		if NPCS[npc_id].location != game.current_location: continue
		var distance: float = game.player.distance_to(npc_position(game, npc_id))
		if distance < distance_limit:
			distance_limit = distance
			nearest = npc_id
	return nearest

## Выбирает активное либо первое открытое задание указанного жителя.
static func mission_for_npc(game: Node, npc_id: String) -> String:
	var missions: Array = NPCS.get(npc_id, {}).get("missions", [])
	for mission_id in missions:
		if mission_state(game, mission_id) == ACTIVE: return mission_id
	for mission_id in missions:
		if mission_state(game, mission_id) == AVAILABLE: return mission_id
	return ""

## Возвращает маркер нового, активного или полностью завершённого набора заданий NPC.
static func npc_marker(game: Node, npc_id: String) -> String:
	var missions: Array = NPCS.get(npc_id, {}).get("missions", [])
	for mission_id in missions:
		if mission_state(game, mission_id) == ACTIVE: return "?"
	for mission_id in missions:
		if mission_state(game, mission_id) == AVAILABLE: return "!"
	return "✓" if not missions.is_empty() and missions.all(func(id): return mission_state(game, id) == COMPLETED) else ""

## Запускает диалог жителя с подходящим заданием или благодарностью.
static func talk_to_npc(game: Node, npc_id: String) -> bool:
	if not NPCS.has(npc_id): return false
	var mission_id := mission_for_npc(game, npc_id)
	if mission_id.is_empty():
		game.message = "%s: %s" % [npc_name(npc_id), game.LocaleSystem.text("thanks")]
		return true
	return talk(game, mission_id)

## Выполняет операцию «миссии данных» и возвращает результат согласно контракту метода.
static func mission_data(mission_id: String) -> Dictionary:
	var result: Dictionary = MISSIONS[mission_id].duplicate()
	for field in ["type", "title", "giver", "description"]:
		result[field] = LocaleSystem.quest(mission_id, field)
	return result

## Выполняет изолированную операцию своей подсистемы и возвращает результат согласно контракту.
static func talk_to_grandmother(game: Node) -> void:
	game.notify_tutorial("talk")
	if not game.quest_active and not game.quest_complete:
		game.quest_active = true
		game.message = game.LocaleSystem.text("carrot_quest")
		game.play_sfx("quest_accept")
	elif game.quest_active and game.carrots >= 10:
		game.carrots -= 10
		game.coins += 50
		game.award_xp(25)
		game.quest_active = false
		game.quest_complete = true
		game.has_bow = true
		game.message = game.LocaleSystem.text("carrot_done")
		game.play_sfx("quest_complete")
		game.notify_tutorial("quest_complete")
	elif game.quest_active:
		game.message = game.LocaleSystem.text("carrot_wait", [game.carrots])
	else:
		game.message = game.LocaleSystem.text("thanks")

## Выполняет операцию «диалога» и возвращает результат согласно контракту метода.
static func talk(game: Node, mission_id: String) -> bool:
	if not MISSIONS.has(mission_id):
		return false
	var mission: Dictionary = mission_data(mission_id)
	var state: String = mission_state(game, mission_id)
	if state == LOCKED: return false
	if state == AVAILABLE:
		game.mission_states[mission_id] = ACTIVE
		game.message = game.LocaleSystem.text("mission_started", [mission.type, mission.title])
		game.play_sfx("quest_accept")
		game.notify_tutorial("mission_accept")
		game.notify_tutorial("story_chain" if mission.type == LocaleSystem.quest("story_relic", "type") else "side_quests")
		return true
	if state == ACTIVE:
		var current: int = game.inventory_item_count(mission.item)
		if current < mission.count:
			game.message = game.LocaleSystem.text("mission_wait", [mission.giver, game.inventory_item_name(mission.item), current, mission.count])
			return true
		game.change_inventory_count(mission.item, -mission.count)
		game.change_inventory_count(mission.reward_item, mission.reward_count)
		game.coins += mission.coins
		game.award_xp(mission.xp)
		game.mission_states[mission_id] = COMPLETED
		game.message = game.LocaleSystem.text("mission_done", [mission.title, mission.coins, mission.xp, game.inventory_item_name(mission.reward_item)])
		game.play_sfx("quest_complete")
		game.notify_tutorial("mission_complete")
		if mission.type == LocaleSystem.quest("side_seed", "type"):
			game.notify_tutorial("side_mission")
		return true
	game.message = "%s: %s" % [mission.giver, game.LocaleSystem.text("thanks")]
	return true

## Выполняет изолированную операцию своей подсистемы и возвращает результат согласно контракту.
static func objective_text(game: Node, mission_id: String) -> String:
	var mission: Dictionary = mission_data(mission_id)
	var state: String = mission_state(game, mission_id)
	if state == LOCKED:
		return game.LocaleSystem.ui("locked")
	if state == AVAILABLE:
		return "Поговори: %s" % mission.giver
	if state == COMPLETED:
		return "Выполнено"
	var count: int = mini(game.inventory_item_count(mission.item), mission.count)
	return "%s: %d/%d" % [game.inventory_item_name(mission.item), count, mission.count]
