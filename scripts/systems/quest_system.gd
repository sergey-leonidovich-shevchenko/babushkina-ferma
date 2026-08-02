extends RefCounted

static func talk_to_grandmother(game: Node) -> void:
	game.notify_tutorial("talk")
	if not game.quest_active and not game.quest_complete:
		game.quest_active = true; game.message = "Задание: принеси бабушке 10 морковок"
	elif game.quest_active and game.carrots >= 10:
		game.carrots -= 10; game.coins += 50; game.award_xp(25); game.quest_active = false; game.quest_complete = true; game.has_bow = true
		game.message = "Квест выполнен! +50 монет, +25 опыта и охотничий лук"; game.notify_tutorial("quest_complete")
	elif game.quest_active: game.message = "Бабушка ждёт морковь: %d/10" % game.carrots
	else: game.message = "Спасибо за помощь, внучек!"
