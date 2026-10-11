extends "res://tests/suites/suite_base.gd"


## Запускает все сценарии текущего набора тестов в фиксированном порядке.
func run() -> void:
	test_audio_assets_and_players()
	test_location_music_and_crossfade()
	test_sfx_pool_and_footstep_throttle()
	test_farming_fishing_combat_and_quest_sounds()
	test_equal_power_music_crossfade()
	test_door_effects_preserve_their_quiet_profile()
	test_combat_music_debounces_boundary_crossings()
	test_language_screen_retains_menu_music()
	test_unknown_track_does_not_destroy_current_theme()
	test_muting_mid_transition_stops_all_music_voices()
	test_exported_audio_quality_report()


## Сценарий: все звуковые ресурсы загружаются, а проигрыватели музыки и эффектов создаются.
## Исходное состояние: новая игра с включённым звуком и подготовленными музыкальными и эффектными проигрывателями.
## Ожидаемый результат: все перечисленные переходы и итоговые значения совпадают с контрактом сценария.
func test_audio_assets_and_players() -> void:
	var game := make_game()
	expect(game.AudioSystem.has_all_assets(), "all original music and sound assets are importable")
	expect(game.get_node_or_null("AudioMusicA") != null and game.get_node_or_null("AudioMusicB") != null, "music uses two players for crossfades")
	expect(game.get_node_or_null("AudioSfx5") != null, "sound effects use a six-voice pool")
	expect(game.audio_current_music == "menu", "main menu owns a separate calm music theme")
	var menu_stream: AudioStreamWAV = load(game.AudioSystem.MUSIC_PATH % "menu")
	var village_stream: AudioStreamWAV = load(game.AudioSystem.MUSIC_PATH % "village")
	expect(menu_stream.get_length() >= 79.0 and village_stream.get_length() >= 95.0, "menu and first-level themes use long developed phrases with breathing space")
	expect(menu_stream.get_length() != village_stream.get_length(), "menu and village use independently composed music rather than one shared track")
	expect(menu_stream.stereo and village_stream.stereo and menu_stream.mix_rate == 24000, "main themes retain the new acoustic stereo palette at 24 kHz")
	expect(menu_stream.format == AudioStreamWAV.FORMAT_16_BITS, "music is imported as measured PCM without lossy-transient changes")
	var travel_stream: AudioStreamWAV = load(game.AudioSystem.SFX_PATH % "travel")
	expect(travel_stream.get_length() >= 0.8, "outdoor travel keeps a soft two-note phrase without a sharp sweep")
	expect(game.AudioSystem.sound_volume_db(game, "travel") <= game.AudioSystem.sfx_volume_db(game) - 3.9, "travel melody is independently softened by at least four decibels")
	game.free()


## Сценарий: две независимые темы встречаются в середине музыкального перехода.
## Исходное состояние: деревенская тема играет на стабильной громкости, затем начинается лесная.
## Ожидаемый результат: сумма квадратов линейных амплитуд сохраняется, без старого провала на десятки децибел.
func test_equal_power_music_crossfade() -> void:
	var game := make_game()
	game.AudioSystem.switch_track(game, "village", true)
	var target: float = game.AudioSystem.music_volume_db(game)
	game.AudioSystem.switch_track(game, "forest")
	game.AudioSystem.update_crossfade(game, game.AudioSystem.CROSSFADE_SECONDS * 0.5)
	var incoming: float = game.AudioSystem.music_player(game, game.audio_music_slot).volume_db
	var outgoing: float = game.AudioSystem.music_player(game, 1 - game.audio_music_slot).volume_db
	expect(absf(incoming - (target - 3.0103)) < 0.02, "incoming halfway cue is only 3dB below its final level")
	expect(absf(outgoing - incoming) < 0.02, "crossfade has balanced midpoint levels")
	var power := pow(db_to_linear(incoming - target), 2) + pow(db_to_linear(outgoing - target), 2)
	expect(absf(power - 1.0) < 0.001, "unrelated musical themes preserve equal power through the crossfade")
	game.AudioSystem.update_crossfade(game, game.AudioSystem.CROSSFADE_SECONDS)
	expect(is_equal_approx(game.AudioSystem.music_player(game, game.audio_music_slot).volume_db, target), "crossfade reaches the exact user-selected final volume")
	game.free()


