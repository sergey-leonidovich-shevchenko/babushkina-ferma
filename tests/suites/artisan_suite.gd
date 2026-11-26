# The test fixture uses the dynamic game scene and existing recipe dictionaries.
@warning_ignore_start(
	"unsafe_call_argument",
	"unsafe_method_access",
	"unsafe_property_access",
	"unsafe_cast",
	"untyped_declaration"
)
extends "res://tests/suites/artisan_production_cases.gd"

const Art := preload("res://scripts/presentation/basement_visual_system.gd")
const Alchemy := preload("res://scripts/systems/alchemy_system.gd")
const Visual := preload("res://scripts/presentation/artisan_visual_system.gd")


## Проверяет построенные мастерские, все новые партии, оплату, топливо, уровни, сохранения и
## нарезку.
func run() -> void:
	test_catalog_and_locales()
	test_all_stations_and_production_recipes()
	test_atomic_queue_pause_and_isolation()
	test_upgrade_paid_queue_and_salvage()
	test_canonical_save_and_invalid_jobs()
	test_original_sprite_regions()
	test_new_alchemy_routes()


## Сценарий: все новые продукты имеют честные нулевые запасы, торговую цену и переводы.
## Исходное состояние: новая игра без бесплатных построенных мастерских.
## Ожидаемый результат: зарегистрированы 8 станков, 41 предмет, 64 партии и 8 алхимических
## вариантов на шести языках.
func test_catalog_and_locales() -> void:
	var game := make_game()
	expect(
		(
			Artisan.STATIONS.size() == 8
			and Artisan.ITEMS.size() == 41
			and Recipes.RECIPES.size() == 72
		),
		"reviewed expansion has complete coherent catalogs"
	)
	for kind in Artisan.ITEMS:
		expect(
			game.inventory_item_count(kind) == 0 and game.InventorySystem.ITEM_DATA.has(kind),
			"no free artisan output: " + kind
		)
		expect(game.VisualAssetSystem.has_item_icon(kind), "cached standalone icon: " + kind)
		expect(
			game.ShopSystem.PRODUCTS.any(func(value): return value.kind == kind),
			"artisan product can be sold: " + kind
		)
	for locale in game.LocaleSystem.LOCALES:
		game.LocaleSystem.current = locale
		for kind in Artisan.ITEMS:
			expect(
				game.LocaleSystem.item(kind) != kind,
				"localized artisan item: " + locale + " " + kind
			)
		for kind in Artisan.STATIONS:
			expect(
				(
					game.LocaleSystem.ui(kind + "_title", [3]) != kind + "_title"
					and game.LocaleSystem.tutorial(kind) != kind
				),
				"localized station and teaching: " + locale + " " + kind
			)
	for kind in Artisan.STATIONS:
		game.open_crafting(kind)
		expect(
			not game.crafting_open and Workshop.state(game, kind).is_empty(),
			"private workshop cannot be opened or created remotely: " + kind
		)
	game.free()


## Сценарий: сохранение сохраняет оплаченные очереди, не принимает сокращённую длительность или
## подмену сырья.
## Исходное состояние: готовый пресс третьего уровня с наполовину выполненной партией.
## Ожидаемый результат: JSON восстанавливается без повторной оплаты и выдачи, некорректные
## документы отбрасываются до изменения игры.
func test_canonical_save_and_invalid_jobs() -> void:
	var game := make_game()
	enter(game)
	var item := place(game, "fruit_press", 25, 18)
	finish(game, item)
	upgrade_to(game, item, 3)
	open_station(game, item)
	var recipe: Dictionary = Workshop.Data.Recipes.recipe("artisan:fruit_press:apple_juice")
	for kind in recipe.inputs:
		game.change_inventory_count(kind, int(recipe.inputs[kind]))
	Workshop.enqueue(game, recipe)
	Workshop.advance(game, "fruit_press", item.production, 2)
	var snapshot: Dictionary = game.SaveSystem.snapshot(game)
	var parsed: Dictionary = JSON.parse_string(JSON.stringify(snapshot))
	expect(
		game.SaveSystem.ValidationSystem.valid(parsed),
		"JSON numbers validate for actual artisan construction and queue"
	)
	var restored := make_game()
	game.SaveSystem.apply(restored, parsed)
	var loaded: Dictionary = Basement.state(restored).objects[0].production.queue[0]
	var saved: Dictionary = parsed.estate.expansion.basement.objects[0].production.queue[0]
	expect(
		(
			loaded.id == saved.id
			and is_equal_approx(loaded.duration, saved.duration)
			and is_equal_approx(loaded.remaining, saved.remaining)
			and restored.inventory_item_count("apple_juice") == 0
		),
		"paid artisan queue restored without early or duplicate output"
	)
	for kind in saved.paid:
		expect(
			int(loaded.paid[kind]) == int(saved.paid[kind]),
			"JSON payment normalized without changing amount: " + kind
		)
	var path := "user://artisan-queue-test.json"
	expect(
		game.SaveSystem.save_at(game, path) and game.SaveSystem.load_at(restored, path),
		"artisan queue survives actual atomic disk save and load"
	)
	for suffix in ["", ".tmp", ".bak"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path + suffix))
	var broken := parsed.duplicate(true)
	broken.estate.expansion.basement.objects[0].production.queue[0].duration = 0.01
	expect(
		not game.SaveSystem.ValidationSystem.valid(broken), "forged accelerated production rejected"
	)
	broken = parsed.duplicate(true)
	broken.estate.expansion.basement.objects[0].production.queue[0].paid.apple = 999
	expect(not game.SaveSystem.ValidationSystem.valid(broken), "forged dismantle refund rejected")
	Production.update(restored, 60)
	expect(restored.inventory_item_count("apple_juice") == 2, "loaded job finishes once")
	restored.free()
	game.free()


