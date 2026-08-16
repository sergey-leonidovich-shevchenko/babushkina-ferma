extends "res://tests/suites/suite_base.gd"


## Запускает сценарии переработки древесины, пакетного производства, изделий и представления материалов.
func run() -> void:
	test_log_and_metal_become_processed_materials()
	test_processed_materials_unlock_useful_construction()
	test_batch_crafting_uses_every_complete_recipe_only()
	test_material_icons_localization_tutorial_and_save()


## Сценарий: верстак превращает два вида сырья в полуфабрикаты с фиксированным выходом партии.
## Исходное состояние: у героя одно бревно и одна единица металла, досок и гвоздей ещё нет.
## Ожидаемый результат: рецепты расходуют сырьё и выдают четыре доски и восемь гвоздей.
func test_log_and_metal_become_processed_materials() -> void:
	var game := make_game()
	game.change_inventory_count("log", 1)
	game.materials.metal = 1
	var plank_recipe: int = game.CraftingSystem.RECIPES.find_custom(func(recipe): return recipe.output == "plank")
	var nail_recipe: int = game.CraftingSystem.RECIPES.find_custom(func(recipe): return recipe.output == "nails")
	expect(game.CraftingSystem.craft(game, plank_recipe), "one log can be sawn at the workbench")
	expect(game.inventory_item_count("log") == 0 and game.inventory_item_count("plank") == 4, "sawing yields exactly four planks")
	expect(game.CraftingSystem.craft(game, nail_recipe), "one metal unit can be forged into nails")
	expect(game.materials.metal == 0 and game.inventory_item_count("nails") == 8, "forging yields exactly eight nails")
	expect(game.tutorial_events_completed.has("lumber_process"), "first processing recipe completes its dedicated tutorial step")
	game.free()


## Сценарий: строительный предмет требует обработанные материалы, а не исходное дерево и металл.
## Исходное состояние: сначала выдан старый набор сырья, затем точный комплект досок и гвоздей для сундука.
## Ожидаемый результат: сырьё не подходит, а обработанный комплект устанавливает домашний сундук без остатка.
func test_processed_materials_unlock_useful_construction() -> void:
	var game := make_game()
	var recipe_index: int = game.CraftingSystem.RECIPES.find_custom(func(recipe): return recipe.output == "home_chest")
	game.wood = 20
	game.materials.metal = 10
	expect(not game.CraftingSystem.can_craft(game, game.CraftingSystem.RECIPES[recipe_index]), "raw wood and metal no longer bypass the production chain")
	game.change_inventory_count("plank", 8)
	game.change_inventory_count("nails", 6)
	expect(game.CraftingSystem.max_craftable(game, game.CraftingSystem.RECIPES[recipe_index]) == 1, "unique home chest caps batch crafting at one installation")
	expect(game.CraftingSystem.craft(game, recipe_index), "processed construction set assembles a home chest")
	expect(game.home_chest_owned and game.inventory_item_count("plank") == 0 and game.inventory_item_count("nails") == 0, "construction consumes exact materials and installs the unique chest")
	game.free()


## Сценарий: ускоренный крафт создаёт максимум полных партий и никогда не уводит материалы в минус.
## Исходное состояние: в рюкзаке три бревна, выбран рецепт распила одного бревна в четыре доски.
## Ожидаемый результат: максимум равен трём, три операции дают двенадцать досок, четвёртая невозможна.
func test_batch_crafting_uses_every_complete_recipe_only() -> void:
	var game := make_game()
	game.change_inventory_count("log", 3)
	var recipe_index: int = game.CraftingSystem.RECIPES.find_custom(func(recipe): return recipe.output == "plank")
	var recipe: Dictionary = game.CraftingSystem.RECIPES[recipe_index]
	expect(game.CraftingSystem.max_craftable(game, recipe) == 3, "batch calculator counts complete recipes")
	expect(game.CraftingSystem.craft_many(game, recipe_index, 99) == 3, "batch crafting stops after the third available log")
	expect(game.inventory_item_count("log") == 0 and game.inventory_item_count("plank") == 12, "three sawing batches preserve the four-to-one output ratio")
	expect(game.CraftingSystem.max_craftable(game, recipe) == 0, "empty raw-material stack reports no further batches")
	game.free()


## Сценарий: новые материалы полностью включены в визуальный, языковой, обучающий и сохраняемый каталоги.
## Исходное состояние: новая игра последовательно переключается на шесть языков и сохраняет обработанные запасы.
## Ожидаемый результат: три отдельные иконки доступны, названия переведены, а количества переживают загрузку.
func test_material_icons_localization_tutorial_and_save() -> void:
	var game := make_game()
	for kind in ["log", "plank", "nails"]:
		expect(game.VisualAssetSystem.item_texture(kind) != null, "processed material has a dedicated icon: %s" % kind)
	for locale in game.LocaleSystem.LOCALES:
		game.LocaleSystem.current = locale
		expect(game.LocaleSystem.item("log") != "log" and game.LocaleSystem.item("plank") != "plank" and game.LocaleSystem.item("nails") != "nails", "material names are localized for %s" % locale)
		expect(game.LocaleSystem.tutorial("lumber_process") != "lumber_process", "processing tutorial is localized for %s" % locale)
	game.LocaleSystem.current = "ru"
	game.change_inventory_count("plank", 7)
	game.change_inventory_count("nails", 11)
	var snapshot: Dictionary = game.SaveSystem.snapshot(game)
	var restored := make_game()
	expect(restored.SaveSystem.apply(restored, snapshot), "save accepts the expanded material catalog")
	expect(restored.inventory_item_count("plank") == 7 and restored.inventory_item_count("nails") == 11, "processed material counts survive save roundtrip")
	game.free()
	restored.free()