## Сценарий: игрок открывает и закрывает настоящую дверь, затем меняет общую громкость.
## Исходное состояние: герой перед домом, звуковые проигрыватели созданы, настройки доступны.
## Ожидаемый результат: деревянные эффекты отличаются от портала и сохраняют тихий профиль после настройки.
func test_door_effects_preserve_their_quiet_profile() -> void:
	var game := make_game()
	expect(game.BuildingSystem.enter(game, "cottage"), "cottage is accessible for the door sound test")
	expect(game.audio_last_sfx == "door_open", "entering the house plays wood and hinge friction")
	var slot: int = (game.audio_sfx_slot - 1 + game.AudioSystem.SFX_POOL_SIZE) % game.AudioSystem.SFX_POOL_SIZE
	var effect: AudioStreamPlayer = game.get_node("AudioSfx%d" % slot)
	expect(effect.stream.get_length() > 1.0, "door opening has enough time for a natural quiet creak")
	game.settings_state.sfx_volume = 0.6
	game.AudioSystem.apply_volumes(game)
	expect(is_equal_approx(effect.volume_db, game.AudioSystem.sound_volume_db(game, "door_open")), "changing settings does not unexpectedly amplify an active door sound")
	expect(effect.volume_db < game.AudioSystem.sfx_volume_db(game), "wooden door stays quieter than tool contact")
	game.BuildingSystem.leave(game)
	expect(game.audio_last_sfx == "door_close", "leaving the house has a separate cushioned latch sound")
	game.free()


## Сценарий: противник ненадолго подходит к радиусу угрозы и снова отходит.
## Исходное состояние: деревенская тема стабильна, один живой враг управляется сценарием.
## Ожидаемый результат: краткий контакт не перезапускает музыку, устойчивый бой включается и отпускает тему спустя паузу.
func test_combat_music_debounces_boundary_crossings() -> void:
	var game := make_game()
	game.AudioSystem.switch_track(game, "village", true)
	game.player = Vector2(500, 500)
	for enemy in game.enemy_nodes: enemy.alive = false
	var enemy = game.enemy_nodes[0]
	enemy.alive = true; enemy.location = game.current_location; enemy.position = Vector2(700, 500)
	game.AudioSystem.update_adaptive_music(game, 0.3)
	expect(game.audio_current_music == "village", "brief enemy proximity does not interrupt a peaceful phrase")
	enemy.position = Vector2(1200, 500)
	game.AudioSystem.update_adaptive_music(game, 0.3)
	enemy.position = Vector2(700, 500)
	game.AudioSystem.update_adaptive_music(game, 0.4)
	expect(game.audio_current_music == "village", "returning threat starts a fresh grace period")
	game.AudioSystem.update_adaptive_music(game, 0.3)
	expect(game.audio_current_music == "danger", "a sustained threat enters the restrained combat arrangement")
	enemy.position = Vector2(1200, 500)
	game.AudioSystem.update_adaptive_music(game, 0.2)
	expect(game.audio_current_music == "danger", "brief movement outside aggro range does not restart the village theme")
	game.AudioSystem.update_adaptive_music(game, 4.0)
	expect(game.audio_current_music == "village", "safe interval returns to the musical identity of the current location")
	game.free()


## Сценарий: выбор языка открыт, а в сохранённом мире рядом с героем находится враг.
## Исходное состояние: титульный экран закрыт, language_screen открыт, музыка боя была активна.
## Ожидаемый результат: настройки языка сохраняют спокойную тему меню и сбрасывают отложенную угрозу.
func test_language_screen_retains_menu_music() -> void:
	var game := make_game()
	game.language_screen = true
	game.state.player.feedback.combat_music = true
	game.AudioSystem.update(game, 5.0)
	expect(game.audio_current_music == "menu" and not game.state.player.feedback.combat_music, "language screen cannot be interrupted by combat audio from the world")
	game.free()


## Сценарий: ошибочный идентификатор музыки приходит в диспетчер.
## Исходное состояние: тема меню уже загружена, номер проигрывателя сохранён.
## Ожидаемый результат: неизвестная тема отклоняется без смены текущего состояния и потери музыки.
func test_unknown_track_does_not_destroy_current_theme() -> void:
	var game := make_game()
	var before: int = game.audio_music_slot
	expect(not game.AudioSystem.switch_track(game, "not_a_track"), "unknown soundtrack id is rejected safely")
	expect(game.audio_current_music == "menu" and game.audio_music_slot == before, "invalid audio request preserves the running theme")
	game.free()


## Сценарий: звук выключают в середине перехода, затем возвращают.
## Исходное состояние: одновременно затухает меню и появляется деревня.
## Ожидаемый результат: оба голоса замолкают, после включения остаётся только выбранная тема без скачка старой.
func test_muting_mid_transition_stops_all_music_voices() -> void:
	var game := make_game()
	game.AudioSystem.switch_track(game, "village")
	game.AudioSystem.update_crossfade(game, 0.7)
	game.AudioSystem.set_enabled(game, false)
	expect(game.audio_music_fade == 0.0 and game.AudioSystem.music_volume_db(game) == game.AudioSystem.SILENT_DB, "muting clears an unfinished music envelope")
	game.AudioSystem.set_enabled(game, true)
	expect(is_equal_approx(game.AudioSystem.music_player(game, game.audio_music_slot).volume_db, game.AudioSystem.music_volume_db(game)), "unmuting restores the selected theme to its configured level")
	expect(game.AudioSystem.music_player(game, 1 - game.audio_music_slot).volume_db == game.AudioSystem.SILENT_DB, "outgoing cue stays silent after unmuting")
	game.free()


