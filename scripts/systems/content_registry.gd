extends RefCounted

const InventorySystem := preload("res://scripts/systems/inventory_system.gd")
const CraftingSystem := preload("res://scripts/systems/crafting_system.gd")
const CombatSystem := preload("res://scripts/systems/combat_system.gd")
const WildlifeSystem := preload("res://scripts/systems/wildlife_system.gd")
const ResourceSystem := preload("res://scripts/systems/resource_system.gd")
const ForageSystem := preload("res://scripts/systems/forage_system.gd")
const ShopSystem := preload("res://scripts/systems/shop_system.gd")
const QuestSystem := preload("res://scripts/systems/quest_system.gd")
const LootContainerSystem := preload("res://scripts/systems/loot_container_system.gd")
const TutorialSystem := preload("res://scripts/systems/tutorial_system.gd")
const WorldSystem := preload("res://scripts/systems/world_system.gd")
const LocaleSystem := preload("res://scripts/systems/locale_system.gd")
const ForgeSystem := preload("res://scripts/systems/forge_system.gd")
const ContractSystem := preload("res://scripts/systems/contract_system.gd")

## Проверяет ссылки между управляемыми данными каталогами до начала игры. Добавление
## контента с опечаткой падает в тестах, а не через несколько часов прохождения.
static func validate() -> Array[String]:
	var errors: Array[String] = []
	var items: Dictionary = InventorySystem.ITEM_DATA
	for recipe_index in CraftingSystem.RECIPES.size():
		var recipe: Dictionary = CraftingSystem.RECIPES[recipe_index]
		_validate_item(errors, items, recipe.output, "recipe[%d].output" % recipe_index)
		for kind in recipe.inputs:
			_validate_item(errors, items, kind, "recipe[%d].inputs" % recipe_index)
	for product_index in ShopSystem.PRODUCTS.size():
		_validate_item(errors, items, ShopSystem.PRODUCTS[product_index].kind, "shop[%d]" % product_index)
	for upgrade_index in ForgeSystem.UPGRADES.size():
		var upgrade: Dictionary = ForgeSystem.UPGRADES[upgrade_index]
		_validate_item(errors, items, upgrade.kind, "forge[%d].kind" % upgrade_index)
		for kind in upgrade.cost:
			_validate_item(errors, items, kind, "forge[%d].cost" % upgrade_index)
	for contract_id in ContractSystem.POOLS:
		for contract in ContractSystem.POOLS[contract_id]:
			_validate_item(errors, items, contract.item, "contract.%s.item" % contract_id)
	for enemy_kind in CombatSystem.TYPES:
		for kind in CombatSystem.TYPES[enemy_kind].loot:
			if kind != "coins": _validate_item(errors, items, kind, "enemy.%s.loot" % enemy_kind)
	for animal_kind in WildlifeSystem.TYPES:
		for kind in WildlifeSystem.TYPES[animal_kind].loot:
			_validate_item(errors, items, kind, "wildlife.%s.loot" % animal_kind)
	for mission_id in QuestSystem.MISSIONS:
		var mission: Dictionary = QuestSystem.MISSIONS[mission_id]
		_validate_item(errors, items, mission.item, "mission.%s.item" % mission_id)
		_validate_item(errors, items, mission.reward_item, "mission.%s.reward" % mission_id)
		var requirement: String = mission.get("requires", "")
		if not requirement.is_empty() and not QuestSystem.MISSIONS.has(requirement): errors.append("mission.%s requires unknown mission: %s" % [mission_id, requirement])
	for npc_id in QuestSystem.NPCS:
		_validate_location(errors, QuestSystem.NPCS[npc_id].location, "quest npc.%s" % npc_id)
		for mission_id in QuestSystem.NPCS[npc_id].missions:
			if not QuestSystem.MISSIONS.has(mission_id): errors.append("quest npc.%s references unknown mission: %s" % [npc_id, mission_id])
	for container_kind in LootContainerSystem.TYPES:
		for entry in LootContainerSystem.TYPES[container_kind].table:
			if entry[0] != "coins": _validate_item(errors, items, entry[0], "container.%s.loot" % container_kind)
	for node in ResourceSystem.SPAWNS:
		_validate_item(errors, items, node.kind, "resource spawn")
		_validate_location(errors, node.location, "resource spawn")
	for node in ForageSystem.SPAWNS:
		_validate_item(errors, items, node.kind, "forage spawn")
		if not ForageSystem.TYPES.has(node.kind): errors.append("forage spawn has unknown type: %s" % node.kind)
		_validate_location(errors, node.location, "forage spawn")
	for enemy in CombatSystem.SPAWNS:
		if not CombatSystem.TYPES.has(enemy.kind): errors.append("enemy spawn has unknown type: %s" % enemy.kind)
		_validate_location(errors, enemy.location, "enemy spawn")
	for animal in WildlifeSystem.SPAWNS:
		if not WildlifeSystem.TYPES.has(animal.kind): errors.append("wildlife spawn has unknown type: %s" % animal.kind)
		_validate_location(errors, animal.location, "wildlife spawn")
	for event_id in TutorialSystem.STEP_IDS:
		if not LocaleSystem.TUTORIAL.has(event_id): errors.append("tutorial has no translation: %s" % event_id)
	return errors


## Выполняет изолированную операцию своей подсистемы и возвращает результат согласно контракту.
static func _validate_item(errors: Array[String], items: Dictionary, kind: String, owner: String) -> void:
	if not items.has(kind):
		errors.append("%s references unknown item: %s" % [owner, kind])


## Выполняет изолированную операцию своей подсистемы и возвращает результат согласно контракту.
static func _validate_location(errors: Array[String], location: String, owner: String) -> void:
	if location not in WorldSystem.LOCATIONS:
		errors.append("%s references unknown location: %s" % [owner, location])
