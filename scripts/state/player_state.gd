extends RefCounted

## Типизированное изменяемое состояние героя. Логика остаётся в системах,
## поэтому модель можно создавать и тестировать без Node/сцены.

var position: Vector2 = Vector2(280, 510)
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
var companion_command: String = "follow"
var companion_bonds: Dictionary = {}


## Приводит загруженное состояние к безопасным допустимым значениям.
func normalize() -> void:
	hp = clampi(hp, 0, maxi(max_hp, 1))
	mana = clampi(mana, 0, maxi(max_mana, 0))
	energy = maxi(energy, 0)
	level = clampi(level, 1, 20)
	xp = maxi(xp, 0)
	skill_points = maxi(skill_points, 0)
	if companion_command not in ["follow", "wait", "attack", "defend"]: companion_command = "follow"
	for companion_id in companion_bonds: companion_bonds[companion_id] = maxi(0, int(companion_bonds[companion_id]))
