extends SceneTree

const Points := preload("res://tools/qa/camera/visual_camera_points.gd")
const Reference := preload("res://scripts/presentation/visual_reference_mode.gd")
const Cabinet := preload("res://scripts/systems/dev_cabinet_system.gd")
const Prepared := preload("res://scripts/presentation/prepared_item_icon_system.gd")
const Assets := preload("res://scripts/systems/visual_asset_system.gd")
const Catalog := preload("res://assets/game/items/ui/catalog.gd")
var output := OS.get_environment("VICONS_OUTPUT")
var game: Node
var faults: Array=[]

## Изолирует настоящий запуск от слотов игрока и запрещает перезапись доказательств.
func _initialize() -> void:
	var profile := OS.get_environment("VICONS_PROFILE")
	if output.is_empty() or DirAccess.dir_exists_absolute(output) or not profile.begins_with("Codex-VPIPELINE-006-") or "/" in profile or "\\" in profile: quit(2); return
	ProjectSettings.set_setting("application/config/use_custom_user_dir",true); ProjectSettings.set_setting("application/config/custom_user_dir_name",profile)
	capture.call_deferred()

## Сравнивает ресурсы до окна, первый видимый кадр, повтор и прокрутку в одном свежем процессе.
func capture() -> void:
	if DisplayServer.get_name()=="headless" or FileAccess.file_exists("user://farm-settings.cfg"): quit(2); return
	var point: Dictionary
	for candidate in Points.registry().points:
		if candidate.location=="cottage_interior": point=candidate; break
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED; root.content_scale_size=Vector2i.ZERO; root.content_scale_factor=1.0
	game=Points.create_game(); root.add_child(game); current_scene=game; Points.configure(game,point); Reference.enable(game,true)
	await create_timer(2.0).timeout
	root.mode=Window.MODE_WINDOWED; root.size=Points.SIZE; DirAccess.make_dir_recursive_absolute(output)
	await redraw(); save_frame("room")
	var result := {"room":snapshot(),"source_sha256":{},"frames":{},"errors":faults}
	var before_state: Dictionary=game.SaveSystem.snapshot(game)
	game.player=Cabinet.POSITION
	if not Cabinet.open(game): faults.append("cabinet did not open")
	result.open_before_draw=snapshot()
	await redraw(1); save_frame("cabinet-first"); result.first_frame=snapshot()
	await redraw(); save_frame("cabinet-stable"); result.stable=snapshot()
	Cabinet.close(game)
	if not Cabinet.open(game): faults.append("cabinet did not reopen")
	await redraw(); save_frame("cabinet-reopen"); result.reopened=snapshot()
	Cabinet.close(game); game.player=Points.vector(point.player)
	result.serialized_before=before_state; result.serialized_after=game.SaveSystem.snapshot(game)
	result.state_unchanged=before_state==result.serialized_after
	var expected := before_state.duplicate(true)
	expected.tutorial.events.dev_cabinet=true; expected.estate.expansion.first_chapter.events.dev_cabinet=true
	result.only_cabinet_visit_recorded=expected==result.serialized_after
	if not result.only_cabinet_visit_recorded: faults.append("unexpected serialized state changes")
	result.inventory_ids=game.InventorySystem.ITEM_DATA.keys()
	result.merge({"engine":Engine.get_version_info().string,"version":ProjectSettings.get_setting("application/config/version"),"profile":OS.get_user_data_dir().get_file(),"configuration":Points.snapshot(game,point),"framebuffer":[1152,648],"performance_eligible":false})
	for name in ["room","cabinet-first","cabinet-stable","cabinet-reopen"]: result.frames[name]=FileAccess.get_sha256(output+"/"+name+".png")
	for path in ["scripts/presentation/prepared_item_icon_system.gd","scripts/systems/visual_asset_system.gd","assets/game/items/ui/catalog.json","tools/item_sizes_capture.gd"]:result.source_sha256[path]=FileAccess.get_sha256("res://"+("tools/assets/contracts/item_sizes_capture.gd" if path=="tools/item_sizes_capture.gd" else path))
	FileAccess.open(output+"/capture.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  ")+"\n")
	print("ITEM SIZE CAPTURE: ",output); quit(0 if faults.is_empty() else 2)

## Считает существующие ссылки ResourceLoader без загрузки или чтения изображений ради измерения.
func snapshot() -> Dictionary:
	var masters: Array[String]=[]; var previews: Array[String]=[]
	for kind in Catalog.DATA.entries:
		if ResourceLoader.has_cached(Catalog.DATA.entries[kind].path): masters.append(kind)
		if ResourceLoader.has_cached("res://assets/game/items/ui/preview/"+kind+".png"): previews.append(kind)
	var prepared := Prepared.cache_info(); var size: Vector2=prepared.atlas
	prepared.atlas=[int(size.x),int(size.y)]
	return {"master_ids_cached":masters,"preview_ids_cached":previews,"prepared":prepared,"sources":Assets.item_cache_info()}

## Дожидается указанного числа реальных кадров, не прогревая текстуры отдельными вызовами поставщика.
func redraw(frames: int=20) -> void:
	for index in frames:
		game.queue_redraw(); await process_frame; RenderingServer.force_draw(false)

## Сохраняет целый framebuffer, обнаруживая ошибку размера или записи.
func save_frame(name: String) -> void:
	var image := root.get_texture().get_image()
	if image.get_size()!=Points.SIZE or image.save_png(output+"/"+name+".png")!=OK: faults.append("invalid frame: "+name)
