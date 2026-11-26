# The test fixture uses the dynamic game scene and existing recipe dictionaries.
@warning_ignore_start(
	"unsafe_call_argument",
	"unsafe_method_access",
	"unsafe_property_access",
	"unsafe_cast",
	"untyped_declaration"
)
extends "res://tests/suites/basement_suite.gd"

const Artisan := preload("res://scripts/systems/artisan_data.gd")
const Recipes := preload("res://scripts/systems/artisan_recipe_data.gd")
const Workshop := preload("res://scripts/systems/workshop_system.gd")
const ArtisanFx := preload("res://scripts/presentation/artisan_fx_renderer.gd")


## Улучшает оплаченный станок настоящим удержанием с восстановлением энергии только между
## рабочими секундами стенда.
func upgrade_to(game: Node, item: Dictionary, target: int) -> void:
	while int(item.level) < target:
		game.crafting_open = false
		game.player = Basement.Data.BOARD
		Basement.open(game)
		var cost := Basement.Data.upgrade_cost(item.kind, int(item.level))
		game.coins += int(cost.coins)
		for kind in cost.inputs:
			game.change_inventory_count(kind, int(cost.inputs[kind]))
		expect(Build.upgrade(game, int(item.id)), "blueprint reserves upgrade: " + item.kind)
		game.player = Basement.Layout.center(Basement.Layout.approach_cell(item))
		Stations.interact(game, int(item.id))
		for _second in int(item.duration):
			game.energy = 12
			Build.update_hold(game, 1)
		expect(
			item.phase == "ready" and int(item.production.level) == int(item.level),
			"hold work finishes local upgrade: " + item.kind
		)


## Открывает единственную рабочую сторону реального построенного экземпляра.
func open_station(game: Node, item: Dictionary) -> void:
	game.current_location = Basement.Data.LOCATION
	game.player = Basement.Layout.center(Basement.Layout.approach_cell(item))
	expect(
		Stations.interact(game, int(item.id)) and game.crafting_station == item.kind,
		"normal context opens artisan instance: " + item.kind
	)
	game.energy = 12


## Сценарий: каждая новая технология исполняется на построенном станке после последовательных
## улучшений.
## Исходное состояние: восемь оплаченных экземпляров, три уровня, материалы выдаются только на
## проверяемую партию.
## Ожидаемый результат: уровни ограничивают доступ, вход списывается сразу, выход и побочные
## продукты приходят один раз позже.
func test_all_stations_and_production_recipes() -> void:
	var game := make_game()
	enter(game)
	var index := 0
	for station_kind in Artisan.STATIONS:
		var item := place(
			game,
			station_kind,
			25 + (index % 4) * 14,
			16 + (index / 4) * 14,
			preload("res://scripts/systems/furniture_facing_system.gd").SELECTABLE[index % 3]
		)
		finish(game, item)
		index += 1
		open_station(game, item)
		var tier_three: Array = Recipes.RECIPES.filter(
			func(value): return value.station == station_kind and int(value.workshop_level) == 3
		)
		var high: Dictionary = tier_three[0]
		expect(
			not Workshop.reason(game, high).is_empty(),
			"tier one cannot produce advanced goods: " + station_kind
		)
		upgrade_to(game, item, 3)
		if station_kind == "candlebench":
			expect(
				int(Build.salvage(item).ceramic_shard) == 2,
				"porcelain and bowl parts become ceramic shards on dismantle"
			)
		if station_kind == "gardenbench":
			expect(
				int(Build.salvage(item).compost) == 2,
				"organic upgrade leftovers return to the compost chain"
			)
		for recipe in Recipes.RECIPES:
			if recipe.station != station_kind:
				continue
			open_station(game, item)
			for material in recipe.inputs:
				game.change_inventory_count(material, int(recipe.inputs[material]))
			var before: Dictionary = game.export_inventory_counts().duplicate()
			var energy_before: float = game.energy
			var recipe_index: int = game.CraftingSystem.RECIPES.find_custom(
				func(value): return value.get("id", "") == recipe.id
			)
			expect(
				recipe_index >= 0 and game.CraftingSystem.craft(game, recipe_index),
				"actual recipe can be queued: " + recipe.id
			)
			expect(
				(
					is_equal_approx(game.energy, energy_before - float(recipe.energy))
					and (
						game.inventory_item_count(recipe.output)
						== int(before.get(recipe.output, 0))
					)
				),
				"energy paid now and output deferred: " + recipe.id
			)
			for material in recipe.inputs:
				expect(
					(
						game.inventory_item_count(material)
						== int(before.get(material, 0)) - int(recipe.inputs[material])
					),
					"exact production input: " + recipe.id + " " + material
				)
			if Workshop.thermal(station_kind):
				item.production.fuel = "charcoal"
				game.change_inventory_count("charcoal", 1)
				expect(Workshop.load_fuel(game), "clean fuel loads the smoker")
			game.crafting_open = false
			Workshop.advance(game, station_kind, item.production, 60)
			expect(
				(
					item.production.queue.is_empty()
					and (
						game.inventory_item_count(recipe.output)
						== int(before.get(recipe.output, 0)) + int(recipe.count)
					)
				),
				"exact completed batch: " + recipe.id
			)
			for material in recipe.get("byproducts", {}):
				expect(
					(
						game.inventory_item_count(material)
						== int(before.get(material, 0)) + int(recipe.byproducts[material])
					),
					"exact useful byproduct: " + recipe.id
				)
			var completed: int = item.production.completed
			Workshop.advance(game, station_kind, item.production, 60)
			expect(
				int(item.production.completed) == completed,
				"no repeated batch completion: " + recipe.id
			)
	expect(
		not game.state.world.estate.expansion.get("workshops", {}).keys().any(
			func(value): return Artisan.STATIONS.has(value)
		),
		"no hidden public duplicates for cellar-only workshops"
	)
	game.free()


