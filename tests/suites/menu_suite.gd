extends "res://tests/suites/suite_base.gd"

const TEST_SAVE_PATH := "user://menu-suite-save.json"
const TEST_SETTINGS_PATH := "user://menu-suite-settings.cfg"


## Запускает все сценарии главного меню, паузы, сохранений, настроек и универсального ввода.
func run() -> void:
	test_title_continue_and_new_game_contract()
	test_pause_stops_world_and_resumes()
	test_pause_save_and_load_cycle()
	test_fullscreen_is_default_and_migrates_legacy_windowed_config()
	test_settings_persist_and_apply_audio_levels()
	test_accessibility_and_control_preset_are_effective_and_persistent()
	test_title_visual_design_assets_and_layout()
	test_shared_ui_kit_has_independent_scalable_components()
	test_adaptive_viewport_text_and_touch_contract()
	test_menu_keyboard_gamepad_touch_and_layout()
	test_settings_grid_confirmation_and_save_summary()
	test_defeat_screen_pauses_and_resumes_safely()
	test_exit_is_safe_outside_scene_tree()


## Сценарий: главное меню корректно различает продолжение и начало новой игры.
## Исходное состояние: сначала файл отсутствует, затем создаётся валидное сохранение с известным количеством монет.
## Ожидаемый результат: недоступное продолжение пропускается, а доступное загружает точное состояние и закрывает титульный экран.
func test_title_continue_and_new_game_contract() -> void:
	cleanup_files()
	var game := make_game()
	game.title_screen = true
	game.MenuSystem.prepare_title(game, TEST_SAVE_PATH)
	expect(game.menu_state.title_selected == 1 and not game.MenuSystem.has_save(game, TEST_SAVE_PATH), "title selects new game when no save exists")
	game.MenuSystem.move_selection(game, -1, TEST_SAVE_PATH)
	expect(game.menu_state.title_selected == 3, "title navigation skips disabled Continue")
	game.coins = 246
	expect(game.SaveSystem.save_at(game, TEST_SAVE_PATH), "menu fixture creates an atomic save")
	game.MenuSystem.prepare_title(game, TEST_SAVE_PATH)
	expect(game.menu_state.title_selected == 0 and game.MenuSystem.has_save(game, TEST_SAVE_PATH), "title selects Continue when a save exists")
	game.coins = 1
	expect(game.MenuSystem.activate_title(game, TEST_SAVE_PATH), "Continue accepts a valid save")
	expect(not game.title_screen and game.coins == 246, "Continue restores progress and enters the world")
	game.free()
	cleanup_files()


## Сценарий: титульный экран использует самостоятельный атмосферный арт, кириллический шрифт и встроенную доску меню.
## Исходное состояние: ресурсы меню импортированы, а четыре hit-зоны должны совпадать с нарисованными плашками справа.
## Ожидаемый результат: фон имеет нативное разрешение, Alice содержит кириллицу с fallback, а название и кнопки занимают разные безопасные области.
func test_title_visual_design_assets_and_layout() -> void:
	var game := make_game()
	expect(game.TITLE_ART.resource_path.ends_with("title_background_v2.png") and game.TITLE_ART.get_size() == Vector2(1152, 648), "title uses the native-resolution authored farm-and-adventure background")
	expect(game.MENU_FONT.has_char("Б".unicode_at(0)) and game.MENU_FONT.get_string_size("БАБУШКИНА ФЕРМА", HORIZONTAL_ALIGNMENT_LEFT, -1, 54).x > 300.0, "Alice menu font imports real Cyrillic title glyphs")
	expect(game.MENU_FONT.has_char("菜".unicode_at(0)), "menu font keeps the configured CJK fallback for every supported locale")
	expect(FileAccess.file_exists("res://assets/game/fonts/Alice-OFL.txt"), "bundled decorative font keeps its open license beside the asset")
	expect(game.MenuRenderer.TITLE_BUTTON_SELECTED_ART.resource_path.ends_with("title_button_selected_v1.png") and game.MenuRenderer.TITLE_BUTTON_SELECTED_ART.get_size() == Vector2(238, 56), "selected title row uses its own fitted pixel-art sprite instead of sampling the full background")
	var selected_image: Image = game.MenuRenderer.TITLE_BUTTON_SELECTED_ART.get_image()
	expect(selected_image.get_pixel(0, 0).a == 0.0 and selected_image.get_pixel(119, 28).a > 0.9, "selected title sprite has transparent corners and an opaque illuminated center")
	var painted_board := Rect2(786, 300, 306, 268)
	for index in game.MenuSystem.TITLE_ITEMS.size():
		expect(painted_board.encloses(game.MenuRenderer.title_item_rect(index)), "title hit row fits its painted inventory-style button: %d" % index)
		expect(game.MenuRenderer.title_selected_art_rect(game.MenuRenderer.title_item_rect(index)).get_center() == game.MenuRenderer.title_item_rect(index).get_center(), "selected title art stays centered on its painted button: %d" % index)
	expect(not game.MenuRenderer.TITLE_WORDMARK_RECT.intersects(game.MenuRenderer.TITLE_PANEL), "storybook wordmark stays clear of the integrated menu board")
	var highlight_dark: Color = game.MenuRenderer.title_highlight_modulate(0)
	var highlight_bright: Color = game.MenuRenderer.title_highlight_modulate(408)
	expect(highlight_dark.a < highlight_bright.a and highlight_bright.a <= 1.0, "selected title art breathes with a bounded opacity pulse")
	game.free()


