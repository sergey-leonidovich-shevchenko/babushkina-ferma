extends "res://tools/action_lifecycle_native.gd"

const FOLDER_FARM := "res://docs/reports/farm-2026-10/native/"

## Снимает хозяйственные интерфейсы в настоящей сцене, не читая игровые слоты пользователя.
func _initialize() -> void:
	ProjectSettings.set_setting("application/config/use_custom_user_dir",true)
	ProjectSettings.set_setting("application/config/custom_user_dir_name","Codex-FARM-Native")
	start_farm.call_deferred()

## Создаёт нативный кадр карточки семян с реальной локализацией и действующим шрифтом.
func start_farm() -> void:
	if DisplayServer.get_name()=="headless": quit(2); return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(FOLDER_FARM))
	root.size=Vector2i(1152,648); DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	OS.low_processor_usage_mode=false
	var game:=make_game(); game.tutorial_visible=false; game.state.player.profile.created=true
	game.FirstChapterSystem.state(game).completed=true
	var life:Dictionary=game.FarmLifeSystem.state(game); life.first_day=6; life.cutscene=""; life.cutscene_timer=0
	game.open_inventory(); game.inventory_selected=game.inventory_slots.find("seeds"); game.queue_redraw()
	await process_frame; RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png(FOLDER_FARM+"seed-card.png")
	game.inventory_open=false; game.current_location="overworld"
	var animal:Dictionary=game.FarmLifeSystem.LivestockData.animal("cow")
	game.player=Vector2(animal.position)+Vector2(48,0); game.update_camera()
	game.FarmLifeSystem.Livestock.interact(game,life,"life:animal:cow"); game.update_hud_feedback(0); game.queue_redraw()
	await process_frame; RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png(FOLDER_FARM+"livestock-hint.png")
	game.current_location="forge_interior"; game.player=game.FurnaceSystem.STATION
	game.CraftingSystem.open(game,"furnace")
	game.crafting_selected=game.CraftingSystem.RECIPES.find_custom(func(recipe): return recipe.get("id","")=="furnace:ore")
	game.change_inventory_count("iron_ore",2); game.FurnaceSystem.load_fuel(game)
	game.CraftingSystem.craft(game,game.crafting_selected); game.queue_redraw()
	await process_frame; RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png(FOLDER_FARM+"production-queue.png")
	game.current_location="cottage_interior"; game.player=game.CraftingSystem.Alchemy.STATION
	game.CraftingSystem.open(game,"alchemy"); game.queue_redraw()
	await process_frame; RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png(FOLDER_FARM+"alchemy-learning.png")
	game.crafting_open=false; game.WorldMapSystem.toggle(game); game.WorldMapSystem.set_page(game,4)
	game.world_guide_selected=game.CraftingSystem.RECIPES.find_custom(func(recipe): return recipe.get("id","")=="kitchen:bread")
	var guide:=preload("res://scripts/systems/production_guide_system.gd")
	guide.state(game).batches=2; guide.state(game).stock=false; game.UiFeedbackSystem.update(game,1); game.queue_redraw()
	await process_frame; RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png(FOLDER_FARM+"production-plan.png")
	game.free(); quit()
