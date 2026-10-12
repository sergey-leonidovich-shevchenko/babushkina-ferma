extends "res://tests/suites/suite_base.gd"

const Actions := preload("res://scripts/systems/hero_action_visual_system.gd")
const Visual := preload("res://scripts/systems/hero_visual_system.gd")

## Проверяет самостоятельные полные позы, масштаб и приоритет боевого снимка над инструментом.
func run() -> void:
	test_native_frames_and_boot_anchor()
	test_tools_and_attack_snapshots()
	test_fishing_hold_then_release()

## Сценарий: каждый из шести инструментов проходит четыре фазы в четырёх направлениях.
## Исходное состояние: отдельные малые кадры и измеренные ботинки, выступающие инструменты не служат опорой.
## Ожидаемый результат: все 96 фигур прозрачны, имеют разные кадры, не требуют уменьшения и сохраняют физическую точку.
func test_native_frames_and_boot_anchor() -> void:
	for kind in Actions.catalog():
		for direction in [Vector2.DOWN,Vector2.LEFT,Vector2.RIGHT,Vector2.UP]:
			var ids := {}
			for progress in [0.05,0.3,0.68,0.95]:
				var pose := Actions.pose(kind,direction,progress)
				var sprite: Texture2D = pose.texture
				var image := sprite.get_image()
				var rect := Visual.destination(Vector2(540,720),pose)
				expect((rect.position+pose.pivot).is_equal_approx(Vector2(540,720)),"tool animation preserves measured boot anchor")
				expect(pose.scale==1.0 and sprite.get_width()<170 and sprite.get_height()<170,"production pose has native display dimensions")
				expect(image.detect_alpha()!=Image.ALPHA_NONE and not image.is_invisible(),"whole tool pose has genuine RGBA alpha")
				expect(pose.pivot.x>0 and pose.pivot.y>0 and pose.pivot.y<=sprite.get_height()+1,"measured boots lie inside sprite")
				ids[sprite.get_rid()] = true
			expect(ids.size()==4,"tool has four separately drawn phases")
	var contact := Actions.pose("pickaxe",Vector2.DOWN,0.55)
	expect(contact.pivot.y < contact.source.size.y-3,"pickaxe extending below boots cannot move the body")
	contact = Actions.pose("hammer",Vector2.DOWN,0.55)
	expect(contact.pivot.y < contact.source.size.y-3,"hammer impact remains below the physical boot anchor")

## Сценарий: герой работает четырьмя инструментами, затем поворачивается и меняет оружие во время замаха.
## Исходное состояние: успешное действие фиксирует направление; молот и посох имеют собственные полные тела.
## Ожидаемый результат: инструмент выбирает правильную фигуру, бой сохраняет снимок, завершение возвращает ходьбу.
func test_tools_and_attack_snapshots() -> void:
	var game := make_game()
	for action in Actions.TOOLS:
		game.HeroActionSystem.begin(game,action,game.player+Vector2.LEFT*40)
		game.HeroActionSystem.update(game,0.25)
		expect(Visual.current_pose(game,Vector2.UP,false).kind==Actions.TOOLS[action],"successful tool action selects full body")
		game.HeroActionSystem.update(game,1.0)
	for weapon in Actions.WEAPONS:
		game.equipped_weapon=weapon; game.facing=Vector2.LEFT
		game.WeaponSystem.begin_attack(game,true); game.WeaponSystem.update(game,0.25)
		game.facing=Vector2.RIGHT; game.equipped_weapon="bow"
		var actual := Visual.current_pose(game,game.facing,false)
		var expected := Actions.pose(Actions.WEAPONS[weapon],Vector2.LEFT,game.WeaponSystem.attack_progress(game))
		expect(actual.texture==expected.texture and Actions.combat_active(game),"weapon snapshot preserves full body and direction")
		game.WeaponSystem.update(game,2.0)
		expect(not Actions.combat_active(game) and Visual.current_pose(game,Vector2.DOWN,false).texture==Visual.WALK_MASTER,"finished tool combat returns to walk")
	expect(Actions.frame(0.60,"staff")==1 and Actions.frame(0.65,"staff")==2,"staff charge holds until actual release")
	game.free()

## Сценарий: герой выбирает силу заброса, отпускает действие и ждёт поклёвку.
## Исходное состояние: стартовая удочка у воды, направленная к воде поза сохраняется независимо от поворота.
## Ожидаемый результат: удержание не бросает удочку, отпускание запускает полное тело, ожидание сохраняет снасть в руках.
func test_fishing_hold_then_release() -> void:
	var game := make_game(); game.current_location="overworld"; game.player=game.pond_position+Vector2(120,0)
	game.facing=Vector2.RIGHT; game.has_fishing_rod=true; game.action_held=true
	expect(game.FishingSystem.use_rod(game),"rod starts actual cast charging")
	var pose := Actions.current_pose(game)
	expect(pose.texture==Actions.pose("fishing",Vector2.LEFT,0.3).texture,"charging aims toward water and holds windup")
	game.action_held=false; game.FishingSystem.update(game,0.016)
	pose=Actions.current_pose(game)
	expect(pose.frame==0 and game.HeroActionSystem.pose(game).direction==Vector2.LEFT,"release begins directed whole-body cast")
	game.HeroActionSystem.update(game,1.0)
	expect(Actions.current_pose(game).frame==3,"waiting holds rod after cast animation ends")
	game.state.fishing.reset_cast()
	expect(Actions.current_pose(game).is_empty(),"cancel fishing returns to ordinary movement")
	game.free()
