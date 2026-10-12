extends SceneTree

const Scene := preload("res://main.tscn")
const Alchemy := preload("res://scripts/systems/alchemy_system.gd")
const Recipes := preload("res://scripts/systems/alchemy_recipe_data.gd")
var game:Node2D
var errors:=0

## Готовит отдельную визуальную модель, не открывая и не записывая пользовательские слоты.
func _initialize() -> void:
	_start.call_deferred()

## Проверяет настоящий renderer у стола, в рецептах и на полянке, сохраняя отдельные контрольные кадры.
func _start() -> void:
	if DisplayServer.get_name()=="headless": quit(2); return
	ProjectSettings.set_setting("application/config/use_custom_user_dir",true)
	ProjectSettings.set_setting("application/config/custom_user_dir_name","Codex-Alchemy-Visual-Review")
	game=Scene.instantiate(); game.audio_enabled=false; root.add_child(game); current_scene=game
	game.set_physics_process(false); game.set_process(false)
	game.language_screen=false; game.title_screen=false; game.tutorial_visible=false; game.discovery_current={}; game.LocaleSystem.current="ru"
	var life:Dictionary=game.FarmLifeSystem.state(game); life.first_day=6; life.cutscene=""; life.cutscene_timer=0.0
	game.message=""; game.hud_message_timer=0.0
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED); root.size=Vector2i(1152,648)
	game.settings_state.text_scale=1.0; game.current_location="cottage_interior"; game.player=Alchemy.STATION
	game.sync_background_location(); game.update_camera()
	await capture("table")
	game.change_inventory_count("chamomile",6); game.CraftingSystem.open(game,"alchemy")
	game.set_meta("alchemy_filter","juice"); select("chamomile_juice")
	await capture("press")
	var value:=Alchemy.state(game)
	for recipe in Recipes.recipes().slice(0,10): value.discovered.append(recipe.id)
	Alchemy.restore(game); game.skill_points=2; game.TalentSystem.unlock(game,"craft_apprentice"); game.TalentSystem.unlock(game,"craft_alchemy")
	for kind in ["wild_thyme_powder","wormwood_tincture","herb_oil","glass_vial"]: game.change_inventory_count(kind,2)
	game.set_meta("alchemy_filter","potions"); select("insect_repellent"); game.settings_state.text_scale=1.2
	await capture("potions-120")
	game.crafting_open=false; game.LocaleSystem.current="fr"
	for kind in ["balanced_elixir","insect_repellent"]: game.change_inventory_count(kind,1)
	game.open_inventory(); game.inventory_selected=game.inventory_slots.find("balanced_elixir")
	await capture("inventory-balance-fr-120")
	game.inventory_selected=game.inventory_slots.find("insect_repellent"); await capture("inventory-repellent-fr-120")
	preload("res://scripts/systems/menu_hub_system.gd").close(game); game.LocaleSystem.current="ru"
	game.crafting_open=false; game.current_location="overworld"; game.player=Vector2(576,810); game.settings_state.text_scale=1.0
	game.sync_background_location(); game.update_camera(); await capture("meadow")
	print("ALCHEMY CAPTURE: "+("PASS" if errors==0 else "FAIL")); quit(0 if errors==0 else 1)

## Выбирает реальный рецепт для проверки карточки без производства и выдачи опыта.
func select(output: String) -> void:
	game.crafting_selected=game.CraftingSystem.RECIPES.find_custom(func(recipe): return recipe.get("id","")=="alchemy:"+output)

## Ждёт готовности GPU и сохраняет изображение только в каталоге технических отчётов.
func capture(label: String) -> void:
	for _frame in 8:
		game.queue_redraw(); await RenderingServer.frame_post_draw
	if root.get_texture().get_image().save_png("res://docs/reports/alchemy-2026-10-12-"+label+".png")!=OK: errors+=1