## Сценарий: системные меню используют единый набор нарисованных компонентов вместо процедурных прямоугольников.
## Исходное состояние: UI Kit нарезан на независимые PNG, а манифест задаёт базовую сетку и nine-patch поля.
## Ожидаемый результат: все компоненты прозрачны по углам, имеют собственный файл и формируют кэшируемые масштабируемые стили.
func test_shared_ui_kit_has_independent_scalable_components() -> void:
	var game := make_game()
	var kit = game.MenuRenderer.UiKitSystem
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/game/ui/ui_kit_manifest.json"))
	expect(int(manifest.design_viewport[0]) == 1152 and int(manifest.design_viewport[1]) == 648 and int(manifest.base_spacing) == 8, "UI kit fixes the native viewport and eight-pixel spacing contract")
	expect(kit.TEXTURES.size() == 16 and manifest.components.size() == 16, "manifest and runtime register all sixteen authored UI components")
	for component in kit.TEXTURES:
		var texture: Texture2D = kit.texture(component)
		var image: Image = texture.get_image()
		expect(texture.resource_path.contains("/kit_v1/") and image.get_pixel(0, 0).a == 0.0 and image.get_pixel(image.get_width() - 1, image.get_height() - 1).a == 0.0, "%s is an independent transparent sprite without atlas bleed" % component)
	for component in kit.NINE_PATCH_MARGINS:
		var first: StyleBoxTexture = kit.style(component)
		expect(first == kit.style(component) and first.texture == kit.texture(component), "%s reuses a cached nine-patch style with the matching authored texture" % component)
	var centered: Rect2 = kit.centered_content_rect(Rect2(100, 100, 64, 64), Vector2(128, 32), 8)
	expect(centered.get_center() == Vector2(132, 132) and centered.size == Vector2(48, 12), "oversized wide content scales down and remains flex-centered inside its safe area")
	game.free()


