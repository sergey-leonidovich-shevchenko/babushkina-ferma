extends RefCounted

const MUSIC_BY_LOCATION := {
	"overworld": "village",
	"forest": "forest",
	"rocky": "rocky",
	"ruins": "danger",
	"cave": "cave",
	"cursed": "danger",
	"glassworks": "workshop",
	"pirate_ship": "pirate",
	"cottage_interior": "village", "shop_interior": "village", "guild_interior": "village",
	"forge_interior": "workshop", "chapel_interior": "cave", "prison_interior": "danger",
	"tower_interior": "forest", "castle_hall": "danger", "castle_upper": "danger", "castle_dungeon": "cave",
}
const MENU_TRACK := "menu"
const MUSIC_TRACKS := ["menu", "village", "forest", "rocky", "danger", "cave", "workshop", "pirate"]
const MUSIC_PATH := "res://assets/game/audio/music/%s.wav"
const SFX_PATH := "res://assets/game/audio/sfx/%s.wav"
const SFX_IDS := [
	"hoe", "plant", "water", "harvest", "mine", "chop", "attack", "hit", "defeat",
	"fish_cast", "fish_bite", "fish_catch", "pickup", "craft", "coin", "quest_accept",
	"quest_complete", "level_up", "ui_open", "ui_focus", "ui_press", "ui_back", "travel", "door_open", "door_close",
]
const MUSIC_VOLUME_DB := -6.0
const SFX_VOLUME_DB := -5.0
const TRAVEL_VOLUME_OFFSET_DB := -4.0
const UI_VOLUME_OFFSET_DB := -3.0
const DOOR_VOLUME_OFFSET_DB := -3.0
const SILENT_DB := -80.0
const CROSSFADE_SECONDS := 2.4
const COMBAT_ENTER_SECONDS := 0.65
const COMBAT_LEAVE_SECONDS := 4.0
const SFX_POOL_SIZE := 6


## Создаёт два музыкальных голоса и фиксированный пул эффектов; отключённые шаги не возвращаются.
static func initialize(game: Node) -> void:
	if game.get_node_or_null("AudioMusicA"):
		return
	for suffix in ["A", "B"]:
		var player := AudioStreamPlayer.new()
		player.name = "AudioMusic" + suffix
		player.volume_db = SILENT_DB
		game.add_child(player)
	for index in SFX_POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.name = "AudioSfx%d" % index
		player.volume_db = sfx_volume_db(game)
		game.add_child(player)
	switch_track(game, MENU_TRACK if game.title_screen or game.language_screen else MUSIC_BY_LOCATION.get(game.current_location, "village"), true)
	apply_volumes(game)


## Выбирает тему локации, сохраняя текущую фразу при повторном входе в тот же музыкальный контекст.
static func switch_music(game: Node, location: String, immediate: bool = false) -> bool:
	var track: String = MUSIC_BY_LOCATION.get(location, "village")
	return switch_track(game, track, immediate)


## Переключает непосредственно музыкальную тему с общим кроссфейдом.
static func switch_track(game: Node, track: String, immediate: bool = false) -> bool:
	if track == game.audio_current_music:
		return false
	if track not in MUSIC_TRACKS:
		return false
	var stream: AudioStreamWAV = load(MUSIC_PATH % track)
	if not stream:
		return false
	var outgoing := music_player(game, game.audio_music_slot)
	var level := db_to_linear(music_volume_db(game))
	game.set_meta("audio_outgoing_gain", clampf(db_to_linear(outgoing.volume_db) / maxf(level, 0.0001), 0.0, 1.0))
	game.audio_current_music = track
	game.audio_music_slot = 1 - game.audio_music_slot
	game.audio_music_fade = CROSSFADE_SECONDS
	var incoming: AudioStreamPlayer = music_player(game, game.audio_music_slot)
	if stream:
		stream = stream.duplicate()
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = int(stream.get_length() * stream.mix_rate)
		incoming.stream = stream
		incoming.volume_db = music_volume_db(game) if immediate else SILENT_DB
		if game.is_inside_tree() and game.audio_enabled:
			incoming.play()
	if immediate:
		music_player(game, 1 - game.audio_music_slot).stop()
		game.audio_music_fade = 0.0
	return true


