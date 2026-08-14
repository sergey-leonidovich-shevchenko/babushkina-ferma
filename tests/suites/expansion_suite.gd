extends "res://tests/suites/suite_base.gd"


## Запускает сценарии второго сюжетного акта, фаз босса, выбора и сохранения.
func run() -> void:
	test_castle_investigation_uses_ordered_world_objectives()
	test_shadow_regent_changes_three_combat_phases()
	test_final_choice_changes_permanent_character_build()
	test_castle_campaign_survives_save_roundtrip()
	test_companion_commands_change_movement_combat_and_defense()
	test_estate_upgrades_unlock_permanent_system_benefits()
	test_item_quality_and_daily_market_change_sale_value()
	test_world_map_discovers_regions_and_marks_story_objective()
	test_npc_schedule_reacts_to_time_and_weather()
	test_combat_dodge_block_critical_and_knockback()
	test_world_bosses_have_distinct_second_phase_mechanics()
	test_debug_mission_queue_is_ordered_collapsible_and_inspectable()
	test_debug_mission_completion_uses_real_rewards_and_consumes_world_source()
	test_debug_completion_resolves_locked_story_and_moon_expedition()


## Сценарий: расследование проходит через совет, три независимые улики и ритуал.
## Исходное состояние: «Первый рассвет» завершён, герой последовательно посещает три этажа замка.
## Ожидаемый результат: пропустить этап нельзя, все улики учитываются отдельно, ритуал пробуждает босса.
func test_castle_investigation_uses_ordered_world_objectives() -> void:
	var game := make_game()
	game.mission_states.story_first_dawn = game.QuestSystem.COMPLETED
	game.current_location = "castle_dungeon"; game.player = game.CastleCampaignSystem.RITUAL_POSITION
	expect(game.nearest_interaction() != "castle_ritual", "castle ritual cannot bypass council and investigation")
	game.current_location = "castle_hall"; game.player = game.CastleCampaignSystem.COUNCIL_POSITION
	expect(game.perform_context_action() and game.state.world.castle_campaign.stage == 1, "castle council starts investigation objective")
	game.current_location = "castle_upper"
	for index in game.CastleCampaignSystem.CLUE_POSITIONS.size():
		game.player = game.CastleCampaignSystem.CLUE_POSITIONS[index]
		expect(game.perform_context_action(), "independent castle clue can be investigated: %d" % index)
	expect(game.state.world.castle_campaign.stage == 2 and game.CastleCampaignSystem.clue_count(game.state.world.castle_campaign) == 3, "three clues unlock dungeon ritual")
	game.current_location = "castle_dungeon"; game.player = game.CastleCampaignSystem.RITUAL_POSITION
	expect(game.perform_context_action() and game.state.world.castle_campaign.boss_alive, "investigation ritual awakens shadow regent")
	expect(game.tutorial_events_completed.has("castle_investigation") and game.tutorial_events_completed.has("quest_investigation"), "non-fetch investigation has tutorial coverage")
	game.free()


## Сценарий: обычная кнопка атаки проводит Регента через три порога здоровья.
## Исходное состояние: босс активен, герой стоит в ближнем радиусе с Кристальным мечом.
## Ожидаемый результат: наблюдаются фазы 1, 2 и 3, победа открывает два взаимоисключающих решения.
func test_shadow_regent_changes_three_combat_phases() -> void:
	var game := make_game()
	game.mission_states.story_first_dawn = game.QuestSystem.COMPLETED
	var state: Dictionary = game.state.world.castle_campaign
	state.stage = 3; state.boss_alive = true; state.boss_hp = game.CastleCampaignSystem.BOSS_MAX_HP
	game.current_location = "castle_dungeon"; game.player = game.CastleCampaignSystem.BOSS_POSITION + Vector2(0, 80)
	game.has_crystal_sword = true; game.equipped_weapon = "crystal_sword"
	var phases := {1:true}
	while state.boss_alive:
		expect(game.attack_nearest_enemy(), "normal attack reaches active shadow regent")
		phases[int(state.boss_phase)] = true
	expect(phases.has(1) and phases.has(2) and phases.has(3), "shadow regent exposes all three health phases")
	expect(state.stage == 4 and state.boss_defeated and game.inventory_item_count("blue_gem") == 3, "boss defeat unlocks choice and grants exact rare loot")
	game.free()


