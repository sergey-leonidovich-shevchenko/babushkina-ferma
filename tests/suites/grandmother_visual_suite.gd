extends "res://tests/suites/suite_base.gd"

const Visual := preload("res://scripts/systems/grandmother_visual_system.gd")
const DIRECTIONS := [Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT, Vector2.UP]
const FRAME_FPS := 8.0
const MAX_UPPER_SHIFT := Vector2(5.0, 4.0)


## Проверяет новый арт бабушки, источники кадров и общий профиль игрового рендера, диалогов и инспектора.
func run() -> void:
	test_four_direction_mapping_and_sources()
	test_constant_pixel_scale_and_actual_feet()
	test_alpha_padding_and_no_service_background()
	test_distinct_frames_and_stable_upper_body()
	test_runtime_portrait_and_inspector_use_new_profile()


## Сценарий: все восемь направлений движения выбирают четыре настоящих ракурса, включая устойчивые диагонали.
## Исходное состояние: новый мастер и production-описания доступны без создания игровой сцены.
## Ожидаемый результат: прямоугольники целочисленны, находятся в мастере, кадр покоя не зависит от времени.
func test_four_direction_mapping_and_sources() -> void:
	expect(Visual.profiles_are_valid(), "grandmother production profile is valid")
	for pair in [[Vector2.DOWN,0], [Vector2.LEFT,1], [Vector2.RIGHT,2], [Vector2.UP,3], [Vector2(-1,1),1], [Vector2(-1,-1),1], [Vector2(1,1),2], [Vector2(1,-1),2], [Vector2.ZERO,0]]:
		expect(Visual.direction_row(pair[0]) == pair[1], "grandmother cardinal and diagonal view: %s" % pair[0])
	var bounds := Rect2(Vector2.ZERO, Visual.MASTER.get_size())
	for direction in DIRECTIONS:
		var sources: Array[Rect2] = []
		for frame in 4:
			var pose := _pose(direction, frame)
			var source: Rect2 = pose.source
			expect(pose.texture == Visual.MASTER and bounds.encloses(source) and source.has_area(), "grandmother frame belongs to the new master")
			expect(source.position == source.position.round() and source.size == source.size.round(), "grandmother source uses integer pixels without adjacent-frame sampling")
			if not sources.has(source): sources.append(source)
		expect(sources.size() == 4, "grandmother owns four source frames in direction %s" % direction)
		expect(Visual.pose(direction, 0.0, false).source == Visual.pose(direction, 41.3, false).source, "grandmother idle holds one authored frame")


## Сценарий: бабушка шагает во всех фазах в произвольной мировой позиции.
## Исходное состояние: каждый кадр хранит измеренную точку стоп, масштаб задан один раз для всего мастера.
## Ожидаемый результат: опора равна legacy-позиции плюс 24 px, рисунок не растягивается, низ обуви близок к опоре.
func test_constant_pixel_scale_and_actual_feet() -> void:
	var position := Vector2(1536, 816)
	for direction in DIRECTIONS:
		for frame in 4:
			var pose := _pose(direction, frame)
			var destination: Rect2 = Visual.destination(position, pose)
			var scale_value := float(pose.scale)
			expect(is_equal_approx(scale_value, Visual.DRAW_SCALE) and scale_value > 0.0, "grandmother never rescales a single pose to its bounding box")
			expect((destination.position + Vector2(pose.pivot) * scale_value).is_equal_approx(position + Vector2(0,24)), "grandmother foot pivot follows the existing NPC world anchor exactly")
			expect(destination.size.is_equal_approx(Rect2(pose.source).size * scale_value), "grandmother keeps equal horizontal and vertical pixel density")
			var used := _frame_image(pose).get_used_rect()
			expect(absf(float(used.end.y) - Vector2(pose.pivot).y) * scale_value <= 3.0, "grandmother visible feet stay within three world pixels of the ground: %s/%d" % [direction,frame])


## Сценарий: runtime-очистка применяется к каждому из шестнадцати реальных кадров.
## Исходное состояние: проверяется та же очищенная текстура, которую использует production draw_pose.
## Ожидаемый результат: рисунок видим, рамка прозрачна, насыщенный зелёный и шахматный фон не образуют непрозрачную подложку.
func test_alpha_padding_and_no_service_background() -> void:
	for direction in DIRECTIONS:
		for frame in 4:
			var image := _frame_image(_pose(direction, frame))
			var bytes := image.get_data()
			expect(image.get_format() == Image.FORMAT_RGBA8 and not image.is_invisible(), "grandmother cleaned frame has real RGBA and visible art")
			var transparent_rim := true
			var green_pixels := 0
			for y in image.get_height():
				for x in image.get_width():
					var pixel := image.get_pixel(x, y)
					if x < 2 or y < 2 or x >= image.get_width()-2 or y >= image.get_height()-2:
						transparent_rim = transparent_rim and pixel.a < 0.1
					var offset := (y * image.get_width() + x) * 4
					if bytes[offset+3] > 25 and bytes[offset+1] > 215 and bytes[offset] < 65 and bytes[offset+2] < 80: green_pixels += 1
			var transparent_corners := true
			for corner in [Vector2i.ZERO, Vector2i(image.get_width()-8,0), Vector2i(0,image.get_height()-8), Vector2i(image.get_width()-8,image.get_height()-8)]:
				for y in 8:
					for x in 8:
						transparent_corners = transparent_corners and image.get_pixel(corner.x+x,corner.y+y).a < 0.1
			expect(transparent_rim and transparent_corners, "grandmother has safe padding and no opaque checkerboard backdrop: %s/%d" % [direction,frame])
			expect(green_pixels == 0, "grandmother matte leaves no visible service-green pixels: %s/%d count=%d" % [direction,frame,green_pixels])


