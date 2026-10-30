extends RefCounted
const Recovery := preload("res://scripts/presentation/foliage_recovery.gd")
const Wind := preload("res://scripts/presentation/foliage_wind.gd")
const Contact := Wind.Contact
const Points := preload("res://tools/qa/camera/visual_camera_points.gd")


## Проверяет частотную независимость экспоненты, отсутствие перелёта, предел памяти, удаление хвостов и реальные сбросы сцены.
static func run(ctx: SceneTree) -> void:
	_sign_reversal(ctx)
	for hz in [30, 60, 120]:
		var state := Recovery.new()
		var desired := Contact.empty()
		desired[6] = Vector2(3, 1)
		ctx.expect(
			state.sample(desired, [6], 0)[6] == Vector2.ZERO, "new contact starts without a snap"
		)
		var previous := Vector2.ZERO
		for tick in range(1, hz + 1):
			var value := state.sample(desired, [6], float(tick) / hz)[6]
			var expected := desired[6] * (1.0 - exp(-float(tick) / hz / Recovery.ATTACK))
			ctx.expect(
				(
					value.distance_to(expected) < 0.000004
					and value.length() >= previous.length()
					and value.length() <= desired[6].length() + 0.000001
				),
				"analytic attack is monotonic and independent of render frequency"
			)
			previous = value
		desired[6] = Vector2.ZERO
		var start := previous
		for tick in range(1, hz * 2 + 1):
			var value := state.sample(desired, [6], 1.0 + float(tick) / hz)[6]
			var expected := start * exp(-float(tick) / hz / Recovery.RELEASE)
			ctx.expect(
				(
					value.length() <= previous.length() + 0.000001
					and value.distance_to(expected) < Recovery.EPSILON + 0.000004
				),
				"recovery decays smoothly with a subpixel cleanup threshold"
			)
			previous = value
		ctx.expect(
			state.entries.is_empty() and previous == Vector2.ZERO,
			"settled entries are removed, not retained at tiny values"
		)
	var state := Recovery.new()
	var desired := Contact.empty()
	var slots := []
	for i in Recovery.LIMIT:
		slots.append(i)
		desired[i] = Vector2(4, 0)
	state.sample(desired, slots, 0)
	state.sample(desired, slots, 1)
	ctx.expect(
		state.entries.size() == Recovery.LIMIT, "active numerical state has an explicit hard limit"
	)
	var frozen := state.sample(desired, slots, 1)
	for i in 300:
		ctx.expect(
			state.sample(desired, slots, 1) == frozen,
			"repeated draw cannot integrate the same physical tick twice"
		)
	state.sample(desired, [6], 1)
	ctx.expect(
		state.entries.size() == 1, "culled slots are immediately released even at frozen time"
	)
	state.sample(desired, [], 1)
	ctx.expect(state.entries.is_empty(), "offscreen state returns to baseline")
	for bad in [NAN, INF, -1.0]:
		ctx.expect(
			state.sample(desired, slots, bad) == Contact.empty() and state.entries.is_empty(),
			"invalid clocks clear all transient state"
		)
	state.sample(desired, slots, 2)
	state.sample(desired, slots, 3)
	ctx.expect(
		state.sample(desired, slots, 0) == Contact.empty() and state.entries.is_empty(),
		"clock rewind cannot reuse the old displacement"
	)
	for bad in [Vector2.INF, Vector2(NAN, 0), Vector2(100, 0)]:
		desired[6] = bad
		state.sample(desired, [6], 0)
		ctx.expect(
			state.sample(desired, [6], 1)[6] == Vector2.ZERO,
			"nonfinite or excessive targets cannot reach a shader"
		)
	ctx.expect(
		(
			state.sample(desired, [-1], 2) == Contact.empty()
			and state.sample(desired, [64], 2) == Contact.empty()
			and state.sample(PackedVector2Array(), [], 2) == Contact.empty()
		),
		"invalid slots or buffers cannot expand the active set"
	)
	_scene(ctx)


## Проверяет точный ноль между противоположными целями: память и следующий шаг должны продолжить движение.
static func _sign_reversal(ctx: SceneTree) -> void:
	var half_time := Recovery.ATTACK * log(2.0)
	for direction in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
		var state := Recovery.new()
		var desired := Contact.empty()
		desired[6] = direction * 2.0
		state.sample(desired, [6], 0.0)
		var before := state.sample(desired, [6], half_time)[6]
		ctx.expect(
			before == direction and state.entries.size() == 1,
			"reversal starts with a real stored displacement"
		)
		desired[6] = -direction
		var zero := state.sample(desired, [6], 2.0 * half_time)[6]
		ctx.expect(
			zero == Vector2.ZERO and not state.entries.has(6),
			"exact zero removes the stale opposite displacement"
		)
		var after := state.sample(desired, [6], 3.0 * half_time)[6]
		ctx.expect(
			after == -direction * 0.5 and state.entries.size() == 1,
			"next physical interval advances beyond zero"
		)
		ctx.expect(state.entries[6] == after, "stored state matches the visible post-zero output")
		ctx.expect(
			state.sample(desired, [6], 4.0 * half_time)[6] == -direction * 0.75,
			"subsequent interval keeps converging to the opposite target"
		)


