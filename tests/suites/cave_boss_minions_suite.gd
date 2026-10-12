extends "res://tests/suites/suite_base.gd"

const Boss := preload("res://scripts/systems/cave_boss_system.gd")
const Data := preload("res://scripts/systems/cave_boss_data.gd")
const Minions := preload("res://scripts/systems/cave_boss_minion_system.gd")
const Shots := preload("res://scripts/systems/cave_boss_projectile_system.gd")

## Запускает сценарии появления нежити, прямолинейных мух, укусов и всех способов нанесения урона.
func run() -> void:
	test_summons_are_limited_safe_and_animate_before_attacking()
	test_zombie_fly_locks_direction_and_detects_swept_hit()
	test_random_bites_are_small_finite_and_do_not_stack()
	test_dodge_block_and_pause_control_fly_damage()
	test_weapons_spells_and_companions_can_hit_summons()
	test_boss_scheduler_summons_stage_specific_creatures()

## Создаёт бой с одним выбранным призванным существом и отключённым замахом босса.
func battle(kind: String = "zombie") -> Node:
	var game := make_game(); game.current_location = Data.LOCATION; game.player = Vector2(1584,600)
	Boss.start(game); Minions.summon(game,[kind])
	return game

## Сценарий: призывы появляются из земли или прилетают, не заполняя арену бесконечно.
## Исходное состояние: на арене запрашиваются скелеты, зомби и вампиры, включая лишнюю волну.
## Ожидаемый результат: одновременно живут максимум четыре существа, появление неуязвимо и не наносит урона.
func test_summons_are_limited_safe_and_animate_before_attacking() -> void:
	var game := battle("skeleton")
	Minions.summon(game,["zombie","vampire","skeleton","zombie"])
	expect(Minions.living_count(game) == 4 and Minions.summon(game,["zombie"]) == 0,"summon cap includes emerging creatures and rejects a fifth")
	for minion in game.state.world.cave_boss.minions:
		expect(Boss.Attacks.safe(game,minion.position) and game.player.distance_to(minion.position) >= 145.0,"summon emerges on safe dry ground away from the hero")
		expect(float(minion.emerge) == 1.25,"summon receives its own full emergence animation")
	expect(not Minions.damage(game,0,100),"emerging skeleton cannot skip resurrection by taking damage")
	expect(not Minions.safe_floor(game,Vector2(1848,972)) and Minions.safe_floor(game,Vector2(1944,792)),"summons cannot stand on the sanctuary column base")
	var hp: int = game.player_hp
	Minions.update(game,0.6)
	expect(game.player_hp == hp and game.state.world.cave_boss.minions.all(func(minion): return float(minion.emerge)>0.0),"emergence does not include hidden AI attacks")
	Minions.update(game,0.7)
	expect(game.state.world.cave_boss.minions.all(func(minion): return float(minion.emerge)==0.0),"all creature types finish emergence and become vulnerable")
	Minions.damage(game,0,100); Minions.update(game,1.1)
	expect(Minions.living_count(game) == 3 and Minions.summon(game,["zombie"]) == 1,"death animation frees a slot for a later wave")
	game.free()

