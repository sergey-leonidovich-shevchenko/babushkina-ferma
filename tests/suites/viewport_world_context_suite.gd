# Сценарий сравнивает два динамических Game-экземпляра в расширенном тестовом SceneTree.
@warning_ignore_start(
	"untyped_declaration",
	"unsafe_call_argument",
	"unsafe_cast",
	"unsafe_method_access",
	"unsafe_property_access",
	"unsafe_void_return"
)
extends RefCounted

const Points := preload("res://tools/qa/camera/visual_camera_points.gd")
const Context := preload("res://scripts/presentation/viewport_world_context.gd")
const Clock := preload("res://scripts/presentation/village_ground_clock.gd")
const Frame := preload("res://scripts/presentation/post_motion_frame.gd")
const Pose := preload("res://scripts/systems/presentation_pose_system.gd")
const WorldProjection := preload("res://scripts/systems/world_projection_system.gd")


## Проверяет два настоящих viewport, чужие токены, паузу редактора и независимые переходы карт.
static func run(context: SceneTree) -> void:
	var host := Node.new()
	var left_view := SubViewport.new()
	var right_view := SubViewport.new()
	for viewport in [left_view, right_view]:
		viewport.size = Vector2i(1152, 648)
		viewport.disable_3d = true
		host.add_child(viewport)
	context.root.add_child(host)
	var left := Points.create_game()
	var right := Points.create_game()
	left_view.add_child(left)
	right_view.add_child(right)
	Points.configure(left, Points.registry().points[0])
	Points.configure(right, Points.registry().points[0])
	for game in [left, right]:
		game.settings_state.reduced_motion = false
		game.player = Vector2(696, 696)
		game.update_camera()
		Pose.reset(game)

	var left_token := Context.read(left)
	var right_token := Context.read(right)
	var left_background := left.get_node("WorldBackground")
	var right_background := right.get_node("WorldBackground")
	(
		context
		. expect(
			(
				left_token.is_read_only()
				and right_token.is_read_only()
				and left_token.game != right_token.game
				and left_token.viewport != right_token.viewport
			),
			"each real viewport receives one distinct immutable world owner",
		)
	)
	(
		context
		. expect(
			(
				Context.owns(left, left_background)
				and Context.owns(right, right_background)
				and not Context.owns(left, right_background)
			),
			"background ownership cannot cross between viewport worlds",
		)
	)
	(
		context
		. expect(
			(
				left_background.terrain_canvas.get_meta(Context.OWNER_META, {}) == left_token
				and right_background.terrain_canvas.get_meta(Context.OWNER_META, {}) == right_token
			),
			"terrain canvases inherit only their parent world token",
		)
	)

	var left_save: Dictionary = left.SaveSystem.snapshot(left)
	var right_save: Dictionary = right.SaveSystem.snapshot(right)
	Clock.advance(left, 1.0)
	Clock.advance(right, 7.0)
	(
		context
		. expect(
			Clock.seconds(left) == 1.0 and Clock.seconds(right) == 7.0,
			"decorative time advances independently in two viewport worlds",
		)
	)
	context.expect(
		Frame.publish(left, 0.25) and Frame.publish(right, 0.5),
		"both owners publish their own completed visual frame"
	)
	var left_frame := Frame.read(left)
	var right_frame := Frame.read(right)
	(
		context
		. expect(
			(
				left_frame.owner == left_token.game
				and right_frame.owner == right_token.game
				and left_frame.seconds != right_frame.seconds
			),
			"post-motion packets retain the matching owner and independent phase",
		)
	)
	var foreign := right_frame.duplicate()
	foreign.make_read_only()
	left.set_meta(Frame.META, foreign)
	context.expect(
		Frame.read(left).is_empty(), "a valid packet from the neighbouring viewport is rejected"
	)
	context.expect(
		Frame.publish(left, 0.25),
		"the owner restores its own packet after a rejected foreign value"
	)
	(
		context
		. expect(
			(
				left.SaveSystem.snapshot(left) == left_save
				and right.SaveSystem.snapshot(right) == right_save
			),
			"owner, clocks and post-motion packets remain outside both complete saves",
		)
	)

	var left_position: Vector2 = left_background.position
	var left_scale: Vector2 = left_background.scale
	(
		context
		. expect(
			(
				not left_background.sync_projection(
					right_token, Vector2(999, 777), Vector2.ONE * 3.0
				)
				and left_background.position == left_position
				and left_background.scale == left_scale
			),
			"foreign projection cannot overwrite another viewport position or scale",
		)
	)
	right.current_location = "village_market"
	(
		context
		. expect(
			(
				not left_background.sync_from(right, right_token)
				and left_background.location == "overworld"
			),
			"foreign map transition cannot overwrite another viewport background",
		)
	)
	right.sync_background_location()
	(
		context
		. expect(
			(
				right_background.location == "village_market"
				and left_background.location == "overworld"
			),
			"map entry updates only the owning background",
		)
	)
	right.current_location = "overworld"
	right.sync_background_location()

	left.set_meta(left.LevelEditorSystem.META_KEY, {"active": true})
	var left_seconds := Clock.seconds(left)
	var right_seconds := Clock.seconds(right)
	Clock.advance(left, 3.0)
	Clock.advance(right, 0.5)
	(
		context
		. expect(
			Clock.seconds(left) == left_seconds and Clock.seconds(right) == right_seconds + 0.5,
			"manual editor freezes only its viewport and leaves the game viewport running",
		)
	)
	left.remove_meta(left.LevelEditorSystem.META_KEY)
	right.MenuSystem.open_pause(right)
	left_seconds = Clock.seconds(left)
	right_seconds = Clock.seconds(right)
	Clock.advance(left, 0.5)
	Clock.advance(right, 3.0)
	(
		context
		. expect(
			Clock.seconds(left) == left_seconds + 0.5 and Clock.seconds(right) == right_seconds,
			"manual pause freezes only the selected viewport world",
		)
	)

	left_save = left.SaveSystem.snapshot(left)
	right_save = right.SaveSystem.snapshot(right)
	WorldProjection.sync_background(left)
	WorldProjection.sync_background(right)
	(
		context
		. expect(
			(
				Context.read(left) == left_token
				and Context.read(right) == right_token
				and left.SaveSystem.snapshot(left) == left_save
				and right.SaveSystem.snapshot(right) == right_save
			),
			"owner checks and render-only state never enter either complete game save",
		)
	)
	context.expect(
		left_token.values().all(func(value: Variant) -> bool: return typeof(value) == TYPE_INT),
		"world token retains no Node, viewport resource, material or callback",
	)
	var packet_before_move := Frame.read(left)
	left.reparent(right_view)
	(
		context
		. expect(
			Context.read(left).is_empty() and Frame.read(left).is_empty(),
			"moving a world invalidates its viewport context and published frame",
		)
	)
	var rebound := Context.ensure(left)
	(
		context
		. expect(
			(
				rebound.viewport == right_view.get_instance_id()
				and rebound.viewport != left_token.viewport
				and Frame.read(left).is_empty()
			),
			"rebind cannot revive a packet published for the previous viewport",
		)
	)
	(
		context
		. expect(
			(
				Frame.publish(left, 0.25)
				and Frame.read(left).viewport_owner == rebound.viewport
				and Frame.read(left).background_owner == rebound.background
				and Frame.read(left) != packet_before_move
			),
			"a fresh publish binds the frame to the complete rebound world identity",
		)
	)
	var left_id := left.get_instance_id()
	var right_id := right.get_instance_id()
	host.free()
	(
		context
		. expect(
			not is_instance_id_valid(left_id) and not is_instance_id_valid(right_id),
			"viewport fixture releases both world roots before the suite returns",
		)
	)
