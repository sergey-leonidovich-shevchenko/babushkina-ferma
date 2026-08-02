extends "res://tests/suites/suite_base.gd"

## Запускает сценарии ежедневных заказов, репутации гильдии и наградного знака.
func run() -> void:
	test_daily_offers_are_deterministic_and_scale()
	test_guild_board_discovery_service_and_input()
	test_contract_acceptance_requirements_and_rewards()
	test_three_contracts_grant_rank_and_badge()
	test_new_day_refreshes_contracts()
	test_contract_touch_and_gamepad_input()
	test_contract_progress_is_saved_and_old_saves_migrate()


## Сценарий: каждый день предлагает три предсказуемых заказа с растущей сложностью и наградой.
## Исходное состояние: две новые игры находятся на одинаковом дне, затем одна переводится на поздний день.
## Ожидаемый результат: предложения совпадают для одного дня и становятся сложнее и дороже позже.
func test_daily_offers_are_deterministic_and_scale() -> void:
	var game := make_game()
	var twin := make_game()
	var first: Array[Dictionary] = game.ContractSystem.offers(game)
	var same: Array[Dictionary] = twin.ContractSystem.offers(twin)
	expect(first == same and first.size() == 3, "daily guild board deterministically exposes three contracts")
	expect(first.map(func(contract): return contract.id) == ["farmer", "hunter", "miner"], "daily contracts cover farming hunting and mining")
	game.day = 13
	var later: Array[Dictionary] = game.ContractSystem.offers(game)
	expect(later[0].amount > first[0].amount and later[0].coins > first[0].coins, "later days scale contract amount and coin reward")
	expect(game.state.contracts.offer_day == 13, "offer generation records its active day")
	game.free()
	twin.free()


## Сценарий: доска гильдии обнаруживается, подсвечивается и открывает отдельное модальное окно.
## Исходное состояние: герой впервые входит в интерьер гильдии и стоит у доски заказов.
## Ожидаемый результат: карточка объясняет объект, контекстное действие открывает окно и клавиши меняют выбор.
func test_guild_board_discovery_service_and_input() -> void:
	var game := make_game()
	game.current_location = "guild_interior"
	game.player = game.BuildingSystem.INTERIORS.guild_interior.service_position
	expect(game.DiscoverySystem.scan_nearby(game) and game.discovery_current.id == "contracts", "guild contract board has a first-approach explanation")
	expect(game.nearest_interaction() == "interior_service:contracts", "guild board is a contextual interior service")
	expect(game.perform_context_action() and game.contract_open, "context action opens the dedicated contract window")
	expect(game.tutorial_events_completed.has("contract_board"), "opening the board completes its tutorial event")
	game.InputSystem.handle_contract_input(game, key_event(KEY_DOWN, KEY_DOWN, true))
	expect(game.contract_selected == 1, "keyboard moves contract selection immediately")
	game.InputSystem.handle_contract_input(game, key_event(KEY_ESCAPE, KEY_ESCAPE, true))
	expect(not game.contract_open, "keyboard closes the contract window")
	game.free()


## Сценарий: заказ сначала принимается, затем требует точное количество предметов и выдаёт награду.
## Исходное состояние: открыт первый заказ дня, в рюкзаке сначала нет его предметов, затем выдан полный стек.
## Ожидаемый результат: ранняя сдача отклоняется, успешная атомарно списывает предметы и начисляет прогресс.
func test_contract_acceptance_requirements_and_rewards() -> void:
	var game := make_game()
	game.current_location = "guild_interior"
	game.ContractSystem.open(game)
	var contract: Dictionary = game.ContractSystem.offers(game)[0]
	expect(game.ContractSystem.act_selected(game), "available daily contract can be accepted")
	expect(game.state.contracts.status(contract.id) == "active" and game.tutorial_events_completed.has("contract_accept"), "accepted contract persists and teaches acceptance")
	expect(not game.ContractSystem.act_selected(game), "active contract cannot complete without requested items")
	game.change_inventory_count(contract.item, contract.amount)
	var coins_before: int = game.coins
	var xp_before: int = game.player_xp
	expect(game.ContractSystem.act_selected(game), "active contract completes with exact requested stack")
	expect(game.inventory_item_count(contract.item) == 0, "contract consumes the delivered stack exactly once")
	expect(game.coins == coins_before + contract.coins and game.player_xp == xp_before + contract.xp, "contract awards configured coins and character experience")
	expect(game.skill_xp.farming == 8 and game.tutorial_events_completed.has("contract_complete"), "farm contract also trains its profession and tutorial")
	expect(not game.ContractSystem.act_selected(game), "completed daily contract cannot be claimed twice")
	game.free()


