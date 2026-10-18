extends "res://tests/suites/suite_base.gd"

const Padded := preload("res://scripts/presentation/padded_atlas_system.gd")
const Prepared := preload("res://scripts/presentation/prepared_item_icon_system.gd")
const Sampling := preload("res://scripts/presentation/visual_sampling_system.gd")


## Проверяет масштаб, безопасную выборку, совместное владение и границы кеша миниатюр.
func run() -> void:
	test_levels_are_selected_from_destination_size()
	test_every_item_has_four_independent_frames()
	test_catalog_paths_and_cache_bounds_remain_safe()


## Сценарий: интерфейс рисует предмет между порогами размера и ниже самого малого подготовленного уровня.
## Исходное состояние: четыре страницы 64/32/16/8 и отсутствие аппаратных mipmaps.
## Ожидаемый результат: размер выбирается явно, меньше 8 остаётся последняя страница без соседнего кадра.
func test_levels_are_selected_from_destination_size() -> void:
	for pair in [[80,0],[64,0],[40,0],[32,1],[31,1],[16,2],[8,3],[4,3],[1,3]]:
		expect(Padded.level_for(pair[0])==pair[1],"explicit independent level at destination size: "+str(pair[0]))
	for value in [0,-1,INF,NAN]: expect(Padded.frame("bread",value)==null,"invalid destination does not allocate a page: "+str(value))
	expect(Padded.frame("missing",64)==null,"unknown item cannot select an unrelated atlas frame")
	Prepared.clear(); var frame := Padded.frame("bread",8); Prepared.cache_info()
	expect(frame!=null and Padded.cache_info().levels==[3],"small-frame request and cache diagnostics do not preload the full-size page")


## Сценарий: каждый предмет запрашивается на каждом поддержанном экранном уровне.
## Исходное состояние: действующий каталог предметов, реальные страницы и пустой кеш.
## Ожидаемый результат: каждый регион целиком внутри поля, страницы общие, источник не имеет аппаратных mipmaps.
func test_every_item_has_four_independent_frames() -> void:
	Prepared.clear()
	for level in 4:
		var row: Dictionary = Padded.DATA.data.levels[level]
		var previous: Texture2D
		for kind in row.entries:
			var frame := Padded.frame(kind,float(row.frame_size))
			expect(frame!=null and frame.get_size()==Vector2(row.frame_size,row.frame_size) and frame.filter_clip and Rect2(Vector2(2,2),frame.atlas.get_size()-Vector2(4,4)).encloses(frame.region),"all items retain an isolated region and exact dimensions: %s/%d"%[kind,level])
			if previous==null: previous=frame.atlas
			expect(frame.atlas==previous and frame.atlas.texture_filter==CanvasItem.TEXTURE_FILTER_LINEAR,"items share one explicit linear page per level: %s/%d"%[kind,level])
		var image: Image = previous.get_image()
		expect(not image.has_mipmaps(),"global hardware mip chain cannot mix frames: "+str(level))
	expect(Padded.cache_info().pages==4,"all item requests retain exactly four shared pages")


## Сценарий: весь каталог просматривается на четырёх размерах и с крупными превью.
## Исходное состояние: зарегистрированные источники и сохранённый приоритет визуальных пакетов.
## Ожидаемый результат: кадры кешируются, число ограничено каталогом; чужая страница и флаг готовности не допускаются.
func test_catalog_paths_and_cache_bounds_remain_safe() -> void:
	var game := make_game(); Prepared.clear()
	for kind in game.InventorySystem.ITEM_DATA:
		for size in [64,32,16,8]:
			var packet: Dictionary = game.VisualAssetSystem.item_draw_visual(kind,size)
			expect(packet.texture==game.VisualAssetSystem.item_draw_visual(kind,size).texture and packet.texture.get_size()==Vector2(size,size),"prepared packets reuse their frame without changing tint/provider: %s/%d"%[kind,size])
	expect(Prepared.cache_info().small<=game.InventorySystem.ITEM_DATA.size()*4 and Padded.cache_info().pages==4,"frame and page caches have hard catalog/level bounds")
	expect(Sampling.create(Prepared.ATLAS,"painted_atlas","padded_atlas")==null,"a caller cannot grant itself padded status through a layout string")
	expect(Sampling.padded_page(load("res://assets/game/items/ui/thumbnails.png"),0)==null,"legacy page is not accepted under the prepared page passport")
	expect(Sampling.padded_page(Prepared.ATLAS,3)==null,"wrong level cannot borrow another page's validated path")
	var before: int = Padded.cache_info().pages; Padded.frame("unknown",8)
	expect(Padded.cache_info().pages==before,"unknown identifiers never grow page caches")
	Prepared.clear(); expect(Padded.cache_info().pages==0 and Prepared.cache_info().small==0,"catalog reset releases shared wrappers and frame references")
	game.free()