## Сценарий: неудачная постановка ничего не списывает, а рюкзак останавливает оплаченный станок.
## Исходное состояние: два пресса первого уровня, одна оплаченная партия и недостаток энергии
## или сырья.
## Ожидаемый результат: полная очередь, неверная рабочая сторона и удалённый доступ
## отклоняются; время и выход не дублируются.
func test_atomic_queue_pause_and_isolation() -> void:
	var game := make_game()
	enter(game)
	var left := place(game, "fruit_press", 25, 18)
	finish(game, left)
	var right := place(game, "fruit_press", 42, 18)
	finish(game, right)
	open_station(game, left)
	var recipe: Dictionary = Workshop.Data.Recipes.recipe("artisan:fruit_press:apple_juice")
	var before: Dictionary = game.export_inventory_counts().duplicate()
	expect(
		not Workshop.enqueue(game, recipe) and before == game.export_inventory_counts(),
		"missing ingredients are atomic"
	)
	for kind in recipe.inputs:
		game.change_inventory_count(kind, int(recipe.inputs[kind]) * 2)
	game.energy = 0
	before = game.export_inventory_counts().duplicate()
	expect(
		not Workshop.enqueue(game, recipe) and before == game.export_inventory_counts(),
		"missing energy preserves all input"
	)
	game.energy = 12
	expect(Workshop.enqueue(game, recipe), "funded batch accepted")
	before = game.export_inventory_counts().duplicate()
	expect(
		not Workshop.enqueue(game, recipe) and before == game.export_inventory_counts(),
		"full queue never charges second batch"
	)
	var remaining: float = left.production.queue[0].remaining
	game.crafting_open = false
	game.inventory_open = true
	game._process(1)
	expect(
		is_equal_approx(left.production.queue[0].remaining, remaining),
		"backpack freezes actual artisan production"
	)
	game.inventory_open = false
	open_station(game, right)
	expect(
		right.production.queue.is_empty() and left.production.queue.size() == 1,
		"selected same-kind station owns separate queue"
	)
	game.player += Vector2(60, 0)
	before = game.export_inventory_counts().duplicate()
	expect(
		not Workshop.enqueue(game, recipe) and before == game.export_inventory_counts(),
		"wrong side cannot enqueue"
	)
	game.current_location = "forest"
	Production.update(game, 1)
	expect(
		(
			is_equal_approx(left.production.queue[0].remaining, remaining - 1)
			and right.production.queue.is_empty()
		),
		"paid work progresses exactly once outside its room"
	)
	game.free()


