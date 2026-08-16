extends RefCounted

const UiFeedbackSystem := preload("res://scripts/systems/ui_feedback_system.gd")

const TEXTURES := {
	"panel_large": preload("res://assets/game/ui/kit_v1/panel_large.png"),
	"panel_medium": preload("res://assets/game/ui/kit_v1/panel_medium.png"),
	"button_normal": preload("res://assets/game/ui/kit_v1/button_normal.png"),
	"button_selected": preload("res://assets/game/ui/kit_v1/button_selected.png"),
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
	"progress_frame": Vector4(24, 18, 24, 18),
	"tooltip": Vector4(24, 22, 24, 22),
	"tab_normal": Vector4(22, 18, 22, 18),
	"tab_selected": Vector4(22, 18, 22, 18),
	"quest_ribbon": Vector4(54, 30, 42, 30),
}
const COLORS := {
	"ink": Color("3d281c"),
	"text_light": Color("fff0cf"),
	"text_disabled": Color("9b8a70"),
	"focus": Color("ffe28b"),
	"success": Color("66804c"),
	"danger": Color("a83f2a"),
	"secondary": Color("315d78"),
}

static var _styles: Dictionary = {}


## Возвращает зарегистрированную художественную текстуру компонента по стабильному идентификатору.
static func texture(component: String) -> Texture2D:
	return TEXTURES.get(component, TEXTURES.tooltip)


## Создаёт и кэширует nine-patch стиль, который сохраняет углы при любом допустимом размере панели.
static func style(component: String) -> StyleBoxTexture:
	if _styles.has(component): return _styles[component]
	var margins: Vector4 = NINE_PATCH_MARGINS.get(component, Vector4(16, 16, 16, 16))
	var box := StyleBoxTexture.new()
	box.texture = texture(component)
	box.texture_margin_left = margins.x
	box.texture_margin_top = margins.y
	box.texture_margin_right = margins.z
	box.texture_margin_bottom = margins.w
	box.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	box.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	_styles[component] = box
	return box


## Рисует масштабируемый художественный компонент без деформации его латунных углов.
static func draw_nine_patch(canvas: CanvasItem, component: String, rect: Rect2, modulate: Color = Color.WHITE) -> void:
	canvas.draw_style_box(style(component), rect)
	if modulate != Color.WHITE:
		canvas.draw_rect(rect.grow(-4), modulate, true)


## Рисует основную или компактную панель единой древесно-пергаментной системы.
static func draw_panel(canvas: CanvasItem, rect: Rect2, large: bool = true) -> void:
	draw_nine_patch(canvas, "panel_large" if large else "panel_medium", rect)


## Рисует непрозрачное модальное полотно под резной рамой, не пропуская подписи игрового мира сквозь декоративные вырезы.
static func draw_modal_panel(canvas: CanvasItem, rect: Rect2, large: bool = true) -> void:
	canvas.draw_rect(rect.grow(-18),Color("ead7a1"),true)
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
		canvas.draw_rect(rect.grow(-5), Color(0.12, 0.11, 0.10, 0.46), true)


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
	canvas.draw_texture_rect(texture("slot_selected" if selected else "slot_normal"), square, false)
	return square.grow(-maxf(6.0, square_size * 0.14))


## Рисует художественную рамку прогресса и заполнение с безопасными внутренними полями.
static func draw_progress(canvas: CanvasItem, rect: Rect2, ratio: float, color: Color) -> Rect2:
	draw_nine_patch(canvas, "progress_frame", rect)
	var track := rect.grow(-10)
	canvas.draw_rect(track, Color(0.12, 0.075, 0.04, 0.88), true)
	var fill := Rect2(track.position, Vector2(track.size.x * clampf(ratio, 0.0, 1.0), track.size.y))
	if fill.size.x > 0.0: canvas.draw_rect(fill, color, true)
	return track
