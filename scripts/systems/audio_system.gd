extends RefCounted

const MUSIC_BY_LOCATION := {
	"overworld": "village",
	"forest": "forest",
	"rocky": "rocky",
	"ruins": "danger",
	"cave": "cave",
	"cursed": "danger",
	"glassworks": "workshop",
}
const MUSIC_PATH := "res://assets/game/audio/music/%s.wav"
const SFX_PATH := "res://assets/game/audio/sfx/%s.wav"
const SFX_IDS := [
	"step", "hoe", "plant", "water", "harvest", "mine", "attack", "hit", "defeat",
	"fish_cast", "fish_bite", "fish_catch", "pickup", "craft", "coin", "quest_accept",
	"quest_complete", "level_up", "ui_open", "travel",
]
const MUSIC_VOLUME_DB := -17.0
const SFX_VOLUME_DB := -7.0
const SILENT_DB := -45.0
const CROSSFADE_SECONDS := 0.8
const STEP_INTERVAL := 0.32
const SFX_POOL_SIZE := 6


## Выполняет изолированную операцию своей подсистемы и возвращает результат согласно контракту.
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
		player.volume_db = SFX_VOLUME_DB
		game.add_child(player)
	switch_music(game, game.current_location, true)


## Выполняет изолированную операцию своей подсистемы и возвращает результат согласно контракту.
static func switch_music(game: Node, location: String, immediate: bool = false) -> bool:
	var track: String = MUSIC_BY_LOCATION.get(location, "village")
	if track == game.audio_current_music:
		return false
	game.audio_current_music = track
	game.audio_music_slot = 1 - game.audio_music_slot
	game.audio_music_fade = CROSSFADE_SECONDS
	var incoming: AudioStreamPlayer = music_player(game, game.audio_music_slot)
	var stream: AudioStreamWAV = load(MUSIC_PATH % track)
	if stream:
		stream = stream.duplicate()
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = int(stream.get_length() * stream.mix_rate)
		incoming.stream = stream
		incoming.volume_db = MUSIC_VOLUME_DB if immediate else SILENT_DB
		if game.is_inside_tree() and game.audio_enabled:
			incoming.play()
	if immediate:
		music_player(game, 1 - game.audio_music_slot).stop()
		game.audio_music_fade = 0.0
	return true


## Выполняет изолированную операцию своей подсистемы и возвращает результат согласно контракту.
static func update(game: Node, delta: float) -> void:
	update_crossfade(game, delta)
	game.audio_step_timer = maxf(game.audio_step_timer - delta, 0.0)
	if game.title_screen or game.shop_open or game.inventory_open or game.crafting_open or game.quest_log_open or game.skill_menu_open:
		return
	if game.get_movement_direction() != Vector2.ZERO and game.audio_step_timer <= 0.0:
		play_sfx(game, "step")
		game.audio_step_timer = STEP_INTERVAL


## Обновляет плавного перехода на текущем кадре.
static func update_crossfade(game: Node, delta: float) -> void:
	if game.audio_music_fade <= 0.0:
		return
	game.audio_music_fade = maxf(game.audio_music_fade - delta, 0.0)
	var progress: float = 1.0 - game.audio_music_fade / CROSSFADE_SECONDS
	music_player(game, game.audio_music_slot).volume_db = lerpf(SILENT_DB, MUSIC_VOLUME_DB, progress)
	var outgoing := music_player(game, 1 - game.audio_music_slot)
	outgoing.volume_db = lerpf(MUSIC_VOLUME_DB, SILENT_DB, progress)
	if game.audio_music_fade <= 0.0:
		outgoing.stop()


## Выполняет изолированную операцию своей подсистемы и возвращает результат согласно контракту.
static func play_sfx(game: Node, sound_id: String) -> bool:
	if not game.audio_enabled or sound_id not in SFX_IDS:
		return false
	game.audio_last_sfx = sound_id
	game.audio_sfx_count += 1
	var player: AudioStreamPlayer = game.get_node_or_null("AudioSfx%d" % game.audio_sfx_slot)
	game.audio_sfx_slot = (game.audio_sfx_slot + 1) % SFX_POOL_SIZE
	if player:
		player.stream = load(SFX_PATH % sound_id)
		if game.is_inside_tree():
			player.play()
	return true


## Устанавливает относящееся к методу значение и синхронизирует зависимое состояние.
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
	for index in SFX_POOL_SIZE:
		var effect: AudioStreamPlayer = game.get_node_or_null("AudioSfx%d" % index)
		if effect and not enabled:
			effect.stop()


## Выполняет операцию «музыки героя» и возвращает результат согласно контракту метода.
static func music_player(game: Node, slot: int) -> AudioStreamPlayer:
	return game.get_node("AudioMusicA" if slot == 0 else "AudioMusicB")


## Проверяет заявленное методом условие без изменения игрового состояния.
static func has_all_assets() -> bool:
	for track in MUSIC_BY_LOCATION.values():
		if not ResourceLoader.exists(MUSIC_PATH % track):
			return false
	for sound_id in SFX_IDS:
		if not ResourceLoader.exists(SFX_PATH % sound_id):
			return false
	return true
