extends "res://tests/suites/suite_base.gd"

const Cache := preload("res://scripts/systems/weak_owner_cache.gd")
const Maintenance := preload("res://scripts/systems/runtime_maintenance_system.gd")
const Matte := preload("res://scripts/systems/sprite_matte_system.gd")
const Bounds := preload("res://scripts/systems/wildlife_visual_system.gd")
const Residents := preload("res://scripts/systems/resident_visual_system.gd")
const Picker := preload("res://scripts/systems/level_editor_atlas_picker_renderer.gd")
const Cabinet := preload("res://scripts/systems/dev_cabinet_system.gd")

## Проверяет слабое владение, жёсткие пределы, постепенный обход, паузу и сохранность игровых данных.
func run() -> void:
	test_dead_owner_and_live_result_lifetimes()
	test_capacity_key_reuse_and_identity()
	test_periodic_incremental_schedule()
	test_sprite_pixels_bounds_and_live_sources()
	test_real_pause_preserves_gameplay_and_saves()
	test_cabinet_queries_remain_bounded()

## Создаёт маленькую временную текстуру с понятным телом и служебным цветом у края.
func texture() -> ImageTexture:
	var image := Image.create(32,32,false,Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT); image.fill_rect(Rect2i(4,6,19,21),Color.CORNFLOWER_BLUE)
	image.set_pixel(0,0,Color.MAGENTA)
	return ImageTexture.create_from_image(image)

## Создаёт производную запись, не оставляя сильных ссылок в вызывающем тесте.
func abandoned(cache: RefCounted, key: Variant) -> WeakRef:
	var owner := RefCounted.new(); var value := RefCounted.new()
	cache.store(owner,key,value)
	return weakref(value)

## Завершает ограниченный проход, не подменяя настоящий порционный алгоритм массовой очисткой.
func finish(game: Node, now_usec: int) -> int:
	var frames := 0
	var frame_limit := 8
	for cache in Maintenance.caches(): frame_limit+=cache.scan_size()*2
	while Maintenance.busy(game) and frames<frame_limit:
		Maintenance.update(game,now_usec); frames+=1
		expect(Maintenance.statistics(game).last_checks<=Maintenance.MAX_CHECKS_PER_FRAME,"maintenance respects hard operation limit")
	expect(not Maintenance.busy(game),"incremental pass completes within its bounded slots")
	return frames

## Сценарий: исчезнувший исходник больше не удерживает производный результат, а живой остаётся доступен.
## Исходное состояние: две записи, у одной отпущен владелец, у второй сохранены исходник и результат.
## Ожидаемый результат: точечная очистка освобождает только первую запись и сохраняет точное значение второй.
func test_dead_owner_and_live_result_lifetimes() -> void:
	var cache := Cache.new(8); var released := abandoned(cache,"dead")
	var owner := RefCounted.new(); var kept := RefCounted.new(); cache.store(owner,"live",kept)
	expect(released.get_ref()!=null,"derived value initially belongs to cache")
	for index in cache.scan_size(): cache.prune_one()
	expect(released.get_ref()==null and cache.size()==1,"dead owner permits releasing derived value")
	expect(cache.fetch(owner,"live")==kept,"live owner and exact derived result survive sweep")
	expect(cache.statistics().removed==1,"only expired owner counted as removed")

## Сценарий: тысячи разных ключей и переиспользованный идентификатор не раздувают таблицу и не возвращают чужое значение.
## Исходное состояние: вместимость восемь, живой исходник и отдельная запись, где значение совпадает с владельцем.
## Ожидаемый результат: таблица и кольцо ограничены, слабое самозначение освобождается, пустые слоты переиспользуются.
func test_capacity_key_reuse_and_identity() -> void:
	var cache := Cache.new(8); var owner := RefCounted.new()
	for index in 2000: cache.store(owner,index,index)
	expect(cache.size()==8 and cache.scan_size()==8,"keys and scan ring stay bounded after 2000 inserts")
	expect(cache.fetch(owner,1999)==1999 and cache.fetch(owner,0)==null,"bounded eviction retains recent result")
	var stranger := RefCounted.new()
	expect(cache.fetch(stranger,1999)==null,"reused identifier cannot return different owner's data")
	cache.store(stranger,1999,123)
	expect(cache.fetch(stranger,1999)==123 and cache.size()==8,"replacing same key does not leak scan slots")
	cache.clear()
	var identity := RefCounted.new(); var reference: WeakRef = weakref(identity)
	cache.store(identity,"self",identity)
	expect(cache.fetch(identity,"self")==identity,"identity result preserves original resource")
	identity=null
	expect(reference.get_ref()==null,"identity result cannot pin its own weak owner")
	cache.prune_one()
	for index in 50:
		abandoned(cache,"reuse")
		cache.prune_one()
	expect(cache.size()==0 and cache.scan_size()<=8,"repeated dead slot reuse never grows scan queue")

