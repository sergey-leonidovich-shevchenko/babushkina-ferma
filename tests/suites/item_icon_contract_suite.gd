extends "res://tests/suites/suite_base.gd"

const Alchemy := preload("res://scripts/presentation/alchemy_icon_system.gd")
const Furnace := preload("res://scripts/systems/furnace_data.gd")

## Проверяет общий контракт рисунка, окраски, выбранных замен и независимости возвращённых пакетов.
func run() -> void:
	test_full_registry_and_tints()
	test_selected_replacement_overrides_specialized_shapes()

## Сценарий: один каталог обслуживает рюкзак, шкаф, рецепты, Wiki и визуальный аудит.
## Исходное состояние: все предметы загружены, сырьё имеет цвет, неизвестный вид не зарегистрирован.
## Ожидаемый результат: каждый рисунок существует, сохранены цвета и поведение старых окон, пакеты не мутируют кеш.
func test_full_registry_and_tints() -> void:
	var game:=make_game()
	for kind in game.InventorySystem.ITEM_DATA:
		var visual:Dictionary=game.VisualAssetSystem.item_visual(kind)
		expect(visual.texture!=null and visual.texture.get_width()>0 and visual.texture.get_height()>0,"shared final icon exists: "+kind)
	for kind in ["field_mint","moon_grass_powder","valerian_dried"]:
		var visual:Dictionary=game.VisualAssetSystem.item_visual(kind)
		expect(visual.tint==Alchemy.tint(kind) and visual.provider=="alchemy" and not visual.square,"actual alchemy color and sizing survive the shared contract: "+kind)
	var ore:Dictionary=game.VisualAssetSystem.item_visual("iron_ore")
	expect(ore.tint==Color(Furnace.ITEMS.iron_ore.tint).lerp(Color.WHITE,0.3),"ore keeps its actual in-game modulation in exported previews")
	ore.tint=Color.RED; expect(game.VisualAssetSystem.item_visual("iron_ore").tint!=Color.RED,"caller cannot mutate the cached visual packet")
	expect(game.VisualAssetSystem.item_visual("wood_beam").provider=="workshop" and game.VisualAssetSystem.item_visual("glass_shard").provider=="research","specialized material precedence stays stable")
	expect(game.VisualAssetSystem.item_visual("not_a_registered_item").texture==null,"unknown icon retains the existing fallback path")
	game.free()

## Сценарий: выбранный PNG заменяет векторную заготовку во всех потребителях, затем замена отменяется.
## Исходное состояние: мята использует общий растительный спрайт с окраской, каталог замен временно дополнен.
## Ожидаемый результат: выбранный ресурс имеет приоритет и белую модуляцию; повторная загрузка восстанавливает исходник.
func test_selected_replacement_overrides_specialized_shapes() -> void:
	var game:=make_game(); var assets=game.VisualAssetSystem
	var original:Dictionary=assets.item_visual("field_mint")
	var replacements:Dictionary=assets.ITEM_ICON_OVERRIDES.duplicate()
	replacements["field_mint"]="res://assets/game/items/catalog/milk.png"
	assets.initialize_item_icons(game.InventorySystem.ITEM_DATA.keys(),replacements)
	var selected:Dictionary=assets.item_visual("field_mint")
	expect(selected.provider=="override" and selected.texture.resource_path.ends_with("/milk.png") and selected.tint==Color.WHITE,"explicit approved replacement bypasses old shape and old tint")
	assets.initialize_item_icons(game.InventorySystem.ITEM_DATA.keys())
	var restored:Dictionary=assets.item_visual("field_mint")
	expect(restored.provider=="alchemy" and restored.texture==original.texture and restored.tint==original.tint,"cache reset restores all original presentation fields")
	for kind in assets.ITEM_ICON_OVERRIDES: expect(ResourceLoader.exists(assets.ITEM_ICON_OVERRIDES[kind]),"every declared permanent icon replacement exists: "+kind)
	game.free()
