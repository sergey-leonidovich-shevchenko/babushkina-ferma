extends RefCounted

## Типизированное изменяемое состояние героя. Логика остаётся в системах,
## поэтому модель можно создавать и тестировать без Node/сцены.

var position: Vector2 = Vector2(420, 800)
var facing: Vector2 = Vector2.RIGHT
var hp: int = 100
var max_hp: int = 100
var mana: int = 40
var max_mana: int = 40
var xp: int = 0
var level: int = 1
var skill_points: int = 0
var talent_levels: Dictionary = {}
var energy: int = 12
var recruited_companions: Array[String] = []
var active_companions: Array[String] = []
var companion_command: String = "follow"
var companion_bonds: Dictionary = {}
var dodge_timer: float = 0.0
var dodge_cooldown: float = 0.0
var blocking: bool = false
var combat_hits: int = 0
var craft_count: int = 0
var profile: Dictionary = {"created":false,"name":"Гаврила","farm_name":"Бабушкина ферма","appearance":0,"clothes":0,"specialization":"farmer"}
var relationships: Dictionary = {}
var quest_memory: Dictionary = {}
var adventure_ui: Dictionary = {"creation_open":false,"dialogue_open":false,"dialogue":{},"choice":0,"target_enemy":-1}
var feedback: Dictionary = {"action":"","timer":0.0,"position":Vector2.ZERO,"damage_numbers":[],"footprints":[],"camera_shake":0.0}


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
	dodge_timer = maxf(dodge_timer, 0.0); dodge_cooldown = maxf(dodge_cooldown, 0.0); combat_hits = maxi(combat_hits, 0); craft_count = maxi(craft_count, 0)
	profile = profile.merged({"created":false,"name":"Гаврила","farm_name":"Бабушкина ферма","appearance":0,"clothes":0,"specialization":"farmer"}, false)
	for npc_id in relationships: relationships[npc_id] = clampi(int(relationships[npc_id]), 0, 100)
	adventure_ui.choice = maxi(0, int(adventure_ui.get("choice", 0)))
