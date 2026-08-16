class_name WorldMapRenderer
extends RefCounted

const UiKitSystem := preload("res://scripts/systems/ui_kit_system.gd")

const WINDOW := Rect2(38, 30, 1076, 588)
const TITLE_RIBBON := Rect2(326, 42, 500, 58)
const CONTENT := Rect2(62, 154, 1028, 440)
const CLOSE_BUTTON := Rect2(1050, 44, 48, 48)
const TAB_RECTS := [Rect2(66, 106, 198, 42), Rect2(270, 106, 198, 42), Rect2(474, 106, 198, 42), Rect2(678, 106, 198, 42), Rect2(882, 106, 198, 42)]
const MAP_BACKGROUND := preload("res://assets/game/ui/world_map_storybook.png")
const PAGE_LABEL_KEYS := ["guide_map", "guide_calendar", "guide_bestiary", "guide_collections", "guide_recipes"]
const PAGE_ICONS := ["⌖", "☀", "⚔", "★", "◇"]


## Рисует единую энциклопедию мира и выбранную вкладку поверх затемнённой живой локации.
static func draw(game: Node2D) -> void:
	if not game.world_map_open: return
	game.draw_rect(Rect2(0, 0, 1152, 648), Color(0.01, 0.015, 0.01, 0.74))
	UiKitSystem.draw_panel(game, WINDOW)
	UiKitSystem.draw_nine_patch(game, "quest_ribbon", TITLE_RIBBON)
	game.draw_ui_string(game.UI_FONT, TITLE_RIBBON.position + Vector2(24, 39), game.LocaleSystem.ui("world_guide"), HORIZONTAL_ALIGNMENT_CENTER, TITLE_RIBBON.size.x - 48, 19, UiKitSystem.COLORS.text_light)
	game.draw_texture_rect(UiKitSystem.texture("close_button"), CLOSE_BUTTON, false)
	game.draw_ui_string(game.UI_FONT, CLOSE_BUTTON.position + Vector2(7, 34), "×", HORIZONTAL_ALIGNMENT_CENTER, CLOSE_BUTTON.size.x - 14, 24, Color("fff0cf"))
	draw_tabs(game)
	match game.world_guide_page:
		0: draw_map(game)
		1: draw_calendar(game)
		2: draw_bestiary(game)
		3: draw_collections(game)
		_: draw_recipes(game)


## Рисует пять вкладок с внутренним фокусом, сохраняя общие hit-зоны для указателя.
static func draw_tabs(game: Node2D) -> void:
	for index in TAB_RECTS.size():
		var rect: Rect2 = TAB_RECTS[index]
		UiKitSystem.draw_nine_patch(game, "tab_selected" if index == game.world_guide_page else "tab_normal", rect)
		game.draw_ui_string(game.UI_FONT, rect.position + Vector2(10, 28), "%s  %s" % [PAGE_ICONS[index], game.LocaleSystem.ui(PAGE_LABEL_KEYS[index])], HORIZONTAL_ALIGNMENT_CENTER, rect.size.x - 20, 10, Color("fff0cf"))


## Возвращает индекс вкладки под указателем либо минус один.
static func page_at(point: Vector2) -> int:
	for index in TAB_RECTS.size():
		if TAB_RECTS[index].has_point(point): return index
	return -1


## Рисует художественную карту долины, открытые регионы, цель и локальную сводку справа.
static func draw_map(game: Node2D) -> void:
	UiKitSystem.draw_panel(game, CONTENT, false)
	var map_rect := Rect2(82, 174, 744, 392)
	game.draw_texture_rect(MAP_BACKGROUND, map_rect, false)
	game.draw_rect(map_rect, Color(0.02, 0.05, 0.04, 0.10), true)
	var current: String = game.WorldMapSystem.current_region(game)
	var objective: String = game.WorldMapSystem.objective_region(game)
	for location in game.WorldMapSystem.LOCATIONS:
		var source_position: Vector2 = game.WorldMapSystem.LOCATIONS[location]
		var position := map_rect.position + Vector2((source_position.x - 118.0) / 916.0 * map_rect.size.x, (source_position.y - 112.0) / 418.0 * map_rect.size.y)
		var discovered: bool = location in game.state.world.estate.discovered
		var color := Color("efc766") if location == current else (Color("d4825b") if location == objective else (Color("8fcf9e") if discovered else Color("52615b")))
		game.draw_circle(position, 12.0, Color("172822")); game.draw_circle(position, 8.0, color)
		var label: String = game.WorldSystem.name(location) if discovered else game.LocaleSystem.ui("map_unknown")
		game.draw_rect(Rect2(position + Vector2(-58, 14), Vector2(116, 18)), Color(0.025, 0.055, 0.045, 0.82), true)
		game.draw_ui_string(game.UI_FONT, position + Vector2(-56, 28), label, HORIZONTAL_ALIGNMENT_CENTER, 112, 8, Color("f8f1dc"))
	UiKitSystem.draw_nine_patch(game, "tooltip", Rect2(838, 174, 232, 392))
	game.draw_ui_string(game.UI_FONT, Vector2(858, 207), game.LocaleSystem.location(current), HORIZONTAL_ALIGNMENT_LEFT, 192, 16, UiKitSystem.COLORS.ink)
	var weather: String = game.WorldEventSystem.location_weather(game.day, current)
	game.draw_texture_rect(game.InterfaceRenderer.weather_icon(weather), Rect2(858, 222, 52, 52), false)
	game.draw_ui_string(game.UI_FONT, Vector2(920, 251), game.LocaleSystem.ui("season_" + game.WorldEventSystem.season(game.day)), HORIZONTAL_ALIGNMENT_LEFT, 130, 12, Color("67452e"))
	game.draw_ui_string(game.UI_FONT, Vector2(858, 306), game.LocaleSystem.ui("map_legend"), HORIZONTAL_ALIGNMENT_LEFT, 192, 9, Color("765239"))
	game.draw_multiline_string(game.UI_FONT, Vector2(858, 356), game.LocaleSystem.ui("map_close"), HORIZONTAL_ALIGNMENT_LEFT, 190, 10, 4, Color("765239"))


