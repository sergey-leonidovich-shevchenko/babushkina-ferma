extends RefCounted

const PRODUCTS := [
	{"kind": "seeds", "amount": 4, "buy": 5, "sell": 0, "icon": Rect2(0, 55, 36, 45)},
	{"kind": "carrot", "buy": 10, "sell": 8, "icon": Rect2(34, 112, 30, 28)},
	{"kind": "berries", "buy": 0, "sell": 4, "forage": true},
	{"kind": "mushroom", "buy": 0, "sell": 7, "forage": true},
	{"kind": "watermelon", "buy": 0, "sell": 10, "forage": true},
	{"kind": "apple", "buy": 0, "sell": 12, "forage": true},
	{"kind": "nut", "buy": 0, "sell": 22, "forage": true},
]


static func default_products() -> Array:
	return PRODUCTS.duplicate(true)

static func buy(game: Node, product_index: int) -> bool:
	if product_index < 0 or product_index >= game.shop_products.size():
		return false
	var product: Dictionary = game.shop_products[product_index]
	if product.buy <= 0:
		game.message = game.LocaleSystem.text("shop_buy_only")
		return false
	if game.coins < product.buy:
		game.message = game.LocaleSystem.text("no_coins")
		return false
	game.coins -= product.buy
	game.change_inventory_count(product.kind, product.get("amount", 1))
	game.message = game.LocaleSystem.text("bought", [game.inventory_item_name(product.kind)])
	game.notify_tutorial("trade")
	return true

static func sell(game: Node, product_index: int) -> bool:
	if product_index < 0 or product_index >= game.shop_products.size():
		return false
	var product: Dictionary = game.shop_products[product_index]
	if product.sell <= 0:
		game.message = game.LocaleSystem.text("shop_sell_only")
		return false
	if not game.change_inventory_count(product.kind, -1):
		game.message = game.LocaleSystem.text("no_product")
		return false
	game.coins += product.sell
	game.message = game.LocaleSystem.text("sold", [game.inventory_item_name(product.kind), product.sell])
	game.notify_tutorial("trade")
	if product.get("forage", false):
		game.notify_tutorial("forage_sale")
	return true
