extends "res://tests/suites/suite_base.gd"

const Prepared := preload("res://scripts/presentation/prepared_pixel_cache.gd")
const Catalog := preload("res://assets/game/prepared_pixels/catalog.gd")
const Matte := preload("res://scripts/systems/sprite_matte_system.gd")
const Grandmother := preload("res://scripts/systems/grandmother_visual_system.gd")
const Wildlife := preload("res://scripts/systems/wildlife_visual_system.gd")

## Сверяет все производные пиксели и области с прежними алгоритмами, включая отказ устаревшему кешу.
func run() -> void:
	test_every_prepared_texture_matches_original_algorithm_exactly()
	test_stale_unknown_and_disabled_cache_use_safe_fallback()

## Сценарий: до игрового движения загружаются готовые результаты очистки и измерения фигур.
## Исходное состояние: девять исходников, их производные ресурсы и реестр с точными отпечатками.
## Ожидаемый результат: все четыре канала каждого изображения и все области кадров совпадают с прежней обработкой.
func test_every_prepared_texture_matches_original_algorithm_exactly() -> void:
	Prepared.clear()
	expect(Catalog.ENTRIES.size()==9 and Catalog.VERSION==Prepared.VERSION,"prepared graphics catalog has the current nine source contracts")
	for key in Catalog.ENTRIES:
		var algorithm:String=key.get_slice("|",0); var path:String=key.get_slice("|",1)
		var entry:Dictionary=Catalog.ENTRIES[key]; var source:Texture2D=load(path)
		var original:=source.get_image()
		if original.is_compressed(): original.decompress()
		var expected:Image=Grandmother.clean_image(original) if algorithm=="grandmother-green-v1" else Matte.clean_image(original)
		var texture:=Prepared.texture(source,algorithm)
		expect(texture!=null and texture.get_size()==source.get_size(),"prepared image preserves complete dimensions: "+path)
		expect(Prepared.fingerprint(texture)==Prepared.image_fingerprint(expected) and Prepared.fingerprint(texture)==entry.output_sha256,"every prepared RGBA pixel equals the previous algorithm: "+path)
		expect(Prepared.fingerprint(source)==entry.source_sha256,"source artwork is unchanged after preparation: "+path)
		expect(Prepared.texture(source,algorithm)==texture,"repeated lookup reuses one prepared texture: "+path)
		if entry.source_sha256==entry.output_sha256: expect(texture==source,"identity processing retains the original texture without a GPU duplicate: "+path)
		for rectangle in entry.bounds:
			var values:=String(rectangle).split(","); var area:=Rect2i(int(values[0]),int(values[1]),int(values[2]),int(values[3]))
			expect(Prepared.bounds(texture,area)==Wildlife.measure_visible_bounds(expected,area),"prepared alpha bounds preserve the same frame and foot anchor: "+path+":"+rectangle)
	expect(Prepared.statistics().textures<=9 and Prepared.statistics().verified<=9,"prepared graphics caches are bounded by the fixed source catalog")

## Сценарий: исходник или формат кеша не подходит, либо инструмент сборки выключает использование производных данных.
## Исходное состояние: действующая запись героя и самостоятельная синтетическая текстура со служебным внешним цветом.
## Ожидаемый результат: неправильный отпечаток или размер отвергается, неизвестный ресурс проходит прежний алгоритм без изменения исходника.
func test_stale_unknown_and_disabled_cache_use_safe_fallback() -> void:
	var key:String=Catalog.ENTRIES.keys()[0]; var entry:Dictionary=Catalog.ENTRIES[key].duplicate(true); var source:Texture2D=load(key.get_slice("|",1))
	entry.source_sha256="stale"
	expect(not Prepared.source_matches(source,entry),"stale source fingerprint cannot reuse prepared pixels")
	entry=Catalog.ENTRIES[key].duplicate(true); entry.width+=1
	expect(not Prepared.source_matches(source,entry),"stale dimensions cannot reuse prepared pixels")
	expect(Prepared.texture(source,"future-algorithm")==null and Prepared.texture(null,"service-matte-v1")==null,"unknown algorithm and absent source keep the fallback route")
	var image:=Image.create(5,5,false,Image.FORMAT_RGBA8); image.fill(Color.TRANSPARENT); image.set_pixel(0,0,Color.MAGENTA); image.set_pixel(2,2,Color("557799"))
	var custom:=ImageTexture.create_from_image(image); var before:=Prepared.fingerprint(custom)
	expect(Prepared.texture(custom,"service-matte-v1")==null,"unregistered custom images cannot use an unrelated prepared asset")
	var output:=Matte.clean_texture(custom)
	expect(Prepared.fingerprint(output)==Prepared.image_fingerprint(Matte.clean_image(image)) and Prepared.fingerprint(custom)==before,"unknown image preserves the previous matte algorithm and its source pixels")
	Prepared.enabled=false
	expect(Prepared.texture(source,key.get_slice("|",0))==null,"build and diagnostic mode can explicitly bypass derived assets")
	Prepared.enabled=true