## Сценарий: интерфейс сохраняет пропорции, читаемость и точные касания на Full HD, 2K, 4K и экране с safe-area.
## Исходное состояние: внутренний viewport зафиксирован на 1152×648, включены увеличенный текст и крупные сенсорные кнопки.
## Ожидаемый результат: все разрешения используют единый масштаб, преобразования обратимы, текст не переполняет строку, а hit-зоны совпадают с рисунком.
func test_adaptive_viewport_text_and_touch_contract() -> void:
	var game := make_game(); var scale_system = game.UiScaleSystem
	expect(ProjectSettings.get_setting("display/window/size/viewport_width") == 1152 and ProjectSettings.get_setting("display/window/size/viewport_height") == 648 and ProjectSettings.get_setting("display/window/stretch/aspect") == "keep", "project fixes one undistorted design viewport for every display density")
	for resolution in [Vector2(1920,1080), Vector2(2560,1440), Vector2(3840,2160)]:
		var layout: Dictionary = scale_system.viewport_layout(resolution)
		expect(absf(float(layout.scale) - resolution.x / 1152.0) < 0.001 and Vector2(layout.offset).length() < 0.01, "%s scales the sixteen-by-nine canvas without letterbox drift" % resolution)
		var design_point := Vector2(937, 520)
		expect(scale_system.screen_to_design(scale_system.design_to_screen(design_point,resolution),resolution).is_equal_approx(design_point), "%s keeps rendered controls and pointer coordinates reversible" % resolution)
	var ultrawide := Vector2(2400,1080); var physical_safe := Rect2(300,54,1800,972)
	var safe_design: Rect2 = scale_system.safe_area_design(ultrawide,physical_safe)
	expect(Rect2(Vector2.ZERO,scale_system.DESIGN_SIZE).encloses(safe_design) and safe_design.size.x < scale_system.DESIGN_SIZE.x, "safe-area is converted into the letterboxed design canvas and clipped to visible content")
	game.settings_state.text_scale = 1.2
	var fitted: int = scale_system.fitted_font_size(game,game.UI_FONT,"VERY LONG LOCALIZED INTERFACE LABEL",200.0,14)
	expect(fitted <= 17 and game.UI_FONT.get_string_size("VERY LONG LOCALIZED INTERFACE LABEL",HORIZONTAL_ALIGNMENT_LEFT,-1,fitted).x <= 200.0, "large text preference stays bounded by the real localized label container")
	game.settings_state.touch_scale = 1.3
	var dodge: Rect2 = game.InterfaceRenderer.dodge_button_rect(game); var block: Rect2 = game.InterfaceRenderer.block_button_rect(game)
	expect(dodge.size.x > game.InterfaceRenderer.DODGE_BUTTON.size.x and dodge.size.y >= 48.0 and not dodge.intersects(block), "large touch controls grow around their centers without overlapping adjacent actions")
	expect(game.InterfaceRenderer.VIEWPORT.encloses(dodge) and game.InterfaceRenderer.VIEWPORT.encloses(block), "enlarged touch controls remain inside the design safe-area")
	var preview := Image.load_from_file(ProjectSettings.globalize_path("res://assets/generated/ui/adaptive_ui_ingame_preview.png"))
	expect(preview != null and preview.get_size() == Vector2i(1152,648), "adaptive settings visual reference covers text and touch scaling on the native design canvas")
	game.free()


## Сценарий: открытая пауза полностью останавливает игровое время и безопасно возобновляет его.
## Исходное состояние: активный мир без модальных окон и известное значение игровых минут.
## Ожидаемый результат: Esc-меню фиксирует время, очищает движение и пункт продолжения возвращает обновления кадра.
func test_pause_stops_world_and_resumes() -> void:
	var game := make_game()
	game.game_minutes = 120.0
	game.move_right_held = true
	expect(game.MenuSystem.open_pause(game), "pause opens from active gameplay")
	expect(game.menu_state.pause_open and not game.move_right_held and game.tutorial_events_completed.has("pause_menu"), "pause clears movement and completes its tutorial step")
	game._physics_process(2.0)
	expect(game.game_minutes == 120.0, "pause freezes calendar and world simulation")
	game.menu_state.pause_selected = 0
	game.MenuSystem.activate_pause(game)
	game._physics_process(1.0)
	expect(not game.menu_state.pause_open and game.game_minutes > 120.0, "Resume restores world simulation")
	game.free()


## Сценарий: сохранение и загрузка доступны из меню паузы без горячих клавиш.
## Исходное состояние: тестовый путь пуст, пауза открыта, а состояние экономики заранее известно.
## Ожидаемый результат: сохранение создаётся атомарно, загрузка восстанавливает данные и автоматически закрывает паузу.
func test_pause_save_and_load_cycle() -> void:
	cleanup_files()
	var game := make_game()
	game.coins = 321
	game.MenuSystem.open_pause(game)
	game.menu_state.pause_selected = 1
	expect(game.MenuSystem.activate_pause(game, TEST_SAVE_PATH), "pause Save creates a valid file")
	expect(game.menu_state.notice == game.LocaleSystem.text("saved") and game.tutorial_events_completed.has("save"), "pause Save reports success and teaches saving")
	game.coins = 7
	game.menu_state.pause_selected = 2
	expect(game.MenuSystem.activate_pause(game, TEST_SAVE_PATH), "pause Load accepts the saved game")
	expect(game.coins == 321 and not game.menu_state.pause_open, "pause Load restores state and resumes")
	game.free()
	cleanup_files()


