extends RefCounted

const SAVE_PATH := "user://farm-save.json"
const VERSION := 2
const STATE_SCHEMA := "aggregate-v2"

## Собирает полную сериализуемую копию текущего состояния игры.
static func snapshot(game: Node) -> Dictionary:
	var plot_data := []
	var drops := []
	var wildlife := []
	var containers := []
	var forage := []
	for cell in game.plots:
		var plot: Dictionary = game.plots[cell]
		plot_data.append({"x":cell.x,"y":cell.y,"tilled":plot.tilled,"planted":plot.planted,"watered":plot.watered,"growth":plot.growth,"stage":plot.stage})
	for item in game.dropped_items:
		drops.append({"kind":item.kind,"count":item.count,"position":[item.position.x,item.position.y]})
	for animal in game.wildlife_nodes:
		wildlife.append({"hp":animal.hp,"alive":animal.alive,"position":[animal.position.x,animal.position.y]})
	for container in game.world_loot_nodes:
		containers.append({"id":container.id,"kind":container.kind,"location":container.location,"position":[container.position.x,container.position.y],"opened":container.opened,"contents":container.contents.duplicate(true)})
	for node in game.food_nodes:
		forage.append({"active":node.active,"ready_at":node.get("ready_at", 0.0)})
	return {"version":VERSION,"state_schema":STATE_SCHEMA,"player":[game.player.x,game.player.y],"location":game.current_location,"day":game.day,"minutes":game.game_minutes,"energy":game.energy,"coins":game.coins,"xp":game.player_xp,"level":game.player_level,"hp":game.player_hp,"progression":{"points":game.skill_points,"levels":game.skill_levels.duplicate(true),"xp":game.skill_xp.duplicate(true),"mana":game.player_mana},"companions":{"recruited":game.recruited_companions.duplicate(),"active":game.active_companions.duplicate()},"storage":{"owned":game.home_chest_owned,"counts":game.home_chest_counts.duplicate(true)},"forge":game.forge_upgrades.duplicate(true),"contracts":{"day":game.state.contracts.offer_day,"statuses":game.state.contracts.statuses.duplicate(true),"completed":game.state.contracts.completed_total},"counts":game.export_inventory_counts().duplicate(true),"slots":game.inventory_slots.duplicate(true),"hotbar":game.hotbar_slots.duplicate(true),"equipment":game.equipment.duplicate(true),"quest_active":game.quest_active,"quest_complete":game.quest_complete,"missions":game.mission_states.duplicate(true),"tutorial":{"step":game.tutorial_step,"events":game.tutorial_events_completed.duplicate(true),"seen":game.seen_discoveries.duplicate(true),"animation":game.character_animation_directions.keys()},"weapons":{"sword":game.sword_crafted,"bow":game.has_bow,"crystal":game.has_crystal_sword,"equipped":game.equipped_weapon},"plots":plot_data,"resource_hits":game.resource_nodes.map(func(node): return node.hits),"food_active":game.food_nodes.map(func(node): return node.active),"forage":forage,"enemies":game.enemy_nodes.map(func(enemy): return {"hp":enemy.hp,"alive":enemy.alive,"level":enemy.level,"position":[enemy.position.x,enemy.position.y],"direction":[enemy.direction.x,enemy.direction.y],"attack_timer":enemy.attack_timer}),"hazards":game.hazard_nodes.map(func(hazard): return {"cooldown":hazard.cooldown}),"wildlife":wildlife,"world_loot_seed":game.world_loot_seed,"containers":containers,"drops":drops}


## Обновляет сохранение старой версии до актуальной схемы данных.
static func migrate(data: Dictionary) -> Dictionary:
	var migrated := data.duplicate(true)
	match int(migrated.get("version", 0)):
		1:
			migrated.version = VERSION
			migrated.state_schema = STATE_SCHEMA
		VERSION:
			if migrated.get("state_schema", "") != STATE_SCHEMA:
				return {}
		_:
			return {}
	return migrated

