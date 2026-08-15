class_name FirstChapterSystem
extends RefCounted

const REPAIR_POSITION := Vector2(1320, 680)
const REPAIR_WOOD := 8
const REPAIR_STONE := 4
const REWARD_RECTS := [Rect2(194, 292, 236, 154), Rect2(458, 292, 236, 154), Rect2(722, 292, 236, 154)]
const REWARDS := ["farmer", "guardian", "explorer"]
const MILESTONES := [
	{"event":"talk","day":1}, {"event":"plant","day":1}, {"event":"shop","day":1},
	{"event":"harvest","day":2}, {"event":"quest_complete","day":2}, {"event":"mission_accept","day":3},
	{"event":"bridge_repaired","day":3}, {"event":"forest_arrival","day":3}, {"event":"guardian_defeated","day":4},
	{"event":"secret_puzzle","day":4}, {"event":"seed_mission_complete","day":5}, {"event":"reward_selected","day":5},
]
const WORDS := {
	"title":["ГЛАВА I • ВОЗВРАЩЕНИЕ","CHAPTER I • HOMECOMING","CAPÍTULO I • EL REGRESO","KAPITEL I • HEIMKEHR","CHAPITRE I • LE RETOUR","第一章 • 归乡"],
	"day_lock":["Продолжение откроется утром %d-го дня","Continues on the morning of day %d","Continúa en la mañana del día %d","Fortsetzung am Morgen von Tag %d","Suite au matin du jour %d","第%d天早晨继续"],
	"repair_need":["Для ремонта нужно: древесина %d/%d, камень %d/%d","Repair needs: wood %d/%d, stone %d/%d","Reparación: madera %d/%d, piedra %d/%d","Reparatur: Holz %d/%d, Stein %d/%d","Réparation : bois %d/%d, pierre %d/%d","修桥需要：木材%d/%d，石头%d/%d"],
	"repair_done":["Восточная переправа восстановлена — путь в лес открыт","The eastern crossing is restored — the forest road is open","El puente oriental está reparado: el bosque está abierto","Die östliche Brücke ist repariert – der Waldweg ist offen","Le pont oriental est réparé : la forêt est accessible","东侧桥梁已修复——森林道路开放"],
	"gate_locked":["Сначала восстанови восточную переправу","Restore the eastern crossing first","Primero repara el puente oriental","Repariere zuerst die östliche Brücke","Répare d’abord le pont oriental","请先修复东侧桥梁"],
	"reward_title":["НАГРАДА ЗА ПЕРВУЮ ГЛАВУ","FIRST CHAPTER REWARD","RECOMPENSA DEL PRIMER CAPÍTULO","BELOHNUNG DES ERSTEN KAPITELS","RÉCOMPENSE DU PREMIER CHAPITRE","第一章奖励"],
	"reward_hint":["Выбери путь • 1–3 / A / клик","Choose a path • 1–3 / A / click","Elige un camino • 1–3 / A / clic","Wähle einen Weg • 1–3 / A / Klick","Choisis une voie • 1–3 / A / clic","选择道路 • 1–3 / A / 点击"],
	"reward_farmer":["САДОВНИК","ORCHARD KEEPER","HORTELANO","OBSTGÄRTNER","ARBORICULTEUR","果园守护者"],
	"reward_farmer_desc":["3 саженца, 2 редких семени и опыт фермерства","3 saplings, 2 rare seeds and farming XP","3 plantones, 2 semillas raras y XP agrícola","3 Setzlinge, 2 seltene Samen und Landwirtschafts-EP","3 plants, 2 graines rares et XP agricole","3棵树苗、2份稀有种子和农业经验"],
	"reward_guardian":["ЗАЩИТНИК","GUARDIAN","GUARDIÁN","WÄCHTER","GARDIEN","守护者"],
	"reward_guardian_desc":["Лесной меч и 2 лечебных зелья","Forest sword and 2 healing potions","Espada del bosque y 2 pociones curativas","Waldschwert und 2 Heiltränke","Épée forestière et 2 potions de soin","森林之剑和2瓶治疗药水"],
	"reward_explorer":["СЛЕДОПЫТ","PATHFINDER","EXPLORADOR","PFADFINDER","ÉCLAIREUR","探路者"],
	"reward_explorer_desc":["Походные сапоги и 100 монет","Travel boots and 100 coins","Botas de viaje y 100 monedas","Reisestiefel und 100 Münzen","Bottes de voyage et 100 pièces","旅行靴和100金币"],
	"complete":["Глава завершена: долина снова связана с лесом","Chapter complete: the valley is connected to the forest again","Capítulo completo: el valle vuelve a estar unido al bosque","Kapitel beendet: Tal und Wald sind wieder verbunden","Chapitre terminé : la vallée rejoint de nouveau la forêt","章节完成：山谷再次与森林相连"],
}
const OBJECTIVES := [
	["Поговори с бабушкой у дома","Talk to Grandmother by the house","Habla con la abuela junto a la casa","Sprich beim Haus mit Großmutter","Parle à Grand-mère près de la maison","在房子旁和奶奶交谈"],
	["Вспаши землю и посади первые семена","Till the soil and plant the first seeds","Ara la tierra y planta las primeras semillas","Bestelle den Boden und säe die ersten Samen","Laboure la terre et plante les premières graines","耕地并种下第一批种子"],
	["Зайди в сельскую лавку","Visit the village shop","Visita la tienda del pueblo","Besuche den Dorfladen","Visite la boutique du village","前往村庄商店"],
	["Дождись второго дня и собери первый урожай","Wait for day two and gather the first harvest","Espera al segundo día y recoge la primera cosecha","Warte bis Tag zwei und ernte zum ersten Mal","Attends le deuxième jour et récolte","等到第二天并收获第一批作物"],
	["Принеси бабушке 10 морковок","Bring Grandmother 10 carrots","Lleva 10 zanahorias a la abuela","Bringe Großmutter 10 Karotten","Apporte 10 carottes à Grand-mère","给奶奶带回10根胡萝卜"],
	["На третий день возьми поручение у жителя","On day three accept a villager's request","El tercer día acepta el encargo de un aldeano","Nimm an Tag drei einen Auftrag an","Le troisième jour, accepte une demande","第三天接受一位村民的委托"],
	["Собери 8 древесины и 4 камня, почини восточный мост","Gather 8 wood and 4 stone, repair the eastern bridge","Reúne 8 maderas y 4 piedras y repara el puente oriental","Sammle 8 Holz und 4 Stein und repariere die Ostbrücke","Réunis 8 bois et 4 pierres puis répare le pont est","收集8份木材和4块石头，修复东桥"],
	["Перейди мост и войди в лес","Cross the bridge and enter the forest","Cruza el puente y entra en el bosque","Überquere die Brücke und betrete den Wald","Traverse le pont et entre dans la forêt","过桥进入森林"],
	["На четвёртый день победи хищного Стража чащи","On day four defeat the predatory Grove Guardian","El cuarto día derrota al Guardián del Bosque","Besiege an Tag vier den Hainwächter","Le quatrième jour, vaincs le Gardien du bosquet","第四天击败凶猛的林地守卫"],
	["Найди древний тайник в лесу","Find the ancient cache in the forest","Encuentra el alijo antiguo del bosque","Finde das alte Versteck im Wald","Trouve la cache ancienne dans la forêt","找到森林中的古老藏宝处"],
	["На пятый день отдай редкое семя травнице Агафье","On day five bring the rare seed to herbalist Agafya","El quinto día lleva la semilla rara a Agafya","Bringe Agafya an Tag fünf den seltenen Samen","Le cinquième jour, apporte la graine rare à Agafya","第五天把稀有种子交给草药师阿加菲娅"],
	["Выбери награду и будущий путь героя","Choose the reward and the hero's future path","Elige la recompensa y el futuro camino","Wähle Belohnung und künftigen Weg","Choisis la récompense et la voie du héros","选择奖励和英雄未来的道路"],
]

