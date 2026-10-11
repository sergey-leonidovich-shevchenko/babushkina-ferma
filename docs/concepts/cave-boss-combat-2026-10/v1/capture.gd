extends SceneTree

const Boss := preload("res://scripts/systems/cave_boss_system.gd")
const OUT := "res://docs/concepts/cave-boss-combat-2026-10/v1/"

## Запускает воспроизводимый захват игровых кадров после инициализации дерева сцены.
func _initialize() -> void:
	capture.call_deferred()

## Снимает три стадии, появление существ, зомби с мухами и завершённый бой.
func capture() -> void:
	for scenario in ["phase1","phase2","phase3","pulse","impact","summons","flies","victory"]: await shot(scenario)
	quit()

## Использует настоящую сцену, игровые атаки и отрисовщик без отдельного макета локации.
func shot(scenario: String) -> void:
	seed(20261011)
	var viewport := SubViewport.new(); viewport.size=Vector2i(1152,648); viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var game := preload("res://main.tscn").instantiate(); viewport.add_child(game)
	game.set_process(false); game.set_physics_process(false); game.language_screen=false; game.title_screen=false
	game.current_location=Boss.Data.LOCATION; game.player=Vector2(1596,756); game.tutorial_visible=false
	game.discovery_current.clear(); game.discovery_timer=0.0; game.set_meta("capture_hud_clean",true)
	game.FarmLifeSystem.state(game).cutscene=""; game.FarmLifeSystem.state(game).cutscene_timer=0.0
	game.change_inventory_count("iron_spear",1); game.InventorySystem.equip(game,"iron_spear")
	var index := Boss.index(game); game.enemy_nodes[index].position=Vector2(1740,708)
	game.enemy_nodes[index].hp=120 if scenario=="phase1" else (72 if scenario=="phase2" else 32)
	Boss.start(game); var state: Dictionary = game.state.world.cave_boss
	if scenario.begins_with("phase") or scenario in ["pulse","impact"]:
		var attack: String = {"phase1":"slam","phase2":"rockfall","phase3":"cross","pulse":"pulse","impact":"slam"}[scenario]
		Boss.Attacks.begin(game,attack,game.enemy_nodes[index])
		Boss.Attacks.update(game,index,1.62 if scenario=="pulse" else (1.04 if scenario=="impact" else 0.68))
		if scenario=="impact" and not state.effects.is_empty(): state.effects[0].time=0.24
	elif scenario in ["summons","flies"]:
		Boss.Minions.summon(game,["skeleton","zombie","vampire"])
		var positions := [Vector2(1488,588),Vector2(1848,624),Vector2(1968,672)]
		for slot in state.minions.size():
			var minion: Dictionary = state.minions[slot]; minion.position=positions[slot]
			minion.emerge=[0.8,0.4,0.8][slot] if scenario=="summons" else 0.0; minion.age=0.6
		state.clock=2.4
		if scenario=="summons": state.summoning=0.55
		else:
			state.minions[1].fly_windup=0.3; state.minions[1].fly_target=game.player
			Boss.Shots.attach_fly(game,3.8); Boss.Shots.launch(game,Vector2(1730,642),Vector2(-1,0.3),0,"fly")
	elif scenario=="victory": game.CombatSystem.apply_damage(game,index,200)
	game.sync_background_location(); game.update_camera(); game.queue_redraw()
	for _frame in 8: await RenderingServer.frame_post_draw
	var result := viewport.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT+scenario+".png"))
	print("BOSS CAPTURE: ",scenario," result=",result)
	viewport.queue_free(); await process_frame
