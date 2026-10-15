extends "res://tests/suites/suite_base.gd"

var report:Dictionary={}

## Проверяет сезонную достижимость рыбного поручения и настоящий управляемый прогон мини-игры.
func run() -> void:
	test_calendar_and_quest()
	test_controlled_trials()
	test_bait_and_advanced_access()

## Сценарий: базовая удочка проверяется на всех сезонах, погодах, двух водоёмах и глубинах.
## Исходное состояние: обычная снасть без талантов, утро и ночь каждого сезона.
## Ожидаемый результат: рыба для задания доступна всегда, выбор воспроизводим, редкие требования не подменяют обычную рыбу.
func test_calendar_and_quest() -> void:
	var game:=make_game(); var rows:Array=[]
	expect(game.has_fishing_rod and game.QuestSystem.MISSIONS.side_fisher.item=="fish" and game.QuestSystem.MISSIONS.side_fisher.count==5,"ordinary rod and five generic fish suffice for the bridge quest")
	for day in [1,8,15,22]:
		for weather in ["clear","rain","wind","snow","storm"]:
			for hour in [6,22]:
				game.day=day; game.game_minutes=hour*60; game.state.world.weather=weather; game.state.world.weather_day=day
				for water in ["pond","river"]:
					for power in [0.2,0.5,0.9]:
						var state=game.state.fishing; state.water_kind=water; state.cast_power=power
						state.depth_kind=game.FishingSystem.FishingBalanceSystem.depth_for(power)
						var pool:Array=game.FishingSystem.cast_pool(game)
						var selected:Dictionary=game.FishingSystem._select_fish(game)
						expect(not pool.is_empty() and pool.any(func(fish): return fish.rarity=="common"),"basic fish remains obtainable in calendar/water/depth matrix")
						expect(selected in pool and selected==game.FishingSystem._select_fish(game),"unchanged cast tuple selects the same eligible fish")
						rows.append({"day":day,"weather":weather,"hour":hour,"water":water,"power":power,"fish":selected.id})
	report.calendar=rows; game.free()

## Проходит реальную мини-игру двоичным удержанием с упреждением инерции, не меняя рыбу, шкалы или исход.
func trial(day: int, power: float, controlled: bool) -> Dictionary:
	var game:=make_game(); game.day=day; game.game_minutes=720; game.state.world.weather="clear"; game.state.world.weather_day=day
	var state=game.state.fishing; state.total_caught=1; state.water_kind="pond"; state.cast_power=power
	state.depth_kind=game.FishingSystem.FishingBalanceSystem.depth_for(power); state.hook_grade="perfect"
	game.FishingSystem._start_minigame(game); var fish:String=state.fish_id; var seconds:=0.0
	for frame in 1800:
		if state.phase!=game.FishingSystem.PHASE_MINIGAME: break
		game.action_held=controlled and float(state.bar_y)-float(state.fish_y)+0.28*float(state.bar_velocity)>0
		game.FishingSystem.update(game,1.0/60.0); seconds+=1.0/60.0
	var result:={"day":day,"power":power,"initial_caught":1,"hour":12,"fish":fish,"controlled":controlled,"seconds":seconds,"caught":game.inventory_item_count("fish")}
	game.free(); return result

## Сценарий: одинаковые забросы проходят с управлением и без него после учебного первого улова.
## Исходное состояние: восемь воспроизводимых состояний, ни одной гарантированно выставленной шкалы.
## Ожидаемый результат: управляющий ввод позволяет завершить поручение, бездействие не выдаёт рыбу бесплатно.
func test_controlled_trials() -> void:
	var rows:Array=[]; var successes:=0
	for day in [1,8,15,22]:
		for power in [0.25,0.55]:
			var row:=trial(day,power,true); rows.append(row)
			if int(row.caught)>0: successes+=1
			var idle:=trial(day,power,false)
			expect(int(idle.caught)==0,"idle play never receives a guaranteed quest fish")
	expect(successes>=5,"at least five ordinary controlled catches are reachable without changing game difficulty")
	report.trials=rows; report.successes=successes; report.protocol="60 Hz input controller with inertia prediction; not a human success rate; no cast/bite/reaction time included"

## Сценарий: наживка сокращает ожидание, улучшенная снасть открывает глубоководную рыбу.
## Исходное состояние: сначала обычная снасть, затем отдельно выданы тестовые талант и улучшенная удочка.
## Ожидаемый результат: наживка расходуется один раз, новый вид недоступен базовой снасти и не требуется для пяти обычных рыб.
func test_bait_and_advanced_access() -> void:
	var game:=make_game(); var garden:=preload("res://scripts/systems/garden_crafting_system.gd")
	var wait:float=game.SkillSystem.fishing_wait(game); game.change_inventory_count("fishing_bait",1)
	expect(is_equal_approx(garden.cast_multiplier(game),0.65) and game.inventory_item_count("fishing_bait")==0,"one reserved bait reduces waiting by thirty-five percent")
	expect(garden.cast_multiplier(game)==1.0,"no second bait effect without another paid portion")
	game.state.fishing.water_kind="river"; game.state.fishing.depth_kind="deep"; game.state.fishing.cast_power=0.9
	var basic:Array=game.FishingSystem.cast_pool(game)
	expect(not basic.any(func(fish): return fish.id=="deep_pike"),"basic starter equipment excludes advanced pike")
	game.change_inventory_count("advanced_fishing_rod",1); game.talent_levels.fish_deep_water=1; game.talent_levels.fish_fine_rod=1
	var advanced:Array=game.FishingSystem.cast_pool(game)
	expect(advanced.any(func(fish): return fish.id=="deep_pike"),"advanced rod plus learned technique opens a real deep-water species")
	report.upgrades={"base_wait_seconds":wait,"bait_wait_seconds":wait*0.65,"pike_requires":["advanced_fishing_rod","fish_deep_water"],"trap_output":"crab","quest_item":"fish"}
	game.free()
