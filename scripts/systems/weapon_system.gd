extends RefCounted

const ORDER := ["forest_sword", "axe", "iron_spear", "war_hammer", "bow", "moon_staff", "crystal_sword", "orc_blade", "pirate_cutlass"]
const DATA := {
	"none":{"item":"","class":"unarmed","damage":0,"range":78.0,"duration":0.42,"cooldown":0.50,"durability":""},
	"forest_sword":{"item":"sword","class":"blade","damage":1,"range":108.0,"duration":0.48,"cooldown":0.54,"durability":"sword"},
	"crystal_sword":{"item":"crystal_sword","class":"blade","damage":2,"range":112.0,"duration":0.46,"cooldown":0.50,"durability":"crystal_sword"},
	"bow":{"item":"bow","class":"bow","damage":1,"range":300.0,"duration":0.72,"cooldown":0.82,"durability":"bow"},
	"axe":{"item":"axe","class":"heavy","damage":2,"range":100.0,"duration":0.76,"cooldown":0.92,"durability":"axe"},
	"iron_spear":{"item":"iron_spear","class":"spear","damage":2,"range":154.0,"duration":0.58,"cooldown":0.68,"durability":"iron_spear"},
	"war_hammer":{"item":"war_hammer","class":"heavy","damage":4,"range":94.0,"duration":0.88,"cooldown":1.05,"durability":"war_hammer"},
	"moon_staff":{"item":"moon_staff","class":"staff","damage":3,"range":270.0,"duration":0.82,"cooldown":0.96,"durability":"moon_staff"},
	"orc_blade":{"item":"orc_blade","class":"blade","damage":3,"range":112.0,"duration":0.56,"cooldown":0.64,"durability":"orc_blade"},
	"pirate_cutlass":{"item":"pirate_cutlass","class":"blade","damage":4,"range":116.0,"duration":0.52,"cooldown":0.58,"durability":"pirate_cutlass"},
}


## Возвращает безопасный профиль выбранного оружия, включая безоружный резерв.
static func data(kind: String) -> Dictionary:
	return DATA.get(kind, DATA.none)


## Возвращает предмет инвентаря, которому соответствует runtime-идентификатор оружия.
static func item_kind(kind: String) -> String:
	return String(data(kind).item)


## Преобразует предмет рюкзака в runtime-идентификатор оружия героя.
static func weapon_for_item(kind: String) -> String:
	if kind == "sword": return "forest_sword"
	for weapon_id in DATA:
		if String(DATA[weapon_id].item) == kind: return weapon_id
	return "none"


## Проверяет, принадлежит ли герою конкретное оружие из инвентаря или экипировки.
static func owns(game: Node, kind: String) -> bool:
	if kind == "none": return true
	var item := item_kind(kind)
	return not item.is_empty() and game.inventory_item_count(item) > 0


## Возвращает упорядоченный список доступного оружия вместе с кулаками.
static func available(game: Node) -> Array[String]:
	var result: Array[String] = ["none"]
	for kind in ORDER:
		if owns(game, kind): result.append(kind)
	return result


## Выбирает следующее имеющееся оружие и синхронизирует слот рук экипировки.
static func cycle(game: Node) -> String:
	var weapons := available(game)
	var current := weapons.find(game.equipped_weapon)
	game.equipped_weapon = weapons[posmod(maxi(current, 0) + 1, weapons.size())]
	var item := item_kind(game.equipped_weapon)
	game.equipment.hands = item if not item.is_empty() and game.InventorySystem.data(item).get("equip", "") == "hands" else ""
	game.sword_equipped = game.equipped_weapon in ["forest_sword", "crystal_sword"]
	return game.equipped_weapon


## Проверяет завершение предыдущего замаха и общей перезарядки оружия.
static func can_start_attack(game: Node) -> bool:
	if game.player_attack_timer > 0.0 or game.player_attack_cooldown > 0.0: return false
	if not owns(game, game.equipped_weapon): game.equipped_weapon = "none"
	var durability := durability_kind(game.equipped_weapon)
	return durability.is_empty() or game.AdventurePolishSystem.can_use(game, durability)


## Запускает временную шкалу атаки выбранного класса и её индивидуальную перезарядку.
static func begin_attack(game: Node, force: bool = false) -> bool:
	if not force and not can_start_attack(game): return false
	var profile := data(game.equipped_weapon)
	game.player_attack_weapon = game.equipped_weapon
	game.player_attack_timer = float(profile.duration)
	game.player_attack_cooldown = float(profile.cooldown)
	game.notify_tutorial("weapon_cooldown")
	return true


## Уменьшает таймеры замаха, перезарядки и реакции героя на входящий урон.
static func update(game: Node, delta: float) -> void:
	game.player_attack_timer = maxf(game.player_attack_timer - delta, 0.0)
	game.player_attack_cooldown = maxf(game.player_attack_cooldown - delta, 0.0)
	game.player_hurt_timer = maxf(game.player_hurt_timer - delta, 0.0)


## Возвращает заполнение общей перезарядки, чтобы renderer мог показать её под героем.
static func cooldown_ratio(game: Node) -> float:
	var total := float(data(game.player_attack_weapon if not game.player_attack_weapon.is_empty() else game.equipped_weapon).cooldown)
	return clampf(game.player_attack_cooldown / maxf(total, 0.01), 0.0, 1.0)


## Возвращает длительность текущей или выбранной боевой анимации.
static func attack_duration(game: Node) -> float:
	return float(data(game.player_attack_weapon if game.player_attack_timer > 0.0 else game.equipped_weapon).duration)


## Возвращает нормализованный прогресс атаки от подготовки до восстановления.
static func attack_progress(game: Node) -> float:
	if game.player_attack_timer <= 0.0: return -1.0
	var duration := attack_duration(game)
	return clampf(1.0 - game.player_attack_timer / maxf(duration, 0.01), 0.0, 1.0)


## Возвращает дальность, базовый бонус урона и класс выбранного оружия через единый каталог.
static func range_of(kind: String) -> float:
	return float(data(kind).range)


## Возвращает собственный бонус урона оружия до кузницы, талантов и экипировки.
static func damage_bonus(kind: String) -> int:
	return int(data(kind).damage)


## Возвращает ключ прочности оружия для расхода, ремонта и сохранения.
static func durability_kind(kind: String) -> String:
	return String(data(kind).durability)


## Возвращает визуальный класс для траектории клинка, древкового оружия или снаряда.
static func weapon_class(kind: String) -> String:
	return String(data(kind).class)


## Запускает заметную реакцию героя на попадание и частично прерывает его восстановление.
static func hit_player(game: Node, source_position: Vector2) -> void:
	game.player_hurt_timer = 0.30
	game.player_hurt_direction = source_position.direction_to(game.player)
	game.player_attack_timer = minf(game.player_attack_timer, 0.10)
	game.state.player.feedback.camera_shake = maxf(float(game.state.player.feedback.get("camera_shake", 0.0)), 4.0)
	game.notify_tutorial("combat_hit_reaction")