## Рисует прогноз на семь дней и сезонную ленту из двадцати восьми календарных ячеек.
static func draw_calendar(game: Node2D) -> void:
	UiKitSystem.draw_panel(game, CONTENT, false)
	game.draw_ui_string(game.UI_FONT, Vector2(88, 190), game.LocaleSystem.ui("guide_week_forecast"), HORIZONTAL_ALIGNMENT_LEFT, 420, 15, Color("fff0cf"))
	for offset in 7:
		var day: int = game.day + offset
		var rect := Rect2(82 + offset * 141, 204, 131, 174)
		UiKitSystem.draw_nine_patch(game, "tooltip", rect)
		game.draw_ui_string(game.UI_FONT, rect.position + Vector2(10, 27), game.LocaleSystem.ui("day_short", [day]), HORIZONTAL_ALIGNMENT_CENTER, 111, 11, UiKitSystem.COLORS.ink)
		var weather: String = game.WorldEventSystem.location_weather(day, game.WorldMapSystem.current_region(game))
		game.draw_texture_rect(game.InterfaceRenderer.weather_icon(weather), Rect2(rect.position + Vector2(40, 38), Vector2(52, 52)), false)
		game.draw_ui_string(game.UI_FONT, rect.position + Vector2(10, 110), game.LocaleSystem.ui("weather_" + weather), HORIZONTAL_ALIGNMENT_CENTER, 111, 10, UiKitSystem.COLORS.ink)
		game.draw_ui_string(game.UI_FONT, rect.position + Vector2(10, 131), game.LocaleSystem.ui("season_" + game.WorldEventSystem.season(day)), HORIZONTAL_ALIGNMENT_CENTER, 111, 9, Color("735239"))
		var event_name: String = ["РЫНОК", "ПРАЗДНИК", "ПУТНИК", "НАБЕГ"][posmod(day - 1, 4)]
		game.draw_rect(Rect2(rect.position + Vector2(18, 143), Vector2(95, 22)), Color("eed59e"), true)
		game.draw_ui_string(game.UI_FONT, rect.position + Vector2(20, 159), event_name, HORIZONTAL_ALIGNMENT_CENTER, 91, 7, Color("68432a"))
	game.draw_ui_string(game.UI_FONT, Vector2(88, 408), game.LocaleSystem.ui("guide_valley_year"), HORIZONTAL_ALIGNMENT_LEFT, 360, 12, Color("fff0cf"))
	for index in 28:
		var rect := Rect2(82 + (index % 14) * 70.5, 422 + (index / 14) * 58, 62, 50)
		UiKitSystem.draw_nine_patch(game, "tooltip", rect)
		var current: bool = index + 1 == game.day
		if current: game.draw_rect(rect.grow(-6), Color(1.0, 0.67, 0.16, 0.28))
		game.draw_ui_string(game.UI_FONT, rect.position + Vector2(5, 20), "%d" % (index + 1), HORIZONTAL_ALIGNMENT_CENTER, 52, 9, Color("55331f"))
		var season: String = game.WorldEventSystem.season(index + 1)
		game.draw_ui_string(game.UI_FONT, rect.position + Vector2(5, 38), game.LocaleSystem.ui("season_" + season).left(3).to_upper(), HORIZONTAL_ALIGNMENT_CENTER, 52, 7, Color("795538"))


