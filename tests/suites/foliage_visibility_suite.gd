extends RefCounted

const Review := preload("res://tests/helpers/foliage_visibility_scenario.gd")
const Wind := Review.Wind


## Проверяет консервативные bounds, все четыре края, реальные проходы и повторное использование target.
static func run(context: SceneTree) -> void:
	var game := Review.Scenario.create(context)
	var rows := Wind.placements()
	context.expect(rows.size() == 8, "visibility keeps the existing eight plants")
	for row in rows:
		context.expect(row.rect.grow(Wind.Batch.PAD).encloses(Review.swept_rect(row)), "wind plus maximum contact fit output slot: " + row.kind)
		var mesh: ArrayMesh = Wind.Batch.UV.make_mesh(Wind.Batch.UV.mesh_data(row.kind, 72.0 / 362.0))
		var aabb := mesh.custom_aabb
		var bounds := Rect2(Vector2(aabb.position.x, aabb.position.y) + row.anchor, Vector2(aabb.size.x, aabb.size.y))
		context.expect(bounds.encloses(Review.swept_rect(row)), "mesh custom AABB contains every bounded deformation: " + row.kind)
		# Fractional cameras just outside/inside each real screen edge exercise actual production selection.
		for direction in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
			for fraction in [-0.25, 0.0, 0.25]:
				var view_start: Vector2 = row.rect.position - Vector2(480, 270)
				if direction == Vector2.LEFT: view_start.x = row.rect.end.x - fraction
				elif direction == Vector2.RIGHT: view_start.x = row.rect.position.x - 960 + fraction
				elif direction == Vector2.UP: view_start.y = row.rect.end.y - fraction
				else: view_start.y = row.rect.position.y - 540 + fraction
				game.camera_offset = view_start
				Wind.update(game)
				context.expect(game.get_node(Wind.NAME).visible_rows.has(rows.find(row)), "swept edge is never culled: " + str(direction) + "/" + str(fraction))
	var routes := Review.routes(game)
	context.expect(routes.size() == 6, "six walkable native routes exist")
	for route in routes:
		if route.get("camera_only", false): continue
		Review.place(game, route)
		for index in Review.FRAMES: Review.advance(game, route.direction)
		context.expect(game.player.distance_to(route.start + route.direction * Review.TRAVEL) < 0.01, "actual physics traverses full route: " + route.id)
		context.expect(Wind.statistics(game).builds == 1, "crossing does not rebuild targets: " + route.id)
	var saved: Dictionary = game.SaveSystem.snapshot(game)
	var owner: Node = game.get_node(Wind.NAME)
	var target_id: int = owner.batch.viewport.get_instance_id()
	for mode in ["offscreen", "low", "normal", "offscreen", "normal"]:
		game.camera_offset = Vector2(-4000, -4000) if mode == "offscreen" else rows[6].anchor - Vector2(480, 270)
		game.set_meta(Wind.QUALITY, "low" if mode == "low" else "normal")
		Wind.update(game)
		context.expect(owner.batch.viewport.get_instance_id() == target_id and owner.mesh_builds == 1, "target reused: " + mode)
		context.expect(game.SaveSystem.snapshot(game) == saved, "visibility/quality does not modify save: " + mode)
		if mode != "normal":
			context.expect(owner.visible_rows.is_empty() and owner.batch.viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED and owner.recovery.entries.is_empty(), "inactive mode stops work and clears recovery: " + mode)
	game.free()
