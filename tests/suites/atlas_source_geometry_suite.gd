extends "res://tests/suites/suite_base.gd"

const Assets:=preload("res://scripts/systems/visual_asset_system.gd")

## Проверяет целочисленное разбиение нечётного изображения и все реальные старые источники.
func run() -> void:
	test_odd_grid_covers_every_pixel_once()
	test_real_fallback_sources_are_integer_and_bounded()
	test_invalid_grid_has_no_source()

## Сценарий: изображение 17×13 разбивается на четыре столбца и три ряда.
## Исходное состояние: обе стороны не делятся на число ячеек, пиксели покрытия пусты.
## Ожидаемый результат: каждая область целочисленна и каждый пиксель покрыт ровно один раз.
func test_odd_grid_covers_every_pixel_once() -> void:
	var texture:=ImageTexture.create_from_image(Image.create(17,13,false,Image.FORMAT_RGBA8))
	var coverage:=PackedByteArray();coverage.resize(17*13)
	for row in 3:
		for column in 4:
			var source:Rect2=Assets.grid_source(texture,4,3,Vector2i(column,row))
			expect(source.has_area() and source.position==source.position.round() and source.size==source.size.round(),"odd grid has positive integer bounds")
			expect(Rect2(0,0,17,13).encloses(source),"odd grid never leaves original image")
			for y in range(int(source.position.y),int(source.end.y)):
				for x in range(int(source.position.x),int(source.end.x)):coverage[y*17+x]+=1
	for count in coverage:expect(count==1,"odd grid covers every original pixel once")
	expect(Assets.grid_source(texture,4,3,Vector2i(3,2)).end==Vector2(17,13),"last source includes final row and column")

## Сценарий: все пиратские семьи, предметы, зелья и инвентарные ячейки выбирают свой исходник.
## Исходное состояние: настоящие PNG 1254 и прежние совместимые каталоги доступны.
## Ожидаемый результат: регионы остаются в PNG, имеют целые координаты и не теряют пиксели по границе столбцов.
func test_real_fallback_sources_are_integer_and_bounded() -> void:
	for column in Assets.PIRATE_ENEMY_ORDER.size():
		var kind:String=Assets.PIRATE_ENEMY_ORDER[column]
		check_source(Assets.pirate_enemy_source(kind),Assets.PIRATE_ENEMY_ATLAS)
		if column==3:expect(Assets.pirate_enemy_source(kind).end.x==Assets.PIRATE_ENEMY_ATLAS.get_width(),"final pirate source keeps right edge")
	for kind in Assets.PIRATE_ITEM_CELLS:check_source(Assets.pirate_item_source(kind),Assets.PIRATE_ITEM_ATLAS)
	for kind in Assets.POTION_CELLS:check_source(Assets.potion_source(kind),Assets.POTION_ATLAS)
	for catalog in [Assets.INVENTORY_CORE_CELLS,Assets.INVENTORY_RARE_CELLS,Assets.FARM_FOOD_CELLS]:
		for kind in catalog:check_source(Assets.inventory_item_source(kind),Assets.inventory_item_atlas(kind))
	var area:=0.0
	for kind in Assets.POTION_CELLS:area+=Assets.potion_source(kind).get_area()
	expect(area==Assets.POTION_ATLAS.get_width()*Assets.POTION_ATLAS.get_height(),"all potion regions preserve complete atlas area")

## Сценарий: пользовательская сетка или неизвестное семейство не дают допустимого кадра.
## Исходное состояние: пустые размеры, отрицательный индекс и индекс за границей.
## Ожидаемый результат: возвращается пустая область без загрузки другого ресурса и без отрицательных координат.
func test_invalid_grid_has_no_source() -> void:
	var texture:=ImageTexture.create_from_image(Image.create(17,13,false,Image.FORMAT_RGBA8))
	for counts in [Vector2i(0,2),Vector2i(2,0),Vector2i(-1,2),Vector2i(18,2),Vector2i(2,14)]:expect(not Assets.grid_source(texture,counts.x,counts.y,Vector2i.ZERO).has_area(),"invalid grid dimensions have no region")
	for cell in [Vector2i(-1,0),Vector2i(4,0),Vector2i(0,3)]:expect(not Assets.grid_source(texture,4,3,cell).has_area(),"out of grid cell has no region")
	expect(not Assets.grid_source(null,4,3,Vector2i.ZERO).has_area(),"null texture does not create a source")
	expect(not Assets.pirate_enemy_source("unknown-family").has_area(),"unknown pirate has no negative source")

## Проверяет геометрию настоящего источника без предположения о равенстве ширины соседних ячеек.
func check_source(source:Rect2,texture:Texture2D) -> void:
	expect(source.has_area() and source.position==source.position.round() and source.size==source.size.round(),"real source uses integer pixel boundaries")
	expect(Rect2(Vector2.ZERO,texture.get_size()).encloses(source),"real source lies inside actual PNG")
