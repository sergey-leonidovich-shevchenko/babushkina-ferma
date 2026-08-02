extends RefCounted

const MAX_LEVEL := 5
const FAMILY_ORDER := ["poison_ivy", "thorn_bloom", "cactus"]
const TYPES := {
	"poison_ivy":{"damage":4,"mode":"contact","range":58.0,"interval":1.4},
	"thorn_bloom":{"damage":6,"mode":"ranged","range":175.0,"interval":2.2},
	"cactus":{"damage":5,"mode":"contact","range":54.0,"interval":1.2},
}
const SPAWNS := [
	{"kind":"poison_ivy","location":"forest","position":Vector2(420,760),"level":1},
	{"kind":"poison_ivy","location":"cursed","position":Vector2(480,520),"level":3},
	{"kind":"poison_ivy","location":"cursed","position":Vector2(1980,760),"level":5},
	{"kind":"thorn_bloom","location":"forest","position":Vector2(1420,360),"level":1},
	{"kind":"thorn_bloom","location":"cursed","position":Vector2(1020,680),"level":3},
	{"kind":"thorn_bloom","location":"cursed","position":Vector2(1900,380),"level":5},
	{"kind":"cactus","location":"rocky","position":Vector2(420,460),"level":1},
	{"kind":"cactus","location":"rocky","position":Vector2(1260,720),"level":3},
	{"kind":"cactus","location":"rocky","position":Vector2(2010,420),"level":5},
]


## Создаёт независимое runtime-состояние неподвижных растений-угроз.
static func default_hazards() -> Array:
	var result: Array = []
	for spawn in SPAWNS:
		var hazard: Dictionary = spawn.duplicate(true)
		hazard.level = clampi(int(hazard.level), 1, MAX_LEVEL)
		hazard.cooldown = 0.0
		hazard.pulse = float(result.size()) * 0.47
		result.append(hazard)
	return result


## Сопоставляет уровни 1–2, 3–4 и 5 строке визуального ранга.
static func visual_rank(level: int) -> int:
	return mini(floori(float(clampi(level, 1, MAX_LEVEL) - 1) / 2.0), 2)


## Увеличивает контактный или дистанционный урон растения с каждым уровнем.
static func damage(kind: String, level: int) -> int:
	return int(TYPES[kind].damage) + (clampi(level, 1, MAX_LEVEL) - 1) * 2


## Обновляет контактные уколы и дистанционные атаки укоренённых растений.
static func update(game: Node, delta: float) -> void:
	for index in game.hazard_nodes.size():
		var hazard: Dictionary = game.hazard_nodes[index]
		hazard.pulse += delta
		hazard.cooldown = maxf(float(hazard.cooldown) - delta, 0.0)
		if hazard.location == game.current_location:
			var data: Dictionary = TYPES[hazard.kind]
			var distance: float = hazard.position.distance_to(game.player)
			if distance <= float(data.range) and hazard.cooldown <= 0.0:
				hazard.cooldown = float(data.interval)
				game.CombatSystem.damage_player(game, damage(hazard.kind, hazard.level), game.LocaleSystem.entity(hazard.kind))
				game.notify_tutorial("contact_hazard" if data.mode == "contact" else "static_attacker")
		game.hazard_nodes[index] = hazard


## Возвращает ближайшую угрозу для подсветки и обучающей карточки.
static func nearest(game: Node, distance_limit: float = 150.0) -> int:
	var nearest_index := -1
	for index in game.hazard_nodes.size():
		var hazard: Dictionary = game.hazard_nodes[index]
		if hazard.location != game.current_location:
			continue
		var distance: float = game.player.distance_to(hazard.position)
		if distance < distance_limit:
			distance_limit = distance
			nearest_index = index
	return nearest_index
