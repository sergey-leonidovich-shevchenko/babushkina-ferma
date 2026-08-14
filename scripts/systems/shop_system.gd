extends RefCounted

const PRODUCTS := [
	{"kind": "seeds", "amount": 4, "buy": 5, "sell": 0, "seed": true, "icon": Rect2(0, 55, 36, 45)},
	{"kind": "carrot", "buy": 10, "sell": 8, "icon": Rect2(34, 112, 30, 28)},
	{"kind": "berries", "buy": 0, "sell": 4, "forage": true},
	{"kind": "mushroom", "buy": 0, "sell": 7, "forage": true},
	{"kind": "watermelon", "buy": 0, "sell": 10, "forage": true},
	{"kind": "apple", "buy": 0, "sell": 12, "forage": true},
	{"kind": "pear", "buy": 0, "sell": 15, "forage": true},
	{"kind": "cherry", "buy": 0, "sell": 18, "forage": true},
	{"kind": "plum", "buy": 0, "sell": 24, "forage": true},
	{"kind": "nut", "buy": 0, "sell": 22, "forage": true},
	{"kind": "arrows", "amount": 10, "buy": 8, "sell": 1},
	{"kind": "home_chest", "buy": 120, "sell": 0},
	{"kind": "backpack_upgrade", "buy": 120, "sell": 0},
	{"kind":"fence_kit","amount":8,"buy":24,"sell":1}, {"kind":"gate_kit","amount":1,"buy":30,"sell":8},
	{"kind":"tomato","buy":10,"sell":6}, {"kind":"cabbage","buy":14,"sell":8}, {"kind":"egg","buy":12,"sell":7}, {"kind":"milk","buy":18,"sell":10},
	{"kind":"wheat","buy":8,"sell":4}, {"kind":"corn","buy":12,"sell":7}, {"kind":"potato","buy":9,"sell":5}, {"kind":"onion","buy":9,"sell":5},
	{"kind":"cotton","buy":14,"sell":8}, {"kind":"flower","buy":0,"sell":7}, {"kind":"honey","buy":22,"sell":14}, {"kind":"pumpkin","buy":20,"sell":12}, {"kind":"wool","buy":25,"sell":15},
	{"kind":"cheese","buy":0,"sell":28}, {"kind":"rope","buy":0,"sell":12}, {"kind":"bread","buy":0,"sell":24}, {"kind":"pie","buy":0,"sell":42},
	{"kind":"flour","buy":0,"sell":12}, {"kind":"butter","buy":0,"sell":24}, {"kind":"jam","buy":0,"sell":32}, {"kind":"soup","buy":0,"sell":30},
	{"kind":"omelet","buy":0,"sell":34}, {"kind":"cornbread","buy":0,"sell":28}, {"kind":"bouquet","buy":0,"sell":36},
	{"kind":"tomato_seeds","amount":4,"buy":7,"sell":0,"seed":true}, {"kind":"cabbage_seeds","amount":4,"buy":8,"sell":0,"seed":true},
	{"kind":"wheat_seeds","amount":4,"buy":6,"sell":0,"seed":true}, {"kind":"corn_seeds","amount":4,"buy":8,"sell":0,"seed":true},
	{"kind":"potato_seeds","amount":4,"buy":7,"sell":0,"seed":true}, {"kind":"onion_seeds","amount":4,"buy":7,"sell":0,"seed":true},
	{"kind":"pumpkin_seeds","amount":4,"buy":12,"sell":0,"seed":true}, {"kind":"strawberry_seeds","amount":4,"buy":14,"sell":0,"seed":true},
	{"kind":"beet_seeds","amount":4,"buy":8,"sell":0,"seed":true}, {"kind":"pepper_seeds","amount":4,"buy":10,"sell":0,"seed":true},
	{"kind":"cucumber_seeds","amount":4,"buy":9,"sell":0,"seed":true}, {"kind":"sunflower_seeds","amount":4,"buy":10,"sell":0,"seed":true},
	{"kind":"cotton_seeds","amount":4,"buy":12,"sell":0,"seed":true}, {"kind":"melon_seeds","amount":4,"buy":15,"sell":0,"seed":true},
	{"kind":"herb_seeds","amount":4,"buy":18,"sell":0,"seed":true},
	{"kind":"strawberry","buy":0,"sell":18}, {"kind":"beet","buy":0,"sell":7}, {"kind":"pepper","buy":0,"sell":11},
	{"kind":"cucumber","buy":0,"sell":8}, {"kind":"sunflower","buy":0,"sell":12}, {"kind":"melon","buy":0,"sell":16}, {"kind":"herbs","buy":0,"sell":14},
	{"kind":"stone","buy":0,"sell":1}, {"kind":"fiber","buy":0,"sell":2}, {"kind":"bones","buy":0,"sell":3}, {"kind":"metal","buy":0,"sell":7},
	{"kind":"crystal","buy":0,"sell":12}, {"kind":"red_crystal","buy":0,"sell":16}, {"kind":"green_crystal","buy":0,"sell":16}, {"kind":"pirate_doubloon","buy":0,"sell":22},
]


## Возвращает рассчитанное методом значение в безопасном для вызывающего кода виде.
static func default_products() -> Array:
	return PRODUCTS.duplicate(true)

## Возвращает базовую цену продажи предмета или ноль для неторгуемого лута.
static func sell_price(kind: String) -> int:
	for product in PRODUCTS:
		if product.kind == kind: return int(product.sell)
	return 0

## Выполняет операцию «покупки» и возвращает результат согласно контракту метода.
static func buy(game: Node, product_index: int) -> bool:
	if product_index < 0 or product_index >= game.shop_products.size():
		return false
	var product: Dictionary = game.shop_products[product_index]
	refresh_stock(product, game.day)
	if int(product.get("stock", 0)) <= 0: game.message = "Сегодня товар закончился"; game.shop_products[product_index] = product; return false
	if product.kind == "home_chest" and game.home_chest_owned:
		game.message = game.LocaleSystem.text("chest_already_owned")
		return false
	if product.kind == "backpack_upgrade":
		if game.AdventurePolishSystem.upgrade_backpack(game):
			product.stock -= 1; game.shop_products[product_index] = product
			game.message = "Рюкзак расширен до %d ячеек" % game.state.inventory.capacity(); game.play_sfx("coin"); return true
		game.message = "Для расширения нужно больше монет или достигнут максимум"; return false
	if product.buy <= 0:
		game.message = game.LocaleSystem.text("shop_buy_only")
		return false
	var purchase_price: int = roundi(float(product.buy) * game.EstateSystem.purchase_multiplier(game))
	if game.coins < purchase_price:
		game.message = game.LocaleSystem.text("no_coins")
		return false
	game.coins -= purchase_price
	product.stock -= 1; game.shop_products[product_index] = product
	game.change_inventory_count(product.kind, product.get("amount", 1))
	if product.kind == "home_chest": game.StorageSystem.install(game)
	game.message = game.LocaleSystem.text("bought", [game.inventory_item_name(product.kind)])
	game.play_sfx("coin")
	game.notify_tutorial("trade")
	if product.get("seed", false): game.notify_tutorial("seed_catalog")
	return true


## Восстанавливает ограниченный дневной запас товара по стабильному правилу.
static func refresh_stock(product: Dictionary, day: int) -> void:
	if int(product.get("stock_day", 0)) == day: return
	product.stock_day = day
	product.stock = 8 if product.get("seed", false) else (1 if product.kind in ["home_chest", "backpack_upgrade"] else 4)

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
