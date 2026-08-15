extends RefCounted

const ACTIONS := {"hoe":0,"plant":1,"water":2,"harvest":3,"mine":4,"chop":5,"fish_cast":6,"attack":7,"hit":10,"defeat":14,"pickup":14,"quest_complete":15}
const TOOL_BY_ACTION := {"hoe":"hoe","water":"water","mine":"pickaxe","chop":"axe","fish_cast":"fishing_rod","attack":"weapon"}
const NAMES := ["Гаврила", "Василиса", "Мирослав", "Алёна", "Добрыня"]
const FARMS := ["Бабушкина ферма", "Лунный хутор", "Медовая долина", "Тихая роща"]
const SPECIALIZATIONS := ["farmer", "ranger", "artisan"]
const WORDS := {
	"new_story":["НОВАЯ ИСТОРИЯ","NEW STORY","NUEVA HISTORIA","NEUE GESCHICHTE","NOUVELLE HISTOIRE","新故事"],
	"name":["Имя","Name","Nombre","Name","Nom","姓名"], "farm":["Ферма","Farm","Granja","Hof","Ferme","农场"],
	"appearance":["Облик","Appearance","Aspecto","Aussehen","Apparence","外观"], "clothes":["Одежда","Clothes","Ropa","Kleidung","Tenue","服装"], "calling":["Призвание","Calling","Vocación","Berufung","Vocation","专长"],
	"variant":["Вариант %d","Variant %d","Variante %d","Variante %d","Variante %d","外观 %d"], "set":["Набор %d","Set %d","Conjunto %d","Set %d","Tenue %d","套装 %d"],
	"farmer":["Фермер: энергия и семена","Farmer: energy and seeds","Granjero: energía y semillas","Farmer: Energie und Saat","Fermier : énergie et graines","农夫：体力与种子"],
	"ranger":["Следопыт: здоровье и стрелы","Ranger: health and arrows","Explorador: salud y flechas","Waldläufer: Leben und Pfeile","Rôdeur : santé et flèches","游侠：生命与箭矢"],
	"artisan":["Ремесленник: монеты и металл","Artisan: coins and metal","Artesano: monedas y metal","Handwerker: Münzen und Metall","Artisan : pièces et métal","工匠：金币与金属"],
	"creation_help":["↑↓ поле • ←→ изменить • Enter начать","↑↓ field • ←→ change • Enter start","↑↓ campo • ←→ cambiar • Enter iniciar","↑↓ Feld • ←→ ändern • Enter starten","↑↓ champ • ←→ changer • Entrée démarrer","↑↓选择 • ←→更改 • 回车开始"],
	"leave":["Уйти","Leave","Salir","Gehen","Partir","离开"], "accept":["Принять","Accept","Aceptar","Annehmen","Accepter","接受"], "decline":["Отказаться","Decline","Rechazar","Ablehnen","Refuser","拒绝"], "continue":["Продолжить","Continue","Continuar","Weiter","Continuer","继续"],
	"reward_received":["Награда получена","Reward received","Recompensa recibida","Belohnung erhalten","Récompense reçue","已获得奖励"], "thanks":["Спасибо!","Thank you!","¡Gracias!","Danke!","Merci !","谢谢！"],
	"gift_hint":["G — подарить выбранную еду","G — gift selected food","G — regalar comida elegida","G — gewähltes Essen schenken","G — offrir l’aliment choisi","G—赠送所选食物"],
}


## Возвращает короткую строку нового интерфейса на выбранном языке игры.
static func word(game: Node, key: String, values: Array = []) -> String:
	var translated := String(WORDS.get(key, [key])[game.LocaleSystem.index()])
	return translated % values if not values.is_empty() else translated


## Открывает обязательное создание героя перед первым выходом в игровой мир.
static func begin_new_game(game: Node) -> void:
	game.state.player.adventure_ui.creation_open = true
	game.state.player.adventure_ui.creation_field = 0
	game.state.player.profile.created = false
	game.clear_movement_keys()
	game.notify_tutorial("character_creation")


## Возвращает признак активного полноэкранного или диалогового окна этапа.
static func has_modal(game: Node) -> bool:
	return bool(game.state.player.adventure_ui.get("creation_open", false)) or bool(game.state.player.adventure_ui.get("dialogue_open", false))


