extends RefCounted

const AVAILABLE := "available"
const ACTIVE := "active"
const COMPLETED := "completed"

const MISSIONS := {
	"story_relic": {
		"type": "СЮЖЕТ",
		"title": "Сердце пещеры",
		"giver": "Староста Мирон",
		"description": "Победи Хранителя глубин в Кристальной пещере и принеси Лунную реликвию.",
		"item": "moon_relic",
		"count": 1,
		"coins": 120,
		"xp": 50,
		"reward_item": "guardian_armor",
		"reward_count": 1,
	},
	"side_seed": {
		"type": "ПОБОЧНОЕ",
		"title": "Редкий росток",
		"giver": "Травница Агафья",
		"description": "Победи хищное растение в лесу и принеси одно редкое семя.",
		"item": "rare_seeds",
		"count": 1,
		"coins": 35,
		"xp": 20,
		"reward_item": "berries",
		"reward_count": 3,
	},
}

static func talk_to_grandmother(game: Node) -> void:
	game.notify_tutorial("talk")
	if not game.quest_active and not game.quest_complete:
		game.quest_active = true
		game.message = "Задание: принеси бабушке 10 морковок"
	elif game.quest_active and game.carrots >= 10:
		game.carrots -= 10
		game.coins += 50
		game.award_xp(25)
		game.quest_active = false
		game.quest_complete = true
		game.has_bow = true
		game.message = "Квест выполнен! +50 монет, +25 опыта и охотничий лук"
		game.notify_tutorial("quest_complete")
	elif game.quest_active:
		game.message = "Бабушка ждёт морковь: %d/10" % game.carrots
	else:
		game.message = "Спасибо за помощь, внучек!"

static func talk(game: Node, mission_id: String) -> bool:
	if not MISSIONS.has(mission_id):
		return false
	var mission: Dictionary = MISSIONS[mission_id]
	var state: String = game.mission_states.get(mission_id, AVAILABLE)
	if state == AVAILABLE:
		game.mission_states[mission_id] = ACTIVE
		game.message = "%s: %s. Открой журнал [J]" % [mission.type, mission.title]
		game.notify_tutorial("mission_accept")
		return true
	if state == ACTIVE:
		var current: int = game.inventory_item_count(mission.item)
		if current < mission.count:
			game.message = "%s ждёт: %s %d/%d" % [mission.giver, game.inventory_item_name(mission.item), current, mission.count]
			return true
		game.change_inventory_count(mission.item, -mission.count)
		game.change_inventory_count(mission.reward_item, mission.reward_count)
		game.coins += mission.coins
		game.award_xp(mission.xp)
		game.mission_states[mission_id] = COMPLETED
		game.message = "%s выполнено! +%d монет, +%d XP, %s" % [mission.title, mission.coins, mission.xp, game.inventory_item_name(mission.reward_item)]
		game.notify_tutorial("mission_complete")
		if mission_id == "side_seed":
			game.notify_tutorial("side_mission")
		return true
	game.message = "%s благодарит тебя за помощь" % mission.giver
	return true

static func objective_text(game: Node, mission_id: String) -> String:
	var mission: Dictionary = MISSIONS[mission_id]
	var state: String = game.mission_states.get(mission_id, AVAILABLE)
	if state == AVAILABLE:
		return "Поговори: %s" % mission.giver
	if state == COMPLETED:
		return "Выполнено"
	var count: int = mini(game.inventory_item_count(mission.item), mission.count)
	return "%s: %d/%d" % [game.inventory_item_name(mission.item), count, mission.count]
