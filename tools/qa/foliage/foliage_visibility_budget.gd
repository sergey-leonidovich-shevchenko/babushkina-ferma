extends RefCounted

const Review := preload("res://tests/helpers/foliage_visibility_scenario.gd")
const Wind := Review.Wind

class CalibrationCards extends Node2D:
	## Известные0/1/2 перекрытия независимо калибруют additive readback перед измерением meshes.
	func _draw() -> void:
		draw_rect(Rect2(0, 0, 32, 32), Color.WHITE)
		draw_rect(Rect2(16, 16, 32, 32), Color.WHITE)


## Заменяет только fragment у частного QA-target; вершины, атлас, фазы, MultiMesh и материалы production не меняются.
static func coverage_shader() -> Shader:
	var shader := Shader.new()
	var code: String = Wind.Batch.ShaderSource.code
	code = code.replace("blend_disabled", "blend_add")
	code = code.substr(0, code.find("void fragment()")) + "void fragment() { COLOR = vec4(1.0 / 255.0, 0.0, 0.0, 1.0); }"
	shader.code = code
	return shader


## Измеряет настоящий canvas и fragment coverage восьми meshes при трёх DPI и четырёх предельных направлениях.
static func capture(tree: SceneTree, output: String) -> Array:
	var result := []
	var calibration := SubViewport.new()
	calibration.disable_3d = true
	calibration.transparent_bg = true
	calibration.size = Vector2i(128, 96)
	calibration.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	tree.root.add_child(calibration)
	var cards := CalibrationCards.new()
	var material := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = "shader_type canvas_item; render_mode unshaded, blend_add; void fragment() { COLOR = vec4(1.0 / 255.0, 0.0, 0.0, 1.0); }"
	material.shader = shader
	cards.material = material
	calibration.add_child(cards)
	for frame in 3: await tree.process_frame
	await RenderingServer.frame_post_draw
	var calibration_image := calibration.get_texture().get_image()
	calibration_image.save_png(output.path_join("calibration.png"))
	result.append({"calibration": true, "image": "calibration.png"})
	calibration.free()
	for scale in [1, 2, 4]:
		for direction in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
			var batch := Wind.Batch.build(Wind.placements(), Wind.Ambient.ATLAS, scale)
			tree.root.add_child(batch.viewport)
			var bounds := []
			for group in batch.groups:
				group.material.shader = coverage_shader()
				group.material.set_shader_parameter("amplitude", 0.0)
				# Conservative box includes maximum wind1.35 plus contact4.36; not a claimed physically simultaneous reaction.
				var bends := Wind.Contact.empty()
				for index in 8: bends[index] = Vector2(direction.x * 5.71, direction.y * 4.36)
				group.material.set_shader_parameter("contact_bends", bends)
				bounds.append({"kind": group.name, "aabb": Review.pack(group.multimesh.get_aabb()), "mesh": Review.pack(group.multimesh.mesh.custom_aabb)})
			batch.viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
			for frame in 3: await tree.process_frame
			await RenderingServer.frame_post_draw
			var image: Image = batch.viewport.get_texture().get_image()
			image.convert(Image.FORMAT_RGBA8)
			var name := "coverage-%d-%d-%d.png" % [scale, direction.x, direction.y]
			image.save_png(output.path_join(name))
			var bytes := image.get_data()
			var fragments := 0
			var pixels := 0
			var maximum := 0
			for index in range(0, bytes.size(), 4):
				var count: int = bytes[index]
				fragments += count
				if count > 0: pixels += 1
				maximum = maxi(maximum, count)
			result.append({"scale": scale, "extreme": Review.pack(direction), "image": name, "size": Review.pack(image.get_size()), "fragments": fragments, "covered_pixels": pixels, "maximum": maximum, "draw_calls": batch.viewport.get_render_info(Viewport.RENDER_INFO_TYPE_CANVAS, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME), "primitives": batch.viewport.get_render_info(Viewport.RENDER_INFO_TYPE_CANVAS, Viewport.RENDER_INFO_PRIMITIVES_IN_FRAME), "bounds": bounds, "nominal_rgba8_bytes": image.get_width() * image.get_height() * 4})
			batch.viewport.free()
	return result


## Записывает фактические счётчики обычного target отдельно от диагностических проходов и всей сцены.
static func observe(game: Node) -> Dictionary:
	var owner: Node = game.get_node(Wind.NAME)
	var viewport: SubViewport = owner.batch.viewport
	return {"statistics": Wind.statistics(game), "target_size": Review.pack(viewport.size), "target_update_mode": viewport.render_target_update_mode, "target_draw_calls_last_frame": viewport.get_render_info(Viewport.RENDER_INFO_TYPE_CANVAS, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME), "target_primitives_last_frame": viewport.get_render_info(Viewport.RENDER_INFO_TYPE_CANVAS, Viewport.RENDER_INFO_PRIMITIVES_IN_FRAME), "root_draw_calls": game.get_viewport().get_render_info(Viewport.RENDER_INFO_TYPE_CANVAS, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME), "global_texture_bytes": Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED), "global_static_bytes": Performance.get_monitor(Performance.MEMORY_STATIC), "nominal_target_rgba8_bytes": viewport.size.x * viewport.size.y * 4, "target_id": viewport.get_instance_id()}