## Сценарий: сборка поставляет аудиофайлы вместе с отчётом измерения реальных PCM-отсчётов.
## Исходное состояние: offline-аудит проверил WAV после генерации и сохранил JSON.
## Ожидаемый результат: все 33 действующих ресурса имеют запас пиков, чистые границы и ни одного клиппированного отсчёта.
func test_exported_audio_quality_report() -> void:
	var report: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://docs/reports/audio_quality_audit.json"))
	expect(report.get("failures", ["missing"]).is_empty(), "offline PCM audit has no failures")
	expect(report.get("files", []).size() == 33, "all eight musical themes and 25 active effects were measured")
	var audio := preload("res://scripts/systems/audio_system.gd")
	expect(float(report.preview_reference.music_base_db) == audio.MUSIC_VOLUME_DB and float(report.preview_reference.sfx_base_db) == audio.SFX_VOLUME_DB and float(report.preview_reference.door_offset_db) == audio.DOOR_VOLUME_OFFSET_DB, "listening previews document the actual game mix instead of boosted masters")
	expect(float(report.conservative_full_mix_peak) < 0.99, "even six full-volume effects plus a musical crossfade retain mix headroom")
	for entry in report.get("files", []):
		expect(FileAccess.get_sha256("res://" + String(entry.path)) == String(entry.sha256), "PCM measurement belongs to the current audio file: " + String(entry.path))
		expect(int(entry.clipped_samples) == 0 and float(entry.peak_dbfs) <= -8.9, "audio headroom: " + String(entry.path))
		expect(float(entry.endpoint_peak) == 0.0, "audio edges have no hard clicks: " + String(entry.path))


## Сценарий: смена локации плавно переводит музыку на нужную тему без лишнего перезапуска.
## Исходное состояние: новая игра с включённым звуком и подготовленными музыкальными и эффектными проигрывателями.
## Ожидаемый результат: все перечисленные переходы и итоговые значения совпадают с контрактом сценария.
func test_location_music_and_crossfade() -> void:
	var game := make_game()
	game.AudioSystem.update_context_music(game)
	expect(game.audio_current_music == "village", "leaving the title screen starts the melodic first-level theme")
	expect(game.AudioSystem.switch_music(game, "forest"), "entering a new biome changes music")
	expect(game.audio_current_music == "forest" and game.audio_music_fade > 0.0, "forest music begins an audible crossfade")
	game.AudioSystem.update_crossfade(game, game.AudioSystem.CROSSFADE_SECONDS)
	expect(game.audio_music_fade == 0.0, "music crossfade reaches a stable final state")
	expect(not game.AudioSystem.switch_music(game, "forest"), "same location does not restart its music loop")
	game.current_location = "cursed"
	game.sync_background_location()
	expect(game.audio_current_music == "danger", "cursed land selects the danger theme")
	game.title_screen = true
	game.AudioSystem.update_context_music(game)
	expect(game.audio_current_music == "menu", "returning to title crossfades back to its dedicated theme")
	game.free()


## Сценарий: пул эффектов переиспользует голоса, а отключённый звук шагов не попадает в очередь.
## Исходное состояние: новая игра с включённым звуком и подготовленными музыкальными и эффектными проигрывателями.
## Ожидаемый результат: обычный эффект звучит, неизвестные идентификаторы и шаги отклоняются, движение остаётся бесшумным.
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
	var before: int = game.audio_sfx_count
	game.AudioSystem.update(game, 0.01)
	expect(game.audio_sfx_count == before, "walking stays silent after footstep removal")
	expect(not game.play_sfx("step") and game.audio_sfx_count == before, "removed footstep cannot be played through the shared API")
	game.free()


## Сценарий: ферма, рыбалка, бой и завершение задания вызывают собственные звуки.
## Исходное состояние: новая игра с живыми целями; здоровье, позиции, оружие и добыча настраиваются сценарием.
## Ожидаемый результат: все перечисленные переходы и итоговые значения совпадают с контрактом сценария.
func test_farming_fishing_combat_and_quest_sounds() -> void:
	var game := make_game()
	game.player = Vector2(game.FARM_ORIGIN) + Vector2(-18, 24)
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
