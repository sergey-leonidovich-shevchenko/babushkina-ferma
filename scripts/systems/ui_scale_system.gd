extends RefCounted

const DESIGN_SIZE := Vector2(1152, 648)
const MIN_TOUCH_TARGET := Vector2(48, 48)
const TEXT_SCALES := [0.9, 1.0, 1.1, 1.2]
const TOUCH_SCALES := [0.9, 1.0, 1.15, 1.3]
const TextMetrics := preload("res://scripts/systems/ui_text_metrics_cache_system.gd")


## Возвращает letterbox-преобразование из базовой сцены 1152×648 в реальное окно без искажения пропорций.
static func viewport_layout(viewport_size: Vector2) -> Dictionary:
	return viewport_layout_in_area(viewport_size, Rect2(Vector2.ZERO, viewport_size))


## Вписывает дизайн-холст в системную safe-area, сохраняя исходные пропорции и симметричные поля.
static func viewport_layout_in_area(viewport_size: Vector2, physical_safe_area: Rect2) -> Dictionary:
	var viewport := Rect2(Vector2.ZERO, viewport_size)
	var safe_area := physical_safe_area.intersection(viewport)
	if safe_area.size.x <= 0.0 or safe_area.size.y <= 0.0: safe_area = viewport
	var scale := minf(safe_area.size.x / DESIGN_SIZE.x, safe_area.size.y / DESIGN_SIZE.y)
	var content_size := DESIGN_SIZE * scale
	return {"scale":scale,"offset":safe_area.position+(safe_area.size-content_size)*0.5,"content_size":content_size,"safe_area":safe_area}


## Переводит координату физического экрана в единую дизайн-сетку для точного совпадения рисунка и hit-зоны.
static func screen_to_design(point: Vector2, viewport_size: Vector2) -> Vector2:
	var layout := viewport_layout(viewport_size)
	return (point - Vector2(layout.offset)) / float(layout.scale)


## Переводит координату дизайн-сетки в физический экран для проверок Full HD, 2K и 4K.
static func design_to_screen(point: Vector2, viewport_size: Vector2) -> Vector2:
	var layout := viewport_layout(viewport_size)
	return Vector2(layout.offset) + point * float(layout.scale)


## Переводит дизайн-прямоугольник HUD в физический экран с учётом letterbox и системной safe-area.
static func design_rect_to_screen(rect: Rect2, viewport_size: Vector2, physical_safe_area: Rect2 = Rect2()) -> Rect2:
	var safe_area := physical_safe_area if physical_safe_area.size.x > 0.0 and physical_safe_area.size.y > 0.0 else Rect2(Vector2.ZERO, viewport_size)
	var layout := viewport_layout_in_area(viewport_size, safe_area)
	return Rect2(Vector2(layout.offset)+rect.position*float(layout.scale),rect.size*float(layout.scale))


## Преобразует системную safe-area в координаты базовой сцены и ограничивает её видимой областью игры.
static func safe_area_design(viewport_size: Vector2, physical_safe_area: Rect2) -> Rect2:
	var start := screen_to_design(physical_safe_area.position, viewport_size)
	var finish := screen_to_design(physical_safe_area.end, viewport_size)
	return Rect2(start, finish - start).intersection(Rect2(Vector2.ZERO, DESIGN_SIZE))


## Возвращает ближайший разрешённый множитель, чтобы повреждённый конфиг не ломал вёрстку.
static func normalized_scale(value: float, available: Array) -> float:
	var best := float(available[0])
	for candidate in available:
		if absf(float(candidate) - value) < absf(best - value): best = float(candidate)
	return best


## Переключает масштаб по кольцу предустановок в направлении навигации меню.
static func cycle_scale(value: float, direction: int, available: Array) -> float:
	var normalized := normalized_scale(value, available)
	return float(available[posmod(available.find(normalized) + direction, available.size())])


## Подбирает размер шрифта с пользовательским увеличением, но не допускает горизонтального переполнения контейнера.
static func fitted_font_size(game: Node, font: Font, text: String, width: float, requested_size: int) -> int:
	return TextMetrics.fitted_size(font, text, width, 0.0, requested_size, game.settings_state.text_scale)


## Вписывает однострочную подпись по обеим осям с учётом полной высоты системного шрифта и его запасных гарнитур.
static func fitted_singleline_font_size(game: Node, font: Font, text: String, width: float, height: float, requested_size: int) -> int:
	return TextMetrics.fitted_line_size(font, text, width, height, requested_size, game.settings_state.text_scale)


## Подбирает размер многострочного текста по ширине и высоте, не обрезая последний смысловой ряд при масштабе 120%.
static func fitted_multiline_font_size(game: Node, font: Font, text: String, width: float, height: float, requested_size: int) -> int:
	return TextMetrics.fitted_size(font, text, width, height, requested_size, game.settings_state.text_scale, true)


## Масштабирует сенсорную кнопку относительно её центра, сохраняя минимальную удобную область 48×48 px.
static func touch_rect(game: Node, base_rect: Rect2) -> Rect2:
	var size: Vector2 = base_rect.size * game.settings_state.touch_scale
	size.x = maxf(size.x, MIN_TOUCH_TARGET.x); size.y = maxf(size.y, MIN_TOUCH_TARGET.y)
	return Rect2(base_rect.get_center() - size * 0.5, size).intersection(Rect2(Vector2.ZERO, DESIGN_SIZE))


## Собирает детерминированный физический кадр так же, как режим keep показывает дизайн-холст на другом формате экрана.
static func compose_physical_preview(design_image: Image, viewport_size: Vector2i, physical_safe_area: Rect2 = Rect2()) -> Image:
	var output := Image.create(viewport_size.x,viewport_size.y,false,design_image.get_format())
	output.fill(Color("0b1512"))
	var viewport := Vector2(viewport_size)
	var safe_area := physical_safe_area if physical_safe_area.size.x > 0.0 and physical_safe_area.size.y > 0.0 else Rect2(Vector2.ZERO,viewport)
	var layout := viewport_layout_in_area(viewport,safe_area)
	var content_size := Vector2i(roundi(Vector2(layout.content_size).x),roundi(Vector2(layout.content_size).y))
	var scaled := design_image.duplicate(); scaled.resize(content_size.x,content_size.y,Image.INTERPOLATE_NEAREST)
	var destination := Vector2i(roundi(Vector2(layout.offset).x),roundi(Vector2(layout.offset).y))
	output.blit_rect(scaled,Rect2i(Vector2i.ZERO,content_size),destination)
	return output
