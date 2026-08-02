extends RefCounted

## Типизированное изменяемое состояние героя. Логика остаётся в системах,
## поэтому модель можно создавать и тестировать без Node/сцены.

var position: Vector2 = Vector2(260, 360)
var facing: Vector2 = Vector2.RIGHT
var hp: int = 100
var max_hp: int = 100
var mana: int = 40
var max_mana: int = 40
var xp: int = 0
var level: int = 1
var skill_points: int = 0
var energy: int = 12
var recruited_companions: Array[String] = []
var active_companions: Array[String] = []


## Приводит загруженное состояние к безопасным допустимым значениям.
func normalize() -> void:
	hp = clampi(hp, 0, maxi(max_hp, 1))
	mana = clampi(mana, 0, maxi(max_mana, 0))
	energy = maxi(energy, 0)
	level = maxi(level, 1)
	xp = maxi(xp, 0)
	skill_points = maxi(skill_points, 0)
