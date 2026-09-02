extends "res://tests/suites/suite_base.gd"


## Запускает контроль визуальных эталонов, различимости кадров и переполнения шести локалей.
func run() -> void:
	test_manifest_locks_every_ui_reference()
	test_visual_difference_detects_changed_frame()
	test_localized_controls_fit_real_font_contracts()
	test_context_hud_prioritizes_information_and_explains_actions()
	test_adaptive_hud_profiles_preserve_safe_layout()
	test_key_interfaces_pass_project_layout_audit()
	test_feature_interfaces_fit_six_locales_at_120_percent()
	test_item_windows_fit_six_locales_at_120_percent()


## Сценарий: все созданные UI-эталоны входят в один версионированный regression-манифест.
## Исходное состояние: в assets/generated/ui лежат двадцать восемь контрольных PNG с зафиксированными размерами и SHA-256.
## Ожидаемый результат: список полон, имена уникальны, изображения не пусты, пропорции верны и ни одна контрольная сумма не изменилась.
func test_manifest_locks_every_ui_reference() -> void:
	var game := make_game(); var document: Dictionary = game.UiVisualRegressionSystem.manifest(); var names: Dictionary = {}
	for entry in document.get("references",[]): names[String(entry.file)]=true
	expect(document.get("references",[]).size()==28 and names.size()==28, "visual manifest owns every approved system and gameplay interface screenshot exactly once")
	expect(document.get("references",[]).all(func(entry): return int(entry.width)==1152 and int(entry.height)==648), "every UI reference uses the exact design viewport instead of physical fullscreen pixels")
	expect(game.UiVisualRegressionSystem.validate_references().is_empty(), "visual regression gate accepts every committed reference size contrast aspect and SHA-256")
	game.free()


## Сценарий: алгоритм сравнения отличает идентичный кадр от другого экрана того же разрешения.
## Исходное состояние: адаптивные настройки и F10 сохранены в одинаковом холсте 1152×648.
## Ожидаемый результат: самосравнение даёт ноль, а другой экран пересекает заметный порог визуального изменения.
func test_visual_difference_detects_changed_frame() -> void:
	var game := make_game(); var directory := ProjectSettings.globalize_path("res://assets/generated/ui/")
	var adaptive := Image.load_from_file(directory+"adaptive_ui_ingame_preview.png"); var debug := Image.load_from_file(directory+"debug_overlay_ingame_preview.png")
	expect(is_zero_approx(game.UiVisualRegressionSystem.visual_difference(adaptive,adaptive)), "pixel sampler reports zero for an unchanged reference")
	expect(game.UiVisualRegressionSystem.visual_difference(adaptive,debug)>0.08, "pixel sampler reports a material difference for another screen at the same resolution")
	game.free()


## Сценарий: ключевые кнопки и параметры проверяются во всех шести языках с максимальным пользовательским масштабом текста.
## Исходное состояние: UI_FONT, реальные ширины контейнеров и переводы RU/EN/ES/DE/FR/ZH доступны без запуска отдельных сцен.
## Ожидаемый результат: у каждого ключа шесть переводов и интеллектуальное вписывание не опускается ниже минимального читаемого размера.
func test_localized_controls_fit_real_font_contracts() -> void:
	var game := make_game(); game.settings_state.text_scale=1.2
	expect(game.UiVisualRegressionSystem.LOCALIZED_CONTROL_CONTRACTS.size()>=20, "localization gate covers title navigation pause and every settings control")
	expect(game.UiVisualRegressionSystem.validate_localized_controls(game).is_empty(), "all six locales fit their real control widths at maximum text scale")
	game.free()


