extends "res://tests/suites/suite_base.gd"

const Shots := preload("res://scripts/systems/enemy_projectile_system.gd")

## Запускает проверки настоящего контакта стрел, препятствий, паузы и завершения короткого стоп-кадра.
func run() -> void:
	test_all_ranged_families_can_miss_and_hit_once()
	test_windup_and_interruption()
	test_stationary_ranged_plant_uses_the_same_collision()
	test_obstacles_dodge_and_scene_change()
	test_hit_stop_releases_world_and_menu_stays_paused()
	test_all_fullscreen_windows_pause_combat()
	test_loading_clears_transient_shots()

## Создаёт изолированную боевую площадку с настоящими навигацией, ИИ и входящим уроном.
func fixture(kind: String) -> Node:
	var game:=make_game(); game.current_location="ranged_test"; game.player=Vector2(400,400)
	game.enemy_nodes=game.CombatSystem.default_enemies().filter(func(enemy): return enemy.kind==kind).slice(0,1)
	var enemy: Dictionary=game.enemy_nodes[0]
	enemy.location=game.current_location; enemy.position=Vector2(200,400); enemy.home=enemy.position; enemy.action_target=game.player
	enemy.attack_timer=99; enemy.attack_pending=false; game.FarmLifeSystem.state(game).cutscene=""; game.FarmLifeSystem.state(game).cutscene_timer=0
	return game

## Сценарий: каждый стрелок и маг фиксирует цель, а герой уходит в сторону до контакта.
## Исходное состояние: шесть дальних семейств запускают снаряды на одинаковой открытой площадке.
## Ожидаемый результат: отклонение от линии даёт промах, большой кадр не пропускает попадание и не повторяет урон.
func test_all_ranged_families_can_miss_and_hit_once() -> void:
	for kind in ["skeleton","pirate","drowned_captain","undead","sea_ghost","plant"]:
		var game:=fixture(kind); var enemy: Dictionary=game.enemy_nodes[0]; var hp: int=game.player_hp
		Shots.launch(game,enemy)
		expect(game.player_hp==hp and Shots.state(game).size()==1,"launch has a visible flight instead of immediate distance damage: "+kind)
		game.player+=Vector2(0,75); Shots.update(game,2)
		expect(game.player_hp==hp and Shots.state(game).is_empty(),"moving off the fixed shot trajectory avoids damage: "+kind)
		game.player=Vector2(400,400); Shots.launch(game,enemy); Shots.update(game,1)
		var hit_hp: int=game.player_hp
		expect(hit_hp<hp and Shots.state(game).is_empty(),"swept collision catches a real hit during a large frame: "+kind)
		Shots.update(game,1); expect(game.player_hp==hit_hp,"consumed shot cannot damage twice: "+kind)
		game.free()

## Сценарий: подготовка выстрела запоминает цель, удар героя прерывает ещё не выпущенный снаряд.
## Исходное состояние: скелет начинает замах; герой смещается, а в повторной попытке ранит стрелка.
## Ожидаемый результат: урон не происходит в момент отпускания, направление остаётся прежним, прерванный замах не стреляет.
func test_windup_and_interruption() -> void:
	var game:=fixture("skeleton"); var enemy: Dictionary=game.enemy_nodes[0]; enemy.attack_timer=0
	game.CombatSystem.update(game,0.01); expect(enemy.attack_pending and enemy.action_target==game.player,"archer windup captures the initial target")
	var hp: int=game.player_hp; game.player+=Vector2(0,80)
	game.CombatSystem.update(game,game.CombatSystem.attack_impact_delay("shoot")+0.01)
	expect(game.player_hp==hp and Shots.state(game).size()==1 and Vector2(Shots.state(game)[0].direction).is_equal_approx(Vector2.RIGHT),"release creates a fixed trajectory without re-aiming or immediate damage")
	game.CombatSystem.update(game,2); expect(game.player_hp==hp,"AI projectile also misses the evading player")
	game.player=Vector2(400,400); enemy.attack_timer=0; game.CombatSystem.update(game,0.01)
	game.CombatSystem.apply_damage(game,0,1); game.CombatSystem.update(game,0.4)
	expect(not enemy.attack_pending and Shots.state(game).is_empty(),"hurt reaction cancels an unreleased enemy shot")
	game.free()

## Сценарий: герой открывает любое полноэкранное игровое окно при летящем снаряде.
## Исходное состояние: стрелок начал атаку, мир имеет активный стоп-кадр и текущую позицию стрелы.
## Ожидаемый результат: рюкзак, кухня, лавка и остальные окна сохраняют здоровье, время, угрозы и остаток hit_stop.
func test_all_fullscreen_windows_pause_combat() -> void:
	for flag in ["inventory_open","shop_open","crafting_open","storage_open","forge_open","contract_open","quest_log_open","skill_menu_open","world_map_open"]:
		var game:=fixture("skeleton"); Shots.launch(game,game.enemy_nodes[0]); var before: Array=Shots.state(game).duplicate(true)
		var value: Dictionary=game.FarmLifeSystem.state(game); value.hit_stop=0.035; game.set(flag,true)
		var minutes: float=game.game_minutes
		game.GameLoop.physics_process(game,1)
		expect(Shots.state(game)==before and game.player_hp==game.player_max_hp and game.game_minutes==minutes and is_equal_approx(float(value.hit_stop),0.035),"fullscreen window pauses threats, world time and hit stop: "+flag)
		game.free()

