extends "res://tests/suites/suite_base.gd"

const Assets := preload("res://scripts/systems/visual_asset_system.gd")
const Prepared := preload("res://scripts/presentation/prepared_item_icon_system.gd")

## Проверяет загрузку оригиналов по запросу, сохраняя весь общий контракт изображений и выбранных замен.
func run() -> void:
	test_complete_ui_catalog_does_not_retain_original_pngs()
	test_original_request_and_custom_replacement_preserve_priority()
	test_missing_and_non_texture_sources_keep_fallback()

## Сценарий: весь каталог последовательно просматривается в маленьком и крупном экранном размерах.
## Исходное состояние: зарегистрированы все виды, оригиналы PNG ещё не запрошены через прежний API.
## Ожидаемый результат: оба размера и цвета правильны, ни один исходный PNG не загружен ради UI, кеш превью ограничен16.
func test_complete_ui_catalog_does_not_retain_original_pngs() -> void:
	var game:=make_game(); Assets.initialize_item_icons(game.InventorySystem.ITEM_DATA.keys())
	expect(Assets.item_cache_info().loaded_paths==0,"registering item sources loads none of their PNG originals")
	for kind in game.InventorySystem.ITEM_DATA:
		expect(Assets.has_item_icon(kind),"registered icon remains available without decoding it: "+kind)
		var small:=Assets.item_draw_visual(kind,40); var large:=Assets.item_draw_visual(kind,120)
		expect(small.texture!=null and small.texture.get_size()==Vector2(64,64) and large.texture.get_size()==Vector2(160,160) and small.tint==large.tint,"both prepared sizes retain the same item modulation: "+kind)
	expect(Assets.item_cache_info().loaded_paths==0,"viewing every thumbnail and preview does not retain original PNGs")
	expect(Prepared.cache_info().large<=16,"large UI previews retain the existing sixteen-item upper bound")
	for kind in game.InventorySystem.ITEM_DATA:
		var original:=Assets.item_visual(kind); var small:=Assets.item_draw_visual(kind,40)
		expect(original.texture!=null and small.tint==original.tint and small.provider==original.provider,"lazy metadata preserves the canonical source priority and tint: "+kind)
	Assets.initialize_item_icons(game.InventorySystem.ITEM_DATA.keys()); game.free()

## Сценарий: оружие либо Wiki явно запрашивает оригинал, затем выбрана нестандартная замена травы.
## Исходное состояние: каталог зарегистрирован, доски не загружены, мята имеет исходную окраску алхимии.
## Ожидаемый результат: оригинал загружается единожды, замена обходит неподходящие миниатюры и сброс восстанавливает прежний вид.
func test_original_request_and_custom_replacement_preserve_priority() -> void:
	var game:=make_game(); Assets.initialize_item_icons(game.InventorySystem.ITEM_DATA.keys())
	var texture:=Assets.item_texture("plank")
	expect(texture!=null and Assets.item_cache_info().loaded_paths==1 and Assets.item_texture("plank")==texture,"an explicit source request loads exactly that original and reuses it")
	var replacements:Dictionary=Assets.ITEM_ICON_OVERRIDES.duplicate(); replacements.field_mint="res://assets/game/items/catalog/milk.png"
	Assets.initialize_item_icons(game.InventorySystem.ITEM_DATA.keys(),replacements)
	var value:=Assets.item_draw_visual("field_mint",40)
	expect(value.provider=="override" and value.tint==Color.WHITE and value.texture.resource_path.ends_with("/milk.png"),"custom approved replacement bypasses incompatible prepared art and keeps white modulation")
	Assets.initialize_item_icons(game.InventorySystem.ITEM_DATA.keys())
	value=Assets.item_draw_visual("field_mint",40)
	expect(value.provider=="alchemy" and value.texture.get_size()==Vector2(64,64) and Assets.item_cache_info().loaded_paths==0,"reset restores canonical prepared art without retaining an old replacement")
	game.free()

## Сценарий: неизвестный вид не зарегистрирован, а вместо графики в выбранной замене ошибочно указан шрифт.
## Исходное состояние: обычный каталог и существующий Font, уже используемый интерфейсом.
## Ожидаемый результат: проверка доступности не принимает чужой тип за картинку, неизвестный вид сохраняет прежнюю пустую текстуру.
func test_missing_and_non_texture_sources_keep_fallback() -> void:
	var game:=make_game(); var replacements:Dictionary=Assets.ITEM_ICON_OVERRIDES.duplicate()
	replacements.field_mint="res://assets/game/fonts/ui_font.tres"
	Assets.initialize_item_icons(game.InventorySystem.ITEM_DATA.keys(),replacements)
	expect(not Assets.has_item_icon("field_mint"),"an existing font resource cannot masquerade as a registered item texture")
	var descriptors:int=Assets.item_cache_info().descriptors
	expect(not Assets.has_item_icon("not_registered") and Assets.item_draw_visual("not_registered",40).texture==null,"unknown items retain the existing missing-icon fallback")
	expect(Assets.item_cache_info().descriptors==descriptors,"unknown identifiers do not grow the prepared descriptor cache")
	Assets.initialize_item_icons(game.InventorySystem.ITEM_DATA.keys()); game.free()