## Сценарий: зомби запоминает цель броска, а муха летит по прямой и не пролетает сквозь героя в большом кадре.
## Исходное состояние: зомби готов к броску; герой перемещается после начала предупреждения.
## Ожидаемый результат: направление остаётся прежним, пересечение отрезка прикрепляет муху на две–пять секунд.
func test_zombie_fly_locks_direction_and_detects_swept_hit() -> void:
	var game := battle(); var minion: Dictionary = game.state.world.cave_boss.minions[0]
	minion.emerge=0.0; minion.position=Vector2(1700,560); minion.fly_cooldown=0.0; game.player=Vector2(1800,560)
	expect(Minions.update_fly(game,minion,0.1) and minion.fly_target == game.player,"zombie begins a readable fixed-target fly windup")
	game.player=Vector2(1800,700); Minions.update_fly(game,minion,0.7)
	var shot: Dictionary = game.state.world.cave_boss.projectiles[0]
	expect(Vector2(shot.direction).is_equal_approx(Vector2.RIGHT),"zombie fly ignores later changes in player position")
	Shots.update(game,0.2)
	expect(Vector2(shot.direction).is_equal_approx(Vector2.RIGHT) and game.state.world.cave_boss.fly_timer == 0.0,"in-flight fly keeps its straight direction and misses an evading hero")
	game.state.world.cave_boss.projectiles.clear(); game.player=Vector2(1800,560)
	Shots.launch(game,Vector2(1700,560),Vector2.RIGHT,0,"fly",215.0); Shots.update(game,2.0)
	expect(game.state.world.cave_boss.projectiles.is_empty() and float(game.state.world.cave_boss.fly_timer)>=2.0 and float(game.state.world.cave_boss.fly_timer)<=5.0,"swept collision catches the hero during a large frame and attaches a finite fly")
	game.free()

## Сценарий: случайные укусы понемногу отнимают здоровье и не складываются от нескольких мух.
## Исходное состояние: герой многократно получает муху, затем проходит эффект с длительностью 3,4 секунды.
## Ожидаемый результат: длительности различаются в диапазоне 2–5 секунд, урон равен одному HP за полную секунду.
func test_random_bites_are_small_finite_and_do_not_stack() -> void:
	var game := battle(); var durations: Dictionary = {}
	for _sample in 24:
		game.state.world.cave_boss.fly_timer=0.0
		Shots.attach_fly(game)
		var duration := float(game.state.world.cave_boss.fly_timer)
		expect(duration>=2.0 and duration<=5.0,"random bite duration remains within the requested bounds")
		durations[snappedf(duration,0.1)]=true
	expect(durations.size()>1,"fly duration varies instead of always using one fixed value")
	game.state.world.cave_boss.fly_timer=0.0; Shots.attach_fly(game,3.4)
	expect(not Shots.attach_fly(game,5.0) and is_equal_approx(float(game.state.world.cave_boss.fly_timer),3.4),"a second attached fly cannot stack damage or extend duration")
	var hp: int = game.player_hp
	Shots.update_bites(game,0.9); expect(game.player_hp==hp,"fly does not inflict damage before a full bite interval")
	Shots.update_bites(game,0.2); expect(game.player_hp==hp-1,"one full second costs only one health point")
	Shots.update_bites(game,10.0)
	expect(game.player_hp==hp-3 and game.state.world.cave_boss.fly_timer==0.0,"large elapsed time applies only the three earned bites and expires the effect")
	Shots.update_bites(game,2.0); expect(game.player_hp==hp-3,"expired fly cannot continue dealing damage")
	game.free()

## Сценарий: уклонение, блок и пауза рюкзака защищают от нечитаемого урона мух.
## Исходное состояние: герой выполняет рывок, затем блокирует бросок и открывает рюкзак во время укусов.
## Ожидаемый результат: рывок и блок отражают муху, меню замораживает здоровье и все таймеры.
func test_dodge_block_and_pause_control_fly_damage() -> void:
	var game := battle(); game.state.player.dodge_timer=0.3
	expect(not Shots.attach_fly(game,3.0),"dodge invulnerability prevents fly attachment")
	game.state.player.dodge_timer=0.0; game.state.player.blocking=true; var energy: int = game.energy
	expect(not Shots.attach_fly(game,3.0) and game.energy==energy-1,"blocking rejects the fly and spends one energy")
	game.state.player.blocking=false; Shots.attach_fly(game,2.8)
	game.inventory_open=true; var hp: int = game.player_hp
	Boss.update(game,5.0)
	expect(game.player_hp==hp and is_equal_approx(float(game.state.world.cave_boss.fly_timer),2.8),"backpack pauses active biting and emergence timers")
	game.inventory_open=false; Boss.update(game,1.01)
	expect(game.player_hp==hp-1 and float(game.state.world.cave_boss.fly_timer)<1.8,"closing backpack resumes biting from the same moment")
	game.free()