## Возвращает сохранённое состояние первой главы и дополняет данные старых сохранений безопасными значениями.
static func state(game: Node) -> Dictionary:
	var expansion: Dictionary = game.state.world.estate.get("expansion", {})
	var value: Dictionary = expansion.get("first_chapter", {})
	var defaults := {"stage":0,"events":{},"bridge_repaired":false,"reward_pending":false,"reward_choice":"","completed":false,"started_day":game.day}
	for key in defaults:
		if not value.has(key): value[key] = defaults[key]
	expansion.first_chapter = value; game.state.world.estate.expansion = expansion
	return value

## Инициализирует главу и синхронизирует уже выполненные действия без повторной выдачи наград.
static func initialize(game: Node) -> void:
	state(game); update(game)

## Возвращает строку интерфейса на активном языке и подставляет переданные значения.
static func word(game: Node, key: String, values: Array = []) -> String:
	var variants: Array = WORDS.get(key, [key,key,key,key,key,key]); var locale_index: int = maxi(game.LocaleSystem.LOCALES.find(game.LocaleSystem.current),0); var result := String(variants[locale_index])
	return result % values if not values.is_empty() else result

## Возвращает номер текущего этапа в допустимых границах маршрута.
static func stage(game: Node) -> int:
	return clampi(int(state(game).stage), 0, MILESTONES.size())

## Запоминает реальное игровое событие и сразу пытается продвинуть последовательную главу.
static func observe(game: Node, event_name: String) -> void:
	state(game).events[event_name] = true; update(game)