## Обновляет музыкальный контекст, устойчивое состояние боя и непрерывные огибающие перехода.
static func update(game: Node, delta: float) -> void:
	update_context_music(game)
	update_adaptive_music(game, delta)
	update_crossfade(game, delta)


## Выбирает отдельную спокойную тему меню и возвращает музыку локации сразу после входа в игру.
static func update_context_music(game: Node) -> void:
	if game.title_screen or game.language_screen:
		game.state.player.feedback.combat_music = false
		game.set_meta("audio_threat_hold", 0.0)
		switch_track(game, MENU_TRACK)
	elif game.audio_current_music == MENU_TRACK:
		switch_music(game, game.current_location)


## Включает тревожную тему при близкой угрозе и возвращает музыку локации после боя.
static func update_adaptive_music(game: Node, delta: float = 1.0 / 60.0) -> void:
	if game.title_screen or game.language_screen: return
	var was_active := bool(game.state.player.feedback.get("combat_music", false))
	var radius: float = 500.0 if was_active else 390.0
	var threatened: bool = game.enemy_nodes.any(func(enemy): return enemy.alive and enemy.location == game.current_location and game.player.distance_to(enemy.position) <= radius)
	if threatened == was_active:
		game.set_meta("audio_threat_hold", 0.0)
		return
	# Короткое приближение к краю радиуса не обрывает мелодию, а после боя даём ей спокойно вернуться.
	var hold := float(game.get_meta("audio_threat_hold", 0.0)) + delta
	game.set_meta("audio_threat_hold", hold)
	if hold < (COMBAT_ENTER_SECONDS if threatened else COMBAT_LEAVE_SECONDS): return
	game.set_meta("audio_threat_hold", 0.0)
	game.state.player.feedback.combat_music = threatened
	switch_track(game, "danger" if threatened else MUSIC_BY_LOCATION.get(game.current_location, "village"))


## Меняет линейную амплитуду по равноэнергетической кривой: в середине перехода нет провала громкости.
static func update_crossfade(game: Node, delta: float) -> void:
	if game.audio_music_fade <= 0.0:
		return
	game.audio_music_fade = maxf(game.audio_music_fade - delta, 0.0)
	var progress: float = 1.0 - game.audio_music_fade / CROSSFADE_SECONDS
	var level := db_to_linear(music_volume_db(game))
	var incoming_gain := sin(progress * PI * 0.5)
	music_player(game, game.audio_music_slot).volume_db = gain_db(level * incoming_gain)
	var outgoing := music_player(game, 1 - game.audio_music_slot)
	var outgoing_gain := cos(progress * PI * 0.5) * float(game.get_meta("audio_outgoing_gain", 1.0))
	outgoing.volume_db = gain_db(level * outgoing_gain)
	if game.audio_music_fade <= 0.0:
		outgoing.stop()


## Воспроизводит уже подготовленный эффект с его собственным тихим профилем громкости.
static func play_sfx(game: Node, sound_id: String) -> bool:
	if not game.audio_enabled or sound_id not in SFX_IDS:
		return false
	game.audio_last_sfx = sound_id
	game.audio_sfx_count += 1
	var player: AudioStreamPlayer = game.get_node_or_null("AudioSfx%d" % game.audio_sfx_slot)
	game.audio_sfx_slot = (game.audio_sfx_slot + 1) % SFX_POOL_SIZE
	if player:
		player.set_meta("sound_id", sound_id)
		player.stream = load(SFX_PATH % sound_id)
		player.volume_db = sound_volume_db(game, sound_id)
		if game.is_inside_tree():
			player.play()
	return true