## Сценарий: два финальных алтаря создают разные постоянные сборки героя.
## Исходное состояние: два изолированных героя победили Регента и имеют одинаковые базовые характеристики.
## Ожидаемый результат: печать даёт здоровье, подчинение — ману и урон, повторно выбрать нельзя.
func test_final_choice_changes_permanent_character_build() -> void:
	var sealed := make_game(); sealed.mission_states.story_first_dawn = sealed.QuestSystem.COMPLETED
	sealed.state.world.castle_campaign.stage = 4; sealed.current_location = "castle_dungeon"; sealed.player = sealed.CastleCampaignSystem.SEAL_ALTAR_POSITION
	expect(sealed.perform_context_action(), "seal altar accepts permanent story choice")
	var sealed_hp: int = sealed.player_max_hp
	var powered := make_game(); powered.mission_states.story_first_dawn = powered.QuestSystem.COMPLETED
	powered.state.world.castle_campaign.stage = 4; powered.current_location = "castle_dungeon"; powered.player = powered.CastleCampaignSystem.POWER_ALTAR_POSITION
	var base_damage: int = powered.CombatSystem.player_attack_damage(powered)
	expect(powered.perform_context_action(), "power altar accepts alternative permanent story choice")
	expect(sealed_hp == powered.player_max_hp + 20, "seal ending grants twenty permanent maximum health")
	expect(powered.player_max_mana == sealed.player_max_mana + 20 and powered.CombatSystem.player_attack_damage(powered) == base_damage + 2, "power ending grants mana and two damage")
	expect(not powered.CastleCampaignSystem.interact(powered, "castle_choice:seal"), "completed ending cannot be selected twice")
	sealed.free(); powered.free()


## Сценарий: сохранение удерживает найденные улики, здоровье босса и окончательное решение.
## Исходное состояние: расследование частично завершено, Регент ранен во второй фазе.
## Ожидаемый результат: загрузка восстанавливает точные данные и старый снимок получает безопасное начало кампании.
func test_castle_campaign_survives_save_roundtrip() -> void:
	var game := make_game(); game.mission_states.story_first_dawn = game.QuestSystem.COMPLETED
	game.state.world.castle_campaign = {"stage":3,"clues":[true,true,true],"boss_alive":true,"boss_defeated":false,"boss_hp":19,"boss_phase":2,"boss_timer":0.7,"telegraph":0.2,"choice":"","completed":false}
	var snapshot: Dictionary = game.SaveSystem.snapshot(game)
	game.state.world.castle_campaign = game.CastleCampaignSystem.default_state()
	expect(game.SaveSystem.apply(game, snapshot), "castle campaign snapshot loads")
	expect(game.state.world.castle_campaign.boss_hp == 19 and game.state.world.castle_campaign.boss_phase == 2 and game.state.world.castle_campaign.clues == [true,true,true], "boss and investigation progress survive save roundtrip")
	snapshot.erase("castle_campaign")
	expect(game.SaveSystem.apply(game, snapshot) and game.state.world.castle_campaign.stage == 0, "legacy save receives safe unopened castle act")
	game.free()


