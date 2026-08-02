extends RefCounted

const SAVE_PATH := "user://farm-save.json"

static func snapshot(game: Node) -> Dictionary:
	var plot_data := []
	for cell in game.plots:
		var plot: Dictionary = game.plots[cell]
		plot_data.append({"x":cell.x,"y":cell.y,"tilled":plot.tilled,"planted":plot.planted,"watered":plot.watered,"growth":plot.growth,"stage":plot.stage})
	return {"version":1,"player":[game.player.x,game.player.y],"location":game.current_location,"day":game.day,"minutes":game.game_minutes,"energy":game.energy,"coins":game.coins,"xp":game.player_xp,"level":game.player_level,"hp":game.player_hp,"counts":game.export_inventory_counts().duplicate(true),"slots":game.inventory_slots.duplicate(true),"hotbar":game.hotbar_slots.duplicate(true),"equipment":game.equipment.duplicate(true),"quest_active":game.quest_active,"quest_complete":game.quest_complete,"weapons":{"sword":game.sword_crafted,"bow":game.has_bow,"crystal":game.has_crystal_sword,"equipped":game.equipped_weapon},"plots":plot_data,"resource_hits":game.resource_nodes.map(func(node): return node.hits),"food_active":game.food_nodes.map(func(node): return node.active)}

static func apply(game: Node, data: Dictionary) -> bool:
	if data.get("version", 0) != 1: return false
	game.player = Vector2(data.player[0], data.player[1]); game.current_location = data.location
	game.day = data.day; game.game_minutes = data.minutes; game.energy = data.energy; game.coins = data.coins
	game.player_xp = data.xp; game.player_level = data.level; game.player_hp = data.hp
	game.import_inventory_counts(data.counts); game.inventory_slots.assign(data.slots); game.hotbar_slots.assign(data.hotbar)
	game.equipment = data.equipment.duplicate(true); game.quest_active = data.quest_active; game.quest_complete = data.quest_complete
	game.sword_crafted = data.weapons.sword; game.has_bow = data.weapons.bow; game.has_crystal_sword = data.weapons.crystal; game.equipped_weapon = data.weapons.equipped
	for saved_plot in data.plots:
		var cell := Vector2i(saved_plot.x, saved_plot.y)
		if game.plots.has(cell):
			var plot: Dictionary = game.plots[cell]
			for key in ["tilled","planted","watered","growth","stage"]: plot[key] = saved_plot[key]
			game.plots[cell] = plot
	for index in mini(data.resource_hits.size(), game.resource_nodes.size()): game.resource_nodes[index].hits = data.resource_hits[index]
	for index in mini(data.food_active.size(), game.food_nodes.size()): game.food_nodes[index].active = data.food_active[index]
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