## Сценарий: приложение стартует на весь экран и обновляет старую оконную настройку только один раз.
## Исходное состояние: проект имеет полноэкранный boot-mode, а старый конфиг содержит fullscreen=false без версии схемы.
## Ожидаемый результат: первый запуск мигрирует режим в fullscreen, новая игра его сохраняет, а последующий явный выбор пользователя остаётся доступен.
func test_fullscreen_is_default_and_migrates_legacy_windowed_config() -> void:
	cleanup_files()
	var game := make_game()
	expect(ProjectSettings.get_setting("display/window/size/mode") == 3, "project opens fullscreen before the first game scene is ready")
	expect(game.settings_state.fullscreen_enabled, "fresh settings default to fullscreen")
	var legacy := ConfigFile.new()
	legacy.set_value("display","fullscreen",false)
	expect(legacy.save(TEST_SETTINGS_PATH) == OK, "legacy windowed settings fixture is written")
	expect(game.SettingsSystem.load(game,TEST_SETTINGS_PATH,false), "legacy display settings are loaded")
	expect(game.settings_state.fullscreen_enabled, "legacy implicit windowed default migrates to fullscreen")
	var migrated := ConfigFile.new()
	expect(migrated.load(TEST_SETTINGS_PATH) == OK and int(migrated.get_value("meta","schema_version",0)) == game.SettingsSystem.SETTINGS_SCHEMA, "fullscreen migration records the current settings schema")
	game.title_screen = true
	game.MenuSystem.start_new_game(game)
	expect(not game.title_screen and game.settings_state.fullscreen_enabled, "starting gameplay from title keeps fullscreen state")
	game.settings_state.fullscreen_enabled = false
	expect(game.SettingsSystem.save(game,TEST_SETTINGS_PATH), "explicit later windowed choice can be saved")
	var schema_two:=ConfigFile.new(); schema_two.load(TEST_SETTINGS_PATH); schema_two.set_value("meta","schema_version",2); schema_two.save(TEST_SETTINGS_PATH)
	var restored := make_game()
	expect(restored.SettingsSystem.load(restored,TEST_SETTINGS_PATH,false) and not restored.settings_state.fullscreen_enabled, "explicit schema-v2 windowed choice remains respected during accessibility migration")
	game.free(); restored.free()
	cleanup_files()


