extends SceneTree

const Route := preload("res://tools/visual_motion_route.gd")
const Points := preload("res://tools/visual_camera_points.gd")
const SIZE := Vector2i(1152,648)
var folder := ""
var profile := ""
var fault := ""
var probe := false
var game: Node
var route: RefCounted
var running := false
var frames := []
var conditions := []
var injected := false

class Before extends Node:
	var owner_tree: SceneTree
	## Посылает ввод раньше штатного игрового физического кадра.
	func _physics_process(_delta: float) -> void:
		if owner_tree.running: owner_tree.route.before_step(owner_tree.game)

class After extends Node:
	var owner_tree: SceneTree
	## Наблюдает после штатной физики без самостоятельного продвижения мира.
	func _physics_process(delta: float) -> void:
		if owner_tree.running:
			owner_tree.route.after_step(owner_tree.game,delta)
			if not owner_tree.game.is_physics_processing(): owner_tree.route.fail("physics processing disabled")
			if owner_tree.route.finished(): owner_tree.running=false; owner_tree.game.set_physics_process(false)

## Создаёт отдельный профиль до инициализации игры; headless допускается только явной пробой.
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): folder=arg.trim_prefix("--output=")
		elif arg.begins_with("--profile="): profile=arg.trim_prefix("--profile=")
		elif arg.begins_with("--fault="): fault=arg.trim_prefix("--fault=")
		elif arg=="--probe": probe=true
	if folder.is_empty() or not profile.begins_with("Codex-VBASE-005-") or "/" in profile or "\\" in profile:
		push_error("Need fresh output and isolated VBASE-005 profile"); quit(2); return
	ProjectSettings.set_setting("application/config/use_custom_user_dir",true)
	ProjectSettings.set_setting("application/config/custom_user_dir_name",profile)
	_start.call_deferred()

## Запускает полный игровой цикл: ввод, коллизии, NPC и штатный переход двери.
func _start() -> void:
	if (DisplayServer.get_name()=="headless" and not probe) or not OS.get_user_data_dir().ends_with(profile) or FileAccess.file_exists("user://farm-settings.cfg"):
		push_error("Native display and fresh isolated profile required"); quit(2); return
	if FileAccess.file_exists(folder.path_join("capture.json")):
		push_error("Existing captures must not be overwritten"); quit(2); return
	DirAccess.make_dir_recursive_absolute(folder.path_join("frames"))
	game=Points.create_game(); root.add_child(game); current_scene=game
	route=Route.new(); route.prepare(game)
	if probe:
		while not route.finished():
			route.before_step(game); game.GameLoop.physics_process(game,1.0/60.0); route.after_step(game)
		_save(); quit(0 if route.errors.is_empty() else 2); return
	root.title="VBASE-005 | input routes | diagnostic video, not FPS"
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED; root.content_scale_size=Vector2i.ZERO
	root.content_scale_factor=1.0; DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	await _settle(2000); root.mode=Window.MODE_WINDOWED
	await _settle(2000); root.size=SIZE; root.grab_focus(); await _settle(2000)
	var initial:=_conditions(); conditions.append(initial)
	if not initial.valid: route.fail("initial window/framebuffer/focus"); _save(); quit(2); return
	var before:=Before.new(); before.owner_tree=self; before.process_physics_priority=-100
	var after:=After.new(); after.owner_tree=self; after.process_physics_priority=100
	root.add_child(before); root.add_child(after)
	await _frame(true)
	running=true; game.set_physics_process(true)
	while running:
		await RenderingServer.frame_post_draw
		var state:=_conditions(); conditions.append(state)
		if not state.valid: route.fail("window/framebuffer/focus changed"); running=false
		if not injected and not fault.is_empty() and route.tick>=30: _inject()
		if route.tick%3==0 or not running: await _frame(false)
		if route.finished(): running=false
	game.set_physics_process(false); route.direction(game,Vector2.ZERO)
	_save(); print("MOTION: ",route.tick," ticks, ",route.checkpoints.size()," checkpoints, ",route.errors)
	quit(0 if route.errors.is_empty() else 2)

## Ждёт реальные миллисекунды при замороженной подготовке, не время ускоренной съёмки.
func _settle(milliseconds: int) -> void:
	var deadline:=Time.get_ticks_msec()+milliseconds
	while Time.get_ticks_msec()<deadline:
		game.queue_redraw(); await RenderingServer.frame_post_draw

## Проверяет реальное окно отдельно от root и от копируемого Image.
func _conditions() -> Dictionary:
	var value:={"window":Points.pair(DisplayServer.window_get_size()),"root":Points.pair(root.size),"texture":Points.pair(root.get_texture().get_size()),
		"focus":DisplayServer.window_is_focused(),"mode":root.mode,"vsync":DisplayServer.window_get_vsync_mode()}
	value.valid=DisplayServer.window_get_size()==SIZE and root.size==SIZE and Vector2i(root.get_texture().get_size())==SIZE and value.focus and value.mode==0 and value.vsync==1
	return value

## Сохраняет фактический завершённый нативный кадр; readback исключает видео из FPS-гейта.
func _frame(wait_draw: bool) -> void:
	if wait_draw: game.queue_redraw(); await RenderingServer.frame_post_draw
	var image:=root.get_texture().get_image()
	if image.get_size()!=SIZE: route.fail("wrong decoded Image size"); running=false
	var name:="%04d.png"%frames.size()
	if image.save_png(folder.path_join("frames/"+name))!=OK: route.fail("PNG write failed"); running=false
	frames.append({"file":name,"tick":route.tick,"location":game.current_location,"player":Points.pair(game.player),"camera":Points.pair(game.camera_offset),"readback":Points.pair(image.get_size())})

## Вносит только явно запрошенный отрицательный контроль в отдельный запуск.
func _inject() -> void:
	injected=true
	match fault:
		"resize": root.size=Vector2i(1000,600)
		"pause": game.set_physics_process(false)
		"teleport": game.player+=Vector2(100,0)
		"focus":
			root.gui_embed_subwindows=false
			var window:=Window.new(); window.title="VBASE-005 focus control"; window.size=Vector2i(240,100)
			root.add_child(window); window.show(); window.grab_focus()

## Пишет сырые входы и весь маршрут даже при отказе; проба не превращается в нативное доказательство.
func _save() -> void:
	var report:={"schema":1,"kind":"headless-route-probe" if probe else "native-input-motion","performance_eligible":false,
		"reason":"fixed simulation clock and GPU readbacks, not wall-time performance","preset":route.plan.id,"profile":profile,"pid":OS.get_process_id(),
		"engine":Engine.get_version_info().string,"adapter":RenderingServer.get_video_adapter_name(),"renderer":RenderingServer.get_current_rendering_driver_name(),"display_server":DisplayServer.get_name(),
		"clock_source":"actual launcher argv and observed physics delta; engine-consumed flags are not exposed by OS.get_cmdline_args",
		"physics_hz":Engine.physics_ticks_per_second,"simulation_live":not probe,"fault":fault,
		"conditions":conditions,"rows":route.rows,"inputs":route.sent,"checkpoints":route.checkpoints,"transitions":route.events,
		"frames":frames,"finished":route.index==route.plan.steps.size(),"errors":route.errors}
	FileAccess.open(folder.path_join("capture.json"),FileAccess.WRITE).store_string(JSON.stringify(report)+"\n")
