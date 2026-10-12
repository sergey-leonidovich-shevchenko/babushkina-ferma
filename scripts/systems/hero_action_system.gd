extends RefCounted

const META := &"hero_action_pose"
const TOOLS := ["hoe", "mine", "chop", "water", "plant", "harvest", "fish_cast"]
const DURATION := 0.48


## Оставляет диагональное перемещение, но выбирает один из четырёх устойчивых художественных ракурсов.
static func cardinal(direction: Vector2) -> Vector2:
	if direction.is_zero_approx(): return Vector2.DOWN
	if absf(direction.x) >= absf(direction.y): return Vector2.LEFT if direction.x < 0.0 else Vector2.RIGHT
	return Vector2.UP if direction.y < 0.0 else Vector2.DOWN


## Запоминает ракурс и цель успешного действия независимо от громкости звука и последующих поворотов героя.
static func begin(game: Node, action: String, target: Vector2) -> void:
	if action not in TOOLS: return
	var current: Dictionary = game.get_meta(META, {})
	if String(current.get("action", "")) == action and String(current.get("location", "")) == game.current_location and float(current.get("remaining", 0.0)) > 0.0: return
	game.set_meta(META, {"action":action, "remaining":DURATION, "direction":cardinal(game.facing), "target":target, "location":game.current_location})
	game.notify_tutorial("hero_tools")


## Продвигает короткую анимацию инструмента, не двигая физическую позицию героя и не изменяя результат действия.
static func update(game: Node, delta: float) -> void:
	var pose: Dictionary = game.get_meta(META, {})
	if pose.is_empty(): return
	pose.remaining = maxf(0.0, float(pose.remaining) - maxf(delta, 0.0))
	if float(pose.remaining) <= 0.0 or String(pose.location) != game.current_location:
		game.remove_meta(META)
	else:
		game.set_meta(META, pose)


## Возвращает снимок активной позы или пустой словарь для спокойной ходьбы.
static func pose(game: Node) -> Dictionary:
	var result: Dictionary = game.get_meta(META, {})
	if result.is_empty() or String(result.location) != game.current_location: return {}
	return result


## Вычисляет нормализованную фазу подготовки, контакта и возврата инструмента.
static func progress(game: Node) -> float:
	var current := pose(game)
	return -1.0 if current.is_empty() else clampf(1.0 - float(current.remaining) / DURATION, 0.0, 1.0)


## Удерживает крайние фазы чуть дольше для читаемого замаха и не зацикливает последнюю позу.
static func frame(progress_value: float) -> int:
	if progress_value < 0.18: return 0
	if progress_value < 0.43: return 1
	if progress_value < 0.72: return 2
	return 3
