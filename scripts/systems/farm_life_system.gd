extends RefCounted

const ANIMALS := [
	{"id":"hen","name":"Ряба","product":"egg","position":Vector2(315,860),"cell":Vector2i(0,0)},
	{"id":"cow","name":"Зорька","product":"milk","position":Vector2(405,875),"cell":Vector2i(1,0)},
	{"id":"sheep","name":"Облачко","product":"wool","position":Vector2(510,860),"cell":Vector2i(2,0)},
]
const TROUGH_POSITION:=Vector2(610,860)
const FURNITURE := {"rustic_table":Vector2i(0,2),"wooden_chair":Vector2i(1,2),"woven_rug":Vector2i(2,2),"potted_fern":Vector2i(3,2),"wooden_wardrobe":Vector2i(4,2)}
const BIRTHDAYS := {4:"miron",8:"agafya",12:"varvara",16:"gavrila",20:"dunya"}
const MUSEUM_ITEMS := ["blue_gem","moon_relic","ancient_key","cursed_compass","eclipse_core","red_crystal","green_crystal"]
const SECRETS := {"forest":{"position":Vector2(1580,420),"reward":"rare_seeds"},"ruins":{"position":Vector2(1640,610),"reward":"ancient_key"},"cave":{"position":Vector2(1920,650),"reward":"blue_gem"}}

## Возвращает и при необходимости создаёт совместимое состояние большого жизненного расширения.
static func state(game: Node) -> Dictionary:
	var value: Dictionary = game.state.world.estate.get("expansion", {})
	var defaults := {"first_day":0,"animals":{},"furniture":[],"build_mode":false,"build_index":0,"museum":[],"encyclopedia":[],"achievements":[],"secrets":{},"reputation":0,"relationship_scenes":[],"cutscene":"","cutscene_timer":0.0,"compendium":false,"page":0,"photo_mode":false,"photo_grid":false,"projectiles":[],"hit_stop":0.0,"active_slot":1,"autosaved_day":0}
	for key in defaults:
		if not value.has(key): value[key] = defaults[key]
	game.state.world.estate.expansion = value
	return value

## Подготавливает первый день, животных и энциклопедию без сброса старого сохранения.
static func initialize(game: Node) -> void:
	var value := state(game)
	if int(value.first_day) == 0: value.first_day = 1; value.cutscene = "arrival"; value.cutscene_timer = 4.5; game.message = "День 1 • Возвращение на бабушкину ферму"
	for animal in ANIMALS:
		if not value.animals.has(animal.id): value.animals[animal.id] = {"fed_day":0,"collected_day":0,"bond":0}
	update_discoveries(game)

## Обновляет кат-сцены, первый день, летящие снаряды, коллекции и достижения.
static func update(game: Node, delta: float) -> void:
	var value := state(game)
	value.hit_stop = maxf(float(value.hit_stop)-delta,0.0)
	value.cutscene_timer = maxf(float(value.cutscene_timer)-delta,0.0)
	if value.cutscene_timer <= 0.0: value.cutscene = ""
	for projectile in value.projectiles:
		projectile.progress = minf(float(projectile.progress)+delta*5.0,1.0)
	value.projectiles = value.projectiles.filter(func(projectile): return float(projectile.progress) < 1.0)
	update_first_day(game); update_discoveries(game); update_achievements(game); update_relationship_scenes(game)

## Возвращает нулевую дельту во время короткой остановки сильного попадания.
static func simulation_delta(game: Node, delta: float) -> float:
	return 0.0 if float(state(game).hit_stop) > 0.0 else delta

## Продвигает последовательный обучающий маршрут первого дня по реальным действиям игрока.
static func update_first_day(game: Node) -> void:
	var value := state(game); var step := int(value.first_day)
	var ready := [true,game.tutorial_events_completed.has("talk"),game.tutorial_events_completed.has("plant"),game.tutorial_events_completed.has("shop"),game.quest_active or game.mission_states.values().any(func(status): return status != "locked")]
	if step < ready.size() and bool(ready[step]): value.first_day = step+1; game.notify_tutorial(["move","talk","plant","shop","quest"][step])

