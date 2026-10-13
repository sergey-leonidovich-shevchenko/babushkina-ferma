extends SceneTree

const Scene := preload("res://main.tscn")
const Cabinet := preload("res://scripts/systems/dev_cabinet_system.gd")
const Controls := preload("res://scripts/systems/dev_cabinet_input.gd")
const Actions := preload("res://scripts/systems/storage_actions_system.gd")
const Sorting := preload("res://scripts/systems/storage_sort_system.gd")
const Render := preload("res://scripts/presentation/storage_actions_renderer.gd")
var game:Node2D
var viewport:SubViewport
var failed:=0

## Запускает изолированный нативный захват настоящего сундука и шкафа с новыми кнопками.
func _initialize() -> void:
	_start.call_deferred()

## Проверяет переносы настоящими кнопками и снимает состояния до и после на двух языках.
func _start() -> void:
	if DisplayServer.get_name()=="headless": quit(2); return
	OS.low_processor_usage_mode=false
	ProjectSettings.set_setting("application/config/use_custom_user_dir",true)
	ProjectSettings.set_setting("application/config/custom_user_dir_name","Codex-Storage-Actions-Review")
	var container:=SubViewportContainer.new(); root.add_child(container)
	viewport=SubViewport.new(); viewport.size=Vector2i(1152,648); viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS; container.add_child(viewport)
	game=Scene.instantiate(); game.set_meta("capture_windowed",true); viewport.add_child(game); current_scene=container
	game.set_physics_process(false); game.set_process(false); game.audio_enabled=false
	game.language_screen=false; game.title_screen=false; game.LocaleSystem.current="ru"; game.home_chest_owned=true
	var life:Dictionary=game.FarmLifeSystem.state(game); life.first_day=6; life.cutscene=""; life.cutscene_timer=0
	game.current_location="cottage_interior"; game.player=game.StorageSystem.CHEST_POSITION+Vector2(80,0); game.sync_background_location(); game.update_camera()
	clear_bag()
	for entry in [["plank",80],["milk",8],["carrot",30],["stone",12]]: game.change_inventory_count(entry[0],entry[1])
	game.home_chest_counts={"plank":4,"milk":2}
	if not game.perform_context_action() or not game.storage_open: fail("Сундук не открылся обычным действием")
	await capture("chest-before")
	Render.pointer(game,Render.rect(1,false).get_center(),false)
	if game.inventory_item_count("plank")!=0 or game.carrots!=30 or game.state.storage.count("plank")!=84: fail("Неверный совпадающий перенос сундука")
	await capture("chest-matching")
	for _mode in 3: Actions.sort_bag(game,false); Actions.sort_container(game,false)
	await capture("chest-sorted-count")
	Render.pointer(game,Render.rect(0,false).get_center(),false)
	if not Actions.candidates(game,false,false).is_empty() or game.state.storage.count("carrot")!=30: fail("Неверный полный перенос сундука")
	await capture("chest-after-all")
	game.LocaleSystem.current="de"; game.settings_state.text_scale=1.2
	for _mode in 3: Actions.sort_container(game,false)
	await capture("chest-de-120")
	game.storage_open=false; Sorting.reset(game); game.LocaleSystem.current="ru"; game.settings_state.text_scale=1
	game.player=Cabinet.POSITION; game.update_camera(); game.change_inventory_count("plank",12); game.change_inventory_count("apple",5)
	if not game.perform_context_action() or not Cabinet.active(game): fail("Шкаф не открылся обычным действием")
	Cabinet.state(game).stock.plank=0; Cabinet.select_tab(game,1); Controls.query(game,"plank")
	Render.pointer(game,Render.rect(1,true).get_center(),true)
	if game.inventory_item_count("plank")!=12 or int(Cabinet.state(game).stock.apple)!=1004: fail("Совпадающий перенос ошибочно ограничен поиском")
	await capture("cabinet-matching")
	Render.pointer(game,Render.rect(0,true).get_center(),true); Cabinet.refill(game); Controls.query(game,""); Cabinet.select_tab(game,0)
	for _mode in 3: Actions.sort_bag(game,true); Actions.sort_container(game,true)
	Cabinet.state(game).selected=0
	if int(Cabinet.state(game).stock.apple)!=1004 or not Actions.candidates(game,true,false).is_empty(): fail("Полный перенос или пополнение потеряли вещи")
	await capture("cabinet-all-sorted")
	game.LocaleSystem.current="de"; game.settings_state.text_scale=1.2
	for _mode in 3: Actions.sort_container(game,true)
	await capture("cabinet-de-120")
	print("STORAGE ACTIONS CAPTURE: "+("PASS" if failed==0 else "FAIL")); quit(0 if failed==0 else 1)

## Очищает только демонстрационный рюкзак перед фиксированным сценарием кадра.
func clear_bag() -> void:
	for kind in game.InventorySystem.ITEM_DATA:
		var count:int=game.inventory_item_count(kind)
		if count>0: game.change_inventory_count(kind,-count)
	for slot in game.equipment: game.equipment[slot]=""
	game.equipped_weapon="none"; game.sword_equipped=false

## Сохраняет исходный кадр GPU после полной перерисовки без пересчёта масштаба изображения.
func capture(label: String) -> void:
	game.tutorial_visible=false; game.discovery_current={}; game.hud_message_timer=0
	for _frame in 8: game.queue_redraw(); await process_frame; RenderingServer.force_draw()
	var image:=viewport.get_texture().get_image()
	if image.get_size()!=Vector2i(1152,648) or image.save_png("res://docs/reports/storage-actions-2026-10-13-"+label+".png")!=OK: fail("Не удалось сохранить нативный кадр "+label)
	print("STORAGE ACTIONS FRAME: "+label)

## Помечает отказ сценария и печатает причину для обязательной проверки всего журнала.
func fail(label: String) -> void:
	failed+=1; push_error(label)
