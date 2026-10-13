extends "res://tests/suites/suite_base.gd"

const Catalog := preload("res://assets/game/items/painted/catalog.gd")

## Проверяет все утверждённые сосуды и подсолнух в каноническом каталоге, не меняя игровые правила.
func run() -> void:
	test_approved_resources_have_complete_silhouettes()
	test_processing_forms_use_distinct_vessels()

## Сценарий: выбранный растровый набор заменяет процедурные прототипы с безопасными краями.
## Исходное состояние: полный игровой каталог и 85 компактных ресурсов утверждённой партии.
## Ожидаемый результат: каждый вид зарегистрирован, возвращает выбранный PNG без старой окраски и не обрезается.
func test_approved_resources_have_complete_silhouettes() -> void:
	var game:=make_game()
	for kind in Catalog.ITEMS:
		var visual:Dictionary=game.VisualAssetSystem.item_visual(kind)
		expect(game.InventorySystem.ITEM_DATA.has(kind) and visual.provider=="override" and visual.tint==Color.WHITE and visual.texture.resource_path==Catalog.ITEMS[kind],"approved raster has priority without prototype tint: "+kind)
		var pixels:Image=visual.texture.get_image(); var used:=pixels.get_used_rect()
		expect(pixels.get_size()==Vector2i(160,160) and used.has_area() and used.position.x>=6 and used.position.y>=6 and used.end.x<=154 and used.end.y<=154,"approved silhouette stays whole inside transparent margin: "+kind)
	game.free()

## Сценарий: форма обработки определяется разным сосудом, а хороший ботанический рисунок сохраняется.
## Исходное состояние: пустая тара, сок, настойка, эссенция, масло, бальзам и вода выбранного набора.
## Ожидаемый результат: восемь смысловых форм и целый подсолнух остаются отдельными ресурсами; травы и порошки не заменены флаконом.
func test_processing_forms_use_distinct_vessels() -> void:
	var mapping:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/game/items/painted/mapping.json"))
	var groups:={}
	for kind in ["glass_vial","herb_solvent","herb_oil","field_mint_juice","field_mint_tincture","vital_essence","life_balsam","distilled_water"]: groups[mapping[kind].master]=true
	expect(groups.size()==8 and mapping.glass_bottle.master=="bottle_empty" and mapping.glass_jar.master=="jar_empty","all eight alchemy vessel forms and empty crafting containers are distinct")
	expect(mapping.sunflower.master=="sunflower-proposal","selected complete sunflower is included in the runtime set")
	for kind in ["field_mint","moon_grass_powder","valerian_dried","honeycomb"]: expect(not Catalog.ITEMS.has(kind),"existing botanical and apiary imagery remains intact: "+kind)
