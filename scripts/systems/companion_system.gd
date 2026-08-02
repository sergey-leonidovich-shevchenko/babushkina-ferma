extends RefCounted

const COMPANIONS := {
	"mila":{"sprite":0,"price":80,"leadership":0,"damage":2,"defense":3,"heal":0,"position":Vector2(350, 340)},
	"borislav":{"sprite":1,"price":140,"leadership":1,"damage":4,"defense":1,"heal":0,"position":Vector2(576, 340)},
	"luna":{"sprite":2,"price":180,"leadership":2,"damage":1,"defense":1,"heal":4,"position":Vector2(800, 340)},
}
const ATTACK_INTERVAL := 0.8
const HEAL_INTERVAL := 4.0


## Возвращает максимально допустимое число активных напарников по лидерству.
static func capacity(game: Node) -> int:
	return 2 if game.SkillSystem.skill(game, "leadership") >= 2 else 1


## Возвращает локализованное имя кандидата.
static func name(game: Node, companion_id: String) -> String:
	return game.LocaleSystem.entity("companion_%s" % companion_id)


## Находит ближайшего кандидата в тюремной локации.
static func nearest_prisoner(game: Node, distance_limit: float = 92.0) -> String:
	if game.current_location != "prison_interior":
		return ""
	var nearest := ""
	for companion_id in COMPANIONS:
		var distance: float = game.player.distance_to(COMPANIONS[companion_id].position)
		if distance < distance_limit:
			distance_limit = distance
			nearest = "prisoner:%s" % companion_id
	return nearest


## Возвращает позицию кандидата в тюремной локации.
static func interaction_position(interaction: String) -> Vector2:
	if not interaction.begins_with("prisoner:"):
		return Vector2.ZERO
	return COMPANIONS.get(interaction.get_slice(":", 1), {}).get("position", Vector2.ZERO)


## Выкупает нового кандидата либо меняет его активное состояние в группе.
static func interact(game: Node, companion_id: String) -> bool:
	if not COMPANIONS.has(companion_id):
		return false
	var data: Dictionary = COMPANIONS[companion_id]
	if companion_id not in game.recruited_companions:
		if game.SkillSystem.skill(game, "leadership") < int(data.leadership):
			game.message = game.LocaleSystem.text("companion_need_leadership", [int(data.leadership)])
			return false
		if game.coins < int(data.price):
			game.message = game.LocaleSystem.text("companion_need_coins", [int(data.price)])
			return false
		game.coins -= int(data.price)
		game.recruited_companions.append(companion_id)
		activate(game, companion_id)
		game.message = game.LocaleSystem.text("companion_recruited", [name(game, companion_id)])
		game.play_sfx("quest_complete")
		game.notify_tutorial("companion_recruit")
		return true
	if companion_id in game.active_companions:
		game.active_companions.erase(companion_id)
		game.message = game.LocaleSystem.text("companion_resting", [name(game, companion_id)])
		return true
	activate(game, companion_id)
	game.message = game.LocaleSystem.text("companion_active", [name(game, companion_id), game.active_companions.size(), capacity(game)])
	game.notify_tutorial("companion_change")
	return true


## Добавляет напарника в активную группу, заменяя первого при заполненном лимите.
static func activate(game: Node, companion_id: String) -> void:
	if companion_id in game.active_companions:
		return
	while game.active_companions.size() >= capacity(game):
		game.active_companions.pop_front()
	game.active_companions.append(companion_id)
	game.companion_positions[companion_id] = game.player + Vector2(-50, 35)


## Обновляет следование, лечение и автоматические атаки активной группы.
static func update(game: Node, delta: float) -> void:
	for companion_id in game.active_companions:
		var index: int = game.active_companions.find(companion_id)
		var desired: Vector2 = game.player + Vector2(-54 - index * 38, 38 + index * 22)
		var current: Vector2 = game.companion_positions.get(companion_id, desired)
		if current.distance_to(desired) > 420.0:
			current = desired
		game.companion_positions[companion_id] = current.move_toward(desired, 190.0 * delta)
	game.companion_attack_timer -= delta
	if game.companion_attack_timer <= 0.0:
		game.companion_attack_timer = ATTACK_INTERVAL
		attack_nearby(game)
	game.companion_heal_timer -= delta
	if game.companion_heal_timer <= 0.0:
		game.companion_heal_timer = HEAL_INTERVAL
		var healing := healing_power(game)
		if healing > 0:
			game.PlayerSystem.heal(game, healing)


## Ищет доступную цель рядом с каждым напарником и наносит ей его урон.
static func attack_nearby(game: Node) -> bool:
	for companion_id in game.active_companions:
		var position: Vector2 = game.companion_positions.get(companion_id, game.player)
		for index in game.enemy_nodes.size():
			var enemy: Dictionary = game.enemy_nodes[index]
			if enemy.alive and enemy.location == game.current_location and position.distance_to(enemy.position) <= 130.0:
				return game.CombatSystem.companion_attack(game, index, int(COMPANIONS[companion_id].damage), name(game, companion_id))
	return false


## Складывает защиту всех действующих напарников для уменьшения входящего урона.
static func defense_bonus(game: Node) -> int:
	var result := 0
	for companion_id in game.active_companions:
		result += int(COMPANIONS.get(companion_id, {}).get("defense", 0))
	return result


## Складывает периодическое лечение всех действующих целителей.
static func healing_power(game: Node) -> int:
	var result := 0
	for companion_id in game.active_companions:
		result += int(COMPANIONS.get(companion_id, {}).get("heal", 0))
	return result