## Сценарий: обслуживание запускается по реальному времени и продолжает одну работу по нескольким кадрам.
## Исходное состояние: несколько сотен отпущенных источников, время до срока и большой скачок после сна компьютера.
## Ожидаемый результат: до срока ничего не удаляется, повторный запрос не дублирует задачу, пропущенные интервалы не догоняются.
func test_periodic_incremental_schedule() -> void:
	var game := make_game()
	for index in 128: abandoned(Bounds._bounds,"maintenance:%d"%index)
	var initial := Bounds._bounds.size()
	Maintenance.update(game,1000)
	Maintenance.update(game,1000+Maintenance.INTERVAL_USEC-1)
	expect(Bounds._bounds.size()==initial and not Maintenance.busy(game),"nothing purged before periodic deadline")
	Maintenance.update(game,1000+Maintenance.INTERVAL_USEC)
	expect(Maintenance.busy(game),"large cleanup spans multiple frames")
	var remaining: Array=Maintenance.statistics(game).remaining
	Maintenance.request(game)
	expect(Maintenance.statistics(game).remaining==remaining,"request while busy never restarts traversal")
	finish(game,1000+Maintenance.INTERVAL_USEC)
	var done := Maintenance.statistics(game)
	expect(done.cycles==1 and done.removed>=128,"scheduled pass removes abandoned records")
	Maintenance.update(game,1000+Maintenance.INTERVAL_USEC*100)
	finish(game,1000+Maintenance.INTERVAL_USEC*100)
	expect(Maintenance.statistics(game).cycles==2,"resume after sleep triggers one pass, not 99 catch-up passes")
	game.free()

## Сценарий: чистка сохраняет альфу и рамки спрайтов и не выбрасывает живой прогретый источник.
## Исходное состояние: временное изображение, реальный мастер жителя и четыре подключённых кеша.
## Ожидаемый результат: результат очистки совпадает пиксельно, повторные кадры используют сохранённые значения.
func test_sprite_pixels_bounds_and_live_sources() -> void:
	var game := make_game(); var source := texture(); var result := Matte.clean_texture(source)
	var pixels := Matte.clean_image(source.get_image())
	expect(result.get_image().get_data()==pixels.get_data(),"cached matte result preserves exact original cleanup pixels")
	var expected: Rect2i=pixels.get_used_rect(); var area:=Rect2i(0,0,32,32)
	expect(Bounds.visible_bounds(result,area)==expected and Picker.visible_preview_source(result,Rect2(area))==Rect2(expected),"wildlife and atlas preview preserve visible bounds")
	var resident: Texture2D=load("res://assets/game/characters/walk_v2/npc_official.png")
	var pose: Dictionary=Residents.pose(resident,Vector2.DOWN,0,false)
	Maintenance.request(game); finish(game,2000)
	expect(Matte.clean_texture(source)==result,"periodic sweep retains warm live sprite")
	expect(Residents.pose(resident,Vector2.DOWN,0,false)==pose,"periodic sweep retains resident geometry")
	var result_ref: WeakRef = weakref(result); source=null; result=null
	Maintenance.request(game); finish(game,3000)
	expect(result_ref.get_ref()==null,"temporary cleaned texture released after source disappears")
	game.free()

## Сценарий: уборка работает поверх паузы и оставляет сохранение, добычу и незавершённый бой без изменений.
## Исходное состояние: открытый рюкзак, сохранённый предмет на земле и живые временные боевые состояния.
## Ожидаемый результат: внутренний мусор удаляется, но предметы, время, атаки, стройка и сохранение не меняются.
func test_real_pause_preserves_gameplay_and_saves() -> void:
	var game := make_game(); game.open_inventory()
	game.dropped_items.append({"kind":"wood","count":7,"position":game.player,"location":game.current_location})
	game.state.world.cave_boss.attack={"test":true}; game.state.world.cave_boss.fly_timer=3.5
	var save: Dictionary=game.SaveSystem.snapshot(game)
	var attack: Dictionary=game.state.world.cave_boss.duplicate(true)
	var resource := abandoned(Matte._textures,"paused-temp")
	Maintenance.request(game)
	var frame_limit := 8
	for cache in Maintenance.caches(): frame_limit+=cache.scan_size()*2
	for index in frame_limit:
		if not Maintenance.busy(game): break
		game.GameLoop.physics_process(game,0.5)
	expect(resource.get_ref()==null and not Maintenance.busy(game),"real game loop reclaims cache while inventory pauses gameplay")
	expect(game.SaveSystem.snapshot(game)==save and game.dropped_items[0].count==7,"maintenance cannot consume loot, resources or saved world data")
	expect(game.state.world.cave_boss==attack,"maintenance cannot cancel active combat or status effects")
	expect(not save.has(Maintenance.META),"maintenance cursors are never serialized")
	game.free()

## Сценарий: поиск по многим разным строкам не накапливает неограниченный каталог результатов.
## Исходное состояние: домашний шкаф, двести последовательных запросов и неизменный запас.
## Ожидаемый результат: кеш не больше шестнадцати запросов, возврат к старому запросу даёт тот же список без выдачи предметов.
func test_cabinet_queries_remain_bounded() -> void:
	var game := make_game(); var state := Cabinet.state(game)
	var stock: Dictionary=state.stock.duplicate(); var inventory: Dictionary=game.export_inventory_counts().duplicate()
	state.query="молоко"; var expected: Array=Cabinet.items(game).duplicate()
	for index in 200:
		state.query="unknown_%d"%index; Cabinet.items(game)
		expect(state.cache.size()<=Cabinet.QUERY_CACHE_LIMIT,"cabinet query cache stays bounded")
	state.query="молоко"
	expect(Cabinet.items(game)==expected and not expected.is_empty(),"evicted search is rebuilt identically")
	expect(state.stock==stock and game.export_inventory_counts()==inventory,"query eviction preserves both inventories")
	game.free()
