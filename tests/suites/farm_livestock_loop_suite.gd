extends "res://tests/suites/suite_base.gd"

const Animals := preload("res://scripts/systems/livestock_system.gd")

## Проверяет одинаковый дневной итог сна, загрузки и паузы плюс объяснение продукции.
func run() -> void:
	test_daily_replay_and_pause()
	test_product_hints()

## Сценарий: одинаковый недельный уход проходит непрерывно и с загрузкой после каждого сна.
## Исходное состояние: два двора с семью порциями корма, одинаковым порядком ухода и сбора.
## Ожидаемый результат: итоговые запасы, дружба и дни выдачи совпадают, открытый рюкзак ничего не меняет.
func test_daily_replay_and_pause() -> void:
	var direct:=week(false); var restored:=week(true)
	expect(direct==restored,"seven-day livestock outcome is identical after every sleep/load boundary")
	var game:=make_game(); var value:Dictionary=game.FarmLifeSystem.state(game)
	Animals.feed(game,value); Animals.interact(game,value,"life:water")
	var before:=JSON.stringify(value.animals); var day:int=game.day; var energy:int=game.energy
	game.open_inventory()
	for index in 5: game.GameLoop.physics_process(game,10)
	expect(JSON.stringify(value.animals)==before and game.day==day and game.energy==energy,"fifty seconds in backpack do not punish care or create a new day")
	game.free()

## Проходит полную неделю реальных ежедневных взаимодействий с независимым сохранением на каждой границе.
func week(reload_each_day: bool) -> Dictionary:
	var game:=make_game(); game.change_inventory_count("animal_feed",3)
	for day in range(1,8):
		game.current_location="overworld"
		var value:Dictionary=game.FarmLifeSystem.state(game)
		Animals.update(game,value,0); Animals.interact(game,value,"life:water"); Animals.feed(game,value)
		var feed:int=game.inventory_item_count("animal_feed")
		Animals.feed(game,value)
		expect(game.inventory_item_count("animal_feed")==feed,"daily repeat never charges another feed")
		for animal in Animals.Data.ANIMALS:
			Animals.interact(game,value,"life:animal:"+animal.id)
			Animals.interact(game,value,"life:animal:"+animal.id)
		if day==7: break
		game.current_location="cottage_interior"; game.sleep_until_morning()
		if reload_each_day:
			var loaded:=make_game()
			expect(loaded.SaveSystem.apply(loaded,JSON.parse_string(JSON.stringify(game.SaveSystem.snapshot(game)))),"morning boundary reload preserves paid care")
			game.free(); game=loaded
	var result:={"animals":game.FarmLifeSystem.state(game).animals,"produce":{}}
	for kind in ["egg","milk","wool","truffle"]: result.produce[kind]=game.inventory_item_count(kind)
	result=JSON.parse_string(JSON.stringify(result)); game.free(); return result

## Сценарий: животное сообщает продукт и интервал при знакомстве на каждом языке.
## Исходное состояние: шесть видов записей двора с разной дружбой и интервалом.
## Ожидаемый результат: прогноз не выдаёт предметы и отражает действующий размер партии.
func test_product_hints() -> void:
	var game:=make_game(); var value:Dictionary=game.FarmLifeSystem.state(game)
	for locale in game.LocaleSystem.LOCALES:
		game.LocaleSystem.current=locale
		for animal in Animals.Data.ANIMALS:
			var memory:Dictionary=value.animals[animal.id]; memory.bond=0
			var hint:=Animals.product_hint(game,animal,memory)
			expect(hint.contains(game.inventory_item_name(animal.product)) and hint.contains(str(animal.interval)),"product and interval are readable: %s/%s"%[locale,animal.id])
	value.animals.cow.bond=6
	expect(Animals.product_hint(game,Animals.Data.animal("cow"),value.animals.cow).contains("×2"),"friendship forecast matches the actual two-product threshold")
	game.LocaleSystem.current="ru"; game.free()
