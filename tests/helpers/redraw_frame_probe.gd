extends "res://scripts/game.gd"

var review_phase := "warmup"
var review_process: Dictionary = {}
var review_physics: Dictionary = {}
var review_draw: Dictionary = {}
var review_draw_state: Dictionary = {}


## Снимает три фактических флага интерфейса для проверки последнего показанного состояния.
func review_ui() -> Array:
	return [menu_state.pause_open, inventory_open, LevelEditorSystem.active(self)]


## Даёт каждой фазе чистый RGB-маркер для проверки фактической свежести framebuffer.
func review_marker_color() -> Color:
	return {"world": Color.RED, "pause": Color.GREEN, "inventory": Color.BLUE,
		"editor": Color.YELLOW, "resumed": Color.CYAN}.get(review_phase, Color.WHITE)


## Выполняет настоящий кадровый обработчик и запоминает его последнее состояние перед draw.
func _process(delta: float) -> void:
	super._process(delta)
	var frame := Engine.get_process_frames()
	review_process[frame] = {
		"frame": frame,
		"phase": review_phase,
		"time_us": Time.get_ticks_usec(),
		"physics_frame": Engine.get_physics_frames(),
		"ui": review_ui(),
		"minutes": game_minutes,
		"location": current_location
	}


## Считает завершённые настоящие физические шаги и сохраняет сумму их дельт без подмены симуляции.
func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	var frame := Engine.get_process_frames()
	var row: Dictionary = review_physics.get(frame, {"count": 0, "delta_sum": 0.0})
	row.count += 1
	row.delta_sum += delta
	review_physics[frame] = row


## Выполняет реальную отрисовку и связывает её количество и UI с номером кадрового такта.
func _draw() -> void:
	super._draw()
	var frame := Engine.get_process_frames()
	review_draw[frame] = int(review_draw.get(frame, 0)) + 1
	review_draw_state[frame] = review_ui()
	# Маркер принадлежит той же CanvasItem-команде, что настоящий интерфейс, а не отдельному overlay.
	draw_set_transform(Vector2.ZERO)
	draw_rect(Rect2(0, 0, 1152, 6), review_marker_color())
