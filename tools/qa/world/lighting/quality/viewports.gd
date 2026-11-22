extends RefCounted

const Cases := preload("res://tools/qa/world/lighting/quality/cases.gd")
const Fixture := preload("res://tools/qa/world/lighting/quality/game.gd")


## Два настоящих framebuffer независимо меняют low/off и возвращаются к точному standard.
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
		Cases.configure(game, Cases.ENTRIES[2 if index == 0 else 5])
	var result: Dictionary = {}
	for step: String in ["standard", "first-low", "second-off", "restored"]:
		if step == "first-low":
			Cases.mode(games[0], "low", false)
		elif step == "second-off":
			Cases.mode(games[1], "off", false)
		elif step == "restored":
			for game: Fixture in games:
				Cases.mode(game, "standard", false)
		var rows: Array[Dictionary] = []
		for index: int in 2:
			var game := games[index]
			await Cases.redraw(tree, game, 6)
			var before := Cases.state(game, false)
			var image := views[index].get_texture().get_image()
			var filename := "twin-" + step + "-" + str(index) + ".png"
			(
				rows
				. append(
					{
						"file": filename,
						"png_error": image.save_png(output.path_join(filename)),
						"size": [image.get_width(), image.get_height()],
						"before": before,
						"after": Cases.state(game, false),
					}
				)
			)
		result[step] = rows
	host.queue_free()
	await tree.process_frame
	return result
