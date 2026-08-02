extends RefCounted

const SAVE_PATH := "user://farm-save.json"

static func snapshot(game: Node) -> Dictionary:
	var plot_data := []
	var drops := []
	var wildlife := []
	for cell in game.plots:
		var plot: Dictionary = game.plots[cell]
		plot_data.append({"x":cell.x,"y":cell.y,"tilled":plot.tilled,"planted":plot.planted,"watered":plot.watered,"growth":plot.growth,"stage":plot.stage})
	for item in game.dropped_items:
		drops.append({"kind":item.kind,"count":item.count,"position":[item.position.x,item.position.y]})
	for animal in game.wildlife_nodes:
		wildlife.append({"hp":animal.hp,"alive":animal.alive,"position":[animal.position.x,animal.position.y]})
	return {"version":1,"player":[game.player.x,game.player.y],"location":game.current_location,"day":game.day,"minutes":game.game_minutes,"energy":game.energy,"coins":game.coins,"xp":game.player_xp,"level":game.player_level,"hp":game.player_hp,"counts":game.export_inventory_counts().duplicate(true),"slots":game.inventory_slots.duplicate(true),"hotbar":game.hotbar_slots.duplicate(true),"equipment":game.equipment.duplicate(true),"quest_active":game.quest_active,"quest_complete":game.quest_complete,"missions":game.mission_states.duplicate(true),"tutorial":{"step":game.tutorial_step,"events":game.tutorial_events_completed.duplicate(true),"seen":game.seen_discoveries.duplicate(true)},"weapons":{"sword":game.sword_crafted,"bow":game.has_bow,"crystal":game.has_crystal_sword,"equipped":game.equipped_weapon},"plots":plot_data,"resource_hits":game.resource_nodes.map(func(node): return node.hits),"food_active":game.food_nodes.map(func(node): return node.active),"enemies":game.enemy_nodes.map(func(enemy): return {"hp":enemy.hp,"alive":enemy.alive}),"wildlife":wildlife,"drops":drops}

static func apply(game: Node, data: Dictionary) -> bool:
	if data.get("version", 0) != 1: return false
	game.player = Vector2(data.player[0], data.player[1]); game.current_location = data.location
	game.day = data.day; game.game_minutes = data.minutes; game.energy = data.energy; game.coins = data.coins
	game.player_xp = data.xp; game.player_level = data.level; game.player_hp = data.hp
	game.import_inventory_counts(data.counts)
	var inventory_catalog: Array = game.inventory_slots.duplicate()
	game.inventory_slots.assign(data.slots)
	for kind in inventory_catalog:
		if not kind.is_empty() and not game.inventory_slots.has(kind):
			game.inventory_slots.append(kind)
	while game.inventory_slots.size() < inventory_catalog.size():
		game.inventory_slots.append("")
	game.hotbar_slots.assign(data.hotbar)
	game.equipment = data.equipment.duplicate(true); game.quest_active = data.quest_active; game.quest_complete = data.quest_complete
	game.mission_states = data.get("missions", game.mission_states).duplicate(true)
	var tutorial: Dictionary = data.get("tutorial", {})
	game.tutorial_step = tutorial.get("step", game.tutorial_step)
	game.tutorial_events_completed = tutorial.get("events", {}).duplicate(true)
	game.seen_discoveries = tutorial.get("seen", {}).duplicate(true)
	game.sword_crafted = data.weapons.sword; game.has_bow = data.weapons.bow; game.has_crystal_sword = data.weapons.crystal; game.equipped_weapon = data.weapons.equipped
	for saved_plot in data.plots:
		var cell := Vector2i(saved_plot.x, saved_plot.y)
		if game.plots.has(cell):
			var plot: Dictionary = game.plots[cell]
			for key in ["tilled","planted","watered","growth","stage"]: plot[key] = saved_plot[key]
			game.plots[cell] = plot
	for index in mini(data.resource_hits.size(), game.resource_nodes.size()): game.resource_nodes[index].hits = data.resource_hits[index]
	for index in mini(data.food_active.size(), game.food_nodes.size()): game.food_nodes[index].active = data.food_active[index]
	for index in mini(data.get("enemies",[]).size(), game.enemy_nodes.size()):
		game.enemy_nodes[index].hp = data.enemies[index].hp; game.enemy_nodes[index].alive = data.enemies[index].alive
	for index in mini(data.get("wildlife",[]).size(), game.wildlife_nodes.size()):
		game.wildlife_nodes[index].hp = data.wildlife[index].hp
		game.wildlife_nodes[index].alive = data.wildlife[index].alive
		game.wildlife_nodes[index].position = Vector2(data.wildlife[index].position[0], data.wildlife[index].position[1])
	game.dropped_items.clear()
	for item in data.get("drops", []):
		game.dropped_items.append({"kind":item.kind,"count":item.count,"position":Vector2(item.position[0],item.position[1])})
	game.InventorySystem.recalculate_stats(game); game.player_hp = mini(game.player_hp, game.player_max_hp)
	game.sync_background_location(); game.update_camera(); return true

static func save(game: Node) -> bool:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if not file: return false
	file.store_string(JSON.stringify(snapshot(game))); return true

static func load(game: Node) -> bool:
	if not FileAccess.file_exists(SAVE_PATH): return false
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	var data = JSON.parse_string(file.get_as_text())
	return data is Dictionary and apply(game, data)