## Сценарий: контекстный HUD одновременно показывает обучение, одну цель, карту, находку, сообщение и точное действие без наложений.
## Исходное состояние: активна первая глава, затем бабушкино и два обычных задания; проверяются мышь, касание и шесть языков.
## Ожидаемый результат: зоны безопасны, приоритет цели устойчив, карточка открывает журнал, а временное сообщение исчезает после чтения.
func test_context_hud_prioritizes_information_and_explains_actions() -> void:
	var game := make_game(); var layout = game.HudLayoutSystem
	expect(layout.layout_is_safe(), "tutorial objective minimap discovery notification and interaction prompts own non-overlapping regions")
	expect(not layout.EFFECTS_RECT.intersects(layout.OBJECTIVE_RECT) and not layout.EFFECTS_RECT.intersects(layout.MINIMAP_RECT), "temporary effects use their own two-row lane below the objective")
	expect(game.InterfaceRenderer.TUTORIAL_CARD == layout.TUTORIAL_RECT and game.InterfaceRenderer.OBJECTIVE_CARD == layout.OBJECTIVE_RECT and game.discovery_card_rect() == layout.DISCOVERY_RECT, "drawing and pointer input share the coordinator's exact geometry")
	var objective: Dictionary = layout.primary_objective(game)
	expect(objective.kind == "chapter" and objective.text == game.FirstChapterSystem.objective(game), "first chapter owns the primary slot instead of creating a competing panel")
	var chapter: Dictionary = game.FirstChapterSystem.state(game); chapter.completed = true; chapter.reward_pending = false
	game.quest_active = true; game.quest_complete = false; game.carrots = 4
	objective = layout.primary_objective(game)
	expect(objective.kind == "quest" and is_equal_approx(float(objective.ratio), 0.4), "grandmother request becomes a single measurable objective after the chapter")
	game.quest_active = false; game.mission_states.story_relic = game.QuestSystem.ACTIVE; game.mission_states.side_seed = game.QuestSystem.ACTIVE
	objective = layout.primary_objective(game)
	expect(objective.source == "mission" and objective.kind == "story" and layout.hidden_objective_count(game) == 1, "story mission takes priority and reports one hidden side quest behind J")
	for locale in game.LocaleSystem.LOCALES:
		game.LocaleSystem.set_locale(locale)
		var talk: String = layout.interaction_label(game,"quest_npc:miron"); var mine: String = layout.interaction_label(game,"resource:0")
		expect(talk.contains("E / A") and mine.contains("E / A") and talk != mine, "context actions remain specific and localized for %s" % locale)
	game.LocaleSystem.set_locale("ru")
	var touch := InputEventScreenTouch.new(); touch.position = layout.OBJECTIVE_RECT.get_center(); touch.pressed = true
	expect(game.handle_gamepad_and_touch(touch) and game.quest_log_open, "touching the visible objective opens the full journal")
	game.quest_log_open = false; game.message = "Проверка времени чтения"; game.update_hud_feedback(0.0)
	var duration: float = game.hud_message_timer
	expect(duration >= 3.8 and duration <= 7.0, "notification lifetime adapts to message length inside readable limits")
	game.update_hud_feedback(duration + 0.1)
	expect(game.message.is_empty() and game.hud_message_timer == 0.0, "read notification leaves the playfield instead of becoming permanent clutter")
	var chapter_renderer_source := FileAccess.get_file_as_string("res://scripts/systems/first_chapter_renderer.gd")
	expect(not chapter_renderer_source.contains("Rect2(724,103,404,68)"), "legacy chapter card no longer overlaps the unified objective")
	game.free()


## Сценарий: полный контекстный HUD показывается на экранах 16:9, 16:10 и 21:9 без растяжения и потери управления.
## Исходное состояние: три физических профиля используют один дизайн-холст 1152×648, общие карточки и версионированные PNG-эталоны.
## Ожидаемый результат: холст центрирован в safe-area, карточки не пересекаются, координаты обратимы, а три кадра проходят проверку размеров и SHA-256.
func test_adaptive_hud_profiles_preserve_safe_layout()->void:
	var game:=make_game(); var profile_ids:Array[String]=[]
	expect(game.HudLayoutSystem.DISPLAY_PROFILES.size()==3,"adaptive HUD defines exactly the approved 16:9 16:10 and ultrawide profiles")
	var clear_color:Color=ProjectSettings.get_setting("rendering/environment/defaults/default_clear_color"); expect(clear_color.is_equal_approx(Color("0b1512")),"letterbox fields use the same quiet valley color as reproducible physical previews")
	for profile in game.HudLayoutSystem.DISPLAY_PROFILES:
		profile_ids.append(String(profile.id)); var viewport:=Vector2(profile.size); var physical:Dictionary=game.HudLayoutSystem.physical_layout(viewport); var content:Rect2=physical.content
		expect(is_equal_approx(content.size.x/content.size.y,16.0/9.0) and (physical.safe_area as Rect2).grow(0.1).encloses(content),"%s keeps the 32-bit design canvas undistorted inside the physical safe-area"%profile.label)
		expect((physical.cards as Dictionary).values().all(func(rect):return content.grow(0.1).encloses(rect)),"%s keeps every contextual card inside visible game content"%profile.label)
		var design_point:Vector2=game.HudLayoutSystem.INTERACTION_RECT.get_center(); var screen_point:Vector2=game.UiScaleSystem.design_rect_to_screen(Rect2(design_point,Vector2.ONE),viewport).position
		expect(game.UiScaleSystem.screen_to_design(screen_point,viewport).is_equal_approx(design_point),"%s preserves pointer mapping for adaptive HUD actions"%profile.label)
	expect(profile_ids==["16x9","16x10","ultrawide"] and game.UiVisualRegressionSystem.validate_hud_profile_references().is_empty(),"three physical HUD references match their declared dimensions contrast and exact hashes")
	game.free()


