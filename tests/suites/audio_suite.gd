extends "res://tests/suites/suite_base.gd"


## Запускает все сценарии текущего набора тестов в фиксированном порядке.
func run() -> void:
	test_audio_assets_and_players()
	test_location_music_and_crossfade()
	test_sfx_pool_and_footstep_throttle()
	test_farming_fishing_combat_and_quest_sounds()


## Сценарий: все звуковые ресурсы загружаются, а проигрыватели музыки и эффектов создаются.
## Исходное состояние: новая игра с включённым звуком и подготовленными музыкальными и эффектными проигрывателями.
## Ожидаемый результат: все перечисленные переходы и итоговые значения совпадают с контрактом сценария.
func test_audio_assets_and_players() -> void:
	var game := make_game()
	expect(game.AudioSystem.has_all_assets(), "all original music and sound assets are importable")
	expect(game.get_node_or_null("AudioMusicA") != null and game.get_node_or_null("AudioMusicB") != null, "music uses two players for crossfades")
	expect(game.get_node_or_null("AudioSfx5") != null, "sound effects use a six-voice pool")
	expect(game.audio_current_music == "village", "village theme starts in the overworld")
	game.free()


## Сценарий: смена локации плавно переводит музыку на нужную тему без лишнего перезапуска.
## Исходное состояние: новая игра с включённым звуком и подготовленными музыкальными и эффектными проигрывателями.
## Ожидаемый результат: все перечисленные переходы и итоговые значения совпадают с контрактом сценария.
func test_location_music_and_crossfade() -> void:
	var game := make_game()
	expect(game.AudioSystem.switch_music(game, "forest"), "entering a new biome changes music")
	expect(game.audio_current_music == "forest" and game.audio_music_fade > 0.0, "forest music begins an audible crossfade")
	game.AudioSystem.update_crossfade(game, game.AudioSystem.CROSSFADE_SECONDS)
	expect(game.audio_music_fade == 0.0, "music crossfade reaches a stable final state")
	expect(not game.AudioSystem.switch_music(game, "forest"), "same location does not restart its music loop")
	game.current_location = "cursed"
	game.sync_background_location()
	expect(game.audio_current_music == "danger", "cursed land selects the danger theme")
	game.free()


## Сценарий: пул эффектов переиспользует голоса, а шаги не воспроизводятся каждый кадр.
## Исходное состояние: новая игра с включённым звуком и подготовленными музыкальными и эффектными проигрывателями.
## Ожидаемый результат: все перечисленные переходы и итоговые значения совпадают с контрактом сценария.
func test_sfx_pool_and_footstep_throttle() -> void:
	var game := make_game()
	var initial_slot: int = game.audio_sfx_slot
	expect(game.play_sfx("pickup") and game.audio_last_sfx == "pickup", "valid sound effect plays through the shared API")
	expect(game.audio_sfx_slot == (initial_slot + 1) % game.AudioSystem.SFX_POOL_SIZE, "sound pool rotates voices for overlapping effects")
	expect(not game.play_sfx("missing_sound"), "unknown sound ids are rejected")
	game.AudioSystem.set_enabled(game, false)
	expect(not game.audio_enabled and not game.play_sfx("pickup"), "muted audio rejects effects without growing the voice pool")
	game.AudioSystem.set_enabled(game, true)
	game.move_right_held = true
	game.audio_step_timer = 0.0
	var before: int = game.audio_sfx_count
	game.AudioSystem.update(game, 0.01)
	expect(game.audio_last_sfx == "step" and game.audio_sfx_count == before + 1, "walking produces an immediate footstep")
	game.AudioSystem.update(game, 0.01)
	expect(game.audio_sfx_count == before + 1, "footsteps are throttled instead of firing every frame")
	game.free()


## Сценарий: ферма, рыбалка, бой и завершение задания вызывают собственные звуки.
## Исходное состояние: новая игра с живыми целями; здоровье, позиции, оружие и добыча настраиваются сценарием.
## Ожидаемый результат: все перечисленные переходы и итоговые значения совпадают с контрактом сценария.
func test_farming_fishing_combat_and_quest_sounds() -> void:
	var game := make_game()
	game.player = Vector2(390, 240)
	game.facing = Vector2.RIGHT
	game.selected_tool = game.Tool.HOE
	game.use_selected_tool()
	expect(game.audio_last_sfx == "hoe", "tilling soil has a dedicated sound")
	game.player = game.pond_position
	game.selected_tool = game.Tool.ROD
	game.action_held = true
	game.use_fishing_rod()
	expect(game.audio_last_sfx == "fish_cast", "casting the fishing rod has a dedicated sound")
	game.action_held = false
	game.update_fishing(0.01)
	game.state.fishing.timer = 0.0
	game.update_fishing(0.01)
	expect(game.audio_last_sfx == "fish_bite", "fish bite has an attention sound")
	game.player = game.slime_position
	game.attack_slime()
	expect(game.audio_last_sfx == "hit", "combat layers attack and hit feedback")
	game.quest_active = true
	game.carrots = 10
	game.talk_to_grandmother()
	expect(game.audio_last_sfx == "quest_complete", "quest completion uses a reward fanfare")
	expect(game.tutorial_events_completed.has("audio_feedback"), "sound feedback has tutorial coverage")
	game.free()