## Сценарий: новые спрайты действительно нарезаны на уровни, ракурсы, кучи и иконки.
## Исходное состояние: 169 ресурсов с исходной альфой и измеренными целыми регионами.
## Ожидаемый результат: регионы не включают соседей, основание и пропорции постоянны, старый
## задний слот использует передний рисунок.
func test_original_sprite_regions() -> void:
	for kind in Artisan.STATIONS:
		for tier in 4:
			for direction in 4:
				var texture := Art.texture(kind, tier + 1, direction, tier == 3)
				expect(
					(
						texture.filter_clip
						and texture.region.position == texture.region.position.floor()
						and texture.region.size == texture.region.size.floor()
					),
					"integer clipped sprite region: %s %d %d" % [kind, tier, direction]
				)
				expect(
					transparent_edge(texture.get_image()),
					"intact transparent sprite edge: %s %d %d" % [kind, tier, direction]
				)
				var item: Dictionary = {
					"kind": kind,
					"x": 25,
					"y": 18,
					"level": mini(tier + 1, 3),
					"direction": direction
				}
				var dest := Art.destination(item, tier == 3)
				expect(
					(
						is_equal_approx(dest.end.y, Basement.Layout.rect(item).end.y)
						and is_equal_approx(
							dest.size.x / dest.size.y, texture.region.size.x / texture.region.size.y
						)
					),
					"fixed ground pivot and proportional silhouette"
				)
			expect(
				(
					Art.texture(kind, tier + 1, 0, tier == 3)
					== Art.texture(kind, tier + 1, 2, tier == 3)
				),
				"legacy rear slot uses approved front art: " + kind
			)
	for kind in Visual.ITEMS:
		expect(
			transparent_edge(Visual.ITEMS[kind].get_image()),
			"intact standalone inventory icon: " + kind
		)


## Сценарий: изделия новых ремёсел участвуют в существующей алхимической прогрессии.
## Исходное состояние: публичная лаборатория, открытый талант и максимальный изученный ранг.
## Ожидаемый результат: восемь новых путей реально расходуют ингредиенты и дают канонические
## действующие препараты.
func test_new_alchemy_routes() -> void:
	var game := make_game()
	game.current_location = "cottage_interior"
	game.player = Alchemy.STATION
	game.talent_levels["craft_alchemy"] = 1
	Alchemy.state(game).xp = 1000
	for recipe in Recipes.RECIPES:
		if recipe.station != "alchemy":
			continue
		game.open_crafting("alchemy")
		for material in recipe.inputs:
			game.change_inventory_count(material, int(recipe.inputs[material]))
		var before: int = game.inventory_item_count(recipe.output)
		var index: int = game.CraftingSystem.RECIPES.find_custom(
			func(value): return value.get("id", "") == recipe.id
		)
		expect(
			(
				game.CraftingSystem.craft(game, index)
				and game.inventory_item_count(recipe.output) == before + int(recipe.count)
			),
			"artisan material enables actual alchemy: " + recipe.id
		)
	game.free()


## Проверяет край по видимой альфе, допуская только исходный шум до семи процентов непрозрачности.
func transparent_edge(image: Image) -> bool:
	for x in image.get_width():
		if image.get_pixel(x, 0).a >= 0.07 or image.get_pixel(x, image.get_height() - 1).a >= 0.07:
			return false
	for y in image.get_height():
		if image.get_pixel(0, y).a >= 0.07 or image.get_pixel(image.get_width() - 1, y).a >= 0.07:
			return false
	return true
