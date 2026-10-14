extends "res://tests/suites/suite_base.gd"

const Renderer := preload("res://scripts/systems/animation_renderer.gd")
const Visual := preload("res://scripts/systems/hero_visual_system.gd")
const FullActions := preload("res://scripts/systems/hero_action_visual_system.gd")
const FullCombat := preload("res://scripts/systems/hero_combat_visual_system.gd")
const DIRECTIONS := [Vector2.DOWN,Vector2.LEFT,Vector2.RIGHT,Vector2.UP]

## Проверяет отсутствие постоянного оружия, сохранение активных ударов и единственный инструмент в полных позах.
func run() -> void:
	test_equipped_weapon_hidden_during_idle_and_walk()
	test_active_attack_keeps_snapshot_without_duplicates()
	test_tools_and_fishing_keep_their_own_props()

## Сценарий: герой стоит или идёт с любым экипированным оружием и разными выбранными горячими слотами.
## Исходное состояние: атака закончилась, экипировка остаётся выбранной, таймер перезарядки ещё может быть активен.
## Ожидаемый результат: дополнительное оружие не рисуется ни в одном ракурсе и не вмешивается в обычное тело.
func test_equipped_weapon_hidden_during_idle_and_walk() -> void:
	var game:=make_game(); game.current_location="overworld"; game.hotbar_slots[0]="hoe"; game.hotbar_slots[1]="axe"
	for weapon in game.WeaponSystem.ORDER:
		game.equipped_weapon=weapon; game.player_attack_weapon=weapon; game.player_attack_timer=0; game.player_attack_cooldown=0.2
		for direction in DIRECTIONS:
			game.facing=direction
			for moving in [false,true]:
				game.clear_movement_keys(); game.move_left_held=moving
				game.PlayerSystem.record_motion(game,Vector2(-4,0) if moving else Vector2.ZERO)
				for slot in [0,1]:
					game.selected_hotbar=slot
					expect(Renderer.overlay_weapon(game).is_empty(),"equipped weapon has no idle or walk overlay: "+weapon)
					expect(Visual.current_pose(game,direction,moving).texture==Visual.WALK_MASTER,"ordinary movement keeps its unarmed body: "+weapon)
		game.WorldPolishRenderer.draw_held_weapon(game,weapon,game.player,Vector2.LEFT,-1.0)
		game.WorldPolishRenderer.draw_held_weapon(game,weapon,game.player,Vector2.LEFT,false)
	game.free()

## Сценарий: герой начинает атаку, затем меняет экипировку и направление до окончания замаха.
## Исходное состояние: все классы оружия, четыре фазы и четыре направления; часть оружия уже нарисована в полном теле.
## Ожидаемый результат: полный рисунок не получает дубликат, остальные клинки сохраняют свой слой и снимок до завершения атаки.
func test_active_attack_keeps_snapshot_without_duplicates() -> void:
	var game:=make_game()
	for weapon in ["none"]+game.WeaponSystem.ORDER:
		for direction in DIRECTIONS:
			game.equipped_weapon=weapon; game.facing=direction; game.WeaponSystem.begin_attack(game,true)
			game.equipped_weapon="axe" if weapon!="axe" else "crystal_sword"; game.facing=-direction
			var full:bool=weapon in ["forest_sword","iron_spear","bow"] or FullActions.WEAPONS.has(weapon)
			for progress in [0.0,0.25,0.65,0.95]:
				game.player_attack_timer=float(game.WeaponSystem.data(weapon).duration)*(1-progress)
				var actual:=Renderer.overlay_weapon(game)
				expect(actual==("" if full or weapon=="none" else weapon),"attack overlay matches its snapshot and full-body ownership: "+weapon)
				if full: expect(FullCombat.active(game) or not FullActions.current_pose(game).is_empty(),"active full-body attack still displays its weapon: "+weapon)
			game.WeaponSystem.update(game,2)
			expect(Renderer.overlay_weapon(game).is_empty() and Visual.current_pose(game,direction,false).texture==Visual.WALK_MASTER,"finishing an attack stows every weapon: "+weapon)
	game.free()

## Сценарий: экипированный топор соседствует с добычей, поливом и ожиданием поклёвки.
## Исходное состояние: успешные действия инструментов и настоящий заброс удочки; боевой таймер не активен.
## Ожидаемый результат: виден только инструмент текущей полной позы, после окончания работы и отмены рыбалки возвращается обычное тело.
func test_tools_and_fishing_keep_their_own_props() -> void:
	var game:=make_game(); game.equipped_weapon="axe"
	for action in FullActions.TOOLS:
		game.HeroActionSystem.begin(game,action,game.player+Vector2.LEFT*40)
		expect(Renderer.overlay_weapon(game).is_empty() and Visual.current_pose(game,Vector2.DOWN,false).kind==FullActions.TOOLS[action],"tool action has exactly its own body prop: "+action)
		game.HeroActionSystem.update(game,1)
		expect(Renderer.overlay_weapon(game).is_empty() and Visual.current_pose(game,Vector2.DOWN,false).texture==Visual.WALK_MASTER,"finished work does not restore equipped axe")
	game.current_location="overworld"; game.player=game.pond_position+Vector2(120,0); game.has_fishing_rod=true; game.action_held=true
	expect(game.FishingSystem.use_rod(game),"fishing starts through the real rod action")
	expect(Renderer.overlay_weapon(game).is_empty() and FullActions.current_pose(game).kind=="fishing","fishing charge does not display an equipped axe")
	game.action_held=false; game.FishingSystem.update(game,0.016); game.HeroActionSystem.update(game,1)
	expect(Renderer.overlay_weapon(game).is_empty() and FullActions.current_pose(game).kind=="fishing","waiting keeps only the rod")
	game.state.fishing.reset_cast()
	expect(Renderer.overlay_weapon(game).is_empty() and Visual.current_pose(game,Vector2.DOWN,false).texture==Visual.WALK_MASTER,"cancelled fishing returns to ordinary movement")
	game.free()
