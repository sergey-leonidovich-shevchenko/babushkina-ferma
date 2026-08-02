extends RefCounted

static func buy(game: Node, product_index: int) -> bool:
	if product_index < 0 or product_index >= game.shop_products.size():
		return false
	var product: Dictionary = game.shop_products[product_index]
	if product.buy <= 0:
		game.message = "Этот товар лавка только покупает"
		return false
	if game.coins < product.buy:
		game.message = "Не хватает монет"
		return false
	game.coins -= product.buy
	game.change_inventory_count(product.kind, product.get("amount", 1))
	game.message = "Куплено: %s" % product.name
	game.notify_tutorial("trade")
	return true

static func sell(game: Node, product_index: int) -> bool:
	if product_index < 0 or product_index >= game.shop_products.size():
		return false
	var product: Dictionary = game.shop_products[product_index]
	if product.sell <= 0:
		game.message = "Этот товар лавка не покупает"
		return false
	if not game.change_inventory_count(product.kind, -1):
		game.message = "У тебя нет этого товара"
		return false
	game.coins += product.sell
	game.message = "Продано: %s +%d монет" % [game.inventory_item_name(product.kind), product.sell]
	game.notify_tutorial("trade")
	if product.get("forage", false):
		game.notify_tutorial("forage_sale")
	return true
