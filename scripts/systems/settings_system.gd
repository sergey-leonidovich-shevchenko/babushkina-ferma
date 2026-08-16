extends RefCounted

const SETTINGS_PATH := "user://farm-settings.cfg"
const VOLUME_STEP := 0.1
const SETTINGS_SCHEMA := 4

class SettingsState:
	var master_volume := 1.0
	var music_volume := 0.7
	var sfx_volume := 0.9
	var fullscreen_enabled := true
	var vsync_enabled := true
	var reduced_motion := false
	var screen_shake_enabled := true
	var high_contrast := false
	var control_preset := "standard"
	var text_scale := 1.0
	var touch_scale := 1.0


## Загружает пользовательские параметры, нормализует значения и применяет их к доступным системам устройства.
static func load(game: Node, path: String = SETTINGS_PATH, apply_display: bool = true) -> bool:
	var config := ConfigFile.new()
	var loaded := config.load(path) == OK
	game.audio_enabled = bool(config.get_value("audio", "enabled", true))
	game.settings_state.master_volume = clampf(float(config.get_value("audio", "master", 1.0)), 0.0, 1.0)
	game.settings_state.music_volume = clampf(float(config.get_value("audio", "music", 0.7)), 0.0, 1.0)
	game.settings_state.sfx_volume = clampf(float(config.get_value("audio", "effects", 0.9)), 0.0, 1.0)
	game.settings_state.fullscreen_enabled = bool(config.get_value("display", "fullscreen", true))
	game.settings_state.vsync_enabled = bool(config.get_value("display", "vsync", true))
	game.settings_state.reduced_motion = bool(config.get_value("accessibility", "reduced_motion", false))
	game.settings_state.screen_shake_enabled = bool(config.get_value("accessibility", "screen_shake", true))
	game.settings_state.high_contrast = bool(config.get_value("accessibility", "high_contrast", false))
	game.settings_state.control_preset = String(config.get_value("controls", "preset", "standard")) if String(config.get_value("controls", "preset", "standard")) in ["standard","left_handed"] else "standard"
	game.settings_state.text_scale = game.UiScaleSystem.normalized_scale(float(config.get_value("accessibility", "text_scale", 1.0)), game.UiScaleSystem.TEXT_SCALES)
	game.settings_state.touch_scale = game.UiScaleSystem.normalized_scale(float(config.get_value("controls", "touch_scale", 1.0)), game.UiScaleSystem.TOUCH_SCALES)
	var previous_schema:=int(config.get_value("meta","schema_version",1))
	if loaded and previous_schema<SETTINGS_SCHEMA:
		if previous_schema<2: game.settings_state.fullscreen_enabled=true; config.set_value("display","fullscreen",true)
		config.set_value("accessibility","reduced_motion",game.settings_state.reduced_motion); config.set_value("accessibility","screen_shake",game.settings_state.screen_shake_enabled); config.set_value("accessibility","high_contrast",game.settings_state.high_contrast); config.set_value("accessibility","text_scale",game.settings_state.text_scale); config.set_value("controls","preset",game.settings_state.control_preset); config.set_value("controls","touch_scale",game.settings_state.touch_scale); config.set_value("meta","schema_version",SETTINGS_SCHEMA); config.save(path)
	if apply_display and game.is_inside_tree():
		apply_display_settings(game)
	if game.get_node_or_null("AudioMusicA"):
		game.AudioSystem.apply_volumes(game)
	game.InputSystem.apply_control_preset(game.settings_state.control_preset)
	return loaded


## Сохраняет все параметры в общем конфигурационном файле, не удаляя выбранный язык.
static func save(game: Node, path: String = SETTINGS_PATH) -> bool:
	var config := ConfigFile.new()
	config.load(path)
	config.set_value("meta", "schema_version", SETTINGS_SCHEMA)
	config.set_value("language", "locale", game.LocaleSystem.current)
	config.set_value("audio", "enabled", game.audio_enabled)
	config.set_value("audio", "master", game.settings_state.master_volume)
	config.set_value("audio", "music", game.settings_state.music_volume)
	config.set_value("audio", "effects", game.settings_state.sfx_volume)
	config.set_value("display", "fullscreen", game.settings_state.fullscreen_enabled)
	config.set_value("display", "vsync", game.settings_state.vsync_enabled)
	config.set_value("accessibility", "reduced_motion", game.settings_state.reduced_motion)
	config.set_value("accessibility", "screen_shake", game.settings_state.screen_shake_enabled)
	config.set_value("accessibility", "high_contrast", game.settings_state.high_contrast)
	config.set_value("accessibility", "text_scale", game.settings_state.text_scale)
	config.set_value("controls", "preset", game.settings_state.control_preset)
	config.set_value("controls", "touch_scale", game.settings_state.touch_scale)
	return config.save(path) == OK


## Применяет полноэкранный режим и вертикальную синхронизацию к активному окну игры.
static func apply_display_settings(game: Node) -> void:
	if not game.is_inside_tree():
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if game.settings_state.fullscreen_enabled else DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if game.settings_state.vsync_enabled else DisplayServer.VSYNC_DISABLED)


## Возвращает громкость как округлённый процент для стабильного отображения и тестирования.
static func percent(value: float) -> int:
	return roundi(clampf(value, 0.0, 1.0) * 100.0)
