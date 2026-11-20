extends RefCounted

const LEGACY := &"daylight_palette_legacy"
const NIGHT := Color(0.055, 0.08, 0.20, 0.62)
const WARM := Color("e4cb94")
const WARM_ALPHA := 0.08


## Временный откат принадлежит одному canvas и никогда не сохраняется в настройках.
static func enabled(canvas: CanvasItem) -> bool:
	var value: Variant = canvas.get_meta(LEGACY, false)
	return not (value is bool and value)


## Использует календарные дробные минуты; не создаёт собственных часов или кешей.
static func tint(minutes: float) -> Color:
	if not is_finite(minutes):
		return Color.TRANSPARENT
	var minute := fposmod(minutes, 1440.0)
	if minute < 300.0 or minute >= 1200.0:
		return NIGHT
	if minute >= 420.0 and minute < 1080.0:
		return Color.TRANSPARENT
	var dawn := minute < 420.0
	var progress := (minute - (300.0 if dawn else 1080.0)) / 120.0
	var smooth := progress * progress * (3.0 - 2.0 * progress)
	var dark := NIGHT.a * (1.0 - smooth if dawn else smooth)
	# Квадрат синуса обнуляет производную тёплого блика на обоих краях перехода.
	var wave := sin(PI * progress)
	var warm := WARM_ALPHA * wave * wave
	var alpha := dark + warm * (1.0 - dark)
	if alpha <= 0.0:
		return Color.TRANSPARENT
	# Сводим warm-over-cool в один обычный straight-alpha draw_rect.
	var cool_weight := dark * (1.0 - warm)
	return Color(
		(NIGHT.r * cool_weight + WARM.r * warm) / alpha,
		(NIGHT.g * cool_weight + WARM.g * warm) / alpha,
		(NIGHT.b * cool_weight + WARM.b * warm) / alpha,
		alpha
	)
