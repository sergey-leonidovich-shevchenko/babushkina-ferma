extends RefCounted

const Paper := preload("res://scripts/presentation/paper_theme_palette.gd")
const Style := preload("res://scripts/presentation/moon_theme.gd")
const UiFeedbackSystem := preload("res://scripts/systems/ui_feedback_system.gd")

const TEXTURES := {
	"panel_large": preload("res://assets/game/ui/kit_v1/panel_large.png"),
	"panel_medium": preload("res://assets/game/ui/kit_v1/panel_medium.png"),
	"button_normal": preload("res://assets/game/ui/kit_v1/button_normal.png"),
	"button_selected": preload("res://assets/game/ui/kit_v1/button_selected.png"),
	"editor_button_normal": preload("res://assets/game/ui/editor_v1/editor_button_normal_v1.png"),
	"editor_button_selected": preload("res://assets/game/ui/editor_v1/editor_button_selected_v1.png"),
	"editor_card_normal": preload("res://assets/game/ui/editor_v1/editor_card_normal_v1.png"),
	"editor_card_selected": preload("res://assets/game/ui/editor_v1/editor_card_selected_v1.png"),
	"slot_normal": preload("res://assets/game/ui/kit_v1/slot_normal.png"),
	"slot_selected": preload("res://assets/game/ui/kit_v1/slot_selected.png"),
	"progress_frame": preload("res://assets/game/ui/kit_v1/progress_frame.png"),
	"scrollbar": preload("res://assets/game/ui/kit_v1/scrollbar.png"),
	"tooltip": preload("res://assets/game/ui/kit_v1/tooltip.png"),
	"tab_normal": preload("res://assets/game/ui/kit_v1/tab_normal.png"),
	"tab_selected": preload("res://assets/game/ui/kit_v1/tab_selected.png"),
	"portrait_frame": preload("res://assets/game/ui/kit_v1/portrait_frame.png"),
	"badge": preload("res://assets/game/ui/kit_v1/badge.png"),
	"close_button": preload("res://assets/game/ui/kit_v1/close_button.png"),
	"quest_ribbon": preload("res://assets/game/ui/kit_v1/quest_ribbon.png"),
	"divider": preload("res://assets/game/ui/kit_v1/divider.png"),
}
const NINE_PATCH_MARGINS := {
	"panel_large": Vector4(42, 48, 42, 38),
	"panel_medium": Vector4(34, 36, 34, 34),
	"button_normal": Vector4(24, 12, 24, 12),
	"button_selected": Vector4(24, 12, 24, 12),
	"editor_button_normal": Vector4(20, 8, 20, 8),
	"editor_button_selected": Vector4(20, 8, 20, 8),
	"progress_frame": Vector4(24, 18, 24, 18),
	"tooltip": Vector4(24, 22, 24, 22),
	"tab_normal": Vector4(22, 18, 22, 18),
	"tab_selected": Vector4(22, 18, 22, 18),
	"quest_ribbon": Vector4(54, 30, 42, 30),
}
const COLORS := {
	"ink": Paper.TEXT,
	"text_light": Paper.TEXT,
	"text_disabled": Paper.DISABLED,
	"focus": Paper.ACCENT_TEXT,
	"success": Paper.ACCENT_TEXT,
	"danger": Paper.DANGER,
	"secondary": Paper.INFO,
}

static var _styles: Dictionary = {}


## Возвращает зарегистрированную художественную текстуру компонента по стабильному идентификатору.
static func texture(component: String) -> Texture2D:
	return TEXTURES.get(component, TEXTURES.tooltip)


## Возвращает гладкую светлую поверхность также для прежнего API оформления, исключая возврат деревянных рамок.
static func style(component: String) -> StyleBoxFlat:
	if _styles.has(component): return _styles[component]
	var selected:=component.ends_with("selected")
	var inset:bool=component.contains("button") or component.begins_with("tab") or component.begins_with("slot")
	var box := StyleBoxFlat.new()
	box.bg_color=Paper.SELECTED if selected else (Paper.INSET if inset else Paper.PANEL)
	box.border_color=Paper.ACCENT_TEXT if selected else Paper.EDGE
	box.set_border_width_all(1); box.set_corner_radius_all(5)
	_styles[component] = box
	return box


