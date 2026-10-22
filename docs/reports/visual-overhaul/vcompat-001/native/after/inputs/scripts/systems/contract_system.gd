extends RefCounted

const CONTRACT_IDS := ["farmer", "hunter", "miner"]
const POOLS := {
	"farmer":[{"item":"carrot","amount":5,"coins":22,"xp":8},{"item":"berries","amount":4,"coins":28,"xp":10},{"item":"mushroom","amount":3,"coins":32,"xp":11}],
	"hunter":[{"item":"slime","amount":4,"coins":30,"xp":12},{"item":"fiber","amount":3,"coins":36,"xp":14},{"item":"bones","amount":3,"coins":42,"xp":16}],
	"miner":[{"item":"stone","amount":8,"coins":26,"xp":10},{"item":"crystal","amount":4,"coins":38,"xp":14},{"item":"metal","amount":3,"coins":46,"xp":17}],
}
const PROFESSION_BY_ID := {"farmer":"farming", "hunter":"combat", "miner":"mining"}
const CONTRACTS_PER_RANK := 3
const MAX_GUILD_RANK := 5


## Подготавливает изолированную витрину доски контрактов для визуальной проверки.
static func configure_preview(game: Node) -> void:
	game.language_screen = false
	game.title_screen = false
	game.current_location = "guild_interior"
	game.grant_tester_kit()
	open(game)


## Возвращает три детерминированных предложения активного игрового дня.
static func offers(game: Node) -> Array[Dictionary]:
	game.state.contracts.ensure_day(game.day)
	var result: Array[Dictionary] = []
	for offset in CONTRACT_IDS.size():
		var contract_id: String = CONTRACT_IDS[offset]
		var pool: Array = POOLS[contract_id]
		var template: Dictionary = pool[posmod(game.day - 1 + offset, pool.size())]
		var difficulty := mini((game.day - 1) / 4, 4)
		result.append({
			"id":contract_id,
			"item":template.item,
			"amount":int(template.amount) + difficulty,
			"coins":int(template.coins) + maxi(game.day - 1, 0) * 2,
			"xp":int(template.xp) + difficulty * 2,
		})
	return result


## Возвращает текущий ранг репутации по числу выполненных заказов.
static func guild_rank(game: Node) -> int:
	return clampi(game.state.contracts.completed_total / CONTRACTS_PER_RANK, 0, MAX_GUILD_RANK)


## Возвращает число заказов до следующего ранга или ноль на максимуме.
static func contracts_to_next_rank(game: Node) -> int:
	if guild_rank(game) >= MAX_GUILD_RANK:
		return 0
	return CONTRACTS_PER_RANK - game.state.contracts.completed_total % CONTRACTS_PER_RANK


## Открывает доску ежедневных заказов только внутри гильдии.
static func open(game: Node) -> bool:
	if game.current_location != "guild_interior":
		return false
	game.state.contracts.ensure_day(game.day)
	game.state.contracts.board_open = true
	game.state.contracts.selected = 0
	game.clear_movement_keys()
	game.message = game.LocaleSystem.text("contracts_opened", [game.day])
	game.notify_tutorial("contract_board")
	return true


## Принимает доступный заказ либо сдаёт активный заказ с проверкой предметов.
static func act_selected(game: Node) -> bool:
	var daily := offers(game)
	var index := clampi(game.state.contracts.selected, 0, daily.size() - 1)
	var contract: Dictionary = daily[index]
	var status: String = game.state.contracts.status(contract.id)
	if status == "available":
		game.state.contracts.set_status(contract.id, "active")
		game.message = game.LocaleSystem.text("contract_accepted", [game.LocaleSystem.ui("contract_%s" % contract.id)])
		game.play_sfx("quest_accept")
		game.notify_tutorial("contract_accept")
		return true
	if status == "completed":
		game.message = game.LocaleSystem.text("contract_already_done")
		return false
	var current: int = game.inventory_item_count(contract.item)
	if current < contract.amount:
		game.message = game.LocaleSystem.text("contract_need", [game.inventory_item_name(contract.item), current, contract.amount])
		return false
	var previous_rank := guild_rank(game)
	game.change_inventory_count(contract.item, -contract.amount)
	game.coins += contract.coins
	game.award_xp(contract.xp)
	game.SkillSystem.award_profession_xp(game, PROFESSION_BY_ID[contract.id], 8)
	game.state.contracts.set_status(contract.id, "completed")
	game.state.contracts.completed_total += 1
	game.message = game.LocaleSystem.text("contract_completed", [contract.coins, contract.xp])
	game.play_sfx("quest_complete")
	game.notify_tutorial("contract_complete")
	var new_rank := guild_rank(game)
	if new_rank > previous_rank:
		game.coins += new_rank * 25
		if previous_rank == 0 and game.inventory_item_count("guild_badge") == 0:
			game.change_inventory_count("guild_badge", 1)
		game.message = game.LocaleSystem.text("guild_rank_up", [new_rank, new_rank * 25])
		game.play_sfx("level_up")
		game.notify_tutorial("guild_rank")
	return true


## Возвращает локализованную строку текущего состояния заказа для интерфейса.
static func status_text(game: Node, contract_id: String) -> String:
	return game.LocaleSystem.ui("contract_status_%s" % game.state.contracts.status(contract_id))
