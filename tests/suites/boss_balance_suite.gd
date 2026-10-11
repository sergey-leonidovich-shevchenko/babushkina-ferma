extends "res://tests/suites/suite_base.gd"

const Boss := preload("res://scripts/systems/cave_boss_system.gd")
const Data := preload("res://scripts/systems/cave_boss_data.gd")
const Arena := preload("res://scripts/systems/cave_boss_arena_system.gd")

## Проверяет бюджет обычного оружия, честную передышку всей группы и сохранение старого процента HP.
func run() -> void:
	test_ordinary_spear_has_finite_damage_and_durability_budget()
	test_phase_grace_cancels_minion_windups()
	test_legacy_health_fraction_and_walkable_escape()

## Сценарий: герой первого уровня без усилений наносит последовательные удары железным копьём.
## Исходное состояние: у босса 180 HP, оружие имеет 100 прочности и обычную перезарядку.
## Ожидаемый результат: три стадии требуют 48 успешных ударов; прочность достаточна, мгновенный повтор запрещён.
func test_ordinary_spear_has_finite_damage_and_durability_budget() -> void:
	var game := make_game(); Boss.configure_preview(game); Arena.activate(game)
	var index := Boss.index(game)
	game.player=game.enemy_nodes[index].position+Vector2(80,0)
	expect(game.player_max_hp==100 and game.CombatSystem.player_attack_damage(game)==3,"ordinary spear loadout has no hidden armor or damage boost")
	var hits := 0; var phases := {}
	while game.enemy_nodes[index].alive and hits<60:
		phases[Data.phase(game.enemy_nodes[index].hp)]=true
		expect(game.attack_nearest_enemy(),"ordinary spear hit accepted after recovery")
		expect(not game.attack_nearest_enemy(),"same-tick duplicate hit is blocked")
		game.AnimationSystem.update(game,0.68); hits+=1
	expect(hits==48 and phases.size()==3,"normal critical cadence crosses all three stages in a finite 48-hit budget")
	expect(int(game.state.inventory.durability.iron_spear)==52,"one ordinary spear lasts through the whole boss without repair")
	game.free()

## Сценарий: порог стадии пересекается за мгновение до удара и выпуска мухи зомби.
## Исходное состояние: призыв уже появился, замахи активны, игрок уязвим и без брони.
## Ожидаемый результат: оба замаха отменяются; две секунды не дают скрытого урона, затем сохраняется полное новое предупреждение.
func test_phase_grace_cancels_minion_windups() -> void:
	var game := make_game(); Boss.configure_preview(game); Arena.activate(game)
	Boss.Minions.summon(game,["zombie"])
	var minion: Dictionary = game.state.world.cave_boss.minions[0]
	minion.emerge=0; minion.position=game.player+Vector2(50,0); minion.attack=0.1; minion.fly_windup=0.1
	game.CombatSystem.apply_damage(game,Boss.index(game),60)
	var hp: int = game.player_hp
	Boss.update(game,2.0)
	expect(game.player_hp==hp and minion.attack==0 and minion.fly_windup==0,"transition cancels both contact and fly windups")
	expect(game.state.world.cave_boss.projectiles.is_empty() and game.state.world.cave_boss.transition>0,"no delayed summon projectile bypasses the recovery")
	Boss.update(game,0.4)
	expect(game.player_hp==hp and minion.cooldown>0,"resumed summon must start a fresh complete warning")
	game.free()

## Сценарий: сохранение старого босса переносится в новый баланс, герой пешком выходит из замаха.
## Исходное состояние: старый максимум 120, остаётся треть HP; предупреждение удара длится одну секунду.
## Ожидаемый результат: стадия и доля HP сохраняются; обычной скорости хватает выйти без телепорта и бессмертия.
func test_legacy_health_fraction_and_walkable_escape() -> void:
	expect(Data.restored_hp({"hp":40,"max_hp":120},34)==60 and Data.phase(60)==3,"old third phase migrates to the same health fraction")
	expect(Data.restored_hp({"hp":0,"max_hp":120},34)==0,"old victory remains a victory")
	var game := make_game(); Boss.configure_preview(game); Arena.activate(game)
	var index := Boss.index(game)
	game.player=game.enemy_nodes[index].position+Vector2(80,0)
	Boss.Attacks.begin(game,"slam",game.enemy_nodes[index])
	var hp: int = game.player_hp
	Boss.Attacks.update(game,index,0.25)
	for _step in 45: game.NavigationSystem.move(game,Vector2.RIGHT*game.speed/60.0)
	Boss.Attacks.update(game,index,0.8)
	expect(game.player_hp==hp and game.player.distance_to(game.enemy_nodes[index].position)>146,"250ms reaction plus normal walking escapes the announced slam")
	game.free()