## Сценарий: раздельные настройки звука, экрана и языка переживают новый запуск.
## Исходное состояние: чистый конфигурационный файл и игра со значениями по умолчанию вне реального окна.
## Ожидаемый результат: проценты, переключатели и язык сохраняются, нормализуются и меняют расчёт громкости плееров.
func test_settings_persist_and_apply_audio_levels() -> void:
	cleanup_files()
	var game := make_game()
	game.LocaleSystem.set_locale("ru", false)
	game.MenuSystem.open_settings(game, false)
	game.menu_state.settings_selected = 0; game.MenuSystem.adjust_setting(game, -1, TEST_SETTINGS_PATH, false)
	game.menu_state.settings_selected = 1; game.MenuSystem.adjust_setting(game, 1, TEST_SETTINGS_PATH, false)
	game.menu_state.settings_selected = 2; game.MenuSystem.adjust_setting(game, -1, TEST_SETTINGS_PATH, false)
	game.menu_state.settings_selected = 3; game.MenuSystem.adjust_setting(game, 1, TEST_SETTINGS_PATH, false)
	game.menu_state.settings_selected = 4; game.MenuSystem.adjust_setting(game, 1, TEST_SETTINGS_PATH, false)
	game.menu_state.settings_selected = 5; game.MenuSystem.adjust_setting(game, 1, TEST_SETTINGS_PATH, false)
	game.menu_state.settings_selected = 10; game.MenuSystem.adjust_setting(game, 1, TEST_SETTINGS_PATH, false)
	game.menu_state.settings_selected = 11; game.MenuSystem.adjust_setting(game, 1, TEST_SETTINGS_PATH, false)
	game.menu_state.settings_selected = 12; game.MenuSystem.adjust_setting(game, 1, TEST_SETTINGS_PATH, false)
	expect(game.SettingsSystem.percent(game.settings_state.master_volume) == 90 and game.SettingsSystem.percent(game.settings_state.music_volume) == 80 and game.SettingsSystem.percent(game.settings_state.sfx_volume) == 80, "three volume controls move independently in ten-percent steps")
	expect(not game.audio_enabled and not game.settings_state.fullscreen_enabled and not game.settings_state.vsync_enabled, "sound fullscreen and VSync toggles change independently")
	expect(game.AudioSystem.music_volume_db(game) == game.AudioSystem.SILENT_DB and game.AudioSystem.sfx_volume_db(game) == game.AudioSystem.SILENT_DB, "disabled sound mutes both calculated audio channels")
	var restored := make_game()
	restored.LocaleSystem.load_locale(TEST_SETTINGS_PATH)
	expect(restored.SettingsSystem.load(restored, TEST_SETTINGS_PATH, false), "settings file loads on a later launch")
	expect(restored.SettingsSystem.percent(restored.settings_state.master_volume) == 90 and restored.SettingsSystem.percent(restored.settings_state.music_volume) == 80 and restored.SettingsSystem.percent(restored.settings_state.sfx_volume) == 80, "later launch restores all volume controls")
	expect(not restored.audio_enabled and not restored.settings_state.fullscreen_enabled and not restored.settings_state.vsync_enabled and restored.LocaleSystem.current == "en", "later launch restores switches and selected language")
	expect(is_equal_approx(restored.settings_state.text_scale, 1.1) and is_equal_approx(restored.settings_state.touch_scale, 1.15), "later launch restores adaptive text and touch scales")
	expect(restored.tutorial_events_completed.is_empty() and game.tutorial_events_completed.has("settings"), "opening settings has tutorial coverage without polluting a new game")
	game.LocaleSystem.set_locale("ru", false)
	game.free(); restored.free()
	cleanup_files()


## Сценарий: игрок включает доступность и выбирает леворукую схему управления из обычного меню.
## Исходное состояние: анимации, дрожание и стандартные WASD включены, настройки ещё не сохранены.
## Ожидаемый результат: эффекты успокаиваются, контраст усиливается, IJKL управляют героем и весь выбор переживает запуск.
func test_accessibility_and_control_preset_are_effective_and_persistent() -> void:
	cleanup_files(); var game:=make_game(); game.MenuSystem.open_settings(game,false)
	for setting_index in [6,7,8,9]: game.menu_state.settings_selected=setting_index; game.MenuSystem.adjust_setting(game,1,TEST_SETTINGS_PATH,false)
	expect(game.settings_state.reduced_motion and not game.settings_state.screen_shake_enabled and game.settings_state.high_contrast and game.settings_state.control_preset=="left_handed","accessibility switches and left-handed preset change independently")
	game.AdventurePolishSystem.begin_action(game,"hit",game.player); expect(game.AdventurePolishSystem.shake_offset(game)==Vector2.ZERO,"reduced motion and disabled shake suppress camera displacement")
	expect(is_equal_approx(game.MenuRenderer.title_highlight_modulate(0,true).a,game.MenuRenderer.title_highlight_modulate(408,true).a),"reduced motion turns the title pulse into a stable highlight")
	var left_event:=key_event(KEY_J,KEY_J,true); expect(game.PlayerSystem.update_movement_key(game,left_event) and game.move_left_held,"left-handed preset remaps world movement through InputMap")
	game.PlayerSystem.clear_keys(game); var old_event:=key_event(KEY_A,KEY_A,true); expect(not game.PlayerSystem.update_movement_key(game,old_event),"old WASD binding no longer fires after an explicit remap")
	var restored:=make_game(); expect(restored.SettingsSystem.load(restored,TEST_SETTINGS_PATH,false) and restored.settings_state.reduced_motion and restored.settings_state.high_contrast and restored.settings_state.control_preset=="left_handed","accessibility and control preset persist across launch")
	game.InputSystem.apply_control_preset("standard"); game.free(); restored.free(); cleanup_files()