## Применяет настоящий ввод и коллизии; проверяет паузу, четыре подхода, остановку, перенос, доступность и полный save.
static func _scene(ctx: SceneTree) -> void:
	var game := Points.create_game()
	ctx.root.add_child(game)
	Points.configure(game, Points.registry().points[0])
	game.WorkshopSystem.state(game, "pottery")
	game.settings_state.reduced_motion = false
	game.set_meta(&"camera_reference_zoom", 1.2)
	var anchor: Vector2 = Wind.placements()[6].anchor
	for direction in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		game.player = anchor + direction * 16
		Contact.Pose.reset(game)
		game.clear_movement_keys()
		game._physics_process(1.0 / 60)
		Contact.Pose.present(game, 1)
		game.camera_offset = Vector2(1464, 378)
		Wind.update(game)
		var owner := game.get_node(Wind.NAME)
		owner.recovery.clear()
		Wind.update(game)
		ctx.expect(
			owner.render_contacts == Contact.empty(), "each independent approach has a soft onset"
		)
		for tick in 12:
			game._physics_process(1.0 / 60)
			Contact.Pose.present(game, 1)
			game.camera_offset = Vector2(1464, 378)
			Wind.update(game)
		ctx.expect(
			(
				owner.render_contacts[6].dot(-direction) > 0
				and owner.render_contacts[6].length() < owner.last_contacts[6].length()
			),
			"all four approaches bend away with no overshoot"
		)
		var saved: Dictionary = game.SaveSystem.snapshot(game)
		var frozen: PackedVector2Array = owner.render_contacts.duplicate()
		var stats := Wind.statistics(game)
		game.menu_state.pause_open = true
		for tick in 6:
			game._physics_process(1.0 / 60)
			Wind.update(game)
		ctx.expect(
			(
				owner.render_contacts == frozen
				and Wind.statistics(game) == stats
				and game.SaveSystem.snapshot(game) == saved
			),
			"pause freezes every filtered value and GPU counters without clock debt"
		)
		game.menu_state.pause_open = false
		game.move_left_held = direction.x < 0
		game.move_right_held = direction.x > 0
		game.move_up_held = direction.y < 0
		game.move_down_held = direction.y > 0
		for tick in 14:
			game._physics_process(1.0 / 60)
			Contact.Pose.present(game, 1)
			game.camera_offset = Vector2(1464, 378)
			Wind.update(game)
		ctx.expect(
			(
				owner.last_contacts[6] == Vector2.ZERO
				and owner.render_contacts[6].length() > Recovery.EPSILON
			),
			"after leaving the radius the plant retains only a short recovery tail"
		)
		game.clear_movement_keys()
		for tick in 100:
			game._physics_process(1.0 / 60)
			game.camera_offset = Vector2(1464, 378)
			Wind.update(game)
		ctx.expect(
			owner.recovery.entries.is_empty() and owner.render_contacts == Contact.empty(),
			"after settling every active entry returns to baseline"
		)
	var owner := game.get_node(Wind.NAME)
	for mode in [
		"offscreen", "low", "reduced", "jump", "rewind", "contact-off", "rollback", "invalid-frame"
	]:
		game.settings_state.reduced_motion = false
		game.set_meta(Wind.QUALITY, "normal")
		game.set_meta(Contact.FLAG, true)
		game.set_meta(Recovery.FLAG, true)
		game.player = anchor - Vector2(16, 0)
		Contact.Pose.reset(game)
		game.clear_movement_keys()
		for tick in 12:
			game._physics_process(1.0 / 60)
			game.camera_offset = Vector2(1464, 378)
			Wind.update(game)
		ctx.expect(
			not owner.recovery.entries.is_empty(), "fixture has an actual live recovery entry"
		)
		if mode == "offscreen":
			game.camera_offset = Vector2(-8000, -8000)
		elif mode == "low":
			game.set_meta(Wind.QUALITY, "low")
		elif mode == "reduced":
			game.settings_state.reduced_motion = true
		elif mode == "jump":
			game.player += Vector2(500, 0)
			Contact.Frame.publish(game, 1.0 / 60)
		elif mode == "rewind":
			game.set_meta(Wind.Clock.META, 0.0)
			Contact.Frame.publish(game, 1.0 / 60)
		elif mode == "contact-off":
			game.set_meta(Contact.FLAG, false)
		elif mode == "rollback":
			game.set_meta(Recovery.FLAG, false)
		else:
			game.remove_meta(Contact.Frame.META)
		Wind.update(game)
		ctx.expect(owner.recovery.entries.is_empty(), "state is discarded immediately: " + mode)
		ctx.expect(
			(
				owner.render_contacts == owner.last_contacts
				if mode == "rollback"
				else owner.render_contacts == Contact.empty()
			),
			"reset or technical rollback uploads the correct numerical buffer"
		)
	ctx.expect(
		owner.mesh_builds == 1 and owner.batch.groups.size() == 2,
		"soft recovery reuses the same atlas and two groups"
	)
	game.set_meta(Recovery.FLAG, true)
	game.change_inventory_count(Points.Teleport.KIND, 1)
	ctx.expect(
		Points.Teleport.open(game) and Points.Teleport.travel(game, "forest"),
		"real QA transfer succeeds"
	)
	Wind.update(game)
	ctx.expect(owner.recovery.entries.is_empty(), "real map transfer clears the recovery owner")
	game.free()