## Сценарий: четыре приказа группы меняют следование, атаку и защиту без смены состава.
## Исходное состояние: Мила и Борислав активны, рядом существует живой противник, позиции группы известны.
## Ожидаемый результат: ожидание фиксирует позицию, атака ведёт к цели, защита даёт бонус, приказ и дружба сохраняются.
func test_companion_commands_change_movement_combat_and_defense() -> void:
	var game := make_game(); game.recruited_companions.assign(["mila","borislav"]); game.active_companions.assign(["mila","borislav"])
	game.companion_positions = {"mila":game.player + Vector2(-70, 0),"borislav":game.player + Vector2(-90, 0)}
	game.state.player.companion_command = "wait"
	var held_position: Vector2 = game.companion_positions.mila
	game.CompanionSystem.update(game, 0.5)
	expect(game.companion_positions.mila == held_position, "wait command keeps companion at exact position")
	game.state.player.companion_command = "defend"
	expect(game.CompanionSystem.defense_bonus(game) == 8, "defend command adds four defense to companion base protection")
	game.state.player.companion_command = "attack"; game.current_location = game.enemy_nodes[0].location; game.player = game.enemy_nodes[0].position + Vector2(-180, 0)
	game.companion_positions.mila = game.player
	game.CompanionSystem.update(game, 0.5)
	expect(game.companion_positions.mila.distance_to(game.enemy_nodes[0].position) < game.player.distance_to(game.enemy_nodes[0].position), "attack command moves companion toward nearest target")
	expect(game.CompanionSystem.cycle_command(game) == "defend" and game.tutorial_events_completed.has("companion_commands"), "command cycles and teaches tactical control")
	game.state.player.companion_bonds.mila = 12
	var snapshot: Dictionary = game.SaveSystem.snapshot(game)
	game.state.player.companion_command = "follow"; game.state.player.companion_bonds.clear()
	expect(game.SaveSystem.apply(game, snapshot), "companion tactics snapshot loads")
	expect(game.state.player.companion_command == "defend" and game.state.player.companion_bonds.mila == 12, "command and companion bond survive save roundtrip")
	game.free()


## Сценарий: герой последовательно строит дом, теплицу, хлев и лабораторию.
## Исходное состояние: денег и всех ресурсов достаточно, базовые характеристики и вместимость группы измерены.
## Ожидаемый результат: ресурсы списываются, здоровье, рост, группа и зелья получают заявленные постоянные бонусы.
func test_estate_upgrades_unlock_permanent_system_benefits() -> void:
	var game := make_game(); game.coins = 5000
	game.change_inventory_count("wood", 100); game.change_inventory_count("crystal", 20); game.change_inventory_count("metal", 20); game.change_inventory_count("ectoplasm", 10)
	var base_hp: int = game.player_max_hp; var base_capacity: int = game.CompanionSystem.capacity(game)
	for expected_level in range(1, 5):
		expect(game.EstateSystem.purchase_next(game), "estate sequential upgrade can be purchased: %d" % expected_level)
		expect(game.state.world.estate.level == expected_level, "estate reaches exact sequential level: %d" % expected_level)
	expect(game.player_max_hp == base_hp + 10, "house permanently adds ten maximum health")
	expect(game.EstateSystem.crop_multiplier(game) >= 1.2, "greenhouse accelerates crop growth")
	expect(game.CompanionSystem.capacity(game) == base_capacity + 1, "barn adds one active companion slot")
	expect(is_equal_approx(game.EstateSystem.potion_multiplier(game), 1.35), "laboratory extends potion duration")
	expect(game.tutorial_events_completed.has("estate_upgrade"), "estate construction has tutorial coverage")
	game.free()


## Сценарий: качественная морковь продаётся в день ярмарки и состояние экономики сохраняется.
## Исходное состояние: в инвентаре одна морковь иридиевого качества, календарь указывает рыночный день.
## Ожидаемый результат: лучшая партия расходуется, цена выше базовой, карта, событие и качество переживают загрузку.
func test_item_quality_and_daily_market_change_sale_value() -> void:
	var game := make_game(); game.state.world.estate.qualities = {"carrot":{"iridium":1}}; game.state.world.estate.event = "market"
	game.change_inventory_count("carrot", 1); var coins_before: int = game.coins
	expect(game.ShopSystem.sell(game, 1), "quality crop can be sold through regular shop flow")
	expect(game.coins - coins_before == roundi(8.0 * 2.1 * 1.15), "iridium quality and market day combine in final sale value")
	expect(game.state.world.estate.qualities.carrot.iridium == 0, "sold quality unit is removed from its quality stack")
	game.player = game.food_nodes[0].position
	expect(game.ForageSystem.collect(game, 0) and game.state.world.estate.qualities.has(game.food_nodes[0].kind), "wild fruit and mushroom harvest also enters shared quality economy")
	game.EstateSystem.discover_location(game, "cave"); game.day = 3; game.EstateSystem.update_daily_event(game)
	var snapshot: Dictionary = game.SaveSystem.snapshot(game); game.state.world.estate = game.EstateSystem.default_state()
	expect(game.SaveSystem.apply(game, snapshot), "estate economy snapshot loads")
	expect("cave" in game.state.world.estate.discovered and game.state.world.estate.event_day == 3, "map discovery and daily event survive save roundtrip")
	expect(game.tutorial_events_completed.has("world_calendar"), "living calendar has tutorial coverage")
	game.free()


