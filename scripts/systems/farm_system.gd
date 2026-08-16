extends RefCounted

## Выполняет изолированную операцию своей подсистемы и возвращает результат согласно контракту.
static func update(game: Node, delta: float) -> void:
	for cell in game.plots:
		var plot: Dictionary = game.plots[cell]
		update_plot(game, plot, delta)
		game.plots[cell] = plot
	for key in game.state.world.world_plots:
		var plot: Dictionary = game.state.world.world_plots[key]
		update_plot(game, plot, delta)
		game.state.world.world_plots[key] = plot


## Обновляет одну культуру независимо от того, находится она на домашнем или мировом участке.
static func update_plot(game: Node, plot: Dictionary, delta: float) -> void:
	if plot.stage_flash > 0.0: plot.stage_flash = maxf(plot.stage_flash - delta, 0.0)
	var crop_kind: String = String(plot.get("crop_kind", "carrot"))
	var current_season: String = game.WorldEventSystem.season(game.day)
	var growth_duration: float = game.CropCatalogSystem.growth_duration(crop_kind)
	var stage_duration: float = game.CropCatalogSystem.stage_duration(crop_kind)
	if plot.planted and plot.watered and plot.growth < growth_duration and game.CropCatalogSystem.grows_in_season(crop_kind, current_season):
		var previous_stage: int = plot.stage
		var previous_growth: float = float(plot.growth)
		var next_growth := minf(previous_growth + delta * game.WorldEventSystem.crop_growth_multiplier(game) * game.EstateSystem.crop_multiplier(game), growth_duration)
		var watering_threshold := growth_duration * 0.5
		var crossed_watering_threshold := previous_growth < watering_threshold and next_growth >= watering_threshold
		plot.growth = watering_threshold if crossed_watering_threshold else next_growth
		plot.stage = mini(int(plot.growth / stage_duration), 4)
		if plot.stage > previous_stage:
			plot.stage_flash = 0.7
			if crossed_watering_threshold:
				plot.watered = false; game.message = game.LocaleSystem.text("dry_crop")
			if plot.stage >= 4:
				var harvest_kind: String = String(game.CropCatalogSystem.data(crop_kind).harvest)
				game.message = game.LocaleSystem.text("crop_ready", [game.inventory_item_name(harvest_kind)])


## Возвращает выбранный на панели мешок семян, сохраняя морковь как совместимый вариант по умолчанию.
static func selected_seed_kind(game: Node) -> String:
	var held_kind: String = String(game.hotbar_slots[game.selected_hotbar]) if game.selected_hotbar >= 0 and game.selected_hotbar < game.hotbar_slots.size() else ""
	return held_kind if not game.CropCatalogSystem.crop_for_seed(held_kind).is_empty() else "seeds"


## Сажает выбранный сорт в подготовленную грядку и записывает его в постоянное состояние участка.
static func plant(game: Node, plot: Dictionary) -> bool:
	var seed_kind := selected_seed_kind(game)
	var crop_kind: String = game.CropCatalogSystem.crop_for_seed(seed_kind)
	if not plot.tilled or plot.planted:
		game.message = game.LocaleSystem.text("till_first")
		return false
	if game.inventory_item_count(seed_kind) <= 0:
		game.message = game.LocaleSystem.text("no_seeds")
		return false
	if not game.TalentSystem.can_plant_crop(game, crop_kind):
		game.message = "Эта культура откроется в ветке «Редкие культуры»"
		return false
	if not game.CropCatalogSystem.grows_in_season(crop_kind, game.WorldEventSystem.season(game.day)):
		game.message = game.LocaleSystem.text("crop_out_of_season")
		return false
	plot.planted = true
	plot.crop_kind = crop_kind
	plot.growth = 0.0
	plot.stage = 0
	plot.stage_flash = 0.0
	game.change_inventory_count(seed_kind, -1)
	game.energy -= 1
	game.award_xp(1, "Посадка: %s" % game.inventory_item_name(seed_kind))
	game.SkillSystem.award_profession_xp(game, "farming", 2)
	game.message = game.LocaleSystem.text("crop_planted", [game.inventory_item_name(seed_kind)])
	game.notify_tutorial("plant")
	if crop_kind != "carrot": game.notify_tutorial("crop_variety")
	return true


## Собирает урожай указанного сорта, а многолетник переводит в повторный цикл без пересадки.
static func harvest(game: Node, plot: Dictionary) -> bool:
	var crop_kind: String = String(plot.get("crop_kind", "carrot"))
	var growth_duration: float = game.CropCatalogSystem.growth_duration(crop_kind)
	if not plot.planted or float(plot.growth) < growth_duration:
		game.message = game.LocaleSystem.text("not_ripe")
		return false
	if not game.CropCatalogSystem.grows_in_season(crop_kind, game.WorldEventSystem.season(game.day)):
		game.message = game.LocaleSystem.text("crop_out_of_season")
		return false
	var crop_data: Dictionary = game.CropCatalogSystem.data(crop_kind)
	var harvest_kind: String = String(crop_data.harvest)
	var harvested: int = game.CropCatalogSystem.harvest_count(game, crop_kind)
	game.change_inventory_count(harvest_kind, harvested)
	var quality: String = game.EstateSystem.record_quality(game, harvest_kind, harvested)
	if game.CropCatalogSystem.is_perennial(crop_kind):
		plot.planted = true
		plot.growth = growth_duration - game.CropCatalogSystem.regrow_duration(crop_kind)
		plot.stage = mini(int(plot.growth / game.CropCatalogSystem.stage_duration(crop_kind)), 3)
		game.notify_tutorial("perennial_crop")
	else:
		plot.planted = false
		plot.growth = 0.0
		plot.stage = 0
	plot.tilled = true
	plot.watered = false
	plot.stage_flash = 0.0
	var experience: int = game.CropCatalogSystem.harvest_xp(crop_kind)
	game.award_xp(experience, "Урожай: %s" % game.inventory_item_name(harvest_kind))
	game.SkillSystem.award_profession_xp(game, "farming", experience + 1)
	game.message = "%s • %s" % [game.LocaleSystem.text("harvested", [game.inventory_item_name(harvest_kind), harvested]), game.LocaleSystem.ui("quality_%s" % quality)]
	game.notify_tutorial("harvest")
	return true