## Сценарий: меню одинаково управляется клавиатурой, геймпадом и касанием по видимым строкам.
## Исходное состояние: главное меню без сохранения и стабильная геометрия всех трёх системных окон.
## Ожидаемый результат: направления меняют фокус, подтверждение открывает экран, касание попадает в строку, а панели не выходят за viewport.
func test_menu_keyboard_gamepad_touch_and_layout() -> void:
	var game := make_game()
	game.title_screen = true
	game.menu_state.title_selected = 1
	expect(game.MenuSystem.handle_input(game, key_event(KEY_DOWN, KEY_DOWN, true), TEST_SETTINGS_PATH, false) and game.menu_state.title_selected == 2, "keyboard Down moves title selection")
	game.MenuSystem.handle_input(game, key_event(KEY_ENTER, KEY_ENTER, true), TEST_SETTINGS_PATH, false)
	expect(game.menu_state.settings_open, "keyboard Enter activates selected Settings")
	var back := InputEventJoypadButton.new(); back.button_index = JOY_BUTTON_B; back.pressed = true
	game.MenuSystem.handle_input(game, back, TEST_SETTINGS_PATH, false)
	expect(not game.menu_state.settings_open, "gamepad B returns from settings")
	var touch := InputEventScreenTouch.new(); touch.pressed = true; touch.position = game.MenuRenderer.title_item_rect(1).get_center()
	expect(game.MenuSystem.handle_input(game, touch, TEST_SETTINGS_PATH, false) and not game.title_screen, "touch activates the exact New Game row")
	var viewport := Rect2(0, 0, 1152, 648)
	expect(viewport.encloses(game.MenuRenderer.TITLE_PANEL) and viewport.encloses(game.MenuRenderer.PAUSE_PANEL) and viewport.encloses(game.MenuRenderer.SETTINGS_PANEL), "all system panels fit the native viewport")
	expect(game.MenuRenderer.title_item_at(game.MenuRenderer.title_item_rect(3).get_center()) == 3 and game.MenuRenderer.pause_item_at(game.MenuRenderer.pause_item_rect(5).get_center()) == 5 and game.MenuRenderer.settings_item_at(game.MenuRenderer.settings_item_rect(11).get_center()) == 11, "mouse and touch hit zones match rendered menu rows")
	expect(viewport.encloses(game.InterfaceRenderer.PAUSE_BUTTON) and not game.InterfaceRenderer.PAUSE_BUTTON.intersects(game.InterfaceRenderer.hotbar_rect(0)), "touch pause control stays inside HUD and away from hotbar")
	game.free()