## Сценарий: новые существа являются настоящими боевыми целями для оружия, магии и напарников.
## Исходное состояние: уязвимый зомби стоит ближе хранителя, герой вооружён мечом и имеет ману.
## Ожидаемый результат: выбор цели поражает зомби, магия и напарник работают, тело блокирует проход.
func test_weapons_spells_and_companions_can_hit_summons() -> void:
	var game := battle(); var minion: Dictionary = game.state.world.cave_boss.minions[0]
	minion.emerge=0.0; minion.position=Vector2(1644,600)
	game.change_inventory_count("sword",1); game.InventorySystem.equip(game,"sword")
	var hp := int(minion.hp)
	expect(game.attack_nearest_enemy() and int(minion.hp)==hp,"normal player attack chooses a nearer summon without early damage")
	expect(game.player_attack_cooldown>0.0 and not game.attack_nearest_enemy(),"summon attacks obey the same weapon cooldown")
	game.WeaponSystem.update(game,game.WeaponSystem.attack_duration(game)*0.43+0.001)
	expect(int(minion.hp)<hp,"nearer summon receives damage on contact")
	expect(float(minion.attack)==0.0 and float(minion.fly_windup)==0.0,"contact interrupts minion attack and fly release")
	expect(game.NavigationSystem.walkability_reason(game,minion.position)=="enemy","emerged summon has a real blocking footprint")
	game.SpellSystem.state(game).selected=0; game.player_mana=game.player_max_mana; hp=int(minion.hp)
	expect(game.SpellSystem.cast(game) and int(minion.hp)<hp,"arcane bolt targets a nearby summon")
	game.active_companions.assign(["mila"]); game.companion_positions.mila=game.player; hp=int(minion.hp)
	expect(game.CompanionSystem.attack_nearby(game) and int(minion.hp)<hp,"companion can strike a summon")
	minion.hp=12; game.SpellSystem.state(game).selected=2; game.player_mana=game.player_max_mana
	expect(game.SpellSystem.cast(game) and int(minion.hp)<12,"frost nova damages summons through its normal area attack")
	game.player=Vector2(minion.position)+Vector2(20,0); var before: Vector2 = game.player
	game.NavigationSystem.move(game,Vector2(60,0))
	expect(game.player.x>before.x,"hero can escape an existing minion overlap without crossing through its body")
	game.free()

## Сценарий: хранитель периодически призывает разные волны по мере потери здоровья.
## Исходное состояние: перед каждой стадией завершены атака и восстановление, таймер призыва истёк.
## Ожидаемый результат: предупреждение длится 1,2 секунды, виды волны соответствуют стадии, повтор не мгновенный.
func test_boss_scheduler_summons_stage_specific_creatures() -> void:
	var game := battle(); var index := Boss.index(game)
	for sample in [[Data.MAX_HP,["skeleton"]],[Data.MAX_HP/2,["zombie","vampire"]],[Data.MAX_HP/6,["skeleton","zombie","vampire"]]]:
		Boss.reset(game); game.enemy_nodes[index].hp=sample[0]; Boss.start(game)
		var state: Dictionary = game.state.world.cave_boss
		state.recovery=0.0; state.summon_timer=0.0
		Boss.update(game,0.05)
		expect(state.summoning>1.0 and state.minions.is_empty(),"guardian warns before creating a new wave")
		Boss.update(game,1.25)
		for kind in sample[1]: expect(state.minions.any(func(minion): return minion.kind==kind),"phase summons the requested undead type: " + kind)
		expect(state.summon_timer>19.0 and Minions.living_count(game)<=Data.MINION_LIMIT,"summoning has a real cooldown and bounded population")
	game.free()