## Рисует девять семейств врагов с характеристиками, уровневым диапазоном и образцами добычи.
static func draw_bestiary(game: Node2D) -> void:
	UiKitSystem.draw_panel(game, CONTENT, false)
	var kinds: Array = game.CombatSystem.TYPES.keys()
	for index in kinds.size():
		var kind := String(kinds[index])
		var rect := Rect2(82 + (index % 3) * 333, 174 + (index / 3) * 132, 318, 116)
		UiKitSystem.draw_nine_patch(game, "tooltip", rect)
		var known: bool = game.WorldMapSystem.bestiary_discovered(game, kind)
		if not known: game.draw_rect(rect.grow(-8), Color(0.12, 0.10, 0.08, 0.48))
		var data: Dictionary = game.CombatSystem.TYPES[kind]
		if known: draw_enemy_portrait(game, kind, Rect2(rect.position + Vector2(10, 19), Vector2(74, 74)))
		game.draw_ui_string(game.UI_FONT, rect.position + Vector2(88, 28), String(data.name) if known else game.LocaleSystem.ui("guide_unknown_enemy"), HORIZONTAL_ALIGNMENT_LEFT, 210, 11, UiKitSystem.COLORS.ink if known else Color("725f4d"))
		game.draw_ui_string(game.UI_FONT, rect.position + Vector2(88, 49), "УР. 1–5  •  HP %d  •  УРОН %d" % [data.hp, data.damage], HORIZONTAL_ALIGNMENT_LEFT, 210, 8, Color("765239") if known else Color("8f7c66"))
		if known:
			var loot_kinds: Array = data.loot.keys()
			for loot_index in mini(2, loot_kinds.size()):
				var icon_rect := UiKitSystem.draw_slot(game, Rect2(rect.position + Vector2(210 + loot_index * 45, 62), Vector2(40, 40)), false)
				game.draw_item_icon(String(loot_kinds[loot_index]), icon_rect)
		game.draw_ui_string(game.UI_FONT, rect.position + Vector2(88, 83), "+%d XP" % int(data.xp) if known else game.LocaleSystem.ui("guide_find_enemy"), HORIZONTAL_ALIGNMENT_LEFT, 118, 8, Color("9a672e") if known else Color("725f4d"))


## Рисует нейтральный портрет семейства из того же атласа, который используется живым противником.
static func draw_enemy_portrait(game: Node2D, kind: String, rect: Rect2) -> void:
	if kind in game.EnemyAnimationLibrary.CORE_FAMILIES or kind in game.EnemyAnimationLibrary.PIRATE_FAMILIES:
		var source: Rect2 = game.EnemyAnimationLibrary.source_rect(kind, Vector2.DOWN, 1)
		game.draw_texture_rect_region(game.EnemyAnimationLibrary.walk_texture(kind), rect, source)
		return
	var column: int = maxi(0, game.CombatSystem.FAMILY_ORDER.find(kind))
	var cell_size := Vector2(game.ENEMY_RANK_ATLAS.get_width() / 5.0, game.ENEMY_RANK_ATLAS.get_height() / 3.0)
	game.draw_texture_rect_region(game.ENEMY_RANK_ATLAS, rect, Rect2(Vector2(column, 0) * cell_size, cell_size))


## Рисует коллекцию рыб, рекорды размера и условия ещё не встреченных видов.
static func draw_collections(game: Node2D) -> void:
	UiKitSystem.draw_panel(game, CONTENT, false)
	var caught: int = game.state.fishing.best_sizes.size()
	game.draw_ui_string(game.UI_FONT, Vector2(86, 190), "%s  •  %d/%d" % [game.LocaleSystem.ui("guide_fish_collection"), caught, game.FishingSystem.FISH_CATALOG.size()], HORIZONTAL_ALIGNMENT_LEFT, 600, 14, Color("fff0cf"))
	for index in game.FishingSystem.FISH_CATALOG.size():
		var fish: Dictionary = game.FishingSystem.FISH_CATALOG[index]
		var rect := Rect2(82 + (index % 4) * 249, 204 + (index / 4) * 120, 234, 104)
		UiKitSystem.draw_panel(game, rect, false)
		var record := int(game.state.fishing.best_sizes.get(fish.id, 0))
		var catch_count := int(game.state.fishing.catch_counts.get(fish.id, 0)); var best_quality := String(game.state.fishing.best_qualities.get(fish.id, "normal"))
		var icon_rect := UiKitSystem.draw_slot(game, Rect2(rect.position + Vector2(12, 18), Vector2(64, 64)), record > 0)
		game.draw_item_icon("fish", icon_rect)
		game.draw_ui_string(game.UI_FONT, rect.position + Vector2(84, 33), game.LocaleSystem.text(String(fish.name_key)) if record > 0 else "???", HORIZONTAL_ALIGNMENT_LEFT, 136, 11, Color("fff0cf"))
		game.draw_ui_string(game.UI_FONT, rect.position + Vector2(84, 57), game.LocaleSystem.ui("guide_record", [record]) if record > 0 else game.LocaleSystem.ui("guide_not_caught"), HORIZONTAL_ALIGNMENT_LEFT, 136, 8, Color("d0a85f") if record > 0 else Color("9b8a70"))
		var seasons: Array = fish.get("seasons", [])
		var condition_parts: Array[String] = []
		for season in seasons: condition_parts.append(game.LocaleSystem.ui("season_" + String(season)).left(3).to_upper())
		var condition := " • ".join(condition_parts); var habitat_text: String = condition if not condition.is_empty() else game.LocaleSystem.ui("guide_all_year")
		var detail_text: String = game.LocaleSystem.text("fish_collection_stats", [catch_count, game.LocaleSystem.text("quality_" + best_quality)]) + " • " + habitat_text if record > 0 else habitat_text
		game.draw_ui_string(game.UI_FONT, rect.position + Vector2(84, 79), detail_text, HORIZONTAL_ALIGNMENT_LEFT, 136, 7, Color("bca57c"))


