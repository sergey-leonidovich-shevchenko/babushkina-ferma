extends RefCounted


## Отрисовывает три ежедневных заказа, прогресс репутации и награду гильдии.
static func draw(game: Node) -> void:
	game.draw_rect(Rect2(120, 70, 912, 520), Color("182420"))
	game.draw_rect(Rect2(136, 86, 880, 486), Color("d8bf85"))
	game.draw_rect(Rect2(136, 86, 880, 74), Color("365548"))
	game.draw_ui_string(game.UI_FONT, Vector2(176, 128), game.LocaleSystem.ui("contracts_title"), HORIZONTAL_ALIGNMENT_LEFT, 490, 27, Color("fff1c4"))
	var rank: int = game.ContractSystem.guild_rank(game)
	var rank_text: String = game.LocaleSystem.ui("guild_rank_max", [rank]) if rank >= game.ContractSystem.MAX_GUILD_RANK else game.LocaleSystem.ui("guild_rank_progress", [rank, game.ContractSystem.contracts_to_next_rank(game)])
	game.draw_ui_string(game.UI_FONT, Vector2(650, 126), rank_text, HORIZONTAL_ALIGNMENT_RIGHT, 330, 15, Color("f4d477"))
	var offers: Array[Dictionary] = game.ContractSystem.offers(game)
	for index in offers.size():
		var contract: Dictionary = offers[index]
		var row := Rect2(154, 190 + index * 100, 844, 88)
		var selected: bool = index == game.contract_selected
		game.draw_rect(row, Color("efc766") if selected else Color("f4dfaa"))
		game.draw_rect(row, Color("76543c"), false, 2)
		game.draw_item_icon(contract.item, Rect2(row.position + Vector2(14, 18), Vector2(50, 50)))
		game.draw_ui_string(game.UI_FONT, row.position + Vector2(78, 27), game.LocaleSystem.ui("contract_%s" % contract.id), HORIZONTAL_ALIGNMENT_LEFT, 240, 17, Color("3d3428"))
		game.draw_ui_string(game.UI_FONT, row.position + Vector2(78, 55), game.LocaleSystem.ui("contract_objective", [game.inventory_item_name(contract.item), game.inventory_item_count(contract.item), contract.amount]), HORIZONTAL_ALIGNMENT_LEFT, 400, 14, Color("5c4936"))
		game.draw_ui_string(game.UI_FONT, row.position + Vector2(500, 31), game.LocaleSystem.ui("contract_reward", [contract.coins, contract.xp]), HORIZONTAL_ALIGNMENT_LEFT, 220, 14, Color("49704d"))
		game.draw_ui_string(game.UI_FONT, row.position + Vector2(500, 60), game.ContractSystem.status_text(game, contract.id), HORIZONTAL_ALIGNMENT_LEFT, 220, 14, Color("a34d45") if game.state.contracts.status(contract.id) == "available" else Color("49704d"))
	game.draw_item_icon("guild_badge", Rect2(166, 507, 38, 38))
	game.draw_ui_string(game.UI_FONT, Vector2(214, 531), game.LocaleSystem.ui("guild_badge_hint"), HORIZONTAL_ALIGNMENT_LEFT, 520, 13, Color("5c4936"))
	game.draw_ui_string(game.UI_FONT, Vector2(590, 535), game.LocaleSystem.ui("contracts_help"), HORIZONTAL_ALIGNMENT_RIGHT, 390, 13, Color("493b2f"))