## Обрабатывает создание героя, диалоговые варианты и фиксацию боевой цели.
static func handle_input(game: Node, event: InputEvent) -> bool:
	var ui: Dictionary = game.state.player.adventure_ui
	if not has_modal(game):
		if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_Q:
			cycle_target(game); return true
		return false
	var key := -1
	if event is InputEventKey and event.pressed and not event.echo: key = int(event.keycode)
	elif event is InputEventJoypadButton and event.pressed:
		key = {JOY_BUTTON_DPAD_LEFT:KEY_LEFT,JOY_BUTTON_DPAD_RIGHT:KEY_RIGHT,JOY_BUTTON_DPAD_UP:KEY_UP,JOY_BUTTON_DPAD_DOWN:KEY_DOWN,JOY_BUTTON_A:KEY_ENTER,JOY_BUTTON_B:KEY_ESCAPE}.get(event.button_index, -1)
	if key < 0: return true
	if bool(ui.get("creation_open", false)): handle_creation_key(game, key)
	else: handle_dialogue_key(game, key)
	game.queue_redraw()
	return true


## Изменяет выбранное поле создания персонажа и подтверждает стартовую специализацию.
static func handle_creation_key(game: Node, key: int) -> void:
	var ui: Dictionary = game.state.player.adventure_ui
	var profile: Dictionary = game.state.player.profile
	var field: int = int(ui.get("creation_field", 0))
	if key == KEY_UP: ui.creation_field = posmod(field - 1, 5); return
	if key == KEY_DOWN: ui.creation_field = posmod(field + 1, 5); return
	if key in [KEY_LEFT, KEY_RIGHT]:
		var delta := -1 if key == KEY_LEFT else 1
		match field:
			0: profile.name = NAMES[posmod(NAMES.find(String(profile.name)) + delta, NAMES.size())]
			1: profile.farm_name = FARMS[posmod(FARMS.find(String(profile.farm_name)) + delta, FARMS.size())]
			2: profile.appearance = posmod(int(profile.appearance) + delta, 4)
			3: profile.clothes = posmod(int(profile.clothes) + delta, 5)
			4: profile.specialization = SPECIALIZATIONS[posmod(SPECIALIZATIONS.find(String(profile.specialization)) + delta, SPECIALIZATIONS.size())]
		return
	if key in [KEY_ENTER, KEY_SPACE]:
		profile.created = true; ui.creation_open = false
		apply_specialization(game); game.message = "%s — добро пожаловать на %s!" % [profile.name, profile.farm_name]
		game.play_sfx("quest_complete")


## Применяет один раз стартовый бонус выбранной специализации.
static func apply_specialization(game: Node) -> void:
	match String(game.state.player.profile.specialization):
		"farmer": game.energy += 4; game.change_inventory_count("seeds", 4)
		"ranger": game.player_max_hp += 10; game.player_hp = game.player_max_hp; game.change_inventory_count("arrows", 8)
		"artisan": game.coins += 40; game.change_inventory_count("metal", 1)


## Открывает портретный диалог квестового жителя, не выдавая задание без согласия.
static func open_quest_dialogue(game: Node, npc_id: String) -> bool:
	if not game.QuestSystem.NPCS.has(npc_id): return false
	var mission_id: String = game.QuestSystem.mission_for_npc(game, npc_id)
	var dialogue := {"npc_id":npc_id,"mission_id":mission_id,"page":0,"reward":false,"revealed":0.0}
	if mission_id.is_empty():
		dialogue.text = game.VillageLifeSystem.dialogue_text(game, npc_id); dialogue.choices = ["continue", "leave"]; dialogue.personal = true
	else:
		var mission: Dictionary = game.QuestSystem.mission_data(mission_id)
		var state: String = game.QuestSystem.mission_state(game, mission_id)
		dialogue.text = mission.description
		dialogue.title = mission.title
		dialogue.choices = ["accept", "decline"] if state == game.QuestSystem.AVAILABLE else ["continue", "leave"]
	game.state.player.adventure_ui.dialogue = dialogue
	game.state.player.adventure_ui.dialogue_open = true
	game.state.player.adventure_ui.choice = 0
	game.clear_movement_keys(); game.notify_tutorial("dialogue_choices")
	return true


