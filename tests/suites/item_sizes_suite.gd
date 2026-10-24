extends "res://tests/suites/suite_base.gd"

const Assets := preload("res://scripts/systems/visual_asset_system.gd")
const Prepared := preload("res://scripts/presentation/prepared_item_icon_system.gd")
const Catalog := preload("res://assets/game/items/ui/catalog.gd")

## Проверяет роли размеров, настоящую работу ограниченного кеша и отсутствие исходников при просмотре.
func run() -> void:
	test_size_boundary_and_invalid_requests()
	test_lru_hits_eviction_and_release()
	test_catalogue_has_two_roles_without_original_requests()
	test_prepared_files_match_full_resolution_sources()

## Сценарий: размер проходит границу миниатюры, затем становится нулевым или нечисловым.
## Исходное состояние: пустой кеш и реальный предмет с подготовленными обоими размерами.
## Ожидаемый результат: граница берётся из паспорта, неверный запрос не грузит мастера и не растит кеш.
func test_size_boundary_and_invalid_requests() -> void:
	var game := make_game(); Assets.initialize_item_icons(game.InventorySystem.ITEM_DATA.keys())
	expect(Prepared.SMALL_SIZE==64 and Prepared.PREVIEW_SIZE==160,"two preparation sizes are read from the canonical catalogue")
	for pixels in [8,32,40,64,64.001,160,320]:
		var packet := Assets.item_draw_visual("bread",pixels)
		var preview: bool=pixels>64
		expect(packet.prepared_role==("preview" if preview else "thumbnail") and packet.texture_intent=="color_srgb","explicit role and color intent: "+str(pixels))
		expect(packet.prepared_size==packet.texture.get_width() and (not preview or packet.prepared_size==160),"request changes selection, not texture dimensions: "+str(pixels))
	var before := Prepared.cache_info(); var sources := Assets.item_cache_info()
	for pixels in [0,-1,NAN,INF,-INF]:
		expect(Prepared.role(pixels).is_empty() and Assets.item_draw_visual("bread",pixels).texture==null,"invalid request has no drawing texture: "+str(pixels))
	expect(Prepared.cache_info()==before and Assets.item_cache_info()==sources,"invalid sizes neither decode originals nor allocate cache entries")
	Assets.initialize_item_icons(game.InventorySystem.ITEM_DATA.keys()); game.free()

## Сценарий: заполненный кеш повторно использует предмет, вытесняет самый старый и возвращает его по новому запросу.
## Исходное состояние: восемнадцать реальных превью и слабые ссылки без скрытого удержания текстур тестом.
## Ожидаемый результат: попадание не вызывает load, LRU соблюдается, вытесненные обёртка и исходник освобождаются.
func test_lru_hits_eviction_and_release() -> void:
	var game := make_game(); Assets.initialize_item_icons(game.InventorySystem.ITEM_DATA.keys())
	var kinds: Array=game.InventorySystem.ITEM_DATA.keys(); kinds.sort()
	var second: WeakRef; var raw_second: WeakRef
	for index in 16:
		var packet := Assets.item_draw_visual(kinds[index],104)
		expect(packet.texture is CanvasTexture and packet.texture.texture_filter==CanvasItem.TEXTURE_FILTER_LINEAR and packet.texture.texture_repeat==CanvasItem.TEXTURE_REPEAT_DISABLED,"large preview has an explicit non-repeating linear filter: "+kinds[index])
		if index==1: second=weakref(packet.texture); raw_second=weakref(packet.texture.diffuse_texture)
	var before := Prepared.cache_info()
	Assets.item_draw_visual(kinds[0],104)
	var hit := Prepared.cache_info()
	expect(hit.preview_load_requests==before.preview_load_requests and hit.preview_hits==before.preview_hits+1,"cache hit records no additional ResourceLoader request")
	Assets.item_draw_visual(kinds[16],104)
	var evicted := Prepared.cache_info()
	expect(evicted.large==16 and evicted.preview_evictions==1 and kinds[0] in evicted.preview_ids and kinds[1] not in evicted.preview_ids,"recently touched preview survives the LRU eviction")
	expect(second.get_ref()==null and raw_second.get_ref()==null,"evicted preview wrapper and raw resource have no strong references left")
	Assets.item_draw_visual(kinds[1],104)
	expect(Prepared.cache_info().preview_load_requests==evicted.preview_load_requests+1 and Prepared.cache_info().large==16,"revisiting an evicted preview loads only that entry")
	var external: Array=Prepared.cache_info().preview_ids; external.clear()
	expect(Prepared.cache_info().preview_ids.size()==16,"diagnostic result cannot mutate LRU ownership")
	Prepared.clear()
	expect(Prepared.cache_info().large==0 and Prepared.cache_info().preview_load_requests==0,"clear releases previews and resets load counters")
	game.free()