## Сценарий: выполнение трёх разных заказов повышает репутацию и выдаёт уникальный знак.
## Исходное состояние: у героя нулевая репутация, а для всех трёх контрактов выданы нужные предметы.
## Ожидаемый результат: третий заказ открывает первый ранг, премию и надеваемый знак с HP и уроном.
func test_three_contracts_grant_rank_and_badge() -> void:
	var game := make_game()
	game.current_location = "guild_interior"
	game.ContractSystem.open(game)
	var offers: Array[Dictionary] = game.ContractSystem.offers(game)
	var coins_before: int = game.coins
	for index in offers.size():
		game.contract_selected = index
		game.ContractSystem.act_selected(game)
		game.change_inventory_count(offers[index].item, offers[index].amount)
		game.ContractSystem.act_selected(game)
	expect(game.state.contracts.completed_total == 3 and game.ContractSystem.guild_rank(game) == 1, "three completed contracts grant guild rank one")
	expect(game.inventory_item_count("guild_badge") == 1, "first guild rank awards one unique badge")
	var configured_rewards: int = offers.reduce(func(total, contract): return total + contract.coins, 0)
	expect(game.coins == coins_before + configured_rewards + 25, "rank one adds its twenty-five coin promotion bonus")
	var hp_before: int = game.player_max_hp
	var damage_before: int = game.InventorySystem.damage_bonus(game)
	expect(game.InventorySystem.equip(game, "guild_badge"), "guild badge equips into the ring slot")
	expect(game.player_max_hp == hp_before + 10 and game.InventorySystem.damage_bonus(game) == damage_before + 1, "equipped guild badge grants health and damage")
	expect(game.tutorial_events_completed.has("guild_rank"), "first promotion completes guild-rank tutorial")
	game.free()


## Сценарий: ежедневные заказы истекают и полностью обновляются после смены дня.
## Исходное состояние: в первый день один заказ принят, другой выполнен, затем наступает второй день.
## Ожидаемый результат: три строки снова доступны, дневной ранг сохраняется, а набор предложений меняется.
func test_new_day_refreshes_contracts() -> void:
	var game := make_game()
	var first: Array[Dictionary] = game.ContractSystem.offers(game)
	game.state.contracts.set_status("farmer", "active")
	game.state.contracts.set_status("hunter", "completed")
	game.state.contracts.completed_total = 2
	game.day = 2
	var second: Array[Dictionary] = game.ContractSystem.offers(game)
	expect(game.state.contracts.statuses.values().all(func(value): return value == "available"), "new day resets all daily contract states")
	expect(game.state.contracts.completed_total == 2, "new day preserves lifetime guild reputation")
	expect(first[0].item != second[0].item, "daily rotation changes the requested farm item")
	game.free()


## Сценарий: доска одинаково принимает команды геймпада и сенсорного экрана.
## Исходное состояние: окно контрактов открыто, выбран первый доступный заказ.
## Ожидаемый результат: D-pad меняет строку, A принимает её, а касание выбирает и принимает третью.
func test_contract_touch_and_gamepad_input() -> void:
	var game := make_game()
	game.current_location = "guild_interior"
	game.ContractSystem.open(game)
	var down := InputEventJoypadButton.new()
	down.button_index = JOY_BUTTON_DPAD_DOWN
	down.pressed = true
	expect(game.handle_gamepad_and_touch(down) and game.contract_selected == 1, "gamepad D-pad is routed into contract modal")
	var accept := InputEventJoypadButton.new()
	accept.button_index = JOY_BUTTON_A
	accept.pressed = true
	expect(game.handle_gamepad_and_touch(accept) and game.state.contracts.status("hunter") == "active", "gamepad A accepts selected contract")
	var third_row: Vector2 = game.InterfaceRenderer.CONTRACT_ROWS.position + Vector2(30, 220)
	expect(game.InputSystem.handle_contract_touch(game, third_row), "contract touch row is consumed")
	expect(game.contract_selected == 2 and game.state.contracts.status("miner") == "active", "touch selects and accepts matching contract")
	game.free()


## Сценарий: день, статусы и репутация гильдии переживают сохранение, а старый снимок мигрирует.
## Исходное состояние: заказ принят, пять заказов числятся выполненными, затем создаются актуальный и legacy-снимки.
## Ожидаемый результат: новый снимок восстанавливает прогресс, старый получает безопасные значения по умолчанию.
func test_contract_progress_is_saved_and_old_saves_migrate() -> void:
	var game := make_game()
	game.ContractSystem.offers(game)
	game.state.contracts.set_status("miner", "active")
	game.state.contracts.completed_total = 5
	var snapshot: Dictionary = game.SaveSystem.snapshot(game)
	game.state.contracts.statuses.clear()
	game.state.contracts.completed_total = 0
	expect(game.SaveSystem.apply(game, snapshot), "save with guild contract state loads")
	expect(game.state.contracts.status("miner") == "active" and game.state.contracts.completed_total == 5, "save restores active order and lifetime reputation")
	var legacy := snapshot.duplicate(true)
	legacy.erase("contracts")
	expect(game.SaveSystem.apply(game, legacy), "older save without guild contracts still loads")
	expect(game.state.contracts.completed_total == 0 and game.state.contracts.statuses.values().all(func(value): return value == "available"), "legacy save migrates contracts to safe defaults")
	game.free()
