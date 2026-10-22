extends RefCounted

const Paper := preload("res://scripts/presentation/paper_theme_palette.gd")


## Отрисовывает три ежедневных заказа, прогресс репутации и награду гильдии.
static func draw(game: Node) -> void:
	game.draw_rect(Rect2(120, 70, 912, 520), Paper.EDGE)
	game.draw_rect(Rect2(136, 86, 880, 486), Paper.PANEL)
	game.draw_rect(Rect2(136, 86, 880, 74), Paper.INSET)
	game.draw_ui_string(game.UI_FONT, Vector2(176, 128), game.LocaleSystem.ui("contracts_title"), HORIZONTAL_ALIGNMENT_LEFT, 490, 27, Paper.TEXT)
	var rank: int = game.ContractSystem.guild_rank(game)
	var rank_text: String = game.LocaleSystem.ui("guild_rank_max", [rank]) if rank >= game.ContractSystem.MAX_GUILD_RANK else game.LocaleSystem.ui("guild_rank_progress", [rank, game.ContractSystem.contracts_to_next_rank(game)])
	game.draw_ui_string(game.UI_FONT, Vector2(650, 126), rank_text, HORIZONTAL_ALIGNMENT_RIGHT, 330, 15, Paper.MUTED)
	var offers: Array[Dictionary] = game.ContractSystem.offers(game)
	for index in offers.size():
		var contract: Dictionary = offers[index]
		var row := Rect2(154, 190 + index * 100, 844, 88)
		var selected: bool = index == game.contract_selected
		game.draw_rect(row, Paper.SELECTED if selected else Paper.INSET)
		game.draw_rect(row, Paper.EDGE, false, 2)
		game.draw_item_icon(contract.item, Rect2(row.position + Vector2(14, 18), Vector2(50, 50)))
		game.draw_ui_string(game.UI_FONT, row.position + Vector2(78, 27), game.LocaleSystem.ui("contract_%s" % contract.id), HORIZONTAL_ALIGNMENT_LEFT, 240, 17, Paper.TEXT)
		game.draw_ui_string(game.UI_FONT, row.position + Vector2(78, 55), game.LocaleSystem.ui("contract_objective", [game.inventory_item_name(contract.item), game.inventory_item_count(contract.item), contract.amount]), HORIZONTAL_ALIGNMENT_LEFT, 400, 14, Paper.MUTED)
		game.draw_ui_string(game.UI_FONT, row.position + Vector2(500, 31), game.LocaleSystem.ui("contract_reward", [contract.coins, contract.xp]), HORIZONTAL_ALIGNMENT_LEFT, 220, 14, Paper.ACCENT_TEXT)
		game.draw_ui_string(game.UI_FONT, row.position + Vector2(500, 60), game.ContractSystem.status_text(game, contract.id), HORIZONTAL_ALIGNMENT_LEFT, 220, 14, Paper.DANGER if game.state.contracts.status(contract.id) == "available" else Paper.ACCENT_TEXT)
	game.draw_item_icon("guild_badge", Rect2(166, 507, 38, 38))
	game.draw_ui_string(game.UI_FONT, Vector2(214, 531), game.LocaleSystem.ui("guild_badge_hint"), HORIZONTAL_ALIGNMENT_LEFT, 520, 13, Paper.MUTED)
	game.draw_ui_string(game.UI_FONT, Vector2(590, 535), game.LocaleSystem.ui("contracts_help"), HORIZONTAL_ALIGNMENT_RIGHT, 390, 13, Paper.MUTED)