## Продвигает только последовательные выполненные цели и учитывает обязательный игровой день каждой сцены.
static func update(game: Node) -> void:
	var value := state(game)
	if value.completed or value.reward_pending: return
	if game.mission_states.get("side_seed", "") == game.QuestSystem.COMPLETED: value.events.seed_mission_complete = true
	while int(value.stage) < MILESTONES.size():
		var milestone: Dictionary = MILESTONES[int(value.stage)]
		if game.day < int(milestone.day) or not bool(value.events.get(milestone.event, false)): break
		value.stage = int(value.stage) + 1
		if int(value.stage) == MILESTONES.size() - 1: value.reward_pending = true; game.clear_movement_keys(); game.play_sfx("quest_complete"); break

## Возвращает локализованную цель либо итоговую строку завершённой главы.
static func objective(game: Node) -> String:
	var value := state(game)
	if value.completed: return word(game,"complete")
	var index := mini(stage(game), OBJECTIVES.size()-1); var locale_index := maxi(game.LocaleSystem.LOCALES.find(game.LocaleSystem.current),0); var milestone: Dictionary = MILESTONES[index]
	if game.day < int(milestone.day): return word(game,"day_lock",[milestone.day])
	return String(OBJECTIVES[index][locale_index])

## Находит строительную точку восточного моста только на первой локации.
static func nearest_interaction(game: Node, distance_limit: float) -> String:
	return "chapter_bridge" if game.current_location == "overworld" and game.player.distance_to(REPAIR_POSITION) < distance_limit else ""

## Ремонтирует мост штатными ресурсами или объясняет недостающее условие без частичного списания.
static func repair_bridge(game: Node) -> bool:
	var value := state(game)
	if value.bridge_repaired: game.message = word(game,"repair_done"); return true
	var wood: int = game.inventory_item_count("wood"); var stone: int = game.inventory_item_count("stone")
	if stage(game) < 6 or game.day < 3 or wood < REPAIR_WOOD or stone < REPAIR_STONE:
		game.message = word(game,"repair_need",[wood,REPAIR_WOOD,stone,REPAIR_STONE]); return true
	game.change_inventory_count("wood",-REPAIR_WOOD); game.change_inventory_count("stone",-REPAIR_STONE); value.bridge_repaired = true
	game.message = word(game,"repair_done"); game.play_sfx("craft"); game.notify_tutorial("chapter_bridge"); observe(game,"bridge_repaired"); return true

## Разрешает первый выход в лес только после сюжетного ремонта, не ограничивая дальнейшие переходы мира.
static func can_use_world_gate(game: Node) -> bool:
	if game.current_location != "overworld" or bool(state(game).bridge_repaired): return true
	game.message = word(game,"gate_locked"); game.play_sfx("locked"); return false

## Отмечает вход в лес как отдельное событие, не смешивая его с переходами между поздними регионами.
static func on_location_changed(game: Node) -> void:
	if game.current_location == "forest": observe(game,"forest_arrival")

## Возвращает деревню как ранний обратный маршрут из леса, не заставляя новичка обходить все поздние регионы.
static func early_return_location(game: Node) -> String:
	var value := state(game)
	return "overworld" if game.current_location == "forest" and value.bridge_repaired and not value.completed else ""

## Засчитывает только сильнейшее хищное растение леса как первого сюжетного стража.
static func on_enemy_defeated(game: Node, enemy: Dictionary) -> void:
	if enemy.location == "forest" and enemy.kind == "plant" and int(enemy.level) >= 5:
		observe(game,"guardian_defeated"); game.notify_tutorial("chapter_guardian")

## Возвращает признак модального выбора итоговой награды.
static func modal_active(game: Node) -> bool:
	return bool(state(game).reward_pending)

## Выдаёт ровно один выбранный комплект, завершает главу и начисляет общий опыт.
static func select_reward(game: Node, index: int) -> bool:
	var value := state(game)
	if not value.reward_pending or index < 0 or index >= REWARDS.size(): return false
	var reward: String = REWARDS[index]
	if reward == "farmer": game.change_inventory_count("fruit_sapling",3); game.change_inventory_count("rare_seeds",2); game.SkillSystem.award_profession_xp(game,"farming",30)
	elif reward == "guardian": game.sword_crafted = true; game.change_inventory_count("healing_potion",2)
	else: game.change_inventory_count("travel_boots",1); game.coins += 100
	value.reward_choice = reward; value.reward_pending = false; value.completed = true; value.events.reward_selected = true; value.stage = MILESTONES.size()
	game.award_xp(75,"first_chapter"); game.message = word(game,"complete"); game.play_sfx("quest_complete"); game.notify_tutorial("chapter_reward"); return true

## Обрабатывает выбор награды клавиатурой, геймпадом, мышью и касанием.
static func handle_input(game: Node, event: InputEvent) -> bool:
	if not modal_active(game): return false
	if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_1,KEY_2,KEY_3]: return select_reward(game,int(event.keycode)-int(KEY_1))
	if event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_A: return select_reward(game,0)
	if (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) or (event is InputEventScreenTouch and event.pressed):
		for index in REWARD_RECTS.size():
			if REWARD_RECTS[index].has_point(event.position): return select_reward(game,index)
	return true
