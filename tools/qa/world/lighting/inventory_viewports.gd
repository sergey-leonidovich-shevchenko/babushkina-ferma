extends RefCounted

const Cases := preload("res://tools/qa/world/lighting/inventory_cases.gd")
const Points := preload("res://tools/qa/camera/visual_camera_points.gd")
const Observer := preload("res://tools/qa/world/lighting/inventory_game.gd")
const Context := preload("res://scripts/presentation/viewport_world_context.gd")
const Probe := preload("res://tools/qa/world/lighting/light_probe.gd")


## Проверяет оба направления изоляции при разных сценах, часах и размерах render target.
static func capture(tree: SceneTree, output: String, size: Vector2i) -> Dictionary:
	var surface := Control.new()
	tree.root.add_child(surface)
	var views: Array[SubViewport] = []
	var games: Array[Observer] = []
	for index: int in 2:
		var view := SubViewport.new()
		view.size = size if index == 0 else Vector2i(960, 540)
		view.disable_3d = true
		view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		surface.add_child(view)
		views.append(view)
		var game := Cases.create_game(view)
		games.append(game)
		Cases.configure(game, "west-lamp" if index == 0 else "home", 1320 if index == 0 else 720)
		var picture := TextureRect.new()
		picture.position = Vector2(index * size.x / 2.0, 48)
		picture.size = Vector2(size.x / 2.0, size.y - 48)
		picture.texture = view.get_texture()
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		surface.add_child(picture)
		var label := Label.new()
		label.position = Vector2(index * size.x / 2.0 + 12, 10)
		label.text = "Улица · ночь" if index == 0 else "Дом · день"
		surface.add_child(label)
	await Cases.settle(tree, games, 700)
	var records: Dictionary = {}
	var failures: Array[String] = []
	for mode: String in ["both-on", "west-off", "home-off"]:
		for index: int in 2:
			games[index].set_meta(
				"qa_light_inventory_off", mode == ("west-off" if index == 0 else "home-off")
			)
		await Cases.redraw(tree, games, 4)
		var before: Array[Dictionary] = []
		var snapshots: Array[Dictionary] = []
		for game: Observer in games:
			before.append(game.SaveSystem.snapshot(game))
			snapshots.append(Cases.snapshot(game, "viewport"))
			game.draw_records.clear()
			game.observe_draw = true
			game.observe_lights = true
		await Cases.redraw(tree, games, 2)
		var states: Array[Dictionary] = []
		for index: int in 2:
			var game: Observer = games[index]
			game.observe_draw = false
			game.observe_lights = false
			var after: Dictionary = game.SaveSystem.snapshot(game)
			var image := views[index].get_texture().get_image()
			var filename := "viewport-" + mode + "-" + str(index) + ".png"
			if before[index] != after or image.save_png(output.path_join(filename)) != OK:
				failures.append(filename + ": viewport state/image failed")
			states.append(
				{
					"file": filename,
					"size": Points.pair(image.get_size()),
					"owner": Context.read(game),
					"before": before[index],
					"after": after,
					"snapshot": snapshots[index],
					"snapshot_after": Cases.snapshot(game, "viewport"),
					"draws": game.draw_records.duplicate(true),
					"calls": game.light_calls.duplicate(true),
					"off": Probe.is_off(game)
				}
			)
		var composite := root_image(tree)
		var composite_file := "viewport-" + mode + ".png"
		if composite.save_png(output.path_join(composite_file)) != OK:
			failures.append(composite_file + ": composite failed")
		records[mode] = {"states": states, "composite": composite_file}
	surface.queue_free()
	await tree.process_frame
	return {"records": records, "failures": failures}


## Читает настоящий root framebuffer; синтетическая сборка двух изображений не используется.
static func root_image(tree: SceneTree) -> Image:
	return tree.root.get_texture().get_image()