## Рисует прокручиваемый справочник рецептов и подробности выбранного результата без возможности крафта.
static func draw_recipes(game: Node2D) -> void:
	UiKitSystem.draw_panel(game, CONTENT, false)
	var selected := clampi(game.world_guide_selected, 0, game.CraftingSystem.RECIPES.size() - 1)
	game.world_guide_selected = selected
	var first := clampi(selected - 4, 0, maxi(0, game.CraftingSystem.RECIPES.size() - 9))
	for visible_index in 9:
		var recipe_index := first + visible_index
		if recipe_index >= game.CraftingSystem.RECIPES.size(): break
		var recipe: Dictionary = game.CraftingSystem.RECIPES[recipe_index]
		var rect := recipe_row_rect(visible_index)
		UiKitSystem.draw_button(game, rect, recipe_index == selected, true, game.settings_state.reduced_motion, Time.get_ticks_msec())
		game.draw_item_icon(String(recipe.output), Rect2(rect.position + Vector2(12, 5), Vector2(34, 34)))
		game.draw_ui_string(game.UI_FONT, rect.position + Vector2(54, 28), game.inventory_item_name(String(recipe.output)), HORIZONTAL_ALIGNMENT_LEFT, 310, 11, UiKitSystem.COLORS.ink)
	var recipe: Dictionary = game.CraftingSystem.RECIPES[selected]
	UiKitSystem.draw_nine_patch(game, "tooltip", Rect2(548, 174, 522, 392))
	var icon_rect := UiKitSystem.draw_slot(game, Rect2(718, 194, 180, 180), false)
	game.draw_item_icon(String(recipe.output), icon_rect)
	game.draw_ui_string(game.UI_FONT, Vector2(582, 403), game.inventory_item_name(String(recipe.output)), HORIZONTAL_ALIGNMENT_CENTER, 454, 18, UiKitSystem.COLORS.ink)
	game.draw_multiline_string(game.UI_FONT, Vector2(588, 448), game.CraftingSystem.ingredients_text(game, recipe), HORIZONTAL_ALIGNMENT_CENTER, 442, 11, 4, Color("694a33"))
	var unlocked: bool = game.TalentSystem.recipe_unlocked(game, recipe)
	game.draw_ui_string(game.UI_FONT, Vector2(588, 526), game.LocaleSystem.ui("guide_recipe_open") if unlocked else game.LocaleSystem.ui("guide_recipe_locked"), HORIZONTAL_ALIGNMENT_CENTER, 442, 11, Color("66804c") if unlocked else Color("a83f2a"))


## Возвращает область видимой строки справочника рецептов.
static func recipe_row_rect(visible_index: int) -> Rect2:
	return Rect2(82, 174 + visible_index * 43, 450, 39)


## Возвращает экранную область фактического рецепта внутри текущего прокрученного окна.
static func recipe_rect_for_index(game: Node, recipe_index: int) -> Rect2:
	var selected := clampi(game.world_guide_selected, 0, game.CraftingSystem.RECIPES.size() - 1)
	var first := clampi(selected - 4, 0, maxi(0, game.CraftingSystem.RECIPES.size() - 9))
	return recipe_row_rect(recipe_index - first)


## Находит фактический индекс рецепта под указателем с учётом текущего окна прокрутки.
static func recipe_at(game: Node, point: Vector2) -> int:
	var selected := clampi(game.world_guide_selected, 0, game.CraftingSystem.RECIPES.size() - 1)
	var first := clampi(selected - 4, 0, maxi(0, game.CraftingSystem.RECIPES.size() - 9))
	for visible_index in 9:
		if recipe_row_rect(visible_index).has_point(point): return first + visible_index
	return -1
