extends "res://tests/suites/suite_base.gd"

const Arena := preload("res://scripts/systems/cave_boss_arena_system.gd")
const Data := preload("res://scripts/systems/cave_boss_arena_data.gd")
const Layout := preload("res://scripts/systems/cave_layout_system.gd")

## Проверяет выбранную арену, осознанное пробуждение, награды и совместимость сохранений.
func run() -> void:
	test_open_center_and_modular_obstacles()
	test_only_altar_awakens_guardian()
	test_seals_and_chest_follow_victory()
	test_story_relic_is_unique_and_legacy_rewards_survive()
	test_save_relocates_old_chest_without_resetting_progress()
	test_retreat_preserves_hp_and_clears_threats()
	test_altar_explanation_is_localized()

## Создаёт настоящее святилище у алтаря, сохраняя стабильные индексы всех врагов.
func sanctum() -> Node:
	var game := make_game(); game.current_location = Data.LOCATION; game.player = Data.ALTAR+Vector2(0,72)
	game.FirstChapterSystem.state(game).completed = true
	return game

## Сценарий: герой проходит по центру нового зала и обходит основания модульного декора.
## Исходное состояние: вариант А собран из общего каменного пола, алтаря, колонн и трёх кристаллов.
## Ожидаемый результат: рунический круг проходим, основания видимых объектов блокируют движение, оба туннеля лежат на полу.
func test_open_center_and_modular_obstacles() -> void:
	var game := sanctum()
	expect(game.CaveBossSystem.index(game)==36 and game.enemy_nodes.size()==37,"arena preserves all pre-existing enemy indices")
	for point in [Vector2(1200,600),Vector2(1488,816),Vector2(1680,816),Vector2(1200,480)]:
		expect(game.NavigationSystem.walkability_reason(game,point,-1,false)=="walkable","clear arena offers room to dodge: "+str(point))
	for position in Data.COLUMNS:
		expect(not Layout.blocks_position(position,27,Data.LOCATION),"column stands on the cave floor")
		expect(game.NavigationSystem.walkability_reason(game,position-Vector2(0,12),-1,false)=="cave_prop","visible column base stops the hero")
	expect(game.NavigationSystem.walkability_reason(game,Data.ALTAR-Vector2(0,8),-1,false)=="cave_prop","altar has a small visible solid base")
	for position in Data.CRYSTALS: expect(not Layout.blocks_position(position,27,Data.LOCATION),"crystal grows on dry floor inside the rock walls")
	expect(not Layout.blocks_position(Vector2(288,600),game.PLAYER_RADIUS,Data.LOCATION),"left arrival remains safely outside the return trigger")
	expect(not Layout.blocks_position(Data.EXIT,game.PLAYER_RADIUS,Data.LOCATION),"northern exit lies inside its real tunnel")
	game.free()

## Сценарий: герой подходит к хранителю, атакует его и затем сознательно использует алтарь.
## Исходное состояние: хранитель спит, отдельный запуск или загрузка не создают активного боя.
## Ожидаемый результат: близость и урон не пробуждают босса; только доступное действие у алтаря начинает бой.
func test_only_altar_awakens_guardian() -> void:
	var game := sanctum(); var index: int = game.CaveBossSystem.index(game)
	game.player = Data.BOSS+Vector2(0,72); game.CaveBossSystem.update(game,5.0)
	expect(not game.state.world.cave_boss.active and game.player_hp==game.player_max_hp,"entering the arena never starts an unrequested fight")
	expect(not game.CombatSystem.apply_damage(game,index,200) and game.enemy_nodes[index].hp==120,"sleeping guardian cannot be killed before altar activation")
	expect(game.CombatSystem.nearest(game)==-1,"sleeping guardian does not steal weapon targeting")
	expect(not Arena.activate(game),"altar cannot be used remotely")
	game.player = Data.ALTAR+Vector2(0,72)
	expect(game.nearest_interaction()=="cave_altar" and game.PresentationSystem.interaction_position(game,"cave_altar")==Data.ALTAR,"real context action and highlight point to the altar")
	game.menu_state.pause_open = true
	expect(not Arena.activate(game),"pause prevents accidental altar activation")
	game.menu_state.pause_open = false
	expect(game.GameInteractionRouter.perform(game) and game.state.world.cave_boss.active,"E action awakens the actual three-stage boss")
	expect(game.tutorial_events_completed.has("cave_boss_altar") and not Arena.activate(game),"activation teaches the mechanic and cannot restart an active encounter")
	game.free()

