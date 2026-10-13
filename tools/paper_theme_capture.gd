extends SceneTree

const Scene := preload("res://main.tscn")
const Preview := preload("res://scripts/systems/ui_preview_system.gd")
const Cabinet := preload("res://scripts/systems/dev_cabinet_system.gd")
var game:Node2D
var viewport:SubViewport
var folder:String

## Создаёт нативный стенд интерфейса с отдельным каталогом, не читая и не меняя слоты игрока.
func _initialize() -> void:
	_start.call_deferred()

## Снимает все семейства окон одной палитры на одинаковом холсте без последующей обработки картинки.
func _start() -> void:
	if DisplayServer.get_name()=="headless": quit(2); return
	OS.low_processor_usage_mode=false
	ProjectSettings.set_setting("application/config/use_custom_user_dir",true)
	ProjectSettings.set_setting("application/config/custom_user_dir_name","Codex-Paper-Theme-Review")
	var phase:=OS.get_environment("FARM_PAPER_PHASE").strip_edges().validate_filename()
	if phase.is_empty(): phase="after"
	folder="res://docs/reports/paper-ui-2026-10-14/"+phase+"/"
	DirAccess.make_dir_recursive_absolute(folder)
	var container:=SubViewportContainer.new(); root.add_child(container)
	viewport=SubViewport.new(); viewport.size=Vector2i(1152,648); viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS; container.add_child(viewport); current_scene=container
	for label in ["hud","inventory","cabinet","storage","crafting","kitchen","alchemy","study","furnace","shop","forge","quest-log","talent-tree","world-map","calendar","bestiary","recipes","compendium","creation","dialogue","dialogue-long","basement","basement-placement","apiary","contracts","fishing","pause","settings","language","title","inventory-de-120","cabinet-de-120"]:
		var only:=OS.get_environment("FARM_PAPER_ONLY")
		if not only.is_empty() and label not in only.split(","): continue
		if is_instance_valid(game): game.free()
		game=Scene.instantiate(); game.set_meta("capture_windowed",true); viewport.add_child(game)
		game.set_physics_process(false); game.set_process(false); game.audio_enabled=false
		configure(label)
		for _frame in 5:
			game.message=""; game.tutorial_visible=false; game.discovery_current={}; game.queue_redraw()
			await process_frame; RenderingServer.force_draw()
		if viewport.get_texture().get_image().save_png(folder+label+".png")!=OK: push_error("Не удалось сохранить интерфейс "+label)
		print("PAPER UI CAPTURE: "+phase+" "+label)
	quit()

## Использует реальные состояния и профили предметных экранов, оставляя игровые ресурсы неизменными.
func configure(label:String) -> void:
	game.language_screen=false; game.title_screen=false; game.LocaleSystem.set_locale("ru"); game.settings_state.text_scale=1.0; game.settings_state.reduced_motion=true
	game.current_location="cottage_interior"; game.home_chest_owned=true; game.player=Vector2(576,400)
	var life:Dictionary=game.FarmLifeSystem.state(game); life.first_day=6; life.cutscene=""; life.cutscene_timer=0.0
	for entry in [["milk",8],["egg",6],["apple",12],["plank",80],["honey",10],["sunflower",3],["stone",25],["field_mint",9]]: game.change_inventory_count(entry[0],entry[1])
	var args:=PackedStringArray(["--capture-"+label.replace("-log","-log")])
	var done:bool=Preview.configure_item_window_capture(game,args) or Preview.configure_world_guide_capture(game,args) or Preview.configure_character_window_capture(game,args) or Preview.configure_story_window_capture(game,args)
	if not done:
		match label:
			"inventory-de-120": game.open_inventory()
			"cabinet","cabinet-de-120":
				game.player=Cabinet.POSITION
				if not Cabinet.open(game): push_error("Шкаф не открыт в стенде")
				Cabinet.state(game).selected=Cabinet.items(game).find("sunflower")
			"kitchen","alchemy","study","furnace": game.CraftingSystem.open(game,"cauldron" if label=="kitchen" else label)
			"compendium": life.compendium=true; life.page=1
			"creation": game.AdventurePolishSystem.begin_new_game(game)
			"dialogue-long":
				game.AdventurePolishSystem.open_quest_dialogue(game,"varvara")
				game.state.player.adventure_ui.dialogue.text="Вчера я встретила у старого моста рабочих. Им нужна горячая уха: поймай пять рыб и принеси мне. Мы вместе приготовим обед, а ребята успеют закончить переправу до дождя. ".repeat(4)
				game.settings_state.text_scale=1.2
			"basement","basement-placement":
				game.current_location=game.BasementSystem.Data.LOCATION; game.player=game.BasementSystem.Data.BOARD
				if not game.BasementSystem.open(game): push_error("Чертёж не открыт в стенде")
				if label=="basement-placement":
					var value:Dictionary=game.BasementSystem.ui(game); value.open=false; value.placing=true; value.kind="pottery"
			"apiary":
				var apiary=preload("res://scripts/systems/apiary_system.gd")
				game.current_location="overworld"; game.player=apiary.Data.SITES[2]+Vector2(0,48)
				var hive:Dictionary=apiary.state(game).hives[2]; hive.level=3; hive.colonized=true; hive.stock={"honeycomb":3,"bees":1,"pollen":1,"propolis":1}
				if not apiary.interact(game,"life:apiary:2"): push_error("Улей не открыт в стенде")
			"contracts": game.contract_open=true
			"fishing": game.FishingSystem.configure_preview(game)
			"pause": game.MenuSystem.open_pause(game)
			"settings": game.MenuSystem.open_pause(game); game.MenuSystem.open_settings(game,false)
			"language": game.language_screen=true
			"title": game.title_screen=true
	if label.ends_with("-de-120"): game.LocaleSystem.set_locale("de"); game.settings_state.text_scale=1.2
	if bool(game.state.player.adventure_ui.get("dialogue_open",false)): game.state.player.adventure_ui.dialogue.revealed=9999
	for key in ["capture_ui_frames","capture_ui_output","capture_notification_text"]:
		if game.has_meta(key): game.remove_meta(key)
	if not label.begins_with("basement") and label!="apiary": game.current_location="cottage_interior"; game.player=Vector2(576,400)
	game.sync_background_location(); game.update_camera()