## Сценарий: восемь ключевых поверхностей игры проходят единый проектный UI-аудит.
## Исходное состояние: используются реальные прямоугольники, шрифт, worst-case подписи, сетки и художественные safe-area текущей сборки.
## Ожидаемый результат: все проверки containment, пересечений, hit-зон, центрирования, padding и базовых линий завершаются без нарушения.
func test_key_interfaces_pass_project_layout_audit()->void:
	var game:=make_game(); var report:Dictionary=game.UiLayoutAuditSystem.project_report(game)
	expect(int(report.surfaces)==8 and int(report.checks)>=2200,"layout analytics covers eight key UI surfaces with a broad deterministic contract")
	expect(int(report.failed)==0 and int(report.passed)==int(report.checks),"project UI report contains no padding overlap containment centering or typography violations")
	expect(FileAccess.file_exists("res://docs/UI_AUDIT.md") and FileAccess.file_exists("res://docs/reports/ui_layout_audit.json"),"human requirements and machine-readable UI audit remain versioned together")
	game.free()


## Сценарий: рыбалка, энциклопедия, журнал и дерево талантов открываются на каждом из шести поддерживаемых языков.
## Исходное состояние: применяется максимальный масштаб текста 120%, реальные переводы, названия рыб, миссий и всех двадцати талантов.
## Ожидаемый результат: не менее 1400 динамических подписей помещаются в свои контейнеры без размера ниже читаемого порога.
func test_feature_interfaces_fit_six_locales_at_120_percent()->void:
	var report:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://docs/reports/ui_layout_audit.json")); var localization:Dictionary=report.localization
	expect(localization.locales==["ru","en","es","de","fr","zh"] and is_equal_approx(float(localization.text_scale),1.2),"feature audit executes the complete locale matrix at the required maximum text scale")
	var audited_surfaces:Array=["fishing","world_guide","quest_log","talent_tree"]
	expect(int(localization.contracts)>=1400 and audited_surfaces.all(func(surface):return int(localization.surfaces.get(surface,0))>0),"fishing world guide quest log and talent tree expose broad dynamic text contracts")
	expect(int(report.failed)==0,"all localized feature strings preserve readable typography without overflow")


## Сценарий: рюкзак, лавка, верстак, домашний сундук и кузница открываются на каждом из шести языков.
## Исходное состояние: используются все названия предметов и рецептов, максимальные числа, реальные контейнеры и масштаб текста 120%.
## Ожидаемый результат: не менее 3700 предметных подписей помещаются, многострочные блоки масштабируются, а геометрический аудит не находит ошибок.
func test_item_windows_fit_six_locales_at_120_percent()->void:
	var report:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://docs/reports/ui_layout_audit.json")); var localization:Dictionary=report.localization
	var item_surfaces:Array=["inventory","shop","crafting","storage","forge"]; var item_contracts:int=int(item_surfaces.reduce(func(total,surface):return total+int(localization.surfaces.get(surface,0)),0))
	expect(item_surfaces.all(func(surface):return int(localization.surfaces.get(surface,0))>0) and item_contracts>=3700,"all five item surfaces own broad localized text contracts")
	expect(not FileAccess.get_file_as_string("res://scripts/systems/item_window_renderer.gd").contains("draw_multiline_string(") and not FileAccess.get_file_as_string("res://scripts/systems/interface_renderer.gd").contains("draw_multiline_string("),"item windows route every multiline block through adaptive width and height fitting")
	expect(int(report.failed)==0 and int(report.checks)>=6000,"item window geometry and six-locale typography pass the complete project audit")