## Возвращает текущую цель связного первого дня для постоянной небольшой панели.
static func first_day_objective(game: Node) -> String:
	return ["Осмотрись и подойди к бабушке","Поговори с бабушкой","Вспаши грядку и посади семена","Посети сельскую лавку","Возьми первое поручение","Ложись спать дома"][clampi(int(state(game).first_day),0,5)]

## Возвращает ближайшее животное, кормушку, музей или секретный механизм.
static func nearest_interaction(game: Node, distance_limit: float) -> String:
	if game.current_location == "overworld" and game.state.world.estate.level >= 3:
		if game.player.distance_to(TROUGH_POSITION) < distance_limit: return "life:trough"
		for animal in ANIMALS:
			if game.player.distance_to(animal.position) < distance_limit: return "life:animal:%s" % animal.id
	if game.current_location == "guild_interior" and game.player.distance_to(Vector2(780,270)) < distance_limit: return "life:museum"
	if SECRETS.has(game.current_location) and game.player.distance_to(SECRETS[game.current_location].position) < distance_limit: return "life:secret:%s" % game.current_location
	return ""

## Выполняет взаимодействие с животноводством, музейной коллекцией и тайниками.
static func interact(game: Node, interaction: String) -> bool:
	var value := state(game); var parts := interaction.split(":"); if parts.size() < 2: return false
	if parts[1] == "trough":
		if game.inventory_item_count("wheat") < 1: game.message = "Для кормушки нужна пшеница"; return true
		game.change_inventory_count("wheat",-1)
		for animal in ANIMALS: value.animals[animal.id].fed_day = game.day
		game.message = "Все животные накормлены"; game.notify_tutorial("animal_feed"); return true
	if parts[1] == "animal" and parts.size() > 2:
		var animal: Dictionary = ANIMALS.filter(func(item): return item.id == parts[2])[0]; var memory: Dictionary = value.animals[animal.id]
		if int(memory.fed_day) != game.day-1 or int(memory.collected_day) == game.day: game.message = "%s ждёт кормления и нового утра" % animal.name; return true
		memory.collected_day = game.day; memory.bond = int(memory.bond)+1; game.change_inventory_count(animal.product,1); game.message = "%s: получен предмет «%s»" % [animal.name,game.inventory_item_name(animal.product)]; game.notify_tutorial("animal_product"); return true
	if parts[1] == "museum": return donate_museum_item(game)
	if parts[1] == "secret" and parts.size() > 2: return activate_secret(game,parts[2])
	return false

## Передаёт первый доступный редкий предмет музею и повышает репутацию деревни.
static func donate_museum_item(game: Node) -> bool:
	var value := state(game)
	for kind in MUSEUM_ITEMS:
		if kind not in value.museum and game.inventory_item_count(kind) > 0:
			game.change_inventory_count(kind,-1); value.museum.append(kind); value.reputation = int(value.reputation)+5; game.coins += 25
			if value.museum.size()==3: game.change_inventory_count("museum_token",1)
			game.message = "Экспонат передан музею • +25 монет • репутация +5"; game.notify_tutorial("museum"); return true
	game.message = "Новых экспонатов для музея пока нет"; return true

## Открывает уникальный тайник один раз и выдаёт физический предмет добычи.
static func activate_secret(game: Node, location: String) -> bool:
	var value := state(game); if bool(value.secrets.get(location,false)): game.message = "Механизм уже разгадан"; return true
	value.secrets[location] = true; var data: Dictionary = SECRETS[location]; game.dropped_items.append({"kind":data.reward,"count":1,"position":data.position+Vector2(0,45)}); value.reputation = int(value.reputation)+3; game.message = "Тайный проход открыт — рядом появился клад"; game.notify_tutorial("secret_puzzle"); return true

## Запоминает впервые найденные предметы для энциклопедии без влияния на инвентарь.
static func update_discoveries(game: Node) -> void:
	var value := state(game)
	for kind in game.export_inventory_counts():
		if game.inventory_item_count(kind) > 0 and kind not in value.encyclopedia: value.encyclopedia.append(kind)

## Выдаёт одноразовые достижения за исследование, отношения, музей и развитие фермы.
static func update_achievements(game: Node) -> void:
	var value := state(game); var checks := {"first_week":game.day>=7,"collector":value.encyclopedia.size()>=20,"curator":value.museum.size()>=3,"beloved":game.state.player.relationships.values().any(func(score): return int(score)>=50),"rancher":ANIMALS.all(func(animal): return int(value.animals[animal.id].bond)>=3)}
	for achievement in checks:
		if checks[achievement] and achievement not in value.achievements: value.achievements.append(achievement); game.coins += 20; game.message = "Достижение открыто • +20 монет"; game.play_sfx("quest_complete")