## Перемещает выбор диалога, принимает или отклоняет задание и поддерживает подарок NPC.
static func handle_dialogue_key(game: Node, key: int) -> void:
	var ui: Dictionary = game.state.player.adventure_ui
	var dialogue: Dictionary = ui.get("dialogue", {})
	var choices: Array = dialogue.get("choices", ["leave"])
	if key in [KEY_LEFT, KEY_UP]: ui.choice = posmod(int(ui.choice) - 1, choices.size()); return
	if key in [KEY_RIGHT, KEY_DOWN]: ui.choice = posmod(int(ui.choice) + 1, choices.size()); return
	if key == KEY_G:
		give_hotbar_gift(game, String(dialogue.get("npc_id", ""))); return
	if key == KEY_ESCAPE or (key in [KEY_ENTER, KEY_SPACE] and int(ui.choice) > 0):
		ui.dialogue_open = false; return
	if key in [KEY_ENTER, KEY_SPACE]:
		var mission_id := String(dialogue.get("mission_id", ""))
		if mission_id.is_empty() and bool(dialogue.get("personal", false)):
			game.VillageLifeSystem.claim_personal_request(game, String(dialogue.get("npc_id", ""))); ui.dialogue_open = false; return
		if not mission_id.is_empty():
			var before: String = game.QuestSystem.mission_state(game, mission_id)
			game.QuestSystem.talk(game, mission_id)
			dialogue.reward = before == game.QuestSystem.ACTIVE and game.QuestSystem.mission_state(game, mission_id) == game.QuestSystem.COMPLETED
			remember_quest(game, String(dialogue.get("npc_id", "")), mission_id)
			if dialogue.reward:
				dialogue.text = game.message; dialogue.title = word(game, "reward_received"); dialogue.choices = ["thanks"]; dialogue.mission_id = ""; dialogue.revealed = 0.0; ui.dialogue = dialogue; return
		ui.dialogue_open = false


## Передаёт съедобный предмет из активного слота и повышает отношение жителя.
static func give_hotbar_gift(game: Node, npc_id: String) -> bool:
	var kind: String = game.hotbar_slots[game.selected_hotbar]
	if npc_id.is_empty() or not game.InventorySystem.data(kind).get("edible", false) or game.inventory_item_count(kind) <= 0:
		game.message = "Для подарка выбери еду на панели"; return false
	return game.VillageLifeSystem.give_gift(game, npc_id, kind)


## Сохраняет последнюю квестовую встречу NPC для будущих реплик.
static func remember_quest(game: Node, npc_id: String, mission_id: String) -> void:
	var remembered: Dictionary = game.state.player.quest_memory.get(npc_id, {}).duplicate(true)
	remembered.mission = mission_id; remembered.day = game.day; remembered.state = game.QuestSystem.mission_state(game, mission_id); game.state.player.quest_memory[npc_id] = remembered


## Переключает фиксацию между доступными живыми противниками текущей локации.
static func cycle_target(game: Node) -> int:
	var candidates: Array[int] = []
	for index in game.enemy_nodes.size():
		var enemy: Dictionary = game.enemy_nodes[index]
		if enemy.alive and enemy.location == game.current_location and game.player.distance_to(enemy.position) <= 520.0: candidates.append(index)
	if candidates.is_empty(): game.state.player.adventure_ui.target_enemy = -1; return -1
	var current := candidates.find(int(game.state.player.adventure_ui.get("target_enemy", -1)))
	game.state.player.adventure_ui.target_enemy = candidates[(current + 1) % candidates.size()]
	game.notify_tutorial("target_lock")
	return int(game.state.player.adventure_ui.target_enemy)


## Фиксирует врага, по которому игрок коснулся или щёлкнул в экранных координатах.
static func target_at_screen(game: Node, point: Vector2) -> bool:
	for index in game.enemy_nodes.size():
		var enemy: Dictionary = game.enemy_nodes[index]
		if enemy.alive and enemy.location == game.current_location and point.distance_to(enemy.position - game.camera_offset) <= 48.0:
			game.state.player.adventure_ui.target_enemy = index; game.notify_tutorial("target_lock"); return true
	return false


## Обновляет следы, экранный отклик, автоматическую фиксацию и события от проигранных SFX.
static func update(game: Node, delta: float) -> void:
	var feedback: Dictionary = game.state.player.feedback
	if bool(game.state.player.adventure_ui.get("dialogue_open", false)):
		var dialogue: Dictionary = game.state.player.adventure_ui.get("dialogue", {})
		dialogue.revealed = minf(float(String(dialogue.get("text", "")).length()), float(dialogue.get("revealed", 0.0)) + delta * 42.0)
	feedback.timer = maxf(float(feedback.get("timer", 0.0)) - delta, 0.0)
	feedback.camera_shake = maxf(float(feedback.get("camera_shake", 0.0)) - delta * 18.0, 0.0)
	update_damage_numbers(feedback, delta); update_footprints(game, feedback, delta)
	if int(feedback.get("last_sfx_count", -1)) != game.audio_sfx_count:
		feedback.last_sfx_count = game.audio_sfx_count
		if ACTIONS.has(game.audio_last_sfx): begin_action(game, game.audio_last_sfx, game.player + game.facing * 38.0)
	var target := int(game.state.player.adventure_ui.get("target_enemy", -1))
	if target >= game.enemy_nodes.size() or (target >= 0 and (not game.enemy_nodes[target].alive or game.enemy_nodes[target].location != game.current_location)):
		game.state.player.adventure_ui.target_enemy = -1


