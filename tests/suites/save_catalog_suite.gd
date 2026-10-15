extends "res://tests/suites/suite_base.gd"

const Save := preload("res://scripts/systems/save_system.gd")
const References := preload("res://scripts/systems/save_catalog_reference_system.gd")

## Проверяет закреплённые старые схемы, неизвестные ссылки, идемпотентность и неизменность исходного файла.
func run() -> void:
	test_historical_fixtures_and_idempotence()
	test_unknown_catalog_paths_are_atomic()
	test_disk_source_and_backup_policy()

## Сценарий: синтетические документы ранней схемы и более позднего производства загружаются из репозитория.
## Исходное состояние: фиксированные монеты, материалы, знания и частично выполненные очереди.
## Ожидаемый результат: признанный прогресс сохранён, повтор миграции и загрузки не выдаёт предметы заново.
func test_historical_fixtures_and_idempotence() -> void:
	for name in ["v1-core","v2-production"]:
		var path:="res://tests/fixtures/saves/%s.json"%name
		var source:=FileAccess.get_file_as_string(path); var fixture:Dictionary=JSON.parse_string(source)
		var migrated:=Save.migrate(fixture)
		expect(Save.migrate(migrated)==migrated and JSON.stringify(fixture)==JSON.stringify(JSON.parse_string(source)),"fixture migration is pure and idempotent: "+name)
		var game:=make_game(); expect(Save.apply(game,fixture),"historical fixture loads: "+name)
		expect(game.coins==41 and game.wood==14 and game.inventory_item_count("apple")==2,"recognized historical balances survive: "+name)
		if name=="v2-production":
			expect(game.FurnaceSystem.state(game).queue[0].remaining==5 and game.WorkshopSystem.state(game,"sawmill").queue[0].remaining==3,"paid historical work survives without reroll or premature output")
			expect(game.ResearchSystem.learned(game,"plank"),"historical research knowledge survives")
			var foundation:Dictionary=game.BasementSystem.state(game).objects[0]; var paid:=true
			for kind in foundation.paid: paid=paid and int(foundation.paid[kind])==int(fixture.estate.expansion.basement.objects[0].paid[kind])
			expect(foundation.work==2 and paid,"placed foundation preserves its paid ledger and partial assembly")
		var snapshot:=Save.snapshot(game)
		var normalized:Dictionary=JSON.parse_string(JSON.stringify(snapshot))
		expect(Save.apply(game,normalized) and JSON.parse_string(JSON.stringify(Save.snapshot(game)))==normalized,"normalized historical snapshot reloads without additional grants: "+name)
		expect(FileAccess.get_file_as_string(path)==source,"loading never rewrites a repository fixture: "+name)
		game.free()

## Сценарий: корректный по типам слот содержит неизвестные предметы, миссию, очередь или вид станка.
## Исходное состояние: живой мир и отдельные повреждённые копии его снимка.
## Ожидаемый результат: точная проблемная ссылка доступна диагностике; живое состояние не меняется.
func test_unknown_catalog_paths_are_atomic() -> void:
	var game:=make_game(); game.FurnaceSystem.state(game); game.WorkshopSystem.state(game,"sawmill"); game.ResearchSystem.state(game)
	var before:=Save.snapshot(game)
	var debug:=before.duplicate(true); debug.location=game.DebugPlaygroundSystem.LOCATION
	expect(Save.ValidationSystem.valid(debug),"registered QA playground remains a supported save location")
	for issue in ["counts","storage","slots","hotbar","equipment","mission","queue","station","known","drop","container","placed_station","placed_queue"]:
		var data:=before.duplicate(true); var expected:=""
		match issue:
			"counts": data.counts.retired_ore=4; expected="counts.retired_ore"
			"storage": data.storage.counts.retired_ore=4; expected="storage.counts.retired_ore"
			"slots": data.slots[0]="retired_ore"; expected="slots[0]"
			"hotbar": data.hotbar[0]="retired_ore"; expected="hotbar[0]"
			"equipment": data.equipment.head="retired_helm"; expected="equipment.head"
			"mission": data.missions.retired_mission="complete"; expected="missions.retired_mission"
			"queue": data.estate.expansion.furnace.queue=[{"id":"retired:smelt","duration":12,"remaining":5}]; expected="furnace.queue[0].id"
			"station": data.estate.expansion.workshops.retired_station={"level":1,"queue":[]}; expected="workshops.retired_station"
			"known": data.estate.expansion.research.known=["retired_ore"]; expected="research.known"
			"drop": data.drops=[{"kind":"retired_ore","count":1,"position":[300,400]}]; expected="drops[0].kind"
			"container": data.containers[0].contents.retired_ore=2; expected="containers[0].contents.retired_ore"
			"placed_station","placed_queue":
				data.estate.expansion.basement=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/saves/v2-production.json")).estate.expansion.basement
				var placed:Dictionary=data.estate.expansion.basement.objects[0]
				if issue=="placed_station": placed.kind="retired_station"; expected="objects[0].kind"
				else: placed.production.queue=[{"id":"retired:recipe","duration":8,"remaining":4}]; expected="objects[0].production.queue[0].id"
		expect(References.first_error(data).contains(expected),"unsupported content reports exact owner: "+issue)
		expect(not Save.apply(game,data) and Save.snapshot(game)==before,"unsupported content is refused before any mutation: "+issue)
	game.free()

## Сценарий: неизвестная оплаченная очередь находится в основном файле рядом с исправным резервом.
## Исходное состояние: отдельный временный путь и живой мир с другим количеством монет.
## Ожидаемый результат: резерв загружается, оба исходных файла остаются неизменными, без резерва отказ атомарен.
func test_disk_source_and_backup_policy() -> void:
	var game:=make_game(); var path:="/private/tmp/farm-safe-catalog-%d.json"%Time.get_ticks_usec()
	var data:=Save.snapshot(game); data.counts.future_material=7
	var file:=FileAccess.open(path,FileAccess.WRITE); file.store_string(JSON.stringify(data)); file.close()
	var original:=FileAccess.get_file_as_string(path); var before:=Save.snapshot(game)
	expect(not Save.load_at(game,path) and Save.snapshot(game)==before and FileAccess.get_file_as_string(path)==original,"unknown primary without backup refuses without destructive normalization")
	game.coins=71; expect(Save.save_at(game,path+".bak"),"isolated healthy backup writes")
	game.coins=2; expect(Save.load_at(game,path) and game.coins==71,"healthy backup is used for unsupported primary")
	expect(FileAccess.get_file_as_string(path)==original,"fallback never overwrites unsupported source")
	for suffix in ["",".bak",".bak.bak",".tmp",".bak.tmp"]:
		if FileAccess.file_exists(path+suffix): DirAccess.remove_absolute(path+suffix)
	game.free()
