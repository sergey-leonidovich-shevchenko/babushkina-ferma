extends "res://tools/qa/performance/cpu_profile_game.gd"

var render_variant:="full"

## Отделяет стоимость окна от скрытого мира только в измерительном профиле, не меняя production-renderer.
func _draw() -> void:
	if render_variant=="full": super._draw(); return
	if render_variant=="flat-ui":
		for style in preload("res://scripts/presentation/moon_theme.gd").styles.values(): style.set_corner_radius_all(0)
	var started:=Time.get_ticks_usec()
	draw_ui()
	record_cpu("draw",started)
