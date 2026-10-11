extends "res://tests/suites/suite_base.gd"

const Combat := preload("res://scripts/systems/hero_combat_visual_system.gd")
const Visual := preload("res://scripts/systems/hero_visual_system.gd")
const Matte := preload("res://scripts/systems/sprite_matte_system.gd")

## Проверяет нарисованные фазы, общую опору и снимок направления текущего удара.
func run() -> void:
	test_full_body_phases_and_ground()
	test_snapshot_inspector_and_corrected_bow()
	test_side_bow_prepared_at_display_size()

## Сценарий: два боковых кадра из большого мастера подготавливаются сразу к экранному размеру.
## Исходное состояние: исходные измерения и мастер сохранены, обе стороны используют одну готовую пару спрайтов.
## Ожидаемый результат: дополнительное уменьшение в кадре не нужно, исходная опора и габариты сохраняются с точностью округления.
func test_side_bow_prepared_at_display_size() -> void:
	for index in 2:
		var entry: Dictionary = Combat.catalog()["bow-contact"].frames[index]
		var sprite := Combat.frame_texture("bow-contact",index)
		var expected := Vector2(entry.region[2],entry.region[3])*float(entry.scale)
		expect(float(entry.draw_scale)==1.0 and (sprite.get_size()-expected).abs().x<=0.5 and (sprite.get_size()-expected).abs().y<=0.5,"side bow prepared at native display dimensions")
		var pivot := Vector2(entry.draw_pivot[0],entry.draw_pivot[1])*float(entry.draw_scale)
		var original := Vector2(entry.pivot[0],entry.pivot[1])*float(entry.scale)
		expect(pivot.distance_to(original)<0.0001,"prepared bow preserves original measured ground pivot")
		expect(not sprite.get_image().is_invisible(),"prepared bow keeps visible transparent body")

## Сценарий: меч, копьё и лук выполняют четыре фазы во всех четырёх ракурсах.
## Исходное состояние: измеренные области трёх мастер-листов и два исправленных боковых кадра лука.
## Ожидаемый результат: 48 видимых прозрачных фаз сохраняют точку стоп и целочисленные источники.
func test_full_body_phases_and_ground() -> void:
	for kind in ["blade","spear","bow"]:
		for direction in [Vector2.DOWN,Vector2.LEFT,Vector2.RIGHT,Vector2.UP]:
			var sources := {}
			for progress in [0.05,0.3,0.68,0.95]:
				var pose := Combat.pose(kind,direction,progress)
				var rect := Visual.destination(Vector2(1536,816),pose)
				expect((rect.position+Vector2(pose.pivot)*float(pose.scale)).is_equal_approx(Vector2(1536,816)),"attack preserves physical ground pivot")
				var source: Rect2 = pose.source
				expect(Rect2(Vector2.ZERO,pose.texture.get_size()).encloses(source) and source.position == source.position.round(),"combat source lies inside its integer atlas region")
				var image := Matte.clean_texture(pose.texture).get_image().get_region(Rect2i(source))
				expect(not image.is_invisible() and image.detect_alpha()!=Image.ALPHA_NONE,"frame contains visible full body and real alpha")
				expect(pose.texture != Visual.WALK_MASTER,"weapon attack selects separately drawn body")
				sources[str(source)+str(pose.texture.get_rid())] = true
			expect(sources.size()==4,"all four phases have distinct drawn poses")

## Сценарий: во время замаха герой поворачивается, меняет оружие, затем натягивает лук в обе стороны.
## Исходное состояние: активное копьё смотрит влево, поздние боковые позы лука исправлены отдельным листом.
## Ожидаемый результат: снимок и инспектор совпадают, физика не меняется, отражение лука сохраняет стопы.
func test_snapshot_inspector_and_corrected_bow() -> void:
	var game := make_game()
	game.equipped_weapon="iron_spear"; game.facing=Vector2.LEFT; game.player=Vector2(1320,816)
	game.WeaponSystem.begin_attack(game,true); game.WeaponSystem.update(game,0.32)
	game.equipped_weapon="war_hammer"; game.facing=Vector2.RIGHT
	var pose := Visual.current_pose(game,game.facing,false)
	expect(pose.source == Combat.pose("spear",Vector2.LEFT,game.WeaponSystem.attack_progress(game)).source,"turn and equip do not replace attack snapshot")
	var objects: Array[Dictionary] = []
	game.DebugObjectInspectorSystem.append_player(game,objects)
	expect(objects[0].bounds == Visual.destination(game.player,pose),"inspector matches actual attacking body")
	expect(game.player == Vector2(1320,816),"visual evaluation never moves physical hero")
	game.WeaponSystem.update(game,1.0)
	expect(not Combat.active(game) and Visual.current_pose(game,game.facing,false).texture == Visual.WALK_MASTER,"finished attack returns to walking body")
	for progress in [0.68,0.95]:
		var left := Combat.pose("bow",Vector2.LEFT,progress)
		var right := Combat.pose("bow",Vector2.RIGHT,progress)
		expect(left.texture == Combat.frame_texture("bow-contact",0 if progress<0.78 else 1) and right.texture == left.texture,"side bow uses corrected standalone draw and release")
		expect(left.flip and not right.flip and is_equal_approx(left.pivot.x+right.pivot.x,right.source.size.x),"mirroring preserves shooting direction and foot anchor")
	expect(Combat.frame(0.60,"bow")==1 and Combat.frame(0.65,"bow")==2,"bow holds the drawn string before release")
	game.free()