## Запускает одноразовые короткие сцены отношений на трёх значимых порогах дружбы.
static func update_relationship_scenes(game: Node) -> void:
	var value:=state(game); if not String(value.cutscene).is_empty(): return
	for npc_id in game.QuestSystem.NPCS:
		for threshold in [25,50,80]:
			var scene_id:="%s:%d" % [npc_id,threshold]
			if int(game.state.player.relationships.get(npc_id,0))>=threshold and scene_id not in value.relationship_scenes: value.relationship_scenes.append(scene_id); value.cutscene=scene_id; value.cutscene_timer=3.5; game.message="Новая сцена отношений: %s" % game.QuestSystem.npc_name(npc_id); game.notify_tutorial("npc_gift"); return

## Возвращает число сердечек отношений по шкале из десяти сердец.
static func hearts(game: Node, npc_id: String) -> int:
	return ceili(float(game.state.player.relationships.get(npc_id,0))/10.0)

## Возвращает именинника текущего дня сезона или пустую строку.
static func birthday_npc(game: Node) -> String:
	return String(BIRTHDAYS.get(posmod(game.day-1,28)+1,""))

## Регистрирует видимый снаряд и короткий hit-stop для оружия героя.
static func register_player_attack(game: Node, target: Vector2, critical: bool) -> void:
	var value := state(game)
	var weapon_class: String = game.WeaponSystem.weapon_class(game.equipped_weapon)
	value.projectiles.append({"from":game.player,"to":target,"progress":0.0,"kind":weapon_class})
	value.hit_stop = 0.07 if critical else 0.035

## Возвращает уязвимость семейства врага к выбранному типу оружия.
static func vulnerability(kind: String, weapon: String) -> float:
	if kind in ["plant","sea_ghost"] and weapon in ["bow", "axe"]: return 1.5
	if kind in ["skeleton","cave_guardian"] and weapon in ["crystal_sword", "war_hammer", "moon_staff"]: return 1.5
	if kind in ["orc","pirate","zombie_pirate"] and weapon in ["forest_sword","pirate_cutlass"]: return 1.25
	if kind in ["orc", "undead"] and weapon == "iron_spear": return 1.25
	return 1.0

## Завершает день: обновляет цепочку, запускает кат-сцену и выполняет автосохранение активного слота.
static func on_sleep(game: Node) -> void:
	var value := state(game); value.first_day = maxi(int(value.first_day),6); value.cutscene = "morning"; value.cutscene_timer = 2.8; value.autosaved_day = game.day; save_active(game)

## Возвращает путь одного из трёх независимых слотов, сохраняя совместимость первого.
static func slot_path(slot: int) -> String:
	return "user://farm-save.json" if clampi(slot,1,3)==1 else "user://farm-save-%d.json" % clampi(slot,1,3)

## Сохраняет игру в выбранный активный слот.
static func save_active(game: Node) -> bool:
	return game.SaveSystem.save_at(game,slot_path(int(state(game).active_slot)))

## Загружает игру из выбранного активного слота.
static func load_active(game: Node) -> bool:
	return game.SaveSystem.load_at(game,slot_path(int(state(game).active_slot)))

## Переключает один из трёх слотов сохранения по кругу.
static func cycle_slot(game: Node) -> int:
	var value := state(game); value.active_slot = posmod(int(value.active_slot),3)+1; game.message = "Активный слот сохранения: %d" % value.active_slot; return int(value.active_slot)

## Переключает режим расстановки мебели только внутри собственного дома.
static func toggle_build_mode(game: Node) -> bool:
	var value := state(game); if game.current_location != "cottage_interior": game.message = "Мебель можно расставлять только дома"; return false
	value.build_mode = not bool(value.build_mode); game.clear_movement_keys(); game.message = "Режим мебели: выбери предмет Q, поставь Enter" if value.build_mode else "Расстановка мебели завершена"; return true

