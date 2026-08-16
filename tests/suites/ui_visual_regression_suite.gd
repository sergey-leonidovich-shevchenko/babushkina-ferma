extends "res://tests/suites/suite_base.gd"


## Запускает контроль визуальных эталонов, различимости кадров и переполнения шести локалей.
func run() -> void:
	test_manifest_locks_every_ui_reference()
	test_visual_difference_detects_changed_frame()
	test_localized_controls_fit_real_font_contracts()


## Сценарий: все созданные UI-эталоны входят в один версионированный regression-манифест.
## Исходное состояние: в assets/generated/ui лежат двадцать семь контрольных PNG с зафиксированными размерами и SHA-256.
## Ожидаемый результат: список полон, имена уникальны, изображения не пусты, пропорции верны и ни одна контрольная сумма не изменилась.
func test_manifest_locks_every_ui_reference() -> void:
	var game := make_game(); var document: Dictionary = game.UiVisualRegressionSystem.manifest(); var names: Dictionary = {}
	for entry in document.get("references",[]): names[String(entry.file)]=true
	expect(document.get("references",[]).size()==27 and names.size()==27, "visual manifest owns every approved system and gameplay interface screenshot exactly once")
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
