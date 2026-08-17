extends "res://tests/suites/suite_base.gd"


## Запускает контроль визуальных эталонов, различимости кадров и переполнения шести локалей.
func run() -> void:
	test_manifest_locks_every_ui_reference()
	test_visual_difference_detects_changed_frame()
	test_localized_controls_fit_real_font_contracts()
	test_context_hud_prioritizes_information_and_explains_actions()
	test_key_interfaces_pass_project_layout_audit()


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


## Сценарий: восемь ключевых поверхностей игры проходят единый проектный UI-аудит.
## Исходное состояние: используются реальные прямоугольники, шрифт, worst-case подписи, сетки и художественные safe-area текущей сборки.
## Ожидаемый результат: все проверки containment, пересечений, hit-зон, центрирования, padding и базовых линий завершаются без нарушения.
func test_key_interfaces_pass_project_layout_audit()->void:
	var game:=make_game(); var report:Dictionary=game.UiLayoutAuditSystem.project_report(game)
	expect(int(report.surfaces)==8 and int(report.checks)>=750,"layout analytics covers eight key UI surfaces with a broad deterministic contract")
	expect(int(report.failed)==0 and int(report.passed)==int(report.checks),"project UI report contains no padding overlap containment centering or typography violations")
	expect(FileAccess.file_exists("res://docs/UI_AUDIT.md") and FileAccess.file_exists("res://docs/reports/ui_layout_audit.json"),"human requirements and machine-readable UI audit remain versioned together")
	game.free()
