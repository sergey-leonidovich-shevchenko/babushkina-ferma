extends "res://tests/suites/suite_base.gd"

const Palette := preload("res://scripts/presentation/daylight_palette.gd")
const Events := preload("res://scripts/systems/world_event_system.gd")
const Save := preload("res://scripts/systems/save_system.gd")


## Проверяет календарную кривую и изоляцию отката без визуального/FPS-допуска.
func run() -> void:
	_test_endpoints()
	_test_curve()
	_test_owners_and_save()


## Дневной framebuffer и прежняя ночь остаются точными опорными состояниями.
func _test_endpoints() -> void:
	expect(Palette.tint(720.0) == Color.TRANSPARENT, "daylight leaves noon pixels unchanged")
	expect(Palette.tint(1320.0) == Palette.NIGHT, "daylight retains accepted night tint")
	expect(Palette.tint(0.0) == Palette.tint(1440.0), "daylight is seamless across midnight")
	expect(Palette.tint(-120.0) == Palette.tint(1320.0), "calendar minutes wrap backwards")
	expect(Palette.tint(360.0) == Palette.tint(1800.0), "calendar minutes wrap forwards")
	expect(
		Palette.tint(NAN) == Color.TRANSPARENT and Palette.tint(INF) == Color.TRANSPARENT,
		"invalid calendar values cannot submit NaN colors"
	)
	expect(
		Palette.tint(1140.0).r > Palette.NIGHT.r and Palette.tint(360.0).r > Palette.NIGHT.r,
		"both twilight transitions receive a restrained warm highlight"
	)


## Проверяется видимый premultiplied вклад, включая нулевую alpha на границе дня.
func _test_curve() -> void:
	var bounded := true
	for index: int in 5760:
		var color := Palette.tint(float(index) * 0.25)
		bounded = bounded and color.a >= 0.0 and color.a <= Palette.NIGHT.a + 0.000001
		for channel: float in [color.r, color.g, color.b, color.a]:
			bounded = bounded and is_finite(channel) and channel >= 0.0 and channel <= 1.0
	expect(bounded, "all quarter-minute samples are finite and retain the night opacity ceiling")
	var continuous := true
	var smooth := true
	for knot: float in [0.0, 300.0, 420.0, 1080.0, 1200.0, 1440.0]:
		var center := _visible(Palette.tint(knot))
		var left := _visible(Palette.tint(knot - 0.01))
		var right := _visible(Palette.tint(knot + 0.01))
		continuous = continuous and (left - right).length() < 0.00001
		smooth = smooth and ((center - left) / 0.01 - (right - center) / 0.01).length() < 0.00001
	expect(continuous, "twilight colors have no visible jump at any calendar knot")
	expect(smooth, "twilight first derivatives join without a slope jump")
	expect(
		Palette.tint(1140.25) != Palette.tint(1140.0),
		"fractional game minutes change the palette without integer stepping"
	)
	expect(
		Events.darkness(1140.0) == 0.31 and Events.is_night(1200.0),
		"gameplay darkness and night thresholds retain their existing contract"
	)


## Метаданные двух canvas независимы и не входят в полный существующий save.
func _test_owners_and_save() -> void:
	var first := make_game() as Node2D
	var second := Node2D.new()
	var before: Dictionary = Save.snapshot(first)
	first.set_meta(Palette.LEGACY, true)
	expect(
		not Palette.enabled(first) and Palette.enabled(second),
		"legacy flag affects only its own game canvas"
	)
	first.set_meta(Palette.LEGACY, "true")
	expect(Palette.enabled(first), "non-boolean metadata cannot accidentally disable the palette")
	first.remove_meta(Palette.LEGACY)
	expect(Palette.enabled(first), "removing the temporary rollback restores daylight")
	expect(Save.snapshot(first) == before, "daylight flag and pure samples do not alter game saves")
	first.free()
	second.free()


## RGB при нулевой прозрачности не влияет на framebuffer; сравнивается только видимый вклад.
func _visible(color: Color) -> Vector4:
	return Vector4(color.r * color.a, color.g * color.a, color.b * color.a, color.a)
