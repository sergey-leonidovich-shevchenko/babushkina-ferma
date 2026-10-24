extends RefCounted

const Contact := preload("res://scripts/presentation/foliage_contact.gd")
const FLAG := &"foliage_recovery_enabled"
const ATTACK := 0.08
const RELEASE := 0.18
const EPSILON := 0.005
const MAX_BEND := 4.36
const LIMIT := Contact.CAPACITY
var entries := {}
var last_seconds := -1.0
var last_player := Vector2.INF
var last_world := ""


## Удаляет только временные числовые отклонения; ресурсов, таймеров и игровых ссылок здесь нет.
func clear() -> void:
	entries.clear()
	last_seconds = -1.0
	last_player = Vector2.INF
	last_world = ""


## Применяет разрешённые часы симуляции; пауза замораживает, перенос и отключение немедленно очищают след.
func values(game: Node, desired: PackedVector2Array, visible: Array) -> PackedVector2Array:
	var frame := Contact.Frame.read(game)
	var contact: Variant = game.get_meta(Contact.FLAG, true)
	if frame.is_empty() or not frame.active or typeof(contact) != TYPE_BOOL or not contact:
		clear()
		return Contact.empty()
	var flag: Variant = game.get_meta(FLAG, true)
	if typeof(flag) != TYPE_BOOL or not flag:
		clear()
		return desired.duplicate()
	if _frame_discontinuous(frame):
		clear()
	last_player = frame.player_world
	last_world = frame.world
	return sample(desired, visible, float(frame.seconds))


## Отделяет перенос от разрешённого движения, чтобы старый изгиб не переходил к новой позиции героя.
func _frame_discontinuous(frame: Dictionary) -> bool:
	if not last_player.is_finite():
		return false
	var elapsed := maxf(0.0, float(frame.seconds) - last_seconds)
	var max_step := maxf(8.0, Contact.Speed.MAX_SPEED * elapsed)
	var displacement := Vector2(frame.player_world).distance_to(last_player)
	return last_world != frame.world or displacement > max_step


## Интегрирует ограниченный набор аналитической экспонентой: без перелёта, зависимости от частоты draw и истории кадров.
func sample(desired: PackedVector2Array, visible: Array, seconds: float) -> PackedVector2Array:
	var result := Contact.empty()
	if desired.size() != LIMIT or not is_finite(seconds) or seconds < 0 or visible.size() > LIMIT:
		clear()
		return result
	var allowed := {}
	# Сначала проверяем весь ограниченный набор: неверный индекс не оставляет частично обновлённый кадр.
	for slot in visible:
		if typeof(slot) != TYPE_INT or slot < 0 or slot >= LIMIT:
			clear()
			return result
		allowed[slot] = true
	for slot in entries.keys():
		if not allowed.has(slot):
			entries.erase(slot)
	if last_seconds > seconds:
		clear()
	var delta := maxf(0.0, seconds - last_seconds) if last_seconds >= 0 else 0.0
	last_seconds = seconds
	for slot in allowed:
		var target: Vector2 = desired[slot]
		if not target.is_finite() or target.length() > MAX_BEND:
			entries.erase(slot)
			continue
		var previous: Vector2 = entries.get(slot, Vector2.ZERO)
		var tau := RELEASE if target.length_squared() < previous.length_squared() else ATTACK
		var value := target + (previous - target) * exp(-delta / tau) if delta > 0 else previous
		if target == Vector2.ZERO and value.length() <= EPSILON:
			entries.erase(slot)
			continue
		# Точный ноль при смене знака тоже является новым состоянием. Старый вектор нельзя сохранять.
		if value == Vector2.ZERO:
			entries.erase(slot)
		else:
			entries[slot] = value
		result[slot] = value
	return result
