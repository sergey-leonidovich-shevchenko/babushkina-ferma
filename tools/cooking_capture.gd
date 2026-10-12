extends SceneTree

const OUT := "res://docs/concepts/kitchen-2026-10-12/"

class ReviewGame extends "res://scripts/game.gd":
	## Не загружает и не записывает пользовательский профиль на изолированном стенде кухни.
	func _ready() -> void:
		pass

## Снимает кухонные карточки после подготовки окна Godot.
func _initialize() -> void:
	capture.call_deferred()

## Показывает настоящее окно готовки и переработки на обычном и увеличенном шрифте.
func capture() -> void:
	for mode in ["omelet","pancakes","cloth","large_text"]:
		var viewport:=SubViewport.new(); viewport.size=Vector2i(1152,648); viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS; root.add_child(viewport)
		var game:=preload("res://main.tscn").instantiate(); game.set_script(ReviewGame); game.audio_enabled=false; game.world_loot_seed=20261012
		game.GameBootstrap._initialize_services(game); game.GameBootstrap._initialize_world(game); game.GameBootstrap._initialize_runtime_systems(game)
		viewport.add_child(game); game.set_process(false); game.set_physics_process(false)
		game.title_screen=false; game.language_screen=false; game.tutorial_visible=false; game.message=""; game.discovery_current.clear(); game.discovery_timer=0
		game.FarmLifeSystem.state(game).cutscene=""; game.FirstChapterSystem.state(game).completed=true; game.current_location="cottage_interior"; game.player=Vector2(930,390)
		for kind in ["egg","milk","wheat","flour","butter","yarn","cotton"]: game.change_inventory_count(kind,3)
		game.settings_state.text_scale=1.2 if mode=="large_text" else 1.0
		game.CraftingSystem.open(game,"workbench" if mode=="cloth" else "cauldron")
		var selected: String= "omelet" if mode=="large_text" else String(mode)
		game.crafting_selected=game.CraftingSystem.RECIPES.find_custom(func(recipe): return recipe.output==selected)
		game.sync_background_location(); game.update_camera(); game.queue_redraw()
		for frame in 8: await RenderingServer.frame_post_draw
		assert(viewport.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT+mode+".png"))==OK)
		viewport.queue_free(); await process_frame
	quit()
