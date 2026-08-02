extends RefCounted

static func update(game: Node, delta: float) -> void:
	for cell in game.plots:
		var plot: Dictionary = game.plots[cell]
		if plot.stage_flash > 0.0: plot.stage_flash = maxf(plot.stage_flash - delta, 0.0)
		if plot.planted and plot.watered and plot.growth < game.GROWTH_DURATION:
			var previous_stage: int = plot.stage
			plot.growth = minf(plot.growth + delta, game.GROWTH_DURATION)
			plot.stage = mini(int(plot.growth / game.STAGE_DURATION), 4)
			if plot.stage > previous_stage:
				plot.stage_flash = 0.7
				if plot.stage == 2:
					plot.watered = false; game.message = "Земля подсохла — морковь просит второй полив"
				if plot.stage >= 4: game.message = "Морковь созрела — собери её руками [4]"
		game.plots[cell] = plot