## Применяет проверенные данные сохранения к активной игре.
static func apply(game: Node, data: Dictionary) -> bool:
	data = migrate(data)
	if data.is_empty(): return false
	game.player = Vector2(data.player[0], data.player[1]); game.current_location = data.location
	game.day = data.day; game.game_minutes = data.minutes; game.energy = data.energy; game.coins = data.coins
	game.player_xp = data.xp; game.player_level = clampi(int(data.level), 1, game.SkillSystem.MAX_CHARACTER_LEVEL); game.player_hp = data.hp
	var progression: Dictionary = data.get("progression", {})
	game.skill_points = progression.get("points", 0)
	for skill_id in game.skill_levels:
		game.skill_levels[skill_id] = progression.get("levels", {}).get(skill_id, 0)
	for skill_id in game.skill_xp:
		game.skill_xp[skill_id] = progression.get("xp", {}).get(skill_id, 0)
	game.player_mana = progression.get("mana", game.player_mana)
	var storage: Dictionary = data.get("storage", {})
	game.home_chest_owned = bool(storage.get("owned", false))
	game.home_chest_counts = storage.get("counts", {}).duplicate(true)
	game.forge_upgrades = data.get("forge", {}).duplicate(true)
	var contracts: Dictionary = data.get("contracts", {})
	game.state.contracts.offer_day = int(contracts.get("day", 0))
	game.state.contracts.statuses = contracts.get("statuses", {}).duplicate(true)
	game.state.contracts.completed_total = int(contracts.get("completed", 0))
	var companions: Dictionary = data.get("companions", {})
	game.recruited_companions.assign(companions.get("recruited", []))
	game.active_companions.assign(companions.get("active", []))
	for companion_id in game.active_companions.duplicate():
		if companion_id not in game.recruited_companions or not game.CompanionSystem.COMPANIONS.has(companion_id):
			game.active_companions.erase(companion_id)
	while game.active_companions.size() > game.CompanionSystem.capacity(game):
		game.active_companions.pop_back()
	game.companion_positions.clear()
	for companion_id in game.active_companions:
		game.companion_positions[companion_id] = game.player + Vector2(-50, 35)
	game.import_inventory_counts(data.counts)
	var inventory_catalog: Array = game.inventory_slots.duplicate()
	game.inventory_slots.assign(data.slots)
	for kind in inventory_catalog:
		if not kind.is_empty() and not game.inventory_slots.has(kind):
			game.inventory_slots.append(kind)
	while game.inventory_slots.size() < inventory_catalog.size():
		game.inventory_slots.append("")
	for kind in game.export_inventory_counts():
		if game.inventory_item_count(kind) > 0:
			game.InventorySystem.ensure_item_slot(game, kind)
	game.InventorySystem.ensure_capacity(game)
	game.hotbar_slots.assign(data.hotbar)
	game.equipment = data.equipment.duplicate(true)
	if not game.equipment.has("offhand"): game.equipment.offhand = ""
	game.quest_active = data.quest_active; game.quest_complete = data.quest_complete
	game.mission_states = data.get("missions", game.mission_states).duplicate(true)
	var tutorial: Dictionary = data.get("tutorial", {})
	game.tutorial_step = tutorial.get("step", game.tutorial_step)
	game.tutorial_events_completed = tutorial.get("events", {}).duplicate(true)
	game.seen_discoveries = tutorial.get("seen", {}).duplicate(true)
	game.character_animation_directions.clear()
	for direction in tutorial.get("animation", []):
		game.character_animation_directions[int(direction)] = true
	game.sword_crafted = data.weapons.sword; game.has_bow = data.weapons.bow; game.has_crystal_sword = data.weapons.crystal; game.equipped_weapon = data.weapons.equipped
	for saved_plot in data.plots:
		var cell := Vector2i(saved_plot.x, saved_plot.y)
		if game.plots.has(cell):
			var plot: Dictionary = game.plots[cell]
			for key in ["tilled","planted","watered","growth","stage"]: plot[key] = saved_plot[key]
			game.plots[cell] = plot
	for index in mini(data.resource_hits.size(), game.resource_nodes.size()): game.resource_nodes[index].hits = data.resource_hits[index]
	if data.has("forage"):
		for index in mini(data.forage.size(), game.food_nodes.size()):
			game.food_nodes[index].active = data.forage[index].active
			game.food_nodes[index].ready_at = data.forage[index].ready_at
	else:
		for index in mini(data.get("food_active", []).size(), game.food_nodes.size()): game.food_nodes[index].active = data.food_active[index]
	for index in mini(data.get("enemies",[]).size(), game.enemy_nodes.size()):
		var saved_enemy: Dictionary = data.enemies[index]
		game.enemy_nodes[index].level = clampi(int(saved_enemy.get("level", game.enemy_nodes[index].level)), 1, game.CombatSystem.MAX_ENEMY_LEVEL)
		game.enemy_nodes[index].max_hp = game.CombatSystem.max_hp(game.enemy_nodes[index].kind, game.enemy_nodes[index].level)
		game.enemy_nodes[index].hp = saved_enemy.hp
		game.enemy_nodes[index].alive = saved_enemy.alive
		if saved_enemy.has("position"): game.enemy_nodes[index].position = Vector2(saved_enemy.position[0], saved_enemy.position[1])
		if saved_enemy.has("direction"): game.enemy_nodes[index].direction = Vector2(saved_enemy.direction[0], saved_enemy.direction[1])
		game.enemy_nodes[index].attack_timer = saved_enemy.get("attack_timer", 0.0)
	for index in mini(data.get("hazards", []).size(), game.hazard_nodes.size()):
		game.hazard_nodes[index].cooldown = data.hazards[index].get("cooldown", 0.0)
	for index in mini(data.get("wildlife",[]).size(), game.wildlife_nodes.size()):
		game.wildlife_nodes[index].hp = data.wildlife[index].hp
		game.wildlife_nodes[index].alive = data.wildlife[index].alive
		game.wildlife_nodes[index].position = Vector2(data.wildlife[index].position[0], data.wildlife[index].position[1])
	if data.has("containers"):
		game.world_loot_seed = data.get("world_loot_seed", game.world_loot_seed)
		game.world_loot_nodes.clear()
		for container in data.containers:
			game.world_loot_nodes.append({"id":container.id,"kind":container.kind,"location":container.location,"position":Vector2(container.position[0],container.position[1]),"opened":container.opened,"contents":container.contents.duplicate(true)})
	game.dropped_items.clear()
	for item in data.get("drops", []):
		game.dropped_items.append({"kind":item.kind,"count":item.count,"position":Vector2(item.position[0],item.position[1])})
	game.InventorySystem.recalculate_stats(game); game.player_hp = mini(game.player_hp, game.player_max_hp)
	game.state.normalize()
	game.sync_background_location(); game.update_camera(); return true