## Сценарий: настройки, сохранение и опасные команды используют завершённый системный UX.
## Исходное состояние: открыты параметры в сетке две на семь, затем создано сохранение и запрошен выход из титульного экрана.
## Ожидаемый результат: геометрия и навигация совпадают, слот показывает живые данные, а выход выполняется только после явного «Да».
func test_settings_grid_confirmation_and_save_summary() -> void:
	cleanup_files()
	var game := make_game()
	var first: Rect2 = game.MenuRenderer.settings_item_rect(0); var second: Rect2 = game.MenuRenderer.settings_item_rect(1); var below: Rect2 = game.MenuRenderer.settings_item_rect(2)
	expect(first.position.y == second.position.y and second.position.x > first.end.x and below.position.x == first.position.x and below.position.y > first.end.y, "settings form a non-overlapping two-column seven-row card grid")
	game.menu_state.settings_selected = 0; game.MenuSystem.move_settings_selection(game, 1)
	expect(game.menu_state.settings_selected == 2, "Down follows the visual column instead of zigzagging across settings")
	game.day = 7; game.game_minutes = 13 * 60 + 25; game.current_location = "forest"
	expect(game.SaveSystem.save_at(game, TEST_SAVE_PATH), "system UI fixture creates its explicit save slot")
	var summary: String = game.MenuSystem.save_summary(game, TEST_SAVE_PATH)
	expect(summary.contains("7") and summary.contains("13:25") and summary.contains(game.WorldSystem.name("forest")), "pause save card exposes day time and localized location")
	game.title_screen = true; game.menu_state.title_selected = 3; game.MenuSystem.activate_title(game)
	expect(game.menu_state.confirmation == "exit_game" and not game.menu_state.quit_requested, "Exit first opens a safe confirmation")
	game.menu_state.confirm_selected = 0; game.MenuSystem.confirm_action(game)
	expect(game.menu_state.confirmation.is_empty() and game.menu_state.quit_requested, "explicit Yes executes the queued exit exactly once")
	var language_source := FileAccess.get_file_as_string("res://scripts/game_renderer.gd")
	expect(language_source.contains("MenuRenderer.draw_language_screen") and game.MenuRenderer.LANGUAGE_PANEL.encloses(game.language_button_rect(0)) and game.MenuRenderer.LANGUAGE_PANEL.encloses(game.language_button_rect(5)), "language selection reuses the storybook panel while retaining all touch targets")
	for preview_path in ["res://assets/generated/ui/system_settings_ingame_preview.png", "res://assets/generated/ui/language_ingame_preview.png", "res://assets/generated/ui/defeat_ingame_preview.png"]:
		var preview := Image.load_from_file(ProjectSettings.globalize_path(preview_path))
		expect(preview != null and preview.get_width() >= 1152 and absf(float(preview.get_width()) / preview.get_height() - 16.0 / 9.0) < 0.01, "%s remains a native-or-larger 16:9 visual reference" % preview_path)
	game.free(); cleanup_files()


## Сценарий: смертельный урон открывает отдельный экран спасения и останавливает симуляцию до подтверждения.
## Исходное состояние: у героя одна жизнь и три монеты, источник наносит заведомо смертельный удар.
## Ожидаемый результат: герой спасён дома, теряет только доступные монеты, мир заморожен и Enter возвращает управление.
func test_defeat_screen_pauses_and_resumes_safely() -> void:
	var game := make_game(); game.player_hp = 1; game.coins = 3; game.game_minutes = 420.0
	game.CombatSystem.damage_player(game, 20, "Тестовый противник")
	expect(game.menu_state.defeat_open and game.menu_state.defeat_source == "Тестовый противник" and game.menu_state.defeat_lost_coins == 3, "defeat modal records source and exact affordable penalty")
	expect(game.player_hp == game.player_max_hp and game.player == Vector2(260, 360) and game.coins == 0, "Grandma rescue restores health and moves the hero home without negative coins")
	game._physics_process(2.0)
	expect(game.game_minutes == 420.0, "defeat modal freezes world time")
	game.MenuSystem.handle_input(game, key_event(KEY_ENTER, KEY_ENTER, true))
	expect(not game.menu_state.defeat_open, "keyboard or gamepad confirmation returns control after reading the defeat result")
	game.free()


## Сценарий: пункт выхода формирует штатный запрос, не завершая изолированный тестовый runner.
## Исходное состояние: экземпляр игры не добавлен в SceneTree и на главном экране выбран последний пункт.
## Ожидаемый результат: запрос фиксируется, а тест продолжает выполнение и может освободить экземпляр.
func test_exit_is_safe_outside_scene_tree() -> void:
	var game := make_game()
	game.title_screen = true
	game.menu_state.title_selected = 3
	expect(game.MenuSystem.activate_title(game), "Exit command is accepted from the title menu")
	expect(game.menu_state.confirmation == "exit_game" and not game.menu_state.quit_requested, "Exit first records a confirmation without terminating an isolated test")
	game.menu_state.confirm_selected = 0; game.MenuSystem.confirm_action(game)
	expect(game.menu_state.quit_requested, "confirmed Exit records a graceful quit request outside SceneTree")
	game.free()


## Удаляет тестовые сохранения, резервные копии и конфигурацию между независимыми сценариями.
func cleanup_files() -> void:
	for path in [TEST_SAVE_PATH, TEST_SAVE_PATH + ".tmp", TEST_SAVE_PATH + ".bak", TEST_SETTINGS_PATH]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
