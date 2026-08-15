extends RefCounted

const VillageLayoutSystem := preload("res://scripts/systems/village_layout_system.gd")

const CELL_SIZE := 48
const OUTDOOR_LOCATIONS := ["overworld", "forest", "rocky", "ruins", "cursed", "glassworks", "moon_glade"]
const BLOCKED_NAVIGATION_REASONS := ["boundary", "building", "biome_prop", "event_prop", "cave_prop", "scenic_prop", "tree", "fence", "player_fence", "world_prop", "water", "ship", "guardian", "hazard", "resource", "loot", "forage", "village_event", "interior", "furniture", "storage", "debug_obstacle"]
const COMMON_FINDS := [["stone", 1, 3], ["fiber", 1, 2], ["bones", 1, 2], ["metal", 1, 1]]
const UNCOMMON_FINDS := [["crystal", 1, 2], ["red_crystal", 1, 1], ["green_crystal", 1, 1], ["pirate_doubloon", 1, 2]]
const POTION_FINDS := [["healing_potion", 1, 1], ["mana_potion", 1, 1], ["energy_potion", 1, 1], ["regeneration_potion", 1, 1]]
const TREASURE_FINDS := [["crystal_ring", 1, 1], ["rare_seeds", 1, 2], ["herb_seeds", 1, 2], ["strawberry_seeds", 1, 2]]


## Создаёт пустое состояние грядки в том же формате, который использует старая ферма.
static func empty_plot(location: String, cell: Vector2i) -> Dictionary:
	return {"location":location, "cell":cell, "tilled":false, "planted":false, "watered":false, "growth":0.0, "stage":0, "stage_flash":0.0, "crop_kind":"carrot"}


## Возвращает стабильный строковый ключ мировой грядки для сохранений и словаря состояния.
static func plot_key(location: String, cell: Vector2i) -> String:
	return "%s:%d:%d" % [location, cell.x, cell.y]


## Привязывает мировую позицию к модульной фермерской сетке 48×48.
static func cell_at(position: Vector2) -> Vector2i:
	return Vector2i(floori(position.x / CELL_SIZE), floori(position.y / CELL_SIZE))


## Возвращает мировой прямоугольник фермерской клетки без дробных координат.
static func cell_rect(cell: Vector2i) -> Rect2:
	return Rect2(Vector2(cell * CELL_SIZE), Vector2(CELL_SIZE, CELL_SIZE))


## Определяет клетку перед героем и сохраняет совместимость со старым участком у дома.
static func target(game: Node) -> Dictionary:
	var target_position: Vector2 = game.player + game.facing.normalized() * 42.0
	var legacy_cell: Vector2i = game.targeted_plot()
	if game.current_location == "overworld" and game.valid_plot(legacy_cell):
		return {"valid":true, "legacy":true, "cell":legacy_cell, "rect":game.FarmVisualSystem.plot_rect(Vector2(game.FARM_ORIGIN), legacy_cell), "reason":"legacy_plot"}
	var cell := cell_at(target_position)
	var reason := tillability_reason(game, game.current_location, cell)
	return {"valid":reason == "tillable", "legacy":false, "cell":cell, "key":plot_key(game.current_location, cell), "rect":cell_rect(cell), "reason":reason}


## Создаёт соседнюю цель для пакетной обработки, не смешивая домашнюю и мировую сетки.
static func offset_target(game: Node, origin: Dictionary, offset: Vector2i) -> Dictionary:
	var cell: Vector2i = Vector2i(origin.cell) + offset
	if bool(origin.get("legacy", false)):
		var valid: bool = game.valid_plot(cell)
		return {"valid":valid, "legacy":true, "cell":cell, "rect":game.FarmVisualSystem.plot_rect(Vector2(game.FARM_ORIGIN), cell), "reason":"legacy_plot" if valid else "boundary"}
	var reason := tillability_reason(game, game.current_location, cell)
	return {"valid":reason == "tillable", "legacy":false, "cell":cell, "key":plot_key(game.current_location, cell), "rect":cell_rect(cell), "reason":reason}


