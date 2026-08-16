extends RefCounted

## Рисует все локальные и свободно размещённые грядки текущей локации.
static func draw(game: Node2D) -> void:
	if game.current_location == "overworld":
		for cell in game.plots:
			var plot: Dictionary = game.plots[cell]
			var rect: Rect2 = game.FarmVisualSystem.plot_rect(Vector2(game.FARM_ORIGIN), cell)
			draw_plot(game, rect, plot)
	for key in game.state.world.world_plots:
		var plot: Dictionary = game.state.world.world_plots[key]
		if String(plot.location) == game.current_location:
			draw_plot(game, game.WorldFarmingSystem.cell_rect(plot.cell), plot)
	var cultivation_target: Dictionary = game.WorldFarmingSystem.target(game)
	if bool(cultivation_target.valid) or bool(cultivation_target.legacy):
		game.draw_rect(cultivation_target.rect, Color("fff3a6"), false, 3)

## Рисует землю и состояние одной грядки независимо от её локации.
static func draw_plot(game: Node2D, rect: Rect2, plot: Dictionary) -> void:
	game.draw_texture_rect_region(game.FarmVisualSystem.ATLAS, rect, game.FarmVisualSystem.soil_source(plot))
	if not plot.planted:
		return
	draw_crop(game, rect, plot)
	draw_crop_progress(game, rect, plot)
	var crop_kind: String = String(plot.get("crop_kind", "carrot"))
	if not game.CropCatalogSystem.grows_in_season(crop_kind, game.WorldEventSystem.season(game.day)) and plot.growth < game.GROWTH_DURATION:
		draw_season_pause_icon(game, rect.position + Vector2(rect.size.x - 7, 3))
	elif not plot.watered and plot.growth < game.GROWTH_DURATION:
		draw_water_needed_icon(game, rect.position + Vector2(8, 4))

## Рисует текущую стадию культуры с короткой анимацией перехода роста.
static func draw_crop(game: Node2D, rect: Rect2, plot: Dictionary) -> void:
	var stage: int = plot.stage
	var crop_kind: String = String(plot.get("crop_kind", "carrot"))
	var season: String = game.WorldEventSystem.season(game.day)
	var flash: float = plot.stage_flash
	var center := rect.get_center()
	if flash > 0.0:
		game.draw_circle(center - Vector2(0, 8), 20.0 * flash, Color(1.0, 0.91, 0.38, flash * 0.35), false, 3.0)
	var pixel_bounce := roundf(sin(flash * 18.0) * flash * 3.0)
	var destination := Rect2(rect.position + Vector2(0, -pixel_bounce), rect.size)
	game.draw_texture_rect_region(game.FarmVisualSystem.crop_texture(crop_kind), destination, game.FarmVisualSystem.crop_source(stage, crop_kind, season))

## Рисует сегментированный прогресс роста либо значок готового урожая.
static func draw_crop_progress(game: Node2D, rect: Rect2, plot: Dictionary) -> void:
	var progress: float = clampf(plot.growth / game.GROWTH_DURATION, 0.0, 1.0)
	var bar := Rect2(rect.position + Vector2(3, -10), Vector2(rect.size.x - 6, 7))
	if progress >= 1.0:
		var icon_center := rect.position + Vector2(rect.size.x - 5, -7)
		game.draw_colored_polygon(PackedVector2Array([
			icon_center + Vector2(0, -10),
			icon_center + Vector2(10, 0),
			icon_center + Vector2(0, 10),
			icon_center + Vector2(-10, 0),
		]), Color("ffd45c"))
		game.draw_polyline(PackedVector2Array([
			icon_center + Vector2(-5, 0),
			icon_center + Vector2(-1, 4),
			icon_center + Vector2(6, -5),
		]), Color("28583b"), 3.0)
		return
	game.draw_rect(bar, Color("243b35"))
	var fill_color := Color("7aa6c5") if game.WorldEventSystem.season(game.day) == "winter" else Color("e58b3e").lerp(Color("6fcb62"), progress)
	game.draw_rect(Rect2(bar.position + Vector2(1, 1), Vector2((bar.size.x - 2) * progress, bar.size.y - 2)), fill_color)
	for marker in range(1, 4):
		var marker_x := bar.position.x + bar.size.x * marker / 4.0
		game.draw_line(Vector2(marker_x, bar.position.y), Vector2(marker_x, bar.end.y), Color("f7e4b0"), 1.5)

## Рисует сезонные часы над культурой, рост которой приостановлен погодой.
static func draw_season_pause_icon(game: Node2D, center: Vector2) -> void:
	var color := Color("f4dda0")
	game.draw_circle(center, 8.0, Color("3b4c42"))
	game.draw_circle(center, 7.0, color, false, 2.0)
	game.draw_line(center, center + Vector2(0, -4), color, 2.0)
	game.draw_line(center, center + Vector2(4, 2), color, 2.0)
	game.draw_circle(center, 2.0, Color("8db9d5"))

## Рисует пульсирующую красную каплю над культурой, которой требуется полив.
static func draw_water_needed_icon(game: Node2D, center: Vector2) -> void:
	var pulse := 1.0 + sin(Time.get_ticks_msec() / 130.0) * 0.08
	var points := PackedVector2Array([
		center + Vector2(0, -9) * pulse,
		center + Vector2(7, 1) * pulse,
		center + Vector2(5, 7) * pulse,
		center + Vector2(0, 10) * pulse,
		center + Vector2(-5, 7) * pulse,
		center + Vector2(-7, 1) * pulse,
	])
	game.draw_colored_polygon(points, Color("e4473f"))
	game.draw_circle(center + Vector2(-2, 2), 2.0, Color("ffaaa0"))