## Запускает соответствующий кадр атласа и лёгкую вибрацию мира.
static func begin_action(game: Node, action: String, position: Vector2, amount: int = 0) -> void:
	var feedback: Dictionary = game.state.player.feedback
	feedback.action = action; feedback.position = position; feedback.timer = 0.34
	if action in ["mine", "chop", "hit"]: feedback.camera_shake = 3.0
	if amount != 0: feedback.damage_numbers.append({"text":str(amount),"position":position,"time":0.8,"color":Color("ffcf72")})


## Уменьшает таймеры всплывающих чисел и удаляет завершённые.
static func update_damage_numbers(feedback: Dictionary, delta: float) -> void:
	for index in range(feedback.damage_numbers.size() - 1, -1, -1):
		feedback.damage_numbers[index].time -= delta
		feedback.damage_numbers[index].position.y -= delta * 26.0
		if feedback.damage_numbers[index].time <= 0.0: feedback.damage_numbers.remove_at(index)


## Оставляет редкие исчезающие следы только при реальном движении героя.
static func update_footprints(game: Node, feedback: Dictionary, delta: float) -> void:
	for index in range(feedback.footprints.size() - 1, -1, -1):
		feedback.footprints[index].time -= delta
		if feedback.footprints[index].time <= 0.0: feedback.footprints.remove_at(index)
	var last: Vector2 = feedback.get("last_player", game.player)
	if game.player.distance_to(last) >= 34.0:
		feedback.footprints.append({"position":game.player + Vector2(0, 18),"time":1.4}); feedback.last_player = game.player
		if feedback.footprints.size() > 8: feedback.footprints.pop_front()


## Возвращает детерминированное смещение камеры для короткого удара без размытия пикселей.
static func shake_offset(game: Node) -> Vector2:
	if game.settings_state.reduced_motion or not game.settings_state.screen_shake_enabled: return Vector2.ZERO
	var amount := float(game.state.player.feedback.get("camera_shake", 0.0))
	if amount <= 0.0: return Vector2.ZERO
	var phase := Time.get_ticks_msec() / 24
	return Vector2(roundf(sin(phase) * amount), roundf(cos(phase * 1.7) * amount))


## Проверяет остаток прочности выбранного инструмента или оружия.
static func can_use(game: Node, kind: String) -> bool:
	if not game.state.inventory.durability.has(kind): return true
	if int(game.state.inventory.durability[kind]) > 0: return true
	game.message = "Предмет сломан — отремонтируй его в кузнице"; game.notify_tutorial("durability_broken")
	return false


## Расходует одну единицу прочности после успешного действия.
static func consume_durability(game: Node, kind: String, amount: int = 1) -> void:
	if kind == "weapon": kind = game.equipped_weapon
	if kind == "forest_sword": kind = "sword"
	if game.state.inventory.durability.has(kind):
		game.state.inventory.durability[kind] = maxi(0, int(game.state.inventory.durability[kind]) - amount)
		if int(game.state.inventory.durability[kind]) <= 20: game.notify_tutorial("durability_low")


## Полностью ремонтирует предмет за монеты в кузнице.
static func repair(game: Node, kind: String) -> bool:
	if not game.state.inventory.durability.has(kind): return false
	var missing := 100 - int(game.state.inventory.durability[kind])
	var price := ceili(float(missing) / 10.0)
	if missing <= 0 or game.coins < price: return false
	game.coins -= price; game.state.inventory.durability[kind] = 100; game.play_sfx("craft"); game.notify_tutorial("repair")
	return true


## Покупает следующее расширение рюкзака, увеличивающее вместимость на двенадцать ячеек.
static func upgrade_backpack(game: Node) -> bool:
	var level := int(game.state.inventory.backpack_level)
	if level >= 4: return false
	var price := 120 * (level + 1)
	if game.coins < price: return false
	game.coins -= price; game.state.inventory.backpack_level += 1; game.notify_tutorial("backpack_upgrade")
	return true
