extends RefCounted

const DESIGN_SIZE := Vector2(1152, 648)
const MIN_TOUCH_TARGET := Vector2(48, 48)
const TEXT_SCALES := [0.9, 1.0, 1.1, 1.2]
const TOUCH_SCALES := [0.9, 1.0, 1.15, 1.3]


## Возвращает letterbox-преобразование из базовой сцены 1152×648 в реальное окно без искажения пропорций.
static func viewport_layout(viewport_size: Vector2) -> Dictionary:
	var scale := minf(viewport_size.x / DESIGN_SIZE.x, viewport_size.y / DESIGN_SIZE.y)
	var content_size := DESIGN_SIZE * scale
	return {"scale": scale, "offset": (viewport_size - content_size) * 0.5, "content_size": content_size}


## Переводит координату физического экрана в единую дизайн-сетку для точного совпадения рисунка и hit-зоны.
static func screen_to_design(point: Vector2, viewport_size: Vector2) -> Vector2:
	var layout := viewport_layout(viewport_size)
	return (point - Vector2(layout.offset)) / float(layout.scale)


## Переводит координату дизайн-сетки в физический экран для проверок Full HD, 2K и 4K.
static func design_to_screen(point: Vector2, viewport_size: Vector2) -> Vector2:
	var layout := viewport_layout(viewport_size)
	return Vector2(layout.offset) + point * float(layout.scale)


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
	var scaled := maxi(1, roundi(requested_size * game.settings_state.text_scale))
	if width <= 0.0: return scaled
	while scaled > 6 and font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, scaled).x > width:
		scaled -= 1
	return scaled


## Масштабирует сенсорную кнопку относительно её центра, сохраняя минимальную удобную область 48×48 px.
static func touch_rect(game: Node, base_rect: Rect2) -> Rect2:
	var size: Vector2 = base_rect.size * game.settings_state.touch_scale
	size.x = maxf(size.x, MIN_TOUCH_TARGET.x); size.y = maxf(size.y, MIN_TOUCH_TARGET.y)
	return Rect2(base_rect.get_center() - size * 0.5, size).intersection(Rect2(Vector2.ZERO, DESIGN_SIZE))