## Сценарий: неподвижный колючий цветок стреляет после замаха и может промахнуться.
## Исходное состояние: герой находится в дальнем радиусе растения, затем уходит с первоначальной линии.
## Ожидаемый результат: ни замах, ни выпуск не наносят дистанционный урон; только физический контакт с зарядом повреждает героя.
func test_stationary_ranged_plant_uses_the_same_collision() -> void:
	var game:=fixture("skeleton"); game.enemy_nodes.clear(); game.player=Vector2(350,400)
	game.hazard_nodes=game.EnvironmentHazardSystem.default_hazards().filter(func(hazard): return hazard.kind=="thorn_bloom").slice(0,1)
	var hazard: Dictionary=game.hazard_nodes[0]; hazard.location=game.current_location; hazard.position=Vector2(200,400)
	game.EnvironmentHazardSystem.update(game,0.01); game.player+=Vector2(0,75)
	game.EnvironmentHazardSystem.update(game,0.49)
	expect(game.player_hp==game.player_max_hp and Shots.state(game).size()==1,"thorn bloom windup releases a travelling charge without radius damage")
	Shots.update(game,2); expect(game.player_hp==game.player_max_hp,"stationary shooting plant misses a sideways-moving player")
	game.player=Vector2(350,400); hazard.cooldown=0; game.EnvironmentHazardSystem.update(game,0.01); game.EnvironmentHazardSystem.update(game,0.48)
	Shots.update(game,1); expect(game.player_hp<game.player_max_hp,"stationary plant also damages only through actual projectile contact")
	game.free()

## Сценарий: герой использует уклонение, закрывается верстаком или уходит из локации.
## Исходное состояние: активные стрелы проверяются общей геометрией, а капитан находится во второй фазе.
## Ожидаемый результат: препятствие и смена карты убирают снаряд, уклонение не наносит урон и не крадёт монеты.
func test_obstacles_dodge_and_scene_change() -> void:
	var game:=fixture("drowned_captain"); var enemy: Dictionary=game.enemy_nodes[0]; enemy.hp=1; game.coins=20
	game.state.player.dodge_timer=1; Shots.launch(game,enemy); Shots.update(game,1)
	expect(game.player_hp==game.player_max_hp and game.coins==20 and Shots.state(game).is_empty(),"dodged captain shot is consumed without health or coin loss")
	game.state.player.dodge_timer=0; Shots.launch(game,enemy); game.current_location="forest"; Shots.update(game,0.1)
	expect(Shots.state(game).is_empty(),"leaving a room discards its old flying threats")
	game.current_location="overworld"; game.player=Vector2(708,960); enemy.position=Vector2(564,960); enemy.action_target=game.player
	Shots.launch(game,enemy); Shots.update(game,1)
	expect(game.player_hp==game.player_max_hp and Shots.state(game).is_empty(),"the actual workbench foundation stops a shot before the hero")
	game.free()

## Сценарий: попадание кратко останавливает мир, после чего реальный игровой цикл продолжает работу.
## Исходное состояние: стоп-кадр длится 35 мс; затем открывается и закрывается рюкзак.
## Ожидаемый результат: таймер заканчивается без внешнего обновления, мир оживает, меню сохраняет остаток паузы.
func test_hit_stop_releases_world_and_menu_stays_paused() -> void:
	var game:=fixture("skeleton"); var value: Dictionary=game.FarmLifeSystem.state(game); value.hit_stop=0.035
	game.FirstChapterSystem.state(game).completed=true
	var initial: float=game.get_meta("livestock_clock",0.0)
	for tick in 5: game.GameLoop.physics_process(game,1.0/60.0)
	expect(value.hit_stop==0.0 and float(game.get_meta("livestock_clock",0.0))>initial,"hit stop expires through the real loop and world updates resume")
	value.hit_stop=0.035; game.open_inventory(); game.GameLoop.physics_process(game,1)
	expect(is_equal_approx(float(value.hit_stop),0.035),"backpack freezes the remaining stop-frame timer")
	preload("res://scripts/systems/menu_hub_system.gd").close(game); game.GameLoop.physics_process(game,0.1)
	expect(value.hit_stop==0.0,"closing backpack resumes and completes the remaining hit stop")
	game.free()

## Сценарий: сохранение загружается поверх игры с активной стрелой.
## Исходное состояние: новая угроза существует только во временной памяти текущей комнаты.
## Ожидаемый результат: успешная загрузка очищает снаряд, повреждённый документ не изменяет угрозу.
func test_loading_clears_transient_shots() -> void:
	var game:=fixture("skeleton"); game.current_location="overworld"; game.player=game.FarmLifeSystem.MapData.START
	game.enemy_nodes[0].position=game.player-Vector2(120,0); game.enemy_nodes[0].action_target=game.player
	Shots.launch(game,game.enemy_nodes[0]); var document: Dictionary=game.SaveSystem.snapshot(game)
	var broken: Dictionary=document.duplicate(true); broken.hp="invalid"
	expect(not game.SaveSystem.apply(game,broken) and Shots.state(game).size()==1,"invalid load does not mutate the live projectile pool")
	expect(game.SaveSystem.apply(game,document) and Shots.state(game).is_empty(),"successful load discards transient enemy projectiles")
	game.free()