## Отключает все активные голоса либо восстанавливает только текущую музыкальную тему.
static func set_enabled(game: Node, enabled: bool) -> void:
	game.audio_enabled = enabled
	for suffix in ["A", "B"]:
		var music: AudioStreamPlayer = game.get_node_or_null("AudioMusic" + suffix)
		if not music:
			continue
		if enabled and game.is_inside_tree() and suffix == ("A" if game.audio_music_slot == 0 else "B"):
			music.play()
		else:
			music.stop()
	game.audio_music_fade = 0.0
	for index in SFX_POOL_SIZE:
		var effect: AudioStreamPlayer = game.get_node_or_null("AudioSfx%d" % index)
		if effect and not enabled:
			effect.stop()
	apply_volumes(game)


## Применяет раздельные уровни музыки и эффектов ко всем уже созданным проигрывателям.
static func apply_volumes(game: Node) -> void:
	for suffix in ["A", "B"]:
		var music: AudioStreamPlayer = game.get_node_or_null("AudioMusic" + suffix)
		if music and game.audio_music_fade <= 0.0:
			music.volume_db = music_volume_db(game) if suffix == ("A" if game.audio_music_slot == 0 else "B") else SILENT_DB
	for index in SFX_POOL_SIZE:
		var effect: AudioStreamPlayer = game.get_node_or_null("AudioSfx%d" % index)
		if effect: effect.volume_db = sound_volume_db(game, String(effect.get_meta("sound_id", "")))
	if game.audio_music_fade > 0.0: update_crossfade(game, 0.0)


## Рассчитывает итоговую громкость музыки из базового уровня, общего и музыкального ползунков.
static func music_volume_db(game: Node) -> float:
	if not game.audio_enabled or game.settings_state.master_volume <= 0.0 or game.settings_state.music_volume <= 0.0: return SILENT_DB
	return maxf(SILENT_DB, MUSIC_VOLUME_DB + linear_to_db(game.settings_state.master_volume * game.settings_state.music_volume))


## Рассчитывает итоговую громкость эффектов из базового уровня, общего и эффектного ползунков.
static func sfx_volume_db(game: Node) -> float:
	if not game.audio_enabled or game.settings_state.master_volume <= 0.0 or game.settings_state.sfx_volume <= 0.0: return SILENT_DB
	return maxf(SILENT_DB, SFX_VOLUME_DB + linear_to_db(game.settings_state.master_volume * game.settings_state.sfx_volume))


## Возвращает уровень конкретного эффекта; дверь, интерфейс и переход тише предметного контакта.
static func sound_volume_db(game: Node, sound_id: String) -> float:
	var offset := TRAVEL_VOLUME_OFFSET_DB if sound_id == "travel" else (UI_VOLUME_OFFSET_DB if sound_id.begins_with("ui_") else 0.0)
	if sound_id.begins_with("door_"): offset = DOOR_VOLUME_OFFSET_DB
	return maxf(SILENT_DB, sfx_volume_db(game) + offset)


## Переводит амплитуду в децибелы с практически неслышным нижним пределом.
static func gain_db(gain: float) -> float:
	return maxf(SILENT_DB, linear_to_db(maxf(gain, 0.0001)))


## Возвращает один из двух музыкальных голосов по стабильному номеру.
static func music_player(game: Node, slot: int) -> AudioStreamPlayer:
	return game.get_node("AudioMusicA" if slot == 0 else "AudioMusicB")


## Проверяет наличие всех используемых музыкой и событиями импортируемых ресурсов.
static func has_all_assets() -> bool:
	for track in MUSIC_TRACKS:
		if not ResourceLoader.exists(MUSIC_PATH % track):
			return false
	for sound_id in SFX_IDS:
		if not ResourceLoader.exists(SFX_PATH % sound_id):
			return false
	return true
