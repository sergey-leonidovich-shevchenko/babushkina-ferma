extends RefCounted

const PREFERENCES := {
	"miron":{"loves":["carrot","bread"],"likes":["apple","fish"]},
	"agafya":{"loves":["flower","berries"],"likes":["mushroom","orange"]},
	"varvara":{"loves":["fish","watermelon"],"likes":["berries","bread"]},
	"gavrila":{"loves":["nut","bread"],"likes":["carrot","mushroom"]},
	"dunya":{"loves":["mushroom","apple"],"likes":["carrot","berries"]},
}
const PERSONAL_REQUESTS := {
	"miron":{"item":"carrot","count":3,"friendship":15,"coins":28,"xp":12,"text":"Мирон собирает припасы для ночного караула."},
	"agafya":{"item":"flower","count":2,"friendship":12,"coins":24,"xp":14,"text":"Агафье нужны луговые цветы для успокаивающего настоя."},
	"varvara":{"item":"fish","count":2,"friendship":18,"coins":34,"xp":16,"text":"Варвара обещала угостить рыбаков свежей ухой."},
	"gavrila":{"item":"metal","count":2,"friendship":20,"coins":42,"xp":18,"text":"Гаврила испытывает новый сплав для деревенских инструментов."},
	"dunya":{"item":"mushroom","count":2,"friendship":10,"coins":26,"xp":12,"text":"Дуня готовит начинку для праздничных пирогов."},
}


## Возвращает сохранённую память о жителе, не стирая данные квестов и подарков.
static func memory(game: Node, npc_id: String) -> Dictionary:
	return game.state.player.quest_memory.get(npc_id, {}).duplicate(true)


## Вычисляет изменение дружбы с учётом индивидуального вкуса и дневного ограничения.
static func gift_value(game: Node, npc_id: String, kind: String) -> int:
	var remembered := memory(game, npc_id)
	if int(remembered.get("gift_day", 0)) == game.day: return 0
	var taste: Dictionary = PREFERENCES.get(npc_id, {})
	if kind in taste.get("loves", []): return 12
	if kind in taste.get("likes", []): return 6
	return 8 if game.InventorySystem.data(kind).get("edible", false) else -2


## Передаёт выбранный предмет NPC, записывает реакцию и не разрешает фармить дружбу в один день.
static func give_gift(game: Node, npc_id: String, kind: String) -> bool:
	var value := gift_value(game, npc_id, kind)
	if value == 0:
		game.message = "Сегодня этот житель уже получил подарок"; return false
	if not game.change_inventory_count(kind, -1): return false
	game.state.player.relationships[npc_id] = clampi(int(game.state.player.relationships.get(npc_id, 0)) + value, 0, 100)
	var remembered := memory(game, npc_id); remembered.gift_day = game.day; remembered.last_gift = kind; game.state.player.quest_memory[npc_id] = remembered
	game.message = "Любимый подарок! Дружба +%d" % value if value >= 10 else ("Подарок принят • дружба +%d" % value if value > 0 else "Похоже, подарок не понравился")
	game.play_sfx("quest_accept"); game.notify_tutorial("npc_gift"); return true


## Возвращает словесную ступень отношений для диалога и будущих условий сюжета.
static func friendship_tier(value: int) -> String:
	if value >= 80: return "верный друг"
	if value >= 50: return "добрый друг"
	if value >= 25: return "приятель"
	return "знакомый"


## Собирает личную реплику NPC из отношений, распорядка и доступного поручения.
static func dialogue_text(game: Node, npc_id: String) -> String:
	var friendship := int(game.state.player.relationships.get(npc_id, 0))
	var schedule: String = String(game.NpcMovementSystem.actor(game, npc_id, Vector2.ZERO).get("schedule", "дела"))
	var base := "%s • дружба %d/100 (%s). Сейчас: %s." % [game.QuestSystem.npc_name(npc_id), friendship, friendship_tier(friendship), schedule]
	var request: Dictionary = PERSONAL_REQUESTS.get(npc_id, {})
	if request.is_empty() or bool(memory(game, npc_id).get("personal_done", false)): return base + " Спасибо, что заглянул."
	if friendship < int(request.friendship): return base + " Мы ещё мало знакомы — поговорим снова позже."
	return "%s\n%s Принеси %s ×%d." % [base, request.text, game.inventory_item_name(request.item), request.count]


## Завершает личное поручение дружеского NPC и выдаёт единственную постоянную награду.
static func claim_personal_request(game: Node, npc_id: String) -> bool:
	var request: Dictionary = PERSONAL_REQUESTS.get(npc_id, {})
	var remembered := memory(game, npc_id)
	if request.is_empty() or bool(remembered.get("personal_done", false)) or int(game.state.player.relationships.get(npc_id, 0)) < int(request.friendship): return false
	if game.inventory_item_count(request.item) < int(request.count): return false
	game.change_inventory_count(request.item, -int(request.count)); game.coins += int(request.coins); game.award_xp(int(request.xp), "quest")
	remembered.personal_done = true; remembered.personal_day = game.day; game.state.player.quest_memory[npc_id] = remembered
	game.message = "Личное поручение выполнено • +%d монет • +%d опыта" % [request.coins, request.xp]
	game.play_sfx("quest_complete"); game.notify_tutorial("personal_request"); return true