## Сценарий: весь реестр просматривается без обращения к каноническим изображениям оружия и Wiki.
## Исходное состояние: новая регистрация всех предметов и подготовленный каталог обеих ролей.
## Ожидаемый результат: все ID и окраски совпадают, загрузка оригинальных PNG остаётся нулевой, превью ограничены.
func test_catalogue_has_two_roles_without_original_requests() -> void:
	var game := make_game(); Assets.initialize_item_icons(game.InventorySystem.ITEM_DATA.keys())
	expect(Catalog.DATA.entries.size()==game.InventorySystem.ITEM_DATA.size(),"prepared and canonical catalogues have the same complete item set")
	for kind in game.InventorySystem.ITEM_DATA:
		var small := Assets.item_draw_visual(kind,40); var large := Assets.item_draw_visual(kind,104)
		expect(small.prepared_size==64 and large.prepared_size==160 and small.tint==large.tint and small.provider==large.provider,"both roles preserve identity, tint and provider: "+kind)
		expect(large.texture.diffuse_texture.resource_path=="res://assets/game/items/ui/preview/"+kind+".png","large role uses only its prepared file: "+kind)
	expect(Assets.item_cache_info().loaded_paths==0 and Prepared.cache_info().large==16,"whole catalogue browsing keeps original PNGs untouched and bounds previews")
	expect(Prepared.cache_info().preview_load_requests==Catalog.DATA.entries.size(),"each first preview visit has one explicit load request")
	Assets.initialize_item_icons(game.InventorySystem.ITEM_DATA.keys()); game.free()

## Сценарий: источник и готовый preview проверяются точно, прямой экспорт — по рассмотренным полным RGBA-хешам.
## Исходное состояние: закреплённые engine/fitter, все оригиналы и неизменный реестр двух реальных CI-капсул.
## Ожидаемый результат: игровые PNG/source побайтно сохранны; неизвестный вывод resize, даже 1/255, запрещён.
func test_prepared_files_match_full_resolution_sources() -> void:
	var game := make_game()
	var fitter := preload("res://tools/item_ui_fitter.gd")
	var contract := preload("res://tools/item_export_contract.gd")
	var manifest := contract.manifest()
	expect(
		contract.environment(manifest, game.InventorySystem.ITEM_DATA.keys()).is_empty(),
		"exact export environment and source files"
	)
	for kind in game.InventorySystem.ITEM_DATA:
		var visual := Assets.item_visual(kind)
		var source: Image = visual.texture.get_image()
		if source.is_compressed():
			source.decompress()
		var expected := fitter.fitted(source, source.get_used_rect(), 160, 8)
		var actual := Image.load_from_file(
			ProjectSettings.globalize_path("res://assets/game/items/ui/preview/" + kind + ".png")
		)
		if actual.get_data() != expected.get_data():
			print(
				"ITEM PREVIEW DIFFERENCE: ",
				kind,
				" ",
				JSON.stringify(pixel_difference(actual, expected, source))
			)
		var path := "res://assets/game/items/ui/preview/" + String(kind) + ".png"
		var errors := contract.inspect(
			manifest.entries[kind],
			visual,
			source,
			actual,
			FileAccess.get_file_as_bytes(path),
			expected
		)
		expect(
			errors.is_empty(),
			(
				"exact actual PNG/source and evidenced complete direct export: "
				+ kind
				+ ": "
				+ str(errors)
			)
		)
	Assets.initialize_item_icons(game.InventorySystem.ITEM_DATA.keys())
	game.free()


## Печатает точное отличие resize для диагностики; решение принимает отдельный закреплённый контракт.
func pixel_difference(actual: Image, expected: Image, source: Image) -> Dictionary:
	var actual_bytes := actual.get_data()
	var expected_bytes := expected.get_data()
	var differing_bytes := 0
	var max_delta := 0
	for index in mini(actual_bytes.size(), expected_bytes.size()):
		var delta := absi(int(actual_bytes[index]) - int(expected_bytes[index]))
		if delta > 0:
			differing_bytes += 1
			max_delta = maxi(max_delta, delta)
	return {
		"actual_bytes": actual_bytes.size(),
		"expected_bytes": expected_bytes.size(),
		"differing_bytes": differing_bytes,
		"max_delta": max_delta,
		"source_size": str(source.get_size()),
		"source_bounds": str(source.get_used_rect()),
		"source_sha256": image_digest(source),
		"actual_sha256": image_digest(actual),
		"expected_sha256": image_digest(expected),
	}


## Хеширует новую PNG-сериализацию для диагностики; это не SHA исходного файла или raw RGBA.
func image_digest(image: Image) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(image.save_png_to_buffer())
	return context.finish().hex_encode()