## Объясняет, разрешено ли обрабатывать клетку, не изменяя мир и инвентарь.
static func tillability_reason(game: Node, location: String, cell: Vector2i) -> String:
	if location not in OUTDOOR_LOCATIONS:
		return "location_blocked"
	var rect := cell_rect(cell)
	if rect.position.x < 40.0 or rect.position.y < 120.0 or rect.end.x > game.WORLD_SIZE.x - 40.0 or rect.end.y > game.WORLD_SIZE.y - 80.0:
		return "boundary"
	if location == "overworld":
		if VillageLayoutSystem.is_on_bridge(rect.get_center(), CELL_SIZE * 0.4):
			return "bridge"
		if VillageLayoutSystem.is_road_or_path(rect.get_center()):
			return "paved_road"
	var sample_points := [rect.get_center(), rect.position + Vector2(9, 9), rect.position + Vector2(rect.size.x - 9, 9), rect.end - Vector2(9, 9), rect.position + Vector2(9, rect.size.y - 9)]
	for point in sample_points:
		var navigation_reason: String = game.NavigationSystem.walkability_reason(game, point)
		if navigation_reason in BLOCKED_NAVIGATION_REASONS:
			return navigation_reason
	return "tillable"


## Возвращает грядку выбранной цели или новое пустое состояние для ещё не обработанной земли.
static func read_target(game: Node, target_data: Dictionary) -> Dictionary:
	if bool(target_data.get("legacy", false)):
		return game.plots.get(target_data.cell, empty_plot("overworld", target_data.cell))
	return game.state.world.world_plots.get(String(target_data.key), empty_plot(game.current_location, target_data.cell))


## Записывает изменённую грядку в старый участок или в свободный слой текущей локации.
static func write_target(game: Node, target_data: Dictionary, plot: Dictionary) -> void:
	if bool(target_data.get("legacy", false)):
		game.plots[target_data.cell] = plot
	elif bool(target_data.get("valid", false)):
		game.state.world.world_plots[String(target_data.key)] = plot


## Вскапывает разрешённую клетку, начисляет ремесленный опыт и один раз проверяет тайник.
static func till(game: Node, target_data: Dictionary, plot: Dictionary) -> bool:
	return _till_one(game, target_data, plot, true)


## Обрабатывает шаблон мотыги 1, 3 или 9 клеток и оплачивает действие одним масштабируемым расходом энергии.
static func till_pattern(game: Node, origin: Dictionary) -> int:
	var offsets: Array[Vector2i] = game.TalentSystem.tilling_offsets(game)
	var energy_cost := 1 if offsets.size() == 1 else (2 if offsets.size() == 3 else 3)
	if game.energy < energy_cost:
		game.message = game.LocaleSystem.text("no_energy")
		return 0
	var changed := 0
	var found_names: Array[String] = []
	for offset in offsets:
		var target_data := offset_target(game, origin, offset)
		if not bool(target_data.get("valid", false)):
			continue
		var plot := read_target(game, target_data)
		var before_counts: Dictionary = game.export_inventory_counts()
		if _till_one(game, target_data, plot, false):
			write_target(game, target_data, plot)
			changed += 1
			for kind in game.export_inventory_counts():
				if int(game.inventory_item_count(kind)) > int(before_counts.get(kind, 0)):
					found_names.append(game.inventory_item_name(kind))
	if changed <= 0:
		game.message = game.LocaleSystem.text("already_tilled") if bool(origin.get("valid", false)) else blocked_message(game, String(origin.get("reason", "location_blocked")))
		return 0
	game.energy -= energy_cost
	game.award_xp(maxi(1, ceili(float(changed) / 3.0)), "Вспашка")
	game.message = "Вскопано клеток: %d%s" % [changed, " • найдено: %s" % ", ".join(found_names) if not found_names.is_empty() else ""]
	game.notify_tutorial("wide_tilling" if changed >= 3 else "free_farming")
	return changed


