extends SceneTree

const Scene := preload("res://main.tscn")
const Research := preload("res://scripts/systems/research_system.gd")
var game:Node2D
var viewport:SubViewport
var errors:=0

## Готовит отдельный нативный визуальный стенд без пользовательских слотов.
func _initialize() -> void:
	_start.call_deferred()

## Показывает стол, скрытый и открытый состав, сложный образец, изношенную разборку и полученные детали.
func _start() -> void:
	if DisplayServer.get_name()=="headless": quit(2); return
	ProjectSettings.set_setting("application/config/use_custom_user_dir",true)
	ProjectSettings.set_setting("application/config/custom_user_dir_name","Codex-Research-Visual-Review")
	var container:=SubViewportContainer.new(); root.add_child(container)
	viewport=SubViewport.new(); viewport.size=Vector2i(1152,648); viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS; container.add_child(viewport)
	game=Scene.instantiate(); game.set_meta("capture_windowed",true); viewport.add_child(game); current_scene=container
	game.set_physics_process(false); game.set_process(false); game.audio_enabled=false; game.LocaleSystem.current="ru"
	game.language_screen=false; game.title_screen=false; game.tutorial_visible=false; game.discovery_current={}; game.message=""; game.hud_message_timer=0
	var life:Dictionary=game.FarmLifeSystem.state(game); life.first_day=6; life.cutscene=""; life.cutscene_timer=0
	game.current_location="guild_interior"; game.player=Research.STUDY_POINT; game.sync_background_location(); game.update_camera()
	await capture("room")
	for kind in ["research_paper","research_ink","plank","iron_helmet","crystal","iron_spear"]: game.change_inventory_count(kind,10)
	game.coins=1000; game.open_crafting("study"); select("plank"); await capture("unknown")
	Research.execute(game,game.crafting_selected); await capture("known")
	for cost in Research.Data.UPGRADES:
		for kind in cost.inputs: game.change_inventory_count(kind,int(cost.inputs[kind]))
		Research.upgrade(game)
	game.energy=12; game.settings_state.text_scale=1.2; game.LocaleSystem.current="de"; select("crystal")
	await capture("level3-de-120")
	game.LocaleSystem.current="ru"; game.energy=12; select("iron_spear"); Research.execute(game,game.crafting_selected)
	game.crafting_open=false; game.current_location="forge_interior"; game.player=Research.BENCH_POINT; game.sync_background_location(); game.update_camera()
	game.open_crafting("recycling"); select("iron_spear"); game.state.inventory.durability.iron_spear=0
	await capture("worn-dismantling")
	Research.execute(game,game.crafting_selected); game.crafting_open=false; game.open_inventory(); game.inventory_selected=game.inventory_slots.find("wood_offcut")
	await capture("parts")
	print("RESEARCH CAPTURE: "+("PASS" if errors==0 else "FAIL")); quit(0 if errors==0 else 1)

## Выбирает вид вещи в каталоге, а не одноимённый рецепт её изготовления.
func select(kind: String) -> void:
	game.crafting_selected=Research.Data.ENTRIES.find_custom(func(entry): return entry.kind==kind)

## Ждёт готовности GPU и проверяет фактический размер каждого сохранённого кадра.
func capture(label: String) -> void:
	game.tutorial_visible=false
	for _frame in 8:
		game.queue_redraw(); await RenderingServer.frame_post_draw
	var frame:=viewport.get_texture().get_image()
	if frame.get_size()!=Vector2i(1152,648): errors+=1; push_error("Неверный размер контрольного кадра")
	if frame.save_png("res://docs/reports/research-2026-10-12-"+label+".png")!=OK: errors+=1