## Выполняет изолированную операцию своей подсистемы и возвращает результат согласно контракту.
static func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return {}
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return {}
	return json.data if json.data is Dictionary else {}


## Выполняет изолированную операцию своей подсистемы и возвращает результат согласно контракту.
static func _write_json(path: String, data: Dictionary) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if not file:
		return false
	file.store_string(JSON.stringify(data))
	file.flush()
	return file.get_error() == OK


## Выполняет изолированную операцию своей подсистемы и возвращает результат согласно контракту.
static func _copy_file(source: String, destination: String) -> bool:
	var source_file := FileAccess.open(source, FileAccess.READ)
	if not source_file:
		return false
	var destination_file := FileAccess.open(destination, FileAccess.WRITE)
	if not destination_file:
		return false
	destination_file.store_buffer(source_file.get_buffer(source_file.get_length()))
	destination_file.flush()
	return destination_file.get_error() == OK


## Выполняет операцию «сохранения at» и возвращает результат согласно контракту метода.
static func save_at(game: Node, path: String) -> bool:
	var temporary := path + ".tmp"
	var backup := path + ".bak"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary))
	if not _write_json(temporary, snapshot(game)) or migrate(_read_json(temporary)).is_empty():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary))
		return false
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(backup))
		if not _copy_file(path, backup):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary))
			return false
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var rename_error := DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary), ProjectSettings.globalize_path(path))
	if rename_error != OK:
		if FileAccess.file_exists(backup):
			_copy_file(backup, path)
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary))
		return false
	return true


## Выполняет операцию «сохранения» и возвращает результат согласно контракту метода.
static func save(game: Node) -> bool:
	return save_at(game, SAVE_PATH)


## Проверяет наличие основного или резервного файла сохранения по переданному пути.
static func has_save_at(path: String) -> bool:
	return FileAccess.file_exists(path) or FileAccess.file_exists(path + ".bak")


## Проверяет, доступно ли продолжение игры из стандартного пользовательского сохранения.
static func has_save() -> bool:
	return has_save_at(SAVE_PATH)


## Выполняет изолированную операцию своей подсистемы и возвращает результат согласно контракту.
static func load_at(game: Node, path: String) -> bool:
	var data := _read_json(path)
	if not data.is_empty() and apply(game, data):
		return true
	var backup := _read_json(path + ".bak")
	return not backup.is_empty() and apply(game, backup)


## Выполняет изолированную операцию своей подсистемы и возвращает результат согласно контракту.
static func load(game: Node) -> bool:
	return load_at(game, SAVE_PATH)
