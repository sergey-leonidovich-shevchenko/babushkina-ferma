extends RefCounted

const CameraPoints := preload("res://tools/qa/camera/visual_camera_points.gd")
const ExistingCases := preload("res://tools/qa/world/lighting/inventory_cases.gd")
const Fixture := preload("res://tools/qa/world/lighting/comparison/fixture.gd")
const ExistingObserver := preload("res://tools/qa/world/lighting/inventory_game.gd")


## Создаёт прежнюю main-сцену с тем же seed; HUD получает собственный CanvasLayer.
static func create(parent: Node, layer: bool) -> ExistingObserver:
	var scene := CameraPoints.create_game()
	scene.set_script(ExistingObserver if layer else Fixture)
	var instance := scene as ExistingObserver
	instance.world_loot_seed = CameraPoints.SEED
	if layer:
		var canvas := CanvasLayer.new()
		canvas.layer = 2
		parent.add_child(canvas)
		canvas.add_child(instance)
		instance.hud_only = true
		var background := instance.get_node("WorldBackground") as CanvasItem
		background.visible = false
	else:
		parent.add_child(instance)
		var fixture := instance as Fixture
		fixture.install()
	return instance


## Применяет одинаковую существующую конфигурацию к миру и HUD, не двигая симуляцию.
static func configure(world: Fixture, hud: ExistingObserver, room: String, minute: int) -> void:
	for item: ExistingObserver in [world, hud]:
		ExistingCases.configure(item, room, minute)
		item.settings_state.vsync_enabled = false
	var background := hud.get_node("WorldBackground") as CanvasItem
	background.visible = false
	world.configure_light("off")


## Считывание производится после фактического draw; для времени этот метод не читает PNG.
static func redraw(
	tree: SceneTree, world: ExistingObserver, hud: ExistingObserver, count: int
) -> void:
	for index: int in count:
		world.queue_redraw()
		hud.queue_redraw()
		await tree.process_frame
		await RenderingServer.frame_post_draw


## Полные сохраняемые данные обоих экземпляров сравниваются до/после каждого прохода.
static func state(world: Fixture, hud: ExistingObserver) -> Dictionary:
	return {
		"world": world.SaveSystem.snapshot(world),
		"hud": hud.SaveSystem.snapshot(hud),
		"world_context": ExistingCases.snapshot(world, "comparison"),
		"hud_context": ExistingCases.snapshot(hud, "comparison")
	}


## Сохраняет все wall-frame/CPU samples без readback и фильтрации медленных кадров.
static func measure(tree: SceneTree, world: Fixture, hud: ExistingObserver) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for room: String in ["west-lamp", "home"]:
		configure(world, hud, room, 1320)
		for repeat: int in 3:
			var order: Array[String] = ["off", "mask", "local", "shadow"]
			if repeat == 1:
				order.reverse()
			elif repeat == 2:
				order = ["local", "off", "shadow", "mask"]
			for mode: String in order:
				world.configure_light(mode)
				await redraw(tree, world, hud, 30)
				var before := state(world, hud)
				world.draw_microseconds.clear()
				world.measure_draw = true
				var samples: Array[Dictionary] = []
				var previous := Time.get_ticks_usec()
				for index: int in 90:
					await redraw(tree, world, hud, 1)
					var now := Time.get_ticks_usec()
					samples.append(
						{
							"tick_us": now,
							"process_frame": Engine.get_process_frames(),
							"engine_max_fps": Engine.max_fps,
							"vsync_mode": DisplayServer.window_get_vsync_mode(),
							"frame_us": now - previous,
							"focused": DisplayServer.window_is_focused(),
							"visible": tree.root.visible,
							"window":
							[DisplayServer.window_get_size().x, DisplayServer.window_get_size().y],
							"draw_calls":
							Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
						}
					)
					previous = now
				world.measure_draw = false
				rows.append(
					{
						"room": room,
						"mode": mode,
						"repeat": repeat,
						"warmup_frames": 30,
						"sample_frames": 90,
						"before": before,
						"after": state(world, hud),
						"samples": samples,
						"draw_us": world.draw_microseconds.duplicate(),
						"light": world.light_state()
					}
				)
	return rows
