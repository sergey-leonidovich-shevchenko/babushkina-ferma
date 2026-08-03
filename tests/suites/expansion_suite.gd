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
	game.EstateSystem.discover_location(game, "cave"); game.day = 3; game.EstateSystem.update_daily_event(game)
	var snapshot: Dictionary = game.SaveSystem.snapshot(game); game.state.world.estate = game.EstateSystem.default_state()
	expect(game.SaveSystem.apply(game, snapshot), "estate economy snapshot loads")
	expect("cave" in game.state.world.estate.discovered and game.state.world.estate.event_day == 3, "map discovery and daily event survive save roundtrip")
	expect(game.tutorial_events_completed.has("world_calendar"), "living calendar has tutorial coverage")
	game.free()