## Сценарий: герой открывает карту из замка после начала расследования.
## Исходное состояние: посещены деревня и руины, текущая комната — интерьер замка, акт требует искать улики.
## Ожидаемый результат: карта показывает родительский регион, сюжетную цель, неизвестные области и работает как модальное окно.
func test_world_map_discovers_regions_and_marks_story_objective() -> void:
	var game := make_game(); game.current_location = "castle_upper"; game.state.world.estate.discovered = ["overworld", "ruins"]
	game.state.world.castle_campaign.stage = 1
	expect(game.WorldMapSystem.current_region(game) == "ruins", "castle interior maps to its outdoor ruins region")
	expect(game.WorldMapSystem.objective_region(game) == "ruins", "active castle investigation marks ruins as story objective")
	expect(game.WorldMapRenderer.MAP_BACKGROUND.get_width() == 1862 and game.WorldMapRenderer.MAP_BACKGROUND.get_height() == 845, "world map uses selected high-resolution 32-bit-style painted background")
	expect(game.WorldMapSystem.toggle(game) and game.world_map_open, "map opens from shared keyboard gamepad touch command")
	expect(game.tutorial_events_completed.has("world_map"), "world map has tutorial coverage")
	expect(not game.WorldMapSystem.toggle(game) and not game.world_map_open, "same map command closes modal overlay")
	game.EstateSystem.discover_location(game, "forest")
	expect("forest" in game.state.world.estate.discovered and "cave" not in game.state.world.estate.discovered, "map reveals only regions actually visited")
	game.state.world.castle_campaign.stage = 0; game.mission_states.story_relic = game.QuestSystem.ACTIVE
	expect(game.WorldMapSystem.objective_region(game) == game.QuestSystem.NPCS.miron.location, "active regular quest also supplies its giver region as valid map objective")
	game.free()


## Сценарий: один житель следует дневному распорядку и прячется от снегопада.
## Исходное состояние: фиксированы дом жителя, четыре времени суток и управляемая запись погоды.
## Ожидаемый результат: утро, работа, вечер и укрытие дают разные опорные точки и отмечаются обучением.
func test_npc_schedule_reacts_to_time_and_weather() -> void:
	var game := make_game(); var state: Dictionary = game.npc_movement.grandmother
	game.state.world.weather_day = game.day; game.state.world.weather = "clear"
	game.game_minutes = 6 * 60; var morning: Vector2 = game.NpcMovementSystem.schedule_anchor(game, state)
	game.game_minutes = 12 * 60; var work: Vector2 = game.NpcMovementSystem.schedule_anchor(game, state)
	game.game_minutes = 20 * 60; var evening: Vector2 = game.NpcMovementSystem.schedule_anchor(game, state)
	game.state.world.weather = "snow"; var shelter: Vector2 = game.NpcMovementSystem.schedule_anchor(game, state)
	expect(morning != work and work != evening and shelter != evening, "NPC schedule owns distinct daily and bad-weather anchors")
	expect(state.schedule == "shelter" and game.tutorial_events_completed.has("npc_schedule"), "bad weather selects shelter schedule and teaches living world")
	game.free()


