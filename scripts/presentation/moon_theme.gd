extends RefCounted

const Palette := preload("res://scripts/presentation/paper_theme_palette.gd")
const BACKGROUND := Palette.BACKGROUND
const PANEL := Palette.PANEL
const INSET := Palette.INSET
const EDGE := Palette.EDGE
const TEXT := Palette.TEXT
const MUTED := Palette.MUTED
const ACCENT := Palette.ACCENT_TEXT
const PRIMARY := Palette.ACCENT
const ON_ACCENT := Palette.ON_ACCENT
const SELECTED := Palette.SELECTED
const DISABLED := Palette.DISABLED
const TRACK := Palette.TRACK
const DANGER := Palette.DANGER
const SUCCESS := Palette.SUCCESS
const INFO := Palette.INFO
const BODY_SIZE := 13
const LABEL_SIZE := 11
const HINT_SIZE := 9
const SECTION_SIZE := 18
static var styles: Dictionary = {}

## Превращает системную подпись верхним регистром в обычное предложение, сохраняя правила русского текста.
static func sentence_case(label: String) -> String:
	return label.left(1).to_upper() + label.substr(1).to_lower()

## Рисует непрозрачную пергаментную поверхность с тонкой рамкой и общими спокойными углами.
static func panel(canvas: CanvasItem, rect: Rect2, fill: Color = PANEL, border: Color = EDGE, radius: int = 5) -> void:
	var key := "%s:%s:%d" % [fill.to_html(), border.to_html(), radius]
	if not styles.has(key):
		var style := StyleBoxFlat.new()
		style.bg_color = fill; style.border_color = border
		style.set_border_width_all(1); style.set_corner_radius_all(radius)
		styles[key] = style
	canvas.draw_style_box(styles[key], rect)

## Центрирует текст по высоте доступной области с учётом выбранного пользователем масштаба.
static func text(game: Node, rect: Rect2, label: String, size: int = BODY_SIZE, color: Color = TEXT, alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> void:
	var fitted: int = game.UiScaleSystem.fitted_singleline_font_size(game,game.UI_FONT,label,rect.size.x,rect.size.y,size)
	var baseline := rect.position + Vector2(0, (rect.size.y - game.UI_FONT.get_height(fitted)) * 0.5 + game.UI_FONT.get_ascent(fitted))
	game.draw_string(game.UI_FONT, baseline, label, alignment, rect.size.x, fitted, color)

## Рисует название книжным шрифтом, сохраняя системный fallback для всех локалей.
static func title(game: Node, rect: Rect2, label: String, size: int = 20) -> void:
	var fitted: int = game.UiScaleSystem.fitted_singleline_font_size(game, game.MENU_FONT, label, rect.size.x, rect.size.y, size)
	game.draw_string(game.MENU_FONT, rect.position + Vector2(0, game.MENU_FONT.get_ascent(fitted)), label, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x, fitted, TEXT)

## Рисует действие с общим состоянием выбора или недоступности без резной декоративной рамки.
static func button(game: Node, rect: Rect2, label: String, selected: bool = false, enabled: bool = true) -> void:
	var focused:=selected and enabled
	panel(game,rect,PRIMARY if focused else INSET,ACCENT if focused else EDGE)
	var parts := label.split(" • ")
	for index in parts.size(): parts[index]=sentence_case(parts[index])
	text(game, rect.grow(-6), " • ".join(parts), BODY_SIZE, (ON_ACCENT if focused else TEXT) if enabled else DISABLED, HORIZONTAL_ALIGNMENT_CENTER)

## Рисует спокойный слот и возвращает внутреннюю область для предмета или портрета.
static func slot(game: Node, rect: Rect2, selected: bool = false) -> Rect2:
	panel(game,rect,SELECTED if selected else INSET,ACCENT if selected else EDGE)
	return rect.grow(-6)

## Рисует ресурс на светлой дорожке без декоративной рамки поверх заполнения.
static func progress(game: Node, rect: Rect2, ratio: float, color: Color) -> void:
	panel(game,rect,INSET)
	var inner := rect.grow(-4)
	game.draw_rect(Rect2(inner.position,Vector2(inner.size.x*clampf(ratio,0,1),inner.size.y)),color)

## Возвращает подписи меню сразу для шести поддерживаемых языков.
static func word(game: Node, key: String) -> String:
	var words := {
		"paused":["Мир на паузе","World paused","Mundo en pausa","Welt pausiert","Monde en pause","世界已暂停"],
		"story":["Основной сюжет","Main story","Historia principal","Hauptgeschichte","Histoire principale","主线故事"],
		"side":["Поручения","Side quests","Encargos","Nebenaufgaben","Quêtes annexes","支线任务"],
		"history":["Выполненные","Completed","Completadas","Abgeschlossen","Terminées","已完成"],
		"active":["Активные","Active","Activas","Aktiv","Actives","进行中"],
		"all":["Все","All","Todas","Alle","Toutes","全部"],
		"empty":["Здесь пока нет заданий","No quests here yet","Aún no hay misiones","Noch keine Aufgaben","Aucune quête ici","暂无任务"],
		"close":["Закрыть","Close","Cerrar","Schließen","Fermer","关闭"],
		"moon":["Лунная долина","Moon Valley","Valle lunar","Mondtal","Vallée lunaire","月之谷"],
		"hero":["Герой","Character","Personaje","Charakter","Personnage","角色"],
		"inventory":["Рюкзак","Backpack","Mochila","Rucksack","Sac","背包"],
		"journal":["Журнал","Journal","Diario","Tagebuch","Journal","任务日志"],
		"world":["Мир","World","Mundo","Welt","Monde","世界"],
	}
	var values: Array = words.get(key, [key,key,key,key,key,key])
	return String(values[maxi(0,game.LocaleSystem.LOCALES.find(game.LocaleSystem.current))])