## Сценарий: герой пытается обойти печать и забрать награду, затем побеждает хранителя.
## Исходное состояние: северный туннель запечатан, наградной сундук скрыт и не имеет невидимой коллизии.
## Ожидаемый результат: до победы оба способа перехода запрещены, после победы сундук открывается один раз и выход работает.
func test_seals_and_chest_follow_victory() -> void:
	var game := sanctum(); var chest_index: int = game.world_loot_nodes.size()-1
	var chest: Dictionary = game.world_loot_nodes[chest_index]
	game.player = Data.CHEST
	expect(not Arena.container_visible(game,chest) and not game.LootContainerSystem.open(game,chest_index),"victory chest cannot be seen or opened early")
	expect(game.NavigationSystem.walkability_reason(game,Data.CHEST,-1,false)=="walkable","hidden chest creates no invisible obstacle")
	expect(not game.nearest_interaction().begins_with("container:"),"hidden reward never offers a context action")
	game.player = Vector2(1728,312); game.move_player_with_collisions(Vector2(0,-144))
	expect(game.player.y>Data.SEAL.end.y and game.player.y<312,"large movement stops at the visible moon seal")
	for x in [1656,1728,1800]: expect(Arena.blocks_seal(game,Vector2(x,224),game.PLAYER_RADIUS),"seal covers the whole tunnel width")
	game.player = Data.EXIT
	expect(not game.LocationTransitionSystem.update(game,0) and not game.LocationTransitionSystem.activate(game,"world_gate"),"automatic and explicit travel cannot bypass the living boss")
	game.WorldSystem.travel(game)
	expect(game.current_location==Data.LOCATION,"direct world travel also respects the sealed sanctuary")
	game.player = Data.ALTAR+Vector2(0,72); Arena.activate(game)
	game.CombatSystem.apply_damage(game,game.CaveBossSystem.index(game),200)
	expect(Arena.can_exit(game) and not Arena.blocks_seal(game,Vector2(1728,224),game.PLAYER_RADIUS),"victory extinguishes the seal and removes its collision")
	game.player = Data.CHEST+Vector2(0,72)
	expect(Arena.container_visible(game,chest) and game.LootContainerSystem.open(game,chest_index),"victory reveals a reachable real reward chest")
	expect(not game.LootContainerSystem.open(game,chest_index),"reward chest cannot be opened twice")
	game.player = Data.EXIT
	expect(game.LocationTransitionSystem.activate(game,"world_gate") and game.current_location=="cursed","opened north passage keeps its onward connection")
	game.free()

## Сценарий: обычный страж, сюжетный босс и старое сохранение с добытой реликвией проходят новую наградную логику.
## Исходное состояние: рядовые стражи больше не выдают сюжетный предмет; босс имеет собственную запись выдачи.
## Ожидаемый результат: новый бой даёт ровно одну реликвию, старые предметы и выполненная миссия исключают повторную выдачу.
func test_story_relic_is_unique_and_legacy_rewards_survive() -> void:
	var game := sanctum(); game.current_location = "cave"; game.player = game.enemy_nodes[4].position
	game.CombatSystem.apply_damage(game,4,200)
	expect(not game.dropped_items.any(func(item): return item.kind=="moon_relic"),"ordinary cave guardians no longer drop story relics")
	game.current_location = Data.LOCATION; game.player = Data.ALTAR+Vector2(0,72); Arena.activate(game)
	game.CombatSystem.apply_damage(game,game.CaveBossSystem.index(game),200)
	var relics: Array = game.dropped_items.filter(func(item): return item.kind=="moon_relic")
	expect(relics.size()==1 and relics[0].count==1,"level-five story boss drops exactly one moon relic")
	Arena.award_relic(game)
	expect(game.dropped_items.filter(func(item): return item.kind=="moon_relic").size()==1,"repeat completion cannot duplicate the story reward")
	game.free()
	for legacy in ["inventory","drop","completed"]:
		game = sanctum()
		if legacy=="inventory": game.change_inventory_count("moon_relic",2)
		elif legacy=="drop": game.dropped_items.append({"kind":"moon_relic","count":3,"position":Vector2(960,720),"location":"cave"})
		else: game.mission_states.story_relic = game.QuestSystem.COMPLETED
		var saved: Dictionary = game.SaveSystem.snapshot(game); saved.erase("cave_arena")
		expect(game.SaveSystem.apply(game,saved),"legacy reward loads successfully: "+legacy)
		game.player = Data.ALTAR+Vector2(0,72); Arena.activate(game); var before: Array = game.dropped_items.filter(func(item): return item.kind=="moon_relic")
		game.CombatSystem.apply_damage(game,game.CaveBossSystem.index(game),200)
		expect(game.dropped_items.filter(func(item): return item.kind=="moon_relic")==before,"legacy story reward remains unchanged: "+legacy)
		game.free()