## Сценарий: герой применяет рывок, удерживаемый блок и серию из четырёх ударов.
## Исходное состояние: сил достаточно, два одинаковых героя получают одинаковую атаку, тренировочный враг имеет большой запас здоровья.
## Ожидаемый результат: рывок неуязвим, блок уменьшает урон, четвёртый удар критический, мобильная цель отталкивается.
func test_combat_dodge_block_critical_and_knockback() -> void:
	var dodger := make_game(); dodger.facing = Vector2.RIGHT; var start: Vector2 = dodger.player; var hp_before: int = dodger.player_hp
	expect(dodger.CombatSystem.start_dodge(dodger) and dodger.player.x > start.x, "dodge spends stamina and immediately moves hero forward")
	expect(dodger.CombatSystem.damage_player(dodger, 30, "test") == 0 and dodger.player_hp == hp_before, "active dodge grants a short invulnerability window")
	expect(not dodger.CombatSystem.start_dodge(dodger), "dodge cooldown prevents immediate repeated invulnerability")
	var blocker := make_game(); var unblocked := make_game(); blocker.CombatSystem.set_blocking(blocker, true)
	var blocked_damage: int = blocker.CombatSystem.damage_player(blocker, 30, "test"); var full_damage: int = unblocked.CombatSystem.damage_player(unblocked, 30, "test")
	expect(blocked_damage < full_damage and blocker.energy == unblocked.energy - 1, "held block reduces incoming damage and consumes one stamina per hit")
	var fighter := make_game(); var enemy: Dictionary = fighter.enemy_nodes[1]; fighter.current_location = enemy.location; fighter.player = enemy.position - Vector2(45, 0)
	enemy.hp = 100; enemy.max_hp = 100; fighter.enemy_nodes[1] = enemy; var origin: Vector2 = enemy.position
	for hit in 4:
		fighter.player = fighter.enemy_nodes[1].position - Vector2(45, 0)
		expect(fighter.CombatSystem.attack(fighter, 1), "combat combo hit connects: %d" % (hit + 1))
	enemy = fighter.enemy_nodes[1]
	expect(enemy.hp == 95, "four-hit chain deals three normal points and a double critical point")
	expect(enemy.position.x > origin.x, "melee impact knocks mobile enemy away from hero")
	expect(fighter.tutorial_events_completed.has("critical_hit") and blocker.tutorial_events_completed.has("combat_block") and dodger.tutorial_events_completed.has("combat_dodge"), "all advanced combat actions have tutorial coverage")
	dodger.free(); blocker.free(); unblocked.free(); fighter.free()


## Сценарий: Хранитель глубин и Утопший капитан переходят половину здоровья.
## Исходное состояние: оба босса находятся во второй фазе при одинаковом уровне, у героя есть десять монет.
## Ожидаемый результат: Хранитель сильнее бьёт, Капитан применяет отдельное воровство, обычный орк фаз не имеет.
func test_world_bosses_have_distinct_second_phase_mechanics() -> void:
	var game := make_game(); var guardian: Dictionary = game.enemy_nodes[4]; var captain: Dictionary = game.enemy_nodes[29]; var orc: Dictionary = game.enemy_nodes[1]
	guardian.hp = guardian.max_hp / 2; captain.hp = captain.max_hp / 2
	expect(game.CombatSystem.boss_phase(guardian) == 2 and game.CombatSystem.boss_phase(captain) == 2 and game.CombatSystem.boss_phase(orc) == 0, "only named world bosses own health phases")
	expect(game.CombatSystem.boss_attack_damage(guardian) == game.CombatSystem.attack_damage(guardian.kind, guardian.level) + 6, "cave guardian second phase empowers seismic strike")
	game.coins = 10; game.CombatSystem.apply_boss_side_effect(game, captain)
	expect(game.coins == 8, "drowned captain second phase steals exactly two coins per successful attack")
	expect(game.tutorial_events_completed.has("boss_identity"), "distinct boss mechanics have tutorial coverage")
	game.free()