## Ставит выбранный предмет мебели в сетку дома после проверки инвентаря и пересечений.
static func place_furniture(game: Node) -> bool:
	var value := state(game); var kinds: Array = FURNITURE.keys(); var kind: String = kinds[clampi(int(value.build_index),0,kinds.size()-1)]; var position := Vector2(round(game.player.x/32.0)*32.0,round(game.player.y/32.0)*32.0)
	if game.inventory_item_count(kind)<1: game.message = "В инвентаре нет предмета «%s»" % game.inventory_item_name(kind); return false
	if value.furniture.any(func(item): return Vector2(item.position).distance_to(position)<52.0): game.message = "Здесь уже стоит мебель"; return false
	game.change_inventory_count(kind,-1); value.furniture.append({"kind":kind,"position":position}); game.message = "Предмет установлен: %s" % game.inventory_item_name(kind); game.notify_tutorial("furniture_place"); return true

## Проверяет коллизию героя с видимыми основаниями животных, мебели, музея и тайников.
static func blocks_position(game: Node, position: Vector2, radius: float) -> bool:
	if game.current_location=="overworld" and game.state.world.estate.level>=3:
		for animal in ANIMALS:
			if game.FarmLifeVisualSystem.circle_intersects_rect(position,radius,game.FarmLifeVisualSystem.collision_rect(String(animal.id),Vector2(animal.position))): return true
		if game.FarmLifeVisualSystem.circle_intersects_rect(position,radius,game.FarmLifeVisualSystem.collision_rect("trough",TROUGH_POSITION)): return true
	if game.current_location=="cottage_interior":
		for furniture in state(game).furniture:
			var collision:Rect2=game.FarmLifeVisualSystem.collision_rect(String(furniture.kind),Vector2(furniture.position))
			if game.FarmLifeVisualSystem.circle_intersects_rect(position,radius,collision): return true
	if game.current_location=="guild_interior" and game.FarmLifeVisualSystem.circle_intersects_rect(position,radius,game.FarmLifeVisualSystem.collision_rect("museum",Vector2(780,270))): return true
	if SECRETS.has(game.current_location):
		var secret_position:=Vector2(SECRETS[game.current_location].position)
		if game.FarmLifeVisualSystem.circle_intersects_rect(position,radius,game.FarmLifeVisualSystem.collision_rect("secret",secret_position)): return true
	return false

## Сохраняет снимок экрана фоторежима в пользовательскую папку проекта.
static func capture_photo(game: Node) -> bool:
	if not game.is_inside_tree(): return false
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://photos")); var path := "user://photos/farm-%d.png" % Time.get_ticks_msec(); var result := game.get_viewport().get_texture().get_image().save_png(path); game.message = "Фото сохранено: %s" % path; return result == OK

## Обрабатывает энциклопедию, фоторежим, сетку и выбор слота с клавиатуры.
static func handle_input(game: Node, event: InputEvent) -> bool:
	if not (event is InputEventKey and event.pressed and not event.echo): return false
	var value := state(game)
	match event.keycode:
		KEY_V: value.compendium = not bool(value.compendium); game.clear_movement_keys(); return true
		KEY_P: value.photo_mode = not bool(value.photo_mode); game.clear_movement_keys(); game.notify_tutorial("photo_mode"); return true
		KEY_Z: return toggle_build_mode(game)
		KEY_Q:
			if bool(value.build_mode): value.build_index = posmod(int(value.build_index)+1,FURNITURE.size()); game.message = "Выбрано: %s" % game.inventory_item_name(FURNITURE.keys()[value.build_index]); return true
		KEY_ENTER:
			if bool(value.build_mode): place_furniture(game); return true
			if bool(value.photo_mode): capture_photo(game); return true
		KEY_G:
			if bool(value.photo_mode): value.photo_grid = not bool(value.photo_grid); return true
		KEY_F2: cycle_slot(game); return true
		KEY_LEFT:
			if bool(value.compendium): value.page = posmod(int(value.page)-1,5); return true
		KEY_RIGHT:
			if bool(value.compendium): value.page = posmod(int(value.page)+1,5); return true
	return false

## Сообщает основному циклу, что энциклопедия или фоторежим временно блокируют управление.
static func modal_active(game: Node) -> bool:
	var value := state(game); return bool(value.compendium) or bool(value.photo_mode)
