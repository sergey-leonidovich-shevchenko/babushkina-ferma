extends RefCounted

const DEPTH_SHALLOW := "shallow"
const DEPTH_MIDDLE := "middle"
const DEPTH_DEEP := "deep"
const HOOK_PERFECT := "perfect"
const HOOK_GOOD := "good"
const HOOK_LATE := "late"


## Определяет глубину заброса по силе, чтобы заряд менял доступную экосистему, а не только качество.
static func depth_for(cast_power: float) -> String:
	if cast_power >= 0.72: return DEPTH_DEEP
	if cast_power >= 0.36: return DEPTH_MIDDLE
	return DEPTH_SHALLOW


## Оценивает точность отпускания около дальнего, но не крайнего положения шкалы.
static func cast_grade(cast_power: float) -> String:
	if cast_power >= 0.82 and cast_power <= 0.98: return "perfect"
	if cast_power >= 0.5: return "good"
	return "short"


## Оценивает реакцию на поклёвку по оставшемуся времени окна подсечки.
static func hook_grade(time_left: float, hook_window: float) -> String:
	var ratio := time_left / maxf(hook_window, 0.01)
	if ratio >= 0.68: return HOOK_PERFECT
	if ratio >= 0.30: return HOOK_GOOD
	return HOOK_LATE


## Возвращает стартовый прогресс за качество подсечки без автоматической победы в мини-игре.
static func hook_start_progress(grade: String) -> float:
	return {HOOK_PERFECT:0.32, HOOK_GOOD:0.23, HOOK_LATE:0.15}.get(grade, 0.23)


## Превращает непрерывное удержание рыбы в зоне в ограниченный бонус скорости вываживания.
static func control_multiplier(streak_seconds: float) -> float:
	return 1.0 + minf(maxf(streak_seconds, 0.0) / 5.0, 0.6)


## Рассчитывает скорость натяжения лески с учётом сложности и рывкового характера рыбы.
static func tension_gain(difficulty: float, behavior: String) -> float:
	var rate := 0.11 + difficulty * 0.0022
	if behavior == "dart": rate *= 1.22
	elif behavior == "smooth": rate *= 0.82
	return rate


## Даёт небольшой бонус размера за точную подсечку и штраф за запоздалую.
static func hook_size_bonus(grade: String) -> float:
	return {HOOK_PERFECT:0.08, HOOK_GOOD:0.0, HOOK_LATE:-0.06}.get(grade, 0.0)


## Возвращает числовой порядок качества для сохранения лучшего результата вида.
static func quality_rank(quality: String) -> int:
	return ["normal", "silver", "gold", "iridium"].find(quality)
