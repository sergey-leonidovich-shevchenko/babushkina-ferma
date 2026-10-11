extends "res://tests/suites/suite_base.gd"

const Visual := preload("res://scripts/systems/hero_visual_system.gd")
const Actions := preload("res://scripts/systems/hero_action_system.gd")
const Matte := preload("res://scripts/systems/sprite_matte_system.gd")


## Запускает проверки настоящего production-арта и общей опоры героя в мире и диагностике.
func run() -> void:
	test_cardinal_sources_and_constant_scale()
	test_feet_pivot_is_not_tool_bounding_box()
	test_alpha_and_safe_frame_padding()
	test_current_pose_and_attack_direction()


## Сценарий: герой идёт в четырёх направлениях и по диагоналям, затем копает во всех фазах.
## Исходное состояние: подключены реальные новые PNG с измеренными источниками, старые восьминаправленные hero-листы не используются.
## Ожидаемый результат: диагонали выбирают устойчивую сторону, источники целочисленны и масштаб каждого пикселя одинаков во всех позах.
func test_cardinal_sources_and_constant_scale() -> void:
	expect(Visual.profiles_are_valid(), "new hero production sources are inside both RGBA masters")
	for pair in [[Vector2(1,1),2], [Vector2(1,-1),2], [Vector2(-1,1),1], [Vector2(-1,-1),1], [Vector2.UP,3], [Vector2.DOWN,0]]:
		expect(Visual.direction_row(pair[0]) == pair[1], "four-direction hero has a deterministic diagonal view: %s" % pair[0])
	for direction in [Vector2.DOWN,Vector2.LEFT,Vector2.RIGHT,Vector2.UP]:
		for index in 4:
			var walking := Visual.walk_pose(direction, index/8.0, true)
			var action := Visual.hoe_pose(direction, [0.05,0.3,0.55,0.9][index])
			expect(walking.scale == Visual.DRAW_SCALE and action.scale == Visual.DRAW_SCALE, "walk and tool poses preserve one pixel density")
			for pose in [walking,action]:
				var source: Rect2 = pose.source
				expect(source.position == source.position.round() and source.size == source.size.round(), "hero source never samples fractional neighboring pixels")


## Сценарий: герой стоит в далёкой мировой точке, а мотыга поднимается и опускается вокруг него.
## Исходное состояние: кадры имеют разный bounding box из-за инструмента, но известна отдельная точка между ботинками.
## Ожидаемый результат: во всех кадрах точка стоп точно совпадает с физической позицией, без лишнего +24px или нормализации высоты.
func test_feet_pivot_is_not_tool_bounding_box() -> void:
	var ground := Vector2(1536,816)
	for direction in [Vector2.DOWN,Vector2.LEFT,Vector2.RIGHT,Vector2.UP]:
		for progress_value in [0.0,0.3,0.55,1.0]:
			var pose := Visual.hoe_pose(direction,progress_value)
			var rect := Visual.destination(ground,pose)
			expect((rect.position+Vector2(pose.pivot)*float(pose.scale)).is_equal_approx(ground), "hoe ground pivot stays exactly in physical position")
			expect(is_equal_approx(rect.size.x/Rect2(pose.source).size.x,rect.size.y/Rect2(pose.source).size.y), "hoe frame is never stretched or squashed")


## Сценарий: каждый кадр обоих листов проверяется после реальной опциональной обработки matte.
## Исходное состояние: импортированные PNG содержат прозрачность, crop учитывает вынос рук и инструмента.
## Ожидаемый результат: содержимое видно, а наружные края источника не содержат непрозрачных частей соседней фигуры.
func test_alpha_and_safe_frame_padding() -> void:
	for direction in [Vector2.DOWN,Vector2.LEFT,Vector2.RIGHT,Vector2.UP]:
		for index in 4:
			var frames := [Visual.walk_pose(direction,index/8.0,true),Visual.hoe_pose(direction,[0.05,0.3,0.55,0.9][index])]
			for pose in frames:
				var image := Matte.clean_texture(pose.texture).get_image().get_region(Rect2i(pose.source))
				expect(image.get_format()==Image.FORMAT_RGBA8 and not image.is_invisible(), "hero frame has real alpha and visible art")
				var safe := true
				for x in range(0,image.get_width(),3):
					safe = safe and image.get_pixel(x,0).a < 0.1 and image.get_pixel(x,image.get_height()-1).a < 0.1
				for y in range(0,image.get_height(),3):
					safe = safe and image.get_pixel(0,y).a < 0.1 and image.get_pixel(image.get_width()-1,y).a < 0.1
				expect(safe, "hero crop has no visible neighbor on its outer edge: %s" % pose.source)


## Сценарий: во время копания и удара герой меняет направление, затем открывается технический инспектор.
## Исходное состояние: активная поза сохраняет свой ракурс, физическая позиция героя известна.
## Ожидаемый результат: ракурс замаха не меняется, инспектор использует тот же прямоугольник, и визуальный код не толкает героя.
func test_current_pose_and_attack_direction() -> void:
	var game := make_game()
	game.player=Vector2(700,700); game.facing=Vector2.LEFT
	Actions.begin(game,"hoe",Vector2(652,700))
	Actions.update(game,0.24)
	game.facing=Vector2.RIGHT
	var pose:=Visual.current_pose(game,game.facing,false)
	expect(pose.source==Visual.hoe_pose(Vector2.LEFT,0.5).source,"tool body keeps the direction captured at action start")
	var objects:Array[Dictionary]=[]
	game.DebugObjectInspectorSystem.append_player(game,objects)
	expect(objects[0].bounds==Visual.destination(game.player,pose),"debug outline matches the current drawn hero pose")
	game.facing=Vector2.UP
	game.WeaponSystem.begin_attack(game,true)
	game.facing=Vector2.DOWN
	expect(game.get_meta("attack_visual_direction")==Vector2.UP and game.player==Vector2(700,700),"attack snapshot preserves direction without visual position teleport")
	game.free()
