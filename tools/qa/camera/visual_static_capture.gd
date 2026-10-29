extends SceneTree

const Points := preload("res://tools/visual_camera_points.gd")
const Reference := preload("res://scripts/presentation/visual_reference_mode.gd")
const WorldLabel := preload("res://scripts/presentation/world_label_renderer.gd")
var folder := ""
var profile := ""
var rows := []
var faults := []
var game: Node
var point: Dictionary

## Изолирует съёмку от сохранений игрока до создания сцены.
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): folder=arg.trim_prefix("--output=")
		elif arg.begins_with("--profile="): profile=arg.trim_prefix("--profile=")
	if folder.is_empty() or not profile.begins_with("Codex-VBASE-004-") or "/" in profile or "\\" in profile:
		push_error("Нужны output и свежий профиль VBASE-004"); quit(2); return
	ProjectSettings.set_setting("application/config/use_custom_user_dir",true)
	ProjectSettings.set_setting("application/config/custom_user_dir_name",profile)
	_start.call_deferred()

## Снимает настоящую деревню с одним ракурсом, переключая только декоративные слои и интерфейс.
func _start() -> void:
	if DisplayServer.get_name()=="headless" or not OS.get_user_data_dir().ends_with(profile) or FileAccess.file_exists("user://farm-settings.cfg"):
		push_error("Нужны нативное окно и свежий профиль"); quit(2); return
	point=Points.registry().points[0]
	DirAccess.make_dir_recursive_absolute(folder)
	root.title="VBASE-004 · статический эталон"
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size=Vector2i.ZERO; root.content_scale_factor=1.0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	game=Points.create_game(); root.add_child(game); current_scene=game; Points.configure(game,point)
	await create_timer(2.0).timeout
	root.mode=Window.MODE_WINDOWED
	await create_timer(2.0).timeout
	root.size=Points.SIZE; root.grab_focus()
	await create_timer(2.0).timeout
	await _pair("effects",false,true)
	await _pair("hud",true,true)
	await _pair("clean",true,false)
	Reference.enable(game,true)
	await _wait_redraws(0.0)
	_save("hud-restored")
	Reference.disable(game)
	await _pair("restored",false,true)
	var actor:Dictionary=game.NpcMovementSystem.actor(game,"grandmother",game.npc_position)
	var bounds:Rect2=WorldLabel.bounds(game,actor.position+Vector2(0,18),game.LocaleSystem.entity("grandmother"))
	bounds.position-=game.camera_offset; bounds=bounds.grow(2)
	var masks:=[[0,0,1152,140],[0,560,1152,88],[floori(bounds.position.x),floori(bounds.position.y),ceili(bounds.size.x)+1,ceili(bounds.size.y)+1]]
	var report:={"schema":1,"kind":"static-village-effects-off","preset":"village-static-noon-1152-v1",
		"performance_eligible":false,"simulation_frozen":true,"profile":profile,"frames":rows,"errors":faults,
		"display_server":DisplayServer.get_name(),"renderer":RenderingServer.get_current_rendering_driver_name(),
		"engine":Engine.get_version_info().string,"adapter":RenderingServer.get_video_adapter_name(),
		"disabled_effects":Reference.EFFECTS,"hud_masks":masks,"minimum_delay_ms":2500}
	FileAccess.open(folder.path_join("capture.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t")+"\n")
	for fault in faults: push_error(fault)
	quit(0 if faults.is_empty() else 2)

## Даёт каждому режиму прогреться, затем сравнивает кадры через реальное системное время.
func _pair(prefix: String, static_mode: bool, hud: bool) -> void:
	if static_mode: Reference.enable(game,hud)
	else: Reference.disable(game)
	await _wait_redraws(0.0); _save(prefix+"-0")
	await _wait_redraws(2.5); _save(prefix+"-1")

## Перерисовывает каждый кадр и отклоняет даже промежуточную потерю фокуса или изменение окна.
func _wait_redraws(seconds: float) -> void:
	var start:=Time.get_ticks_msec(); var count:=0
	while count<12 or Time.get_ticks_msec()-start<seconds*1000.0:
		game.queue_redraw(); await RenderingServer.frame_post_draw; count+=1
		if not _conditions().valid and not faults.has("window/framebuffer/focus"):
			faults.append("window/framebuffer/focus")

## Записывает результат реального framebuffer и паспорт состояния в момент чтения.
func _save(name: String) -> void:
	faults.append_array(Points.errors(game,point))
	var image:=root.get_texture().get_image()
	if image.get_size()!=Points.SIZE or image.save_png(folder.path_join(name+".png"))!=OK: faults.append("PNG: "+name)
	var row:=Points.snapshot(game,point)
	row.merge({"image":name+".png","conditions":_conditions(),"ticks_ms":Time.get_ticks_msec(),
		"draw_frame":Engine.get_frames_drawn(),"static_mode":Reference.active(game),"hud":Reference.hud_visible(game)})
	rows.append(row); print("STATIC CAPTURE: ",name)

## Возвращает фактические размеры всех поверхностей, оконный режим и фокус.
func _conditions() -> Dictionary:
	var window:=DisplayServer.window_get_size(); var target:=Vector2i(root.get_texture().get_size())
	var focus:=DisplayServer.window_is_focused(); var mode:=DisplayServer.window_get_mode()
	return {"window":Points.pair(window),"framebuffer":Points.pair(target),"root":Points.pair(root.size),"focused":focus,"mode":mode,
		"valid":window==Points.SIZE and target==Points.SIZE and root.size==Points.SIZE and focus and mode==DisplayServer.WINDOW_MODE_WINDOWED}
