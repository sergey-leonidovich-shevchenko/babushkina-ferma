extends SceneTree

const OUT := "res://docs/concepts/player-contact-2026-10-12/"
const Shots := preload("res://scripts/systems/player_projectile_system.gd")

class ReviewGame extends "res://scripts/game.gd":
	## Не открывает пользовательские настройки или сохранения на изолированном боевом стенде.
	func _ready() -> void:
		pass
	## Добавляет проверяемое состояние здоровья к настоящей игровой отрисовке.
	func _draw() -> void:
		super._draw(); draw_set_transform(Vector2.ZERO)
		draw_rect(Rect2(16,510,1100,38),Color(0.05,0.07,0.08,0.85))
		draw_ui_string(UI_FONT,Vector2(32,536),String(get_meta("review_label","")),HORIZONTAL_ALIGNMENT_LEFT,1070,17,Color("fff0bd"))

## Запускает нативные состояния боя после готовности окна.
func _initialize() -> void:
	capture.call_deferred()

## Снимает подготовку, полёт, контакт, промах и прерывание без чтения пользовательских слотов.
func capture() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	for mode in ["windup","flight","hit","miss","interrupted","castle"]:
		var viewport := SubViewport.new(); viewport.size=Vector2i(1152,648); viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS; root.add_child(viewport)
		var game := preload("res://main.tscn").instantiate(); game.set_script(ReviewGame); game.audio_enabled=false; game.world_loot_seed=20261012
		game.GameBootstrap._initialize_services(game); game.GameBootstrap._initialize_world(game); game.GameBootstrap._initialize_runtime_systems(game)
		viewport.add_child(game); game.set_process(false); game.set_physics_process(false)
		game.title_screen=false; game.language_screen=false; game.tutorial_visible=false; game.message=""; game.discovery_current.clear(); game.discovery_timer=0
		game.FarmLifeSystem.state(game).cutscene=""; game.FirstChapterSystem.state(game).completed=true
		game.current_location="cave"; game.player=Vector2(880,520); game.has_bow=true; game.equipped_weapon="bow"; game.resource_nodes.clear(); game.wildlife_nodes.clear(); game.hazard_nodes.clear()
		var enemy: Dictionary=game.CombatSystem.default_enemies().filter(func(value): return value.kind=="skeleton")[0]
		enemy.position=Vector2(1080,520); enemy.location="cave"; enemy.hp=50; enemy.max_hp=50; enemy.direction=Vector2.LEFT; game.enemy_nodes=[enemy]
		if mode=="castle":
			game.current_location="castle_dungeon"; game.enemy_nodes.clear(); game.mission_states.story_first_dawn=game.QuestSystem.COMPLETED
			game.state.world.castle_campaign.stage=3; game.state.world.castle_campaign.boss_alive=true
			game.player=game.CastleCampaignSystem.BOSS_POSITION+Vector2(80,0); game.change_inventory_count("sword",1); game.equipped_weapon="forest_sword"
		game.sync_background_location(); game.camera_offset=Vector2(432,240) if mode!="castle" else Vector2.ZERO
		game.get_node("WorldBackground").position=-game.camera_offset
		assert(game.attack_nearest_enemy())
		if mode=="miss": game.enemy_nodes[0].position+=Vector2(0,100)
		if mode=="interrupted":
			game.WeaponSystem.update(game,0.25); game.CombatSystem.damage_player(game,1,"Контакт до выпуска"); game.WeaponSystem.update(game,0.4)
		else: game.WeaponSystem.update(game,{"windup":0.25,"flight":0.66,"hit":1.1,"miss":0.66,"castle":0.24}[mode])
		var hp: int=game.state.world.castle_campaign.boss_hp if mode=="castle" else game.enemy_nodes[0].hp
		assert((hp<50)==(mode=="hit") if mode!="castle" else hp<game.CastleCampaignSystem.BOSS_MAX_HP)
		var title: String={"windup":"Натяжение: урона ещё нет","flight":"Стрела летит: урона ещё нет","hit":"Стрела коснулась тела: один урон","miss":"Цель ушла с линии: промах","interrupted":"Замах прерван: стрела не выпущена","castle":"Регент: тело и физическая опора на полу"}[mode]
		game.set_meta("review_label","%s · HP цели %d · снарядов %d" % [title,hp,Shots.state(game).size()]); game.queue_redraw()
		for frame in 8: await RenderingServer.frame_post_draw
		assert(viewport.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT+mode+".png"))==OK)
		viewport.queue_free(); await process_frame
	quit()
