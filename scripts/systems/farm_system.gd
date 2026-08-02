extends RefCounted

## Выполняет изолированную операцию своей подсистемы и возвращает результат согласно контракту.
static func update(game: Node, delta: float) -> void:
	for cell in game.plots:
		var plot: Dictionary = game.plots[cell]
		if plot.stage_flash > 0.0: plot.stage_flash = maxf(plot.stage_flash - delta, 0.0)
		if plot.planted and plot.watered and plot.growth < game.GROWTH_DURATION:
			var previous_stage: int = plot.stage
			plot.growth = minf(plot.growth + delta * game.WorldEventSystem.crop_growth_multiplier(game), game.GROWTH_DURATION)
			plot.stage = mini(int(plot.growth / game.STAGE_DURATION), 4)
			if plot.stage > previous_stage:
				plot.stage_flash = 0.7
				if plot.stage == 2:
					plot.watered = false; game.message = game.LocaleSystem.text("dry_crop")
				if plot.stage >= 4: game.message = game.LocaleSystem.text("crop_ready")
		game.plots[cell] = plot
