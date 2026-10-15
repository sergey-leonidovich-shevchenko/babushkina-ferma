extends "res://tests/suites/suite_base.gd"

const Availability := preload("res://scripts/systems/npc_availability_system.gd")
const Regions := preload("res://scripts/systems/village_region_system.gd")
const Journal := preload("res://scripts/systems/quest_journal_system.gd")

## Проверяет распорядок, услуги, журнал и отсутствие видимых скачков жителя.
func run() -> void:
	test_schedule_matrix_and_load_policy()
	test_visible_departure_waits_and_journal_reports_actual_place()

## Сценарий: первая глава продолжается утром, днём, вечером и ночью при любой погоде.
## Исходное состояние: пять деревенских жителей и три открытые услуги без QA-выдачи предметов.
## Ожидаемый результат: жители находятся на доступном полу, услуги открываются, JSON восстанавливает тот же распорядок.
func test_schedule_matrix_and_load_policy() -> void:
	var game := make_game(); var loaded := make_game()
	for weather in ["clear","rain","storm","snow","wind"]:
		for day in range(1,113):
			if game.WorldEventSystem.weather_for_day(day) == weather: game.day = day; break
		for hour in [6,12,18,23]:
			game.current_location = "forest"; game.game_minutes = hour*60
			game.state.world.weather_day = game.day; game.state.world.weather = weather
			game.NpcMovementSystem.initialize(game); game.NpcMovementSystem.update(game,0)
			var places := {}
			for npc_id in game.NpcMovementSystem.VILLAGE_HOME:
				var actor: Dictionary = game.npc_movement[npc_id]; places[npc_id] = Availability.location(game,npc_id)
				game.current_location = actor.location; game.player = actor.position
				expect(game.NavigationSystem.is_walkable(game,actor.position), "scheduled resident stands on free ground: " + npc_id)
				expect(game.QuestSystem.nearest_npc(game) == npc_id, "scheduled resident can actually be selected: " + npc_id)
			game.current_location = "forest"
			var data: Dictionary = JSON.parse_string(JSON.stringify(game.SaveSystem.snapshot(game)))
			expect(loaded.SaveSystem.apply(loaded,data), "ordinary save accepts the schedule matrix state")
			for npc_id in places: expect(Availability.location(loaded,npc_id) == places[npc_id], "load applies the same phase/weather policy: " + npc_id)
			for area in Regions.Data.SERVICES:
				for service in Regions.Data.SERVICES[area]:
					game.current_location = area; game.player = Regions.Data.SERVICES[area][service]
					expect(Regions.use_service(game,service), "fixed service remains available independent of resident rest")
					game.shop_open = false; game.crafting_open = false
	game.free(); loaded.free()

## Сценарий: на глазах наступает ночь, затем герой уходит из района и ищет заказчика через журнал.
## Исходное состояние: Агафья видна в саду, миссия активна, глава ждёт её поручение.
## Ожидаемый результат: житель не исчезает перед камерой, позднее уходит в дом, журнал и цель показывают фактическое место.
func test_visible_departure_waits_and_journal_reports_actual_place() -> void:
	var game := make_game(); game.current_location = "forest"; game.game_minutes = 12*60
	game.state.world.weather_day = game.day; game.state.world.weather = "clear"
	game.NpcMovementSystem.initialize(game); game.NpcMovementSystem.update(game,0)
	var actor: Dictionary = game.npc_movement.agafya; var position: Vector2 = actor.position
	game.current_location = actor.location; game.player = position + Vector2(0,70); game.camera_offset = position-Vector2(576,324)
	game.game_minutes = 23*60; game.NpcMovementSystem.update(game,1.0)
	expect(actor.position == position and actor.location == "village_garden" and actor.schedule_deferred, "visible departure cannot snap through a wall or vanish")
	expect(Availability.hint(game,"agafya").contains("пока здесь"), "journal explains a visible delayed departure")
	game.current_location = "forest"; game.NpcMovementSystem.update(game,0)
	expect(actor.location == "cottage_interior" and not actor.schedule_deferred, "offscreen night route reaches the actual home")
	game.mission_states.side_seed = game.QuestSystem.ACTIVE; game.FirstChapterSystem.state(game).stage = 5
	var before := JSON.stringify(game.SaveSystem.snapshot(game))
	for locale in game.LocaleSystem.LOCALES:
		game.LocaleSystem.current = locale
		var row: Dictionary = Journal.records(game).filter(func(record): return record.id == "side_seed")[0]
		expect(row.where.contains(game.LocaleSystem.location("cottage_interior")), "journal names the actual shelter in " + locale)
		expect(game.FirstChapterSystem.objective(game).contains(game.LocaleSystem.location("cottage_interior")), "first chapter follows Agafya's actual availability")
		expect(not Availability.hint(game,"agafya").contains("23:"), "schedule hint uses a phase instead of numeric HUD time")
	expect(JSON.stringify(game.SaveSystem.snapshot(game)) == before, "reading availability never moves actors or mutates the saved world")
	expect(game.QuestSystem.objective_region(game) == "cottage_interior", "active quest direction follows the scheduled giver")
	game.free()