## Сценарий: тепло не тратится при простое, очередь ускоряется после сборки улучшения, демонтаж
## возвращает незавершённое сырьё.
## Исходное состояние: два отдельных коптильных шкафа и одна рыба в очереди.
## Ожидаемый результат: запрещены мусор и уголь, нехватка жара останавливает партию, доля
## готовности и полная оплата сохранены.
func test_upgrade_paid_queue_and_salvage() -> void:
	var game := make_game()
	enter(game)
	var item := place(game, "smoker", 25, 18)
	finish(game, item)
	var other := place(game, "smoker", 42, 18)
	finish(game, other)
	open_station(game, item)
	item.production.fuel = "trash"
	game.change_inventory_count("trash", 1)
	expect(
		not Workshop.load_fuel(game) and game.inventory_item_count("trash") == 1,
		"food smoker rejects dirty fuel"
	)
	item.production.fuel = "wood"
	game.change_inventory_count("wood", 1)
	expect(Workshop.load_fuel(game), "wood heats local smoker")
	expect(not ArtisanFx.working(item), "idle smoker has no animated smoke")
	var heat: float = item.production.heat
	Workshop.advance(game, "smoker", item.production, 30)
	expect(item.production.heat == heat and other.production.heat == 0, "idle heat stays local")
	var recipe: Dictionary = Workshop.Data.Recipes.recipe("artisan:smoker:smoked_fish")
	game.change_inventory_count("fish", 2)
	expect(Workshop.enqueue(game, recipe), "smoking batch paid")
	expect(ArtisanFx.working(item), "only fueled paid smoking emits animation")
	Workshop.advance(game, "smoker", item.production, 1)
	var fraction: float = item.production.queue[0].remaining / item.production.queue[0].duration
	upgrade_to(game, item, 2)
	expect(
		is_equal_approx(
			item.production.queue[0].remaining / item.production.queue[0].duration, fraction
		),
		"upgrade preserves completed share and only changes speed"
	)
	item.production.heat = 0.25
	var remaining: float = item.production.queue[0].remaining
	Workshop.advance(game, "smoker", item.production, 5)
	expect(
		(
			is_zero_approx(item.production.heat)
			and is_equal_approx(item.production.queue[0].remaining, remaining - 0.3125)
		),
		"heat exhausts at fractional working instant"
	)
	expect(not ArtisanFx.working(item), "exhausted smoker stops animated smoke")
	Workshop.advance(game, "smoker", item.production, 10)
	expect(
		is_equal_approx(item.production.queue[0].remaining, remaining - 0.3125),
		"cold smoker waits without completing"
	)
	game.crafting_open = false
	game.player = Basement.Data.BOARD
	Basement.open(game)
	var returned := Build.salvage(item)
	expect(int(returned.fish) == 2, "dismantle returns all unfinished batch input")
	var before: Dictionary = game.export_inventory_counts().duplicate()
	expect(Build.dismantle(game, int(item.id)), "blueprint dismantles chosen smoker")
	for kind in returned:
		expect(
			game.inventory_item_count(kind) == int(before.get(kind, 0)) + int(returned[kind]),
			"exact returned components and typed debris: " + kind
		)
	expect(
		Basement.object(game, int(other.id)).size() > 0 and other.production.queue.is_empty(),
		"neighbor survives dismantling"
	)
	var leatherbench := place(game, "tannery", 58, 18)
	finish(game, leatherbench)
	upgrade_to(game, leatherbench, 3)
	var leather_return := Build.salvage(leatherbench)
	expect(
		(
			int(leather_return.leather) == 2
			and int(leather_return.cloth_scrap) == 2
			and int(leather_return.ceramic_shard) == 2
		),
		"paid leather returns half plus cloth scraps, tanning pots yield ceramic debris"
	)
	game.free()
