extends "res://tests/suites/suite_base.gd"

const Rng := preload("res://scripts/systems/world_rng_system.gd")
const Minions := preload("res://scripts/systems/cave_boss_minion_system.gd")
const Flies := preload("res://scripts/systems/cave_boss_projectile_system.gd")

## Проверяет раздельные потоки, настоящий бой, продолжение JSON-снимка и отказ повреждённого состояния.
func run() -> void:
	test_replay_and_cosmetic_independence()
	test_json_continuation_and_legacy()
	test_invalid_rng_is_rejected_before_mutation()
	test_versioned_sequence_and_ranges()

## Сценарий: одинаковый журнал боя повторяется с лишними вызовами косметической случайности.
## Исходное состояние: два одинаковых мира и третий мир с другим seed.
## Ожидаемый результат: положения призыва, длительности мух и добыча совпадают только у одинаковых seed.
func test_replay_and_cosmetic_independence() -> void:
	var a:=seeded(173); var b:=seeded(173); var c:=seeded(174)
	var first:=journal(a,false); var decorated:=journal(b,true)
	expect(first==decorated,"UI/global random calls never alter combat replay")
	expect(first!=journal(c,false),"different world seeds produce a different combat journal")
	expect(a.world_loot_nodes==b.world_loot_nodes,"equal seeds preserve all legacy loot and coordinates")
	var before:=Rng.snapshot(a); Rng.integer(a,"world",0,20); Rng.integer(a,"loot",0,20)
	expect(Rng.snapshot(a).streams.combat==before.streams.combat,"world and loot draws cannot advance combat")
	a.free(); b.free(); c.free()

## Сценарий: запись посередине журнала проходит настоящий JSON и производственный загрузчик.
## Исходное состояние: генераторы уже использованы, слот также содержит обычный прогресс и добычу.
## Ожидаемый результат: продолжение совпадает, старый слот без новых полей мигрирует без повторной выдачи.
func test_json_continuation_and_legacy() -> void:
	var a:=seeded(915); journal(a,false)
	var snapshot: Dictionary=a.SaveSystem.snapshot(a)
	var b:=seeded(300); var decoded: Dictionary=JSON.parse_string(JSON.stringify(snapshot))
	expect(b.SaveSystem.apply(b,decoded),"RNG survives JSON and the real loader")
	expect(journal(a,false)==journal(b,true),"save and continue matches uninterrupted journal")
	decoded.erase("rng"); var legacy:=seeded(333)
	expect(legacy.SaveSystem.apply(legacy,decoded) and legacy.coins==snapshot.coins and legacy.world_loot_nodes==b.world_loot_nodes,"legacy slot derives new streams without rerolling old loot or coins")
	var migrated: Dictionary=legacy.SaveSystem.snapshot(legacy); var restored:=seeded(15)
	expect(restored.SaveSystem.apply(restored,migrated) and Rng.snapshot(restored)==Rng.snapshot(legacy),"migrated state loads idempotently")
	a.free(); b.free(); legacy.free(); restored.free()

## Сценарий: неизвестная версия, дробь, ноль, лишний поток и несовпадающий seed в снимке.
## Исходное состояние: живой мир с валидным прогрессом.
## Ожидаемый результат: отказ происходит до любого изменения; внутренние копии не изменяют генераторы.
func test_invalid_rng_is_rejected_before_mutation() -> void:
	var game:=seeded(512); var before: Dictionary=game.SaveSystem.snapshot(game)
	for issue in ["version","fraction","zero","extra","seed","bool_version","nan"]:
		var bad: Dictionary=before.duplicate(true)
		match issue:
			"version": bad.rng.version=99
			"fraction": bad.rng.streams.combat=1.5
			"zero": bad.rng.streams.combat=0
			"extra": bad.rng.streams.other=12
			"seed": bad.rng.seed+=1
			"bool_version": bad.rng.version=true
			"nan": bad.rng.seed=NAN
		expect(not game.SaveSystem.apply(game,bad) and game.SaveSystem.snapshot(game)==before,"invalid RNG rejects atomically: "+issue)
	var copy:=Rng.snapshot(game); copy.streams.combat=1
	expect(Rng.snapshot(game)==before.rng,"external state snapshots do not mutate the world")
	game.free()

## Сценарий: фиксированный контракт версии один и большое число выборов из небольшого диапазона.
## Исходное состояние: seed один, затем перезапуск того же seed после проверки контрольной последовательности.
## Ожидаемый результат: версия формата меняется только явно, числа всегда входят в заявленные границы.
func test_versioned_sequence_and_ranges() -> void:
	var game:=seeded(1); var values: Array=[]
	for index in 8: values.append(Rng.next(game,"combat"))
	expect(values==[498995007,811398145,1193103309,1073383493,956639434,601257173,43508678,2115872619],"version one keeps its fixed golden sequence")
	var bounded:=true
	for index in 1000:
		var value:=Rng.integer(game,"combat",-7,11); bounded=bounded and value>=-7 and value<=11
	expect(bounded,"all integer samples stay in their inclusive range")
	game.free()

## Создаёт настоящий мир с заданным seed до генерации контейнеров и безопасным положением на арене.
func seeded(value: int) -> Node:
	var game:=GameScript.new(); game.world_loot_seed=value; game._ready(); game.language_screen=false; game.title_screen=false
	game.current_location="cave_sanctum"; game.player=Vector2(1200,600); return game

## Исполняет фиксированный журнал игровых запросов; декоративные вызовы используют отдельную глобальную случайность.
func journal(game: Node, cosmetics: bool) -> Array:
	var events: Array=[]
	for index in 12:
		if cosmetics:
			for draw in 7: randf()
		var point:=Minions.spawn_position(game)
		game.state.world.cave_boss.fly_timer=0; Flies.attach_fly(game)
		events.append([point,game.state.world.cave_boss.fly_timer])
	return events