## Рисует общий светлый компонент, включая прежние псевдонимы кнопок станков.
static func draw_nine_patch(canvas: CanvasItem, component: String, rect: Rect2, modulate: Color = Color.WHITE) -> void:
	canvas.draw_style_box(style(component),rect)
	if modulate != Color.WHITE:
		canvas.draw_rect(rect.grow(-4), modulate, true)


## Рисует основную или компактную панель единой светлой пергаментной системы.
static func draw_panel(canvas: CanvasItem, rect: Rect2, large: bool = true) -> void:
	draw_nine_patch(canvas, "panel_large" if large else "panel_medium", rect)


## Рисует непрозрачное модальное полотно с тонкой рамкой, не пропуская подписи игрового мира сквозь декоративные вырезы.
static func draw_modal_panel(canvas: CanvasItem, rect: Rect2, large: bool = true) -> void:
	canvas.draw_rect(rect.grow(-4),Paper.PANEL,true)
	draw_panel(canvas,rect,large)


## Рисует кнопку с внутренним светом фокуса и спокойным disabled-состоянием без внешней рамки.
static func draw_button(canvas: CanvasItem, rect: Rect2, selected: bool, enabled: bool, reduced_motion: bool = false, milliseconds: int = 0) -> void:
	rect = UiFeedbackSystem.animated_button_rect(canvas, rect, reduced_motion)
	var component := "button_selected" if selected and enabled else "button_normal"
	draw_nine_patch(canvas, component, rect)
	if selected and enabled and not reduced_motion:
		var alpha := 0.04 + sin(milliseconds / 260.0) * 0.025
		canvas.draw_rect(rect.grow(-9), Color(1.0, 0.76, 0.28, alpha), true)
	if not enabled:
		canvas.draw_rect(rect.grow(-5), Color(Paper.BACKGROUND,0.35), true)


## Рисует низкую пергаментную карточку без сжатых резных деталей: вся внутренняя площадь доступна тексту.
static func draw_inset_card(canvas:CanvasItem,rect:Rect2,selected:bool=false,enabled:bool=true,learned:bool=false)->void:
	Style.panel(canvas,rect,Paper.SELECTED if selected or learned else Paper.INSET,Paper.ACCENT_TEXT if selected else Paper.EDGE)
	if not enabled: canvas.draw_rect(rect.grow(-3),Color(Paper.BACKGROUND,0.35))


## Возвращает прямоугольник контента, центрированный как flex-container внутри заданной safe-area.
static func centered_content_rect(container: Rect2, content_size: Vector2, padding: float = 8.0) -> Rect2:
	var available := container.size - Vector2.ONE * padding * 2.0
	var scale := minf(1.0, minf(available.x / content_size.x, available.y / content_size.y)) if content_size.x > 0.0 and content_size.y > 0.0 else 1.0
	var size := content_size * scale
	return Rect2(container.get_center() - size * 0.5, size)


## Рисует самостоятельный слот, сохраняя квадратный аспект и внутреннее центрирование предмета.
static func draw_slot(canvas: CanvasItem, rect: Rect2, selected: bool) -> Rect2:
	var square_size := minf(rect.size.x, rect.size.y)
	var square := Rect2(rect.get_center() - Vector2.ONE * square_size * 0.5, Vector2.ONE * square_size)
	Style.panel(canvas,square,Paper.SELECTED if selected else Paper.INSET,Paper.ACCENT_TEXT if selected else Paper.EDGE)
	return square.grow(-maxf(6.0, square_size * 0.14))


## Рисует светлую рамку прогресса и заполнение с безопасными внутренними полями.
static func draw_progress(canvas: CanvasItem, rect: Rect2, ratio: float, color: Color) -> Rect2:
	var track:=progress_content_rect(rect)
	canvas.draw_rect(rect,Paper.PANEL)
	canvas.draw_rect(rect,Paper.EDGE,false,1.0)
	canvas.draw_rect(track, Paper.TRACK, true)
	var fill := Rect2(track.position, Vector2(track.size.x * clampf(ratio, 0.0, 1.0), track.size.y))
	if fill.size.x > 0.0: canvas.draw_rect(fill, color, true)
	return track


## Подбирает внутренний отступ по высоте: тонкая шкала никогда не получает отрицательный размер.
static func progress_content_rect(rect: Rect2) -> Rect2:
	var inset:=minf(10.0,maxf(1.0,rect.size.y*0.18))
	inset=minf(inset,maxf(0.0,minf(rect.size.x,rect.size.y)*0.5-0.5))
	return rect.grow(-inset)
