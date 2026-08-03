extends RefCounted

const BOARD_POSITION := Vector2(310, 370)
const UPGRADES := [
	{"id":"house","coins":200,"cost":{"wood":10}},
	{"id":"greenhouse","coins":450,"cost":{"wood":15,"crystal":3}},
	{"id":"barn","coins":700,"cost":{"wood":20,"metal":8}},
	{"id":"laboratory","coins":1000,"cost":{"crystal":8,"ectoplasm":4}},
]
const QUALITY_ORDER := ["normal", "silver", "gold", "iridium"]


## Создаёт состояние усадьбы, качества предметов, карты и события дня.
static func default_state() -> Dictionary:
	return {"level":0,"qualities":{},"discovered":["overworld"],"event_day":0,"event":""}


## Нормализует прогресс усадьбы и открытые области старого сохранения.
static func normalize_state(value: Dictionary) -> Dictionary:
	var result := default_state()
	for key in value:
		if result.has(key): result[key] = value[key]
	result.level = clampi(int(result.level), 0, UPGRADES.size())
	result.discovered = Array(result.discovered)
	if "overworld" not in result.discovered: result.discovered.append("overworld")
	result.event_day = maxi(0, int(result.event_day))
	return result


## Возвращает доску развития рядом с домом, если остаётся доступное улучшение.
static func nearest_interaction(game: Node, distance_limit: float = 92.0) -> String:
	if game.current_location == "overworld" and game.state.world.estate.level < UPGRADES.size() and game.player.distance_to(BOARD_POSITION) < distance_limit: return "estate_board"
	return ""


## Покупает следующее последовательное улучшение после проверки денег и материалов.
static func purchase_next(game: Node) -> bool:
	var level: int = int(game.state.world.estate.level)
	if level >= UPGRADES.size(): return false
	var upgrade: Dictionary = UPGRADES[level]
	if game.coins < int(upgrade.coins):
		game.message = game.LocaleSystem.text("estate_need_coins", [upgrade.coins]); return false
	for kind in upgrade.cost:
		if game.inventory_item_count(kind) < int(upgrade.cost[kind]):
			game.message = game.LocaleSystem.text("needs", ["%s ×%d" % [game.inventory_item_name(kind), upgrade.cost[kind]]]); return false
	game.coins -= int(upgrade.coins)
	for kind in upgrade.cost: game.change_inventory_count(kind, -int(upgrade.cost[kind]))
	game.state.world.estate.level = level + 1
	game.SkillSystem.recalculate_resources(game)
	game.message = game.LocaleSystem.text("estate_upgraded", [game.LocaleSystem.ui("estate_%s" % upgrade.id)])
	game.play_sfx("craft"); game.notify_tutorial("estate_upgrade")
	return true


## Записывает качество полученного предмета отдельно от общего количества стека.
static func record_quality(game: Node, kind: String, count: int = 1) -> String:
	var farming: int = game.SkillSystem.skill(game, "farming")
	var score := farming + int(game.state.world.estate.level >= 2) * 2 + posmod(game.day + game.inventory_item_count(kind), 4)
	var quality := "iridium" if score >= 10 else ("gold" if score >= 7 else ("silver" if score >= 4 else "normal"))
	var item_qualities: Dictionary = game.state.world.estate.qualities.get(kind, {})
	item_qualities[quality] = int(item_qualities.get(quality, 0)) + count
	game.state.world.estate.qualities[kind] = item_qualities
	game.notify_tutorial("item_quality")
	return quality


## Возвращает множитель цены лучшего имеющегося качества предмета.
static func quality_multiplier(game: Node, kind: String) -> float:
	var qualities: Dictionary = game.state.world.estate.qualities.get(kind, {})
	for quality in ["iridium", "gold", "silver"]:
		if int(qualities.get(quality, 0)) > 0: return {"silver":1.25,"gold":1.6,"iridium":2.1}[quality]
	return 1.0


## Списывает лучший качественный экземпляр и возвращает его ценовой множитель с учётом события дня.
static func consume_sale_multiplier(game: Node, kind: String) -> float:
	var qualities: Dictionary = game.state.world.estate.qualities.get(kind, {})
	var multiplier := 1.0
	for quality in ["iridium", "gold", "silver", "normal"]:
		if int(qualities.get(quality, 0)) > 0:
			qualities[quality] = int(qualities[quality]) - 1
			multiplier = {"normal":1.0,"silver":1.25,"gold":1.6,"iridium":2.1}[quality]
			break
	game.state.world.estate.qualities[kind] = qualities
	return multiplier * (1.15 if game.state.world.estate.event == "market" else (0.9 if game.state.world.estate.event == "raid" else 1.0))


## Добавляет посещённую локацию на постоянную карту героя.
static func discover_location(game: Node, location: String) -> void:
	if location not in game.state.world.estate.discovered: game.state.world.estate.discovered.append(location)


## Обновляет детерминированное событие дня без случайной порчи сохранения.
static func update_daily_event(game: Node) -> void:
	if game.state.world.estate.event_day == game.day: return
	game.state.world.estate.event_day = game.day
	game.state.world.estate.event = ["market", "festival", "traveler", "raid"][posmod(game.day - 1, 4)]
	game.notify_tutorial("world_calendar")


## Возвращает коэффициент роста культур от построенной теплицы и праздника урожая.
static func crop_multiplier(game: Node) -> float:
	return (1.2 if game.state.world.estate.level >= 2 else 1.0) * (1.1 if game.state.world.estate.event == "festival" else 1.0)


## Возвращает коэффициент длительности зелий от домашней лаборатории.
static func potion_multiplier(game: Node) -> float:
	return 1.35 if game.state.world.estate.level >= 4 else 1.0
