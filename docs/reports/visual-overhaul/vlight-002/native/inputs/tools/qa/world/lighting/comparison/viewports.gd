extends RefCounted

const Scenarios := preload("res://tools/qa/world/lighting/comparison/scenarios.gd")
const Fixture := preload("res://tools/qa/world/lighting/comparison/fixture.gd")
const Observer := preload("res://tools/qa/world/lighting/inventory_game.gd")
const Cases := preload("res://tools/qa/world/lighting/inventory_cases.gd")


## Настоящие разные render targets отделяют владельца источника от глобального состояния.
static func capture(tree: SceneTree, output: String, size: Vector2i) -> Dictionary:
	var surface := Control.new()
	tree.root.add_child(surface)
	var views: Array[SubViewport] = []
	var worlds: Array[Fixture] = []
	var huds: Array[Observer] = []
	for index: int in 2:
		var view := SubViewport.new()
		view.size = size if index == 0 else Vector2i(960, 540)
		view.disable_3d = true
		view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		surface.add_child(view)
		views.append(view)
		var world := Scenarios.create(view, false) as Fixture
		var hud := Scenarios.create(view, true)
		worlds.append(world)
		huds.append(hud)
		Scenarios.configure(world, hud, "west-lamp" if index == 0 else "home", 1320)
		var picture := TextureRect.new()
		picture.position = Vector2(index * size.x / 2.0, 40)
		picture.size = Vector2(size.x / 2.0, size.y - 40)
		picture.texture = view.get_texture()
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		surface.add_child(picture)
		var label := Label.new()
		label.position = Vector2(index * size.x / 2.0 + 12, 10)
		label.text = "Улица · local light" if index == 0 else "Дом · local light"
		surface.add_child(label)
	var records: Dictionary = {}
	for mode: String in ["both-local", "left-off", "right-off"]:
		for index: int in 2:
			worlds[index].configure_light(
				"off" if mode == ("left-off" if index == 0 else "right-off") else "local"
			)
			await Scenarios.redraw(tree, worlds[index], huds[index], 8)
		var items: Array[Dictionary] = []
		for index: int in 2:
			var before := Scenarios.state(worlds[index], huds[index])
			await Scenarios.redraw(tree, worlds[index], huds[index], 2)
			var image := views[index].get_texture().get_image()
			var filename := "viewport-" + mode + "-" + str(index) + ".png"
			var error := image.save_png(output.path_join(filename))
			items.append(
				{
					"file": filename,
					"size": [image.get_width(), image.get_height()],
					"before": before,
					"after": Scenarios.state(worlds[index], huds[index]),
					"light": worlds[index].light_state(),
					"png_error": error
				}
			)
		var filename := "viewport-" + mode + ".png"
		var composite := tree.root.get_texture().get_image()
		var error := composite.save_png(output.path_join(filename))
		records[mode] = {"items": items, "composite": filename, "png_error": error}
	surface.queue_free()
	await tree.process_frame
	return records
