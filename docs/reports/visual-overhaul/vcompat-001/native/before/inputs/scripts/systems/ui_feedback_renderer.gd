class_name UiFeedbackRenderer
extends RefCounted


## Рисует короткое затемнение открытия и золотые искры подтверждения поверх активного интерфейса.
static func draw(game: Node2D) -> void:
	var ratio: float = game.UiFeedbackSystem.transition_ratio(game)
	if ratio > 0.0:
		game.draw_rect(Rect2(0, 0, 1152, 648), Color(0.02, 0.015, 0.01, ratio * 0.34), true)
		var sweep_x := lerpf(170.0, 982.0, 1.0 - ratio)
		game.draw_line(Vector2(sweep_x, 52), Vector2(sweep_x, 596), Color(1.0, 0.78, 0.31, ratio * 0.22), 2.0)
	for particle in game.ui_particles:
		draw_particle(game, particle)


## Рисует одну искру с замедлением, прозрачностью и небольшим тёплым ореолом.
static func draw_particle(game: Node2D, particle: Dictionary) -> void:
	var age := float(particle.age)
	var progress := clampf(age / game.UiFeedbackSystem.PARTICLE_DURATION, 0.0, 1.0)
	var position: Vector2 = Vector2(particle.origin) + Vector2(particle.velocity) * age * (1.0 - progress * 0.45)
	var alpha := (1.0 - progress) * 0.72
	game.draw_circle(position, 2.7 - progress * 1.4, Color(1.0, 0.78, 0.28, alpha))
	game.draw_circle(position, 5.5 - progress * 2.5, Color(1.0, 0.86, 0.45, alpha * 0.16), false, 1.0)