## Вскапывает одну проверенную клетку; пакетный режим отдельно оплачивает общую энергию.
static func _till_one(game: Node, target_data: Dictionary, plot: Dictionary, consume_energy: bool) -> bool:
	if not bool(target_data.get("valid", false)):
		game.message = blocked_message(game, String(target_data.get("reason", "location_blocked")))
		return false
	if bool(plot.get("tilled", false)):
		game.message = game.LocaleSystem.text("already_tilled")
		return false
	plot.tilled = true
	if consume_energy:
		game.energy -= 1
	game.SkillSystem.award_profession_xp(game, "farming", 1)
	var found := buried_find(game.world_loot_seed, game.current_location, target_data.cell)
	if found.is_empty():
		game.message = game.LocaleSystem.text("soil_ready")
	else:
		game.change_inventory_count(String(found.kind), int(found.count))
		game.message = game.LocaleSystem.text("buried_found", [game.inventory_item_name(String(found.kind)), int(found.count)])
		game.notify_tutorial("buried_loot")
	game.notify_tutorial("free_farming")
	return true


## Возвращает локализованное объяснение запрета обработки конкретного типа поверхности.
static func blocked_message(game: Node, reason: String) -> String:
	if reason == "location_blocked": return game.LocaleSystem.text("farming_outdoors_only")
	if reason in ["paved_road", "bridge"]: return game.LocaleSystem.text("cannot_till_road")
	return game.LocaleSystem.text("cannot_till_here")


## Детерминированно вычисляет редкую находку, чтобы перезагрузка не меняла содержимое клетки.
static func buried_find(seed_value: int, location: String, cell: Vector2i) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = abs(seed_value ^ location.hash() ^ (cell.x * 73856093) ^ (cell.y * 19349663))
	var roll := rng.randi_range(0, 9999)
	var table: Array = []
	if roll < 900: table = COMMON_FINDS
	elif roll < 1180: table = UNCOMMON_FINDS
	elif roll < 1245: table = POTION_FINDS
	elif roll < 1260: table = TREASURE_FINDS
	if table.is_empty(): return {}
	var entry: Array = table[rng.randi_range(0, table.size() - 1)]
	var count := rng.randi_range(int(entry[1]), int(entry[2]))
	return {"kind":String(entry[0]), "count":count, "tier":"treasure" if table == TREASURE_FINDS else ("potion" if table == POTION_FINDS else ("uncommon" if table == UNCOMMON_FINDS else "common"))}


## Сериализует свободные участки в JSON-совместимый массив без Variant-координат.
static func snapshot(game: Node) -> Array:
	var result := []
	for key in game.state.world.world_plots:
		var plot: Dictionary = game.state.world.world_plots[key]
		var cell: Vector2i = plot.cell
		result.append({"location":plot.location, "x":cell.x, "y":cell.y, "tilled":plot.tilled, "planted":plot.planted, "watered":plot.watered, "growth":plot.growth, "stage":plot.stage, "crop_kind":plot.get("crop_kind", "carrot")})
	return result


## Восстанавливает только допустимые мировые грядки и безопасно пропускает старые сохранения.
static func restore(game: Node, saved_plots: Array) -> void:
	game.state.world.world_plots.clear()
	for saved in saved_plots:
		var location := String(saved.get("location", ""))
		var cell := Vector2i(int(saved.get("x", -1)), int(saved.get("y", -1)))
		if location not in OUTDOOR_LOCATIONS: continue
		var rect := cell_rect(cell)
		if rect.position.x < 0.0 or rect.position.y < 0.0 or rect.end.x > game.WORLD_SIZE.x or rect.end.y > game.WORLD_SIZE.y: continue
		var plot := empty_plot(location, cell)
		for property in ["tilled", "planted", "watered", "growth", "stage"]:
			plot[property] = saved.get(property, plot[property])
		var crop_kind := String(saved.get("crop_kind", "carrot"))
		plot.crop_kind = crop_kind if game.CropCatalogSystem.CROPS.has(crop_kind) else "carrot"
		game.state.world.world_plots[plot_key(location, cell)] = plot