## Сценарий: debug-панель показывает полную устойчивую очередь миссий и открывает подробности выбранной строки.
## Исходное состояние: новая игра, F10 включён, список миссий свёрнут и прогресс ещё не изменён.
## Ожидаемый результат: обучение идёт первым, сюжет образует цепочку, заголовок раскрывает список, а кнопка i открывает описание.
func test_debug_mission_queue_is_ordered_collapsible_and_inspectable() -> void:
	var game := make_game(); game.DebugOverlaySystem.toggle(game)
	var ids: Array[String] = game.DebugMissionSystem.ordered_ids(game)
	expect(ids[0] == game.DebugMissionSystem.GRANDMOTHER_ID and ids[1] == "story_relic" and ids[8] == "story_first_dawn", "debug mission queue starts with tutorial and chronological story chain")
	expect(ids.size() == game.QuestSystem.MISSIONS.size() + 1 and game.DebugMissionSystem.page_count(game) == 3, "debug mission queue contains every mission on three bounded pages")
	expect(game.DebugMissionSystem.handle_pointer(game, game.DebugMissionSystem.HEADER.get_center()) and game.get_meta(game.DebugOverlaySystem.META_KEY).missions_expanded, "mission header expands inside live F10 overlay")
	var first_row: Dictionary = game.DebugMissionSystem.visible_rows(game)[0]
	expect(game.DebugMissionSystem.handle_pointer(game, first_row.info.get_center()), "mission info icon handles click")
	expect(game.get_meta(game.DebugOverlaySystem.META_KEY).mission_details == game.DebugMissionSystem.GRANDMOTHER_ID, "mission info icon opens selected details modal")
	game.free()


## Сценарий: debug-завершение обычной миссии применяет штатную награду и опустошает связанный источник предмета.
## Исходное состояние: сюжетная реликвия лежит и в выпавшем предмете, и в содержимом закрытого сундука; задание не принято.
## Ожидаемый результат: обычная сдача выдаёт точные монеты, XP и броню, предмет исчезает, а сундук отображается открытым.
func test_debug_mission_completion_uses_real_rewards_and_consumes_world_source() -> void:
	var game := make_game(); game.DebugOverlaySystem.toggle(game); var coins_before: int = game.coins; var level_before: int = game.player_level; var points_before: int = game.skill_points
	game.dropped_items.append({"kind":"moon_relic", "count":1, "position":Vector2(100,100)})
	game.world_loot_nodes[0].contents.moon_relic = 1; game.world_loot_nodes[0].opened = false
	expect(game.DebugMissionSystem.debug_complete(game, "story_relic"), "debug completion accepts available story mission")
	expect(game.mission_states.story_relic == game.QuestSystem.COMPLETED and game.coins == coins_before + 120 and game.player_level == level_before + 1 and game.skill_points == points_before + 1, "debug completion delegates exact coins and level-up XP to normal quest system")
	expect(game.guardian_armor == 1 and game.inventory_item_count("moon_relic") == 0, "normal quest reward is granted and consumed objective does not remain in inventory")
	expect(not game.dropped_items.any(func(item): return item.kind == "moon_relic") and game.world_loot_nodes[0].opened and game.world_loot_nodes[0].contents.is_empty(), "world objective disappears and its source chest becomes visibly empty")
	expect(game.get_meta(game.DebugOverlaySystem.META_KEY).mission_completion.open and game.message.contains("Сердце пещеры"), "completion opens reward modal using the existing completion message")
	game.free()


## Сценарий: debug-завершение поздней главы последовательно закрывает зависимости и уникальную Лунную экспедицию.
## Исходное состояние: совершенно новая сюжетная цепочка, закрытое Сердце затмения и нет квестовой реликвии.
## Ожидаемый результат: предыдущие главы получают штатные награды, лунный сундук открыт, уникальный предмет сохранён и глава завершена.
func test_debug_completion_resolves_locked_story_and_moon_expedition() -> void:
	var game := make_game(); game.DebugOverlaySystem.toggle(game)
	expect(game.DebugMissionSystem.debug_complete(game, "story_eclipse_heart"), "debug completion can resolve a locked conditioned story mission")
	for mission_id in ["story_relic", "story_ancient_key", "story_orc_blade", "story_cursed_gem", "story_moon_seal", "story_eclipse_heart"]:
		expect(game.mission_states[mission_id] == game.QuestSystem.COMPLETED, "story dependency completed consistently: %s" % mission_id)
	expect(game.state.world.moon_glade.chest_opened and game.state.world.moon_glade.completed_runs == 1, "conditioned mission completes its actual expedition and opens moon chest")
	expect(game.inventory_item_count("eclipse_core") == 1 and game.inventory_item_count("mana_potion") == 2, "keep-item objective remains while normal mission reward is granted")
	game.free()
