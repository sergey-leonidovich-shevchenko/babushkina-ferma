extends "res://tests/suites/suite_base.gd"

## Проверяет весь каталог культур на четырёх сезонах и сохранение спящих многолетников.
func run() -> void:
	test_all_seed_seasons_and_stock()
	test_every_crop_save_and_winter()
	test_dormancy_and_perennial_continuation()
	test_seed_information_and_last_day()

## Сценарий: все шестнадцать семян покупаются и пробуются в каждом сезоне.
## Исходное состояние: таланты редких культур открыты только для изоляции сезонного ограничения.
## Ожидаемый результат: доступная культура сажается, запрещённая не расходует семена и энергию.
func test_all_seed_seasons_and_stock() -> void:
	var game:=make_game(); game.talent_levels.farm_exotic_crops=1; game.energy=1000
	for kind in game.CropCatalogSystem.CROPS:
		var data:Dictionary=game.CropCatalogSystem.CROPS[kind]
		var product:int=game.shop_products.find_custom(func(entry): return entry.kind==data.seed and int(entry.buy)>0)
		expect(product>=0,"every crop has a purchasable seed source: "+kind)
		game.change_inventory_count(data.seed,4); game.hotbar_slots[1]=data.seed; game.selected_hotbar=1
		for day in [1,8,15,22]:
			game.day=day
			var plot:Dictionary=game.WorldFarmingSystem.empty_plot("overworld",Vector2i.ZERO); plot.tilled=true
			var before:int=game.inventory_item_count(data.seed); var energy:int=game.energy
			var allowed:bool=game.WorldEventSystem.season(day) in data.seasons
			expect(game.FarmSystem.plant(game,plot)==allowed,"planting obeys actual season: %s/%d"%[kind,day])
			expect(game.inventory_item_count(data.seed)==before-(1 if allowed else 0) and game.energy==energy-(1 if allowed else 0),"season refusal is atomic: %s/%d"%[kind,day])
	game.free()

## Сценарий: каждая культура переходит в зиму на середине настоящего роста и загружается обратно.
## Исходное состояние: растение полилось дважды, сохранена половина длительности, весна или лето подходят его сорту.
## Ожидаемый результат: семена не исчезают повторно, зимний прогресс заморожен, подходящий сезон завершает урожай.
func test_every_crop_save_and_winter() -> void:
	for kind in preload("res://scripts/systems/crop_catalog_system.gd").CROPS:
		var game:=make_game(); var plot:Dictionary=game.plots[Vector2i.ZERO]
		plot.tilled=true; plot.planted=true; plot.crop_kind=kind; plot.watered=true; plot.growth=0.0
		game.day=1+7*game.WorldEventSystem.SEASONS.find(game.CropCatalogSystem.data(kind).seasons[0])
		game.FarmSystem.update_plot(game,plot,100); plot.watered=true
		var growth:float=plot.growth; game.day=22; game.FarmSystem.update_plot(game,plot,100)
		expect(plot.growth==growth and plot.planted,"every planted crop survives winter without growth: "+kind)
		var loaded:=make_game()
		expect(loaded.SaveSystem.apply(loaded,JSON.parse_string(JSON.stringify(game.SaveSystem.snapshot(game)))),"every crop loads its mid-growth stage: "+kind)
		var saved:Dictionary=loaded.plots[Vector2i.ZERO]
		loaded.day=29+7*game.WorldEventSystem.SEASONS.find(game.CropCatalogSystem.data(kind).seasons[0])
		loaded.FarmSystem.update_plot(loaded,saved,100)
		expect(loaded.FarmSystem.harvest(loaded,saved),"suitable season completes saved crop: "+kind)
		game.free(); loaded.free()

## Сценарий: зрелый многолетник собран перед зимой и загружен во время покоя.
## Исходное состояние: клубника и лечебные травы хранят остаток роста и один полив.
## Ожидаемый результат: зима не уничтожает и не растит их, весна продолжает прежний прогресс после загрузки.
func test_dormancy_and_perennial_continuation() -> void:
	for kind in ["strawberry","herbs"]:
		var game:=make_game(); game.day=21
		var plot:Dictionary=game.plots[Vector2i.ZERO]
		plot.tilled=true; plot.planted=true; plot.crop_kind=kind; plot.watered=true
		plot.growth=game.CropCatalogSystem.growth_duration(kind); plot.stage=4
		expect(game.FarmSystem.harvest(game,plot) and plot.planted,"perennial remains planted after actual harvest: "+kind)
		plot.watered=true; game.day=22
		var growth:float=plot.growth; game.FarmSystem.update_plot(game,plot,100)
		expect(plot.growth==growth,"winter preserves dormant growth: "+kind)
		var loaded:=make_game()
		expect(loaded.SaveSystem.apply(loaded,JSON.parse_string(JSON.stringify(game.SaveSystem.snapshot(game)))),"dormant perennial survives actual JSON loader: "+kind)
		var saved:Dictionary=loaded.plots[Vector2i.ZERO]; loaded.day=29
		loaded.FarmSystem.update_plot(loaded,saved,0.5)
		expect(saved.planted and saved.crop_kind==kind and float(saved.growth)>growth,"spring resumes the saved plant without buying another seed: "+kind)
		game.free(); loaded.free()

## Сценарий: карточка семян показывает базовое время и сезоны, поздняя посадка предупреждает о покое.
## Исходное состояние: шесть языков, морковь в последний день осени и первый день зимы.
## Ожидаемый результат: короткие переводы доступны, срок ожидания точен, предупреждение не открывает окно.
func test_seed_information_and_last_day() -> void:
	var game:=make_game()
	for locale in game.LocaleSystem.LOCALES:
		game.LocaleSystem.current=locale
		var text:String=game.ItemPresentationSystem.effect_text(game,"seeds")
		expect(text.contains("20") and not text.contains("crop_seed_info"),"seed information uses localized actual growth: "+locale)
	game.LocaleSystem.current="ru"; game.day=21; game.hotbar_slots[1]="seeds"; game.selected_hotbar=1
	var plot:Dictionary=game.WorldFarmingSystem.empty_plot("overworld",Vector2i.ZERO); plot.tilled=true
	expect(game.FarmSystem.plant(game,plot) and game.message.contains("остановится") and not game.inventory_open,"late season warning stays a compact message")
	expect(game.CropCatalogSystem.days_until_growth("carrot",22)==7 and game.CropCatalogSystem.days_until_growth("carrot",28)==1,"winter wait uses actual seven-day seasons")
	game.free()
