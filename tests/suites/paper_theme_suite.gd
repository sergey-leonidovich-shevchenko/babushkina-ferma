extends "res://tests/suites/suite_base.gd"

const Paper := preload("res://scripts/presentation/paper_theme_palette.gd")
const Style := preload("res://scripts/presentation/moon_theme.gd")
const Kit := preload("res://scripts/systems/ui_kit_system.gd")

## Проверяет читаемость текста на всех поверхностях принятой светлой темы.
func run() -> void:
	test_readable_text_on_normal_inset_and_selected_surfaces()
	test_shared_controls_keep_semantic_roles()

## Сценарий: обычная, вложенная и выбранная панели показывают основной, вторичный и статусный текст.
## Исходное состояние: используется настоящая общая палитра светлого варианта B, включая красную ошибку и голубую информацию.
## Ожидаемый результат: каждая активная подпись имеет контраст не ниже 4,5:1, а светлая подпись акцентной кнопки остаётся читаемой.
func test_readable_text_on_normal_inset_and_selected_surfaces() -> void:
	for surface in [Paper.BACKGROUND,Paper.PANEL,Paper.INSET,Paper.SELECTED]:
		for ink in [Paper.TEXT,Paper.MUTED,Paper.ACCENT_TEXT,Paper.SUCCESS,Paper.DANGER,Paper.INFO]:
			expect(contrast(ink,surface)>=4.5,"active text contrast %.2f on %s"%[contrast(ink,surface),surface.to_html()])
		for rarity in ["common","uncommon","rare","epic","legendary"]:
			expect(contrast(Paper.rarity_ink(rarity),surface)>=4.5,"rarity caption remains readable: "+rarity)
		expect(luminance(surface)>0.5 and is_equal_approx(surface.a,1.0),"light surfaces remain opaque and do not reveal world labels")
	expect(contrast(Paper.ON_ACCENT,Paper.ACCENT)>=4.5,"primary action has readable light text")
	expect(contrast(Paper.DISABLED,Paper.INSET)>=3.0,"unavailable action remains visible on its unselected surface")

## Сценарий: новые панели и прежние предметные компоненты используют одну семантическую тему.
## Исходное состояние: рюкзак, шкаф, диалог и старые окна станков читают разные совместимые API оформления.
## Ожидаемый результат: основные роли совпадают, цвет текста акцента отличается от его заливки, а дорожка не сливается с заполнением.
func test_shared_controls_keep_semantic_roles() -> void:
	expect(Style.TEXT==Paper.TEXT and Kit.COLORS.ink==Paper.TEXT and Kit.COLORS.text_light==Paper.TEXT,"old and new components share dark ink on parchment")
	expect(Style.BACKGROUND==Paper.BACKGROUND and Style.PANEL==Paper.PANEL and Style.SELECTED==Paper.SELECTED,"fullscreen and inset screens share the accepted B surfaces")
	expect(Style.ACCENT!=Style.PRIMARY and Style.PRIMARY==Paper.ACCENT and Style.ON_ACCENT==Paper.ON_ACCENT,"accent labels and filled actions have independent contrast roles")
	expect(contrast(Paper.ACCENT_TEXT,Paper.TRACK)>3.0 and Paper.SELECTED!=Paper.INSET,"selection and progress remain distinguishable without decorative frames")

## Вычисляет относительную яркость sRGB в линейном пространстве для проверки читаемости.
func luminance(color:Color) -> float:
	var linear:=color.srgb_to_linear()
	return linear.r*0.2126+linear.g*0.7152+linear.b*0.0722

## Возвращает отношение яркости текста и фона с поправкой на самые тёмные оттенки.
func contrast(first:Color,second:Color) -> float:
	var a:=luminance(first); var b:=luminance(second)
	return (maxf(a,b)+0.05)/(minf(a,b)+0.05)
