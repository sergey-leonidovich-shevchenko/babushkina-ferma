extends RefCounted

const Cases := preload("res://tools/qa/world/lighting/daycycle/scenarios.gd")
const Fixture := preload("res://tools/qa/world/lighting/daycycle/game.gd")


## Разные часы и размеры двух настоящих миров не разделяют цвет или временный откат.
static func capture(tree: SceneTree, output: String) -> Dictionary:
	var host := Node.new()
	tree.root.add_child(host)
	var views: Array[SubViewport] = []
	var games: Array[Fixture] = []
	for index: int in 2:
		var view := SubViewport.new()
		view.size = Vector2i(1152, 648) if index == 0 else Vector2i(960, 540)
		view.disable_3d = true
		view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		host.add_child(view)
		views.append(view)
		var game := Cases.create(view)
		games.append(game)
		Cases.configure(game, Cases.CASES[2] if index == 0 else Cases.CASES[1])
	var result: Dictionary = {}
	for step: String in ["both", "first-legacy", "second-night"]:
		if step == "first-legacy":
			Cases.mode(games[0], "legacy")
		elif step == "second-night":
			games[1].game_minutes = 1320.0
		for game: Fixture in games:
			await Cases.redraw(tree, game, 4)
		var rows: Array[Dictionary] = []
		for index: int in 2:
			var game := games[index]
			var before := Cases.state(game)
			await Cases.redraw(tree, game, 2)
			var image := views[index].get_texture().get_image()
			var filename := "twin-" + step + "-" + str(index) + ".png"
			var error := image.save_png(output.path_join(filename))
			(
				rows
				. append(
					{
						"file": filename,
						"before": before,
						"after": Cases.state(game),
						"size": [image.get_width(), image.get_height()],
						"png_error": error,
					}
				)
			)
		result[step] = rows
	host.queue_free()
	await tree.process_frame
	return result
