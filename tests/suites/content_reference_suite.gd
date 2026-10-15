extends "res://tests/suites/suite_base.gd"

const Graph := preload("res://scripts/systems/content_reference_graph.gd")

## Проверяет полный реестр и повреждённые копии без изменения текущего героя или статических каталогов.
func run() -> void:
	test_complete_catalog_is_pure_and_localized()
	test_missing_references_quantities_and_station_levels()
	test_cycles_and_missing_languages_are_explained()

## Сценарий: единый граф проверяет все канонические рецепты, станки, миссии, имена и подготовленные иконки.
## Исходное состояние: чистые копии каталогов и отдельно созданный герой с известным прогрессом.
## Ожидаемый результат: ошибок нет, все предметы имеют шесть имён, герой и глобальные данные не меняются.
func test_complete_catalog_is_pure_and_localized() -> void:
	var game:=make_game(); var before:Dictionary=game.SaveSystem.snapshot(game); var data:=Graph.snapshot(); var original:=data.duplicate(true)
	expect(Graph.errors(data).is_empty(),"complete content graph agrees with prepared icons and all six languages")
	expect(data==original and game.SaveSystem.snapshot(game)==before,"catalog validation is read-only and never grants items or saves progress")
	for kind in data.items:
		expect(data.locales.items.has(kind) and data.locales.items[kind].size()==6,"every registered item has six localized names: "+kind)
	data.recipes[0].output="broken_copy"
	expect(Graph.snapshot().recipes[0].output!="broken_copy","external graph copies cannot mutate canonical recipes")
	game.free()

## Сценарий: в копии данных пропущен ингредиент, награда, станок или иконка, либо испорчено количество.
## Исходное состояние: для каждой ошибки берётся свежая копия, а живые реестры остаются нетронутыми.
## Ожидаемый результат: результат содержит точный путь владельца ошибки, после проверки исходный реестр валиден.
func test_missing_references_quantities_and_station_levels() -> void:
	for issue in ["ingredient","output","reward","station","level","quantity","icon","talent"]:
		var data:=Graph.snapshot(); var path:=""
		match issue:
			"ingredient": data.recipes[0].inputs.absent_ore=1; path="recipe[0].inputs.absent_ore"
			"output": data.recipes[0].output="absent_output"; path="recipe[0].output"
			"reward": data.missions.values()[0].reward_item="absent_reward"; path=".reward_item"
			"station": data.recipes[0].station="absent_station"; path="recipe[0].station"
			"level": data.recipes[0].workshop_level=4; path="recipe[0].workshop_level"
			"quantity": data.recipes[0].inputs.wood=0.5; path="recipe[0].inputs.wood invalid quantity"
			"icon": data.icons.erase("wood"); path="icons.wood"
			"talent": data.recipes[0].talent="absent_talent"; path="recipe[0].talent"
		var errors:=Graph.errors(data,false)
		expect(errors.any(func(error): return String(error).contains(path)),"bad catalog reports precise owner: "+issue)
	expect(Graph.errors(Graph.snapshot()).is_empty(),"negative cases leave original content intact")

## Сценарий: цепочка миссий замкнулась, указывает на пропущенный узел или потеряла один язык.
## Исходное состояние: копии действительных миссий и переводов изменяются по одному признаку.
## Ожидаемый результат: цикл, отсутствующий узел и конкретный индекс языка явно указаны; допустимые ремесленные циклы не запрещены.
func test_cycles_and_missing_languages_are_explained() -> void:
	var data:=Graph.snapshot(); data.missions.story_relic.requires="story_ancient_key"
	var errors:=Graph.errors(data,false)
	expect(errors.any(func(error): return String(error).contains("story_relic") and String(error).contains("cycle:") and String(error).contains("story_ancient_key")),"mission cycle includes the complete dependency chain")
	data=Graph.snapshot(); data.missions.story_relic.requires="absent_mission"
	expect(Graph.errors(data,false).has("mission.story_relic.requires -> absent_mission"),"missing mission dependency names owner and target")
	data=Graph.snapshot(); data.locales.items.wood[5]=""
	expect(Graph.errors(data,false).has("locale.items.wood[5] empty translation"),"missing language reports the precise table item and language")
	data=Graph.snapshot(); data.locales.items.wood.pop_back()
	expect(Graph.errors(data,false).has("locale.items.wood requires six languages"),"truncated translation table is rejected")
	data=Graph.snapshot(); data.locales.quests.erase("story_relic.description")
	expect(Graph.errors(data,false).has("mission.story_relic.locale -> quests.story_relic.description"),"mission localization must exist instead of silently displaying an ID")
