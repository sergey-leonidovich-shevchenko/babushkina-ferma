extends RefCounted

const MAX_UPGRADE_LEVEL := 3
const VISIBLE_ROWS := 9
const UPGRADES := [
	{"kind":"sword","group":"weapon","cost":{"metal":2,"stone":1}},
	{"kind":"crystal_sword","group":"weapon","cost":{"crystal":2,"metal":1}},
	{"kind":"bow","group":"weapon","cost":{"wood":2,"fiber":2}},
	{"kind":"arrows","group":"arrows","cost":{"arrows":5,"metal":1}},
	{"kind":"orc_blade","group":"weapon","cost":{"metal":3,"bones":1}},
	{"kind":"pirate_cutlass","group":"weapon","cost":{"metal":3,"pirate_doubloon":2}},
	{"kind":"iron_spear","group":"weapon","cost":{"metal":3,"wood":1}},
	{"kind":"war_hammer","group":"weapon","cost":{"metal":4,"stone":2}},
	{"kind":"moon_staff","group":"weapon","cost":{"crystal":3,"metal":1}},
	{"kind":"iron_helmet","group":"armor","cost":{"metal":2,"stone":1}},
	{"kind":"guardian_armor","group":"armor","cost":{"metal":4,"crystal":1}},
	{"kind":"oak_shield","group":"armor","cost":{"wood":3,"metal":1}},
	{"kind":"travel_boots","group":"armor","cost":{"hide":2,"metal":1}},
]


## Возвращает первую видимую строку так, чтобы выбранное улучшение не уходило за рамку кузницы.
static func visible_start(selected: int) -> int:
	return clampi(selected - VISIBLE_ROWS + 1, 0, maxi(0, UPGRADES.size() - VISIBLE_ROWS))


## Возвращает текущий уровень улучшения предмета.
static func level(game: Node, kind: String) -> int:
	return game.state.forge.level(kind)


## Рассчитывает стоимость следующего уровня с учётом кузнечного ремесла.
static func costs(game: Node, upgrade: Dictionary) -> Dictionary:
	var result := {}
	var multiplier := level(game, upgrade.kind) + 1
	for kind in upgrade.cost:
		result[kind] = game.SkillSystem.material_cost(game, int(upgrade.cost[kind]) * multiplier)
	return result


## Проверяет наличие улучшаемого предмета, материалов и свободного уровня.
static func can_upgrade(game: Node, index: int) -> bool:
	if index < 0 or index >= UPGRADES.size():
		return false
	var upgrade: Dictionary = UPGRADES[index]
	if level(game, upgrade.kind) >= MAX_UPGRADE_LEVEL:
		return false
	if upgrade.kind != "arrows" and game.inventory_item_count(upgrade.kind) <= 0:
		return false
	var required := costs(game, upgrade)
	for kind in required:
		if game.inventory_item_count(kind) < required[kind]:
			return false
	return true


## Улучшает выбранное оружие, броню или наконечники стрел в кузнице.
static func upgrade(game: Node, index: int) -> bool:
	if index < 0 or index >= UPGRADES.size():
		return false
	var upgrade: Dictionary = UPGRADES[index]
	if level(game, upgrade.kind) >= MAX_UPGRADE_LEVEL:
		game.message = game.LocaleSystem.text("forge_max")
		return false
	if upgrade.kind != "arrows" and game.inventory_item_count(upgrade.kind) <= 0:
		game.message = game.LocaleSystem.text("forge_need_item", [game.inventory_item_name(upgrade.kind)])
		return false
	if not can_upgrade(game, index):
		game.message = game.LocaleSystem.text("needs", [cost_text(game, upgrade)])
		return false
	var required := costs(game, upgrade)
	for kind in required:
		game.change_inventory_count(kind, -int(required[kind]))
	game.state.forge.set_level(upgrade.kind, level(game, upgrade.kind) + 1)
	game.SkillSystem.award_profession_xp(game, "smithing", 10)
	game.award_xp(6)
	game.InventorySystem.recalculate_stats(game)
	game.message = game.LocaleSystem.text("forge_upgraded", [game.inventory_item_name(upgrade.kind), level(game, upgrade.kind)])
	game.play_sfx("craft")
	game.notify_tutorial("forge_upgrade")
	game.notify_tutorial("arrow_sharpen" if upgrade.group == "arrows" else ("armor_upgrade" if upgrade.group == "armor" else "weapon_sharpen"))
	return true


## Формирует строку стоимости следующего уровня для окна кузницы.
static func cost_text(game: Node, upgrade: Dictionary) -> String:
	var parts: Array[String] = []
	var required := costs(game, upgrade)
	for kind in required:
		parts.append("%s %d/%d" % [game.inventory_item_name(kind), game.inventory_item_count(kind), required[kind]])
	return ", ".join(parts)


## Возвращает дополнительный урон выбранного оружия и заточенных стрел.
static func weapon_damage_bonus(game: Node, equipped_weapon: String) -> int:
	match equipped_weapon:
		"forest_sword": return level(game, "sword")
		"crystal_sword": return level(game, "crystal_sword") * 2
		"bow": return level(game, "bow") + level(game, "arrows")
		"iron_spear": return level(game, "iron_spear")
		"war_hammer": return level(game, "war_hammer") * 2
		"moon_staff": return level(game, "moon_staff") * 2
		"orc_blade": return level(game, "orc_blade")
		"pirate_cutlass": return level(game, "pirate_cutlass")
	return 0


## Возвращает снижение входящего урона от улучшенной надетой брони.
static func armor_defense_bonus(game: Node) -> int:
	var bonus := 0
	if game.equipment.get("head", "") == "iron_helmet": bonus += level(game, "iron_helmet")
	if game.equipment.get("body", "") == "guardian_armor": bonus += level(game, "guardian_armor") * 2
	if game.equipment.get("offhand", "") == "oak_shield": bonus += level(game, "oak_shield")
	return bonus


## Возвращает прибавку максимального здоровья от усиленных шлема и доспеха.
static func armor_health_bonus(game: Node) -> int:
	var bonus := 0
	if game.equipment.get("head", "") == "iron_helmet": bonus += level(game, "iron_helmet") * 2
	if game.equipment.get("body", "") == "guardian_armor": bonus += level(game, "guardian_armor") * 4
	return bonus


## Возвращает дополнительный множитель скорости от улучшенных походных сапог.
static func boots_speed_bonus(game: Node) -> float:
	return float(level(game, "travel_boots")) * 0.02 if game.equipment.get("legs", "") == "travel_boots" else 0.0