## Сценарий: прежний сундук и повреждённый хранитель загружаются в новый план арены.
## Исходное состояние: снимок содержит старые координаты, открытый сундук, остатки добычи и 63 HP у босса.
## Ожидаемый результат: здоровье, содержимое и открытие сохраняются, временные угрозы сброшены, повреждённый документ отклоняется целиком.
func test_save_relocates_old_chest_without_resetting_progress() -> void:
	var game := sanctum(); var index: int = game.CaveBossSystem.index(game)
	game.enemy_nodes[index].hp = 63
	var chest: Dictionary = game.world_loot_nodes.back(); chest.opened = true; chest.contents = {"coins":17,"metal":2}; chest.position = Vector2(1752,864)
	var saved: Dictionary = game.SaveSystem.snapshot(game); saved.erase("cave_arena")
	saved.player = [1200,600]
	expect(game.SaveSystem.apply(game,saved) and game.player==Vector2(1200,600),"old rock-island coordinates become valid clear floor")
	expect(game.enemy_nodes[index].hp==63 and game.enemy_nodes[index].position==Data.BOSS and not game.state.world.cave_boss.active,"loading preserves boss HP and returns it to the new sleeping position")
	chest = game.world_loot_nodes.back()
	expect(chest.position==Data.CHEST and chest.opened and chest.contents=={"coins":17,"metal":2},"old chest moves without refreshing contents or reopening")
	var invalid: Dictionary = game.SaveSystem.snapshot(game); invalid.cave_arena.relic_awarded = "yes"
	var before: Dictionary = game.SaveSystem.snapshot(game)
	expect(not game.SaveSystem.apply(game,invalid) and game.SaveSystem.snapshot(game)==before,"bad arena progress is rejected without partial mutation")
	game.free()

## Сценарий: герой отступает через левую дверь и позднее возвращается к алтарю.
## Исходное состояние: хранитель имеет 71 HP, на арене есть призванный зомби и прикреплённая муха.
## Ожидаемый результат: путь назад открыт, угрозы исчезают сразу, здоровье сохраняется, повторный бой требует действия у алтаря.
func test_retreat_preserves_hp_and_clears_threats() -> void:
	var game := sanctum(); Arena.activate(game); var index: int = game.CaveBossSystem.index(game)
	game.enemy_nodes[index].hp = 71; game.CaveBossSystem.Minions.summon(game,["zombie"]); game.CaveBossSystem.Shots.attach_fly(game,3.0)
	game.player = Vector2(192,600)
	expect(game.LocationTransitionSystem.CavePassages.travel(game,"left") and game.current_location=="cave_lake","retreat is available during the active boss fight")
	expect(not game.state.world.cave_boss.active and game.state.world.cave_boss.minions.is_empty() and game.state.world.cave_boss.fly_timer==0.0,"leaving clears all temporary threats immediately")
	game.player = Vector2(2208,600); game.LocationTransitionSystem.CavePassages.travel(game,"right")
	game.CaveBossSystem.update(game,2.0)
	expect(game.enemy_nodes[index].hp==71 and not game.state.world.cave_boss.active,"return preserves damage and leaves the guardian sleeping")
	game.player = Data.ALTAR+Vector2(0,72)
	expect(Arena.activate(game) and game.state.world.cave_boss.phase==2,"altar resumes the correct health phase with a recovery window")
	game.free()

## Сценарий: игрок выбирает любой из шести поддерживаемых языков перед встречей с алтарём.
## Исходное состояние: название, контекстное действие и обучение зарегистрированы в общих каталогах.
## Ожидаемый результат: подсказки объясняют пробуждение и награду без технических идентификаторов.
func test_altar_explanation_is_localized() -> void:
	var game := sanctum()
	for locale in game.LocaleSystem.LOCALES:
		game.LocaleSystem.set_locale(locale,false)
		expect(game.LocaleSystem.tutorial("cave_boss_altar")!="cave_boss_altar" and "cave_boss_altar" in game.TutorialSystem.STEP_IDS,"altar tutorial exists: "+locale)
		expect(game.LocaleSystem.ui("context_awaken")!="context_awaken" and game.LocaleSystem.entity("cave_altar")!="cave_altar","altar name and action are localized: "+locale)
	game.LocaleSystem.set_locale("ru",false); game.free()