## Сценарий: четыре фазы каждого ракурса сравниваются попарно, включая шов конца и начала цикла.
## Исходное состояние: силуэт головы и плеч измеряется в мировых пикселях относительно стоп, без подола и шагающих ног.
## Ожидаемый результат: фазы не дублируются, голова не скачет, верх тела не расширяется отдельными полосами.
func test_distinct_frames_and_stable_upper_body() -> void:
	for direction in DIRECTIONS:
		var images: Array[Image] = []
		var profiles: Array[Dictionary] = []
		for frame in 4:
			var pose := _pose(direction, frame)
			var image := _frame_image(pose)
			images.append(image); profiles.append(_upper_body(image, pose))
		for frame in 4:
			for other in range(frame+1,4):
				expect(images[frame].get_data() != images[other].get_data(), "grandmother phases are individually drawn: %s/%d-%d" % [direction,frame,other])
			var next := (frame+1)%4
			var shift: Vector2 = (Vector2(profiles[frame].center)-Vector2(profiles[next].center)).abs()
			var width_ratio := maxf(float(profiles[frame].width),float(profiles[next].width))/maxf(1.0,minf(float(profiles[frame].width),float(profiles[next].width)))
			expect(shift.x <= MAX_UPPER_SHIFT.x and shift.y <= MAX_UPPER_SHIFT.y, "grandmother upper body stays smooth across the walk seam: %s/%d-%d shift=%s" % [direction,frame,next,shift])
			expect(width_ratio <= 1.25, "grandmother upper silhouette does not stretch between phases: %s/%d-%d" % [direction,frame,next])


## Сценарий: бабушка идёт влево, пользователь открывает инспектор и сюжетный диалог.
## Исходное состояние: игра использует новый мастер со служебным RGB-фоном и неквадратными кадрами.
## Ожидаемый результат: рамка совпадает с текущей позой, портрет использует очищенную RGBA и не растягивает тело по горизонтали.
func test_runtime_portrait_and_inspector_use_new_profile() -> void:
	var game := make_game()
	var actor: Dictionary = game.npc_movement.grandmother
	actor.direction = Vector2.LEFT; actor.moving = true
	game.walk_animation_time = 0.28
	var objects: Array[Dictionary] = []
	game.DebugObjectInspectorSystem.append_npcs(game,objects)
	var matches := objects.filter(func(item: Dictionary) -> bool: return item.id == "npc:grandmother")
	expect(matches.size() == 1 and matches[0].bounds == Visual.destination(actor.position,Visual.pose(actor.direction,game.walk_animation_time,true)), "NPC inspector uses the same exact grandmother pose as the world renderer")
	var portrait: Dictionary = game.StoryUiRenderer.npc_portrait_layout(game,Rect2(20,20,180,180),"grandmother")
	var source: Rect2 = portrait.source
	var destination: Rect2 = portrait.destination
	expect(portrait.texture == Visual.texture() and portrait.texture != Visual.MASTER, "grandmother dialogue never draws the raw green master")
	expect(is_equal_approx(destination.size.x/source.size.x,destination.size.y/source.size.y), "grandmother dialogue portrait preserves its natural proportions")
	game.free()


## Даёт одну фазу не на самой границе кадра, исключая погрешность умножения времени.
func _pose(direction: Vector2, frame: int) -> Dictionary:
	return Visual.pose(direction, (frame + 0.05)/FRAME_FPS, true)


## Извлекает именно очищенный production-кадр; исходный файл и текстуры остальных жителей не меняются.
func _frame_image(pose: Dictionary) -> Image:
	return Visual.texture().get_image().get_region(Rect2i(pose.source))


## Измеряет верхние 45% непрозрачной фигуры, отсекая самую вершину платка и активный подол.
func _upper_body(image: Image, pose: Dictionary) -> Dictionary:
	var used := image.get_used_rect()
	var y_start := used.position.y + int(used.size.y * 0.05)
	var y_end := used.position.y + int(used.size.y * 0.50)
	var weighted := Vector2.ZERO
	var weight := 0.0
	var min_x := image.get_width()
	var max_x := 0
	for y in range(y_start,y_end):
		for x in range(used.position.x,used.end.x):
			var alpha := image.get_pixel(x,y).a
			if alpha <= 0.2: continue
			weighted += Vector2(x,y) * alpha; weight += alpha
			min_x = mini(min_x,x); max_x = maxi(max_x,x)
	var center := weighted/maxf(weight,1.0)
	return {"center":(center-Vector2(pose.pivot))*float(pose.scale), "width":maxi(1,max_x-min_x+1)*float(pose.scale)}
