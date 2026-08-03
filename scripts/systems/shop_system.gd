extends RefCounted

const PRODUCTS := [
	{"kind": "seeds", "amount": 4, "buy": 5, "sell": 0, "icon": Rect2(0, 55, 36, 45)},
	{"kind": "carrot", "buy": 10, "sell": 8, "icon": Rect2(34, 112, 30, 28)},
	{"kind": "berries", "buy": 0, "sell": 4, "forage": true},
	{"kind": "mushroom", "buy": 0, "sell": 7, "forage": true},
	{"kind": "watermelon", "buy": 0, "sell": 10, "forage": true},
	{"kind": "apple", "buy": 0, "sell": 12, "forage": true},
	{"kind": "nut", "buy": 0, "sell": 22, "forage": true},
	{"kind": "arrows", "amount": 10, "buy": 8, "sell": 1},
	{"kind": "home_chest", "buy": 120, "sell": 0},
]


## Возвращает рассчитанное методом значение в безопасном для вызывающего кода виде.
static func default_products() -> Array:
	return PRODUCTS.duplicate(true)

## Выполняет операцию «покупки» и возвращает результат согласно контракту метода.
static func buy(game: Node, product_index: int) -> bool:
	if product_index < 0 or product_index >= game.shop_products.size():
		return false
	var product: Dictionary = game.shop_products[product_index]
	if product.kind == "home_chest" and game.home_chest_owned:
		game.message = game.LocaleSystem.text("chest_already_owned")
		return false
	if product.buy <= 0:
		game.message = game.LocaleSystem.text("shop_buy_only")
		return false
	if game.coins < product.buy:
		game.message = game.LocaleSystem.text("no_coins")
		return false
	game.coins -= product.buy
	game.change_inventory_count(product.kind, product.get("amount", 1))
	if product.kind == "home_chest": game.StorageSystem.install(game)
	game.message = game.LocaleSystem.text("bought", [game.inventory_item_name(product.kind)])
	game.play_sfx("coin")
	game.notify_tutorial("trade")
	return true

## Выполняет операцию «продажи» и возвращает результат согласно контракту метода.
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
	var sale_price: int = roundi(float(product.sell) * game.EstateSystem.consume_sale_multiplier(game, product.kind))
	game.coins += sale_price
	game.message = game.LocaleSystem.text("sold", [game.inventory_item_name(product.kind), sale_price])
	game.play_sfx("coin")
	game.notify_tutorial("trade")
	if product.get("forage", false):
		game.notify_tutorial("forage_sale")
	return true
