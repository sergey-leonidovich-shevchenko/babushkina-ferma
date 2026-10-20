extends "res://tests/suites/suite_base.gd"

const Occlusion := preload("res://scripts/systems/tree_occlusion_system.gd")
const Visual := preload("res://scripts/systems/hero_visual_system.gd")
const Orchard := preload("res://scripts/systems/orchard_system.gd")
const Timber := preload("res://scripts/systems/tree_system.gd")


## Проверяет геометрию перекрытия, время появления и единственный передний проход каждого дерева.
func run() -> void:
	test_only_overlapping_foreground_trees_fade()
	test_fade_is_smooth_and_frame_rate_independent()
	test_current_hero_pose_and_world_coordinates()
	test_render_queue_prevents_opaque_duplicates()
	test_camera_culling_keeps_partial_crowns()
	test_fruit_and_timber_families_share_one_path()
	test_visibility_cache_is_transient_and_location_scoped()


## Сценарий: герой проходит за кроной, выходит перед стволом и затем уходит далеко на север или в сторону.
## Исходное состояние: дерево занимает 192×192 пикселя, известны реальное тело героя и отдельная линия земли.
## Ожидаемый результат: прозрачность нужна только при одновременном перекрытии тела и правильной глубине.
func test_only_overlapping_foreground_trees_fade() -> void:
	var tree := Rect2(400,400,192,192)
	var player := Vector2(496,530)
	var body := Rect2(player-Vector2(25,84),Vector2(50,83))
	expect(Occlusion.overlaps_hero(player,body,tree,592),"tree fades while its canopy covers the hero behind the trunk")
	expect(not Occlusion.overlaps_hero(Vector2(496,610),Rect2(471,526,50,83),tree,592),"tree stays opaque when hero is in front of its ground line")
	expect(not Occlusion.overlaps_hero(Vector2(496,150),Rect2(471,66,50,83),tree,592),"north of tree does not mean hidden when sprites do not overlap")
	expect(not Occlusion.overlaps_hero(Vector2(700,530),Rect2(675,446,50,83),tree,592),"tree does not fade when hero passes clear of its side")
	expect(not Occlusion.overlaps_hero(player,Rect2(),tree,592),"empty hero bounds do not hide decorative trees")


## Сценарий: одно и то же перекрытие проигрывается на 30, 60 и 120 FPS, затем герой выходит из кроны.
## Исходное состояние: дерево полностью непрозрачно, целевая alpha равна 0.34, переход занимает 0.20 секунды.
## Ожидаемый результат: промежуточное состояние видно, длительность одинакова, reduced motion отключает анимацию.
func test_fade_is_smooth_and_frame_rate_independent() -> void:
	var halfway := Occlusion.next_alpha(1.0,true,0.1)
	expect(halfway>Occlusion.HIDDEN_ALPHA and halfway<1.0,"tree opacity has a real intermediate fade state")
	for fps in [30,60,120]:
		var alpha := 1.0
		for frame in roundi(fps*0.2): alpha=Occlusion.next_alpha(alpha,true,1.0/fps)
		expect(is_equal_approx(alpha,Occlusion.HIDDEN_ALPHA),"tree fade duration is stable at %d FPS"%fps)
		for frame in roundi(fps*0.2): alpha=Occlusion.next_alpha(alpha,false,1.0/fps)
		expect(is_equal_approx(alpha,1.0),"tree restores original opacity at %d FPS"%fps)
	expect(Occlusion.next_alpha(1.0,true,0.0,true)==Occlusion.HIDDEN_ALPHA,"reduced motion reveals the hidden hero immediately")
	expect(Occlusion.next_alpha(Occlusion.HIDDEN_ALPHA,false,0.0,true)==1.0,"reduced motion restores the tree immediately")
	expect(Occlusion.next_alpha(halfway,true,-0.5)==halfway,"negative frame delta does not rewind opacity")


## Сценарий: герой в мировой точке проходит и копает во всех четырёх ракурсах при смещённой камере.
## Исходное состояние: renderer использует реальные frame/pivot нового HeroVisualSystem, а не старую квадратную заглушку.
## Ожидаемый результат: область тела внутри текущего изображения, сохраняет мировую опору и не реагирует на камеру.
func test_current_hero_pose_and_world_coordinates() -> void:
	var game := make_game()
	game.player=Vector2(1200,850)
	for direction in [Vector2.DOWN,Vector2.UP,Vector2.LEFT,Vector2.RIGHT]:
		game.facing=direction
		var body := Occlusion.hero_bounds(game)
		var frame := Visual.destination(game.player,Visual.current_pose(game,game.facing,false))
		expect(frame.encloses(body) and body.size.y>60.0,"occlusion body is inside current hero pose for %s"%direction)
		game.camera_offset=Vector2(600,420)
		expect(Occlusion.hero_bounds(game)==body,"camera scrolling does not move world-space occlusion bounds")
	game.free()


## Сценарий: один foreground-ствол случайно запрашивается двумя render-проходами в одном кадре.
## Исходное состояние: герой за деревом, очередь пуста; отрисовка GPU не нужна для проверки команд.
## Ожидаемый результат: создаётся ровно одна команда, крона и погодный overlay разделяют alpha, альфа не умножается дублем.
func test_render_queue_prevents_opaque_duplicates() -> void:
	var game := make_game()
	game.player=Vector2(496,530); game.settings_state.reduced_motion=true
	Occlusion.begin_frame(game,1.0/60.0)
	var rect := Rect2(400,400,192,192)
	Occlusion.submit(game,"same_tree",Orchard.TREE_ATLAS,rect,Orchard.source_rect("apple",3),592)
	Occlusion.submit(game,"same_tree",Orchard.TREE_ATLAS,rect,Orchard.source_rect("apple",3),592)
	var state:Dictionary=game.get_meta(Occlusion.META_KEY)
	expect(state.queue.size()==1,"one tree is queued only once even if an old duplicate render path calls it")
	expect(is_equal_approx(state.queue[0].tint.a,Occlusion.HIDDEN_ALPHA),"foreground packet actually contains the faded tint")
	expect(is_equal_approx(state.queue[0].alpha,state.queue[0].tint.a),"weather detail alpha matches its tree")
	Occlusion.begin_frame(game,1.0/60.0)
	expect(state.queue.is_empty() and state.seen.is_empty(),"new frame clears draw commands and duplicate keys")
	game.free()


## Сценарий: камера проходит через крону, частично видимые деревья касаются каждого края экрана.
## Исходное состояние: деревья отправляются в переднюю очередь при смещённой камере, ещё одно лежит далеко вне окна.
## Ожидаемый результат: крайние кроны остаются в очереди, дальнее дерево не создаёт команду и запись прозрачности.
func test_camera_culling_keeps_partial_crowns() -> void:
	var game := make_game(); game.player = Vector2(700, 800); game.camera_offset = Vector2(500, 600)
	game.settings_state.screen_shake_enabled = false
	Occlusion.begin_frame(game, 1.0 / 60.0)
	var state: Dictionary = game.get_meta(Occlusion.META_KEY)
	var view: Rect2 = state.visible_rect
	var partial: Array[Rect2] = [
		Rect2(view.position + Vector2(-90, 100), Vector2(100, 100)),
		Rect2(Vector2(view.end.x - 10, view.position.y + 100), Vector2(100, 100)),
		Rect2(view.position + Vector2(100, -90), Vector2(100, 100)),
		Rect2(Vector2(view.position.x + 100, view.end.y - 10), Vector2(100, 100)),
	]
	for index in partial.size():
		Occlusion.submit(game, "edge:%d" % index, Orchard.TREE_ATLAS, partial[index], Orchard.source_rect("apple", 3), 10000)
	Occlusion.submit(game, "outside", Orchard.TREE_ATLAS, Rect2(-900, -900, 192, 192), Orchard.source_rect("apple", 3), 10000)
	expect(state.queue.size() == 4, "camera culling keeps crowns intersecting all four viewport edges")
	expect(not state.entries.has("outside") and not state.seen.has("outside"), "off-camera tree avoids both draw packet and opacity bookkeeping")
	expect(not game.is_inside_tree(), "visibility regression really exercises a detached game node")
	var field:=preload("res://scripts/systems/world_projection_system.gd").field_size(game)
	expect(view.encloses(Rect2(game.camera_offset,field)), "detached game uses its projected world field with a safe edge margin")
	game.camera_offset += Vector2(2000, 0)
	Occlusion.begin_frame(game, 1.0 / 60.0)
	var new_state: Dictionary = game.get_meta(Occlusion.META_KEY)
	Occlusion.submit(game, "old_view", Orchard.TREE_ATLAS, partial[0], Orchard.source_rect("apple", 3), 10000)
	expect(new_state.queue.is_empty(), "moving camera refreshes culling bounds on the next frame")
	game.free()


## Сценарий: молодой и взрослый сад, рубимое дерево, лесная рамка, орешник и сезонный дуб перекрывают героя.
## Исходное состояние: каждый тип имеет собственную точку опоры и размер; стадии роста и урожай менять нельзя.
## Ожидаемый результат: один алгоритм поддерживает все семьи без подмены изображений, урожая или геометрии.
func test_fruit_and_timber_families_share_one_path() -> void:
	var game := make_game()
	game.settings_state.reduced_motion=true
	for stage in [1,2,3]:
		var position := Vector2(600,650)
		var rect := Orchard.destination_rect(position,stage)
		game.player=Vector2(600,rect.end.y-25)
		Occlusion.begin_frame(game,0.02)
		expect(Occlusion.opacity(game,"orchard",rect,position.y+18)==Occlusion.HIDDEN_ALPHA,"orchard stage %d reveals the overlapping hero"%stage)
	var tree:Dictionary={"position":Vector2(800,700),"stage":3,"health":3}
	var before := tree.duplicate(true)
	game.player=Vector2(800,700)
	Occlusion.begin_frame(game,0.02)
	for family in ["timber","border","nut","seasonal_village","forest_landmark","cursed_landmark"]:
		expect(Occlusion.opacity(game,family,Timber.destination_rect(tree),Timber.ground_anchor(tree.position).y)==Occlusion.HIDDEN_ALPHA,"shared fade handles %s tree"%family)
	expect(tree==before,"occlusion never changes tree health, position, stage or harvest")
	game.free()


## Сценарий: дерево исчезает из текущего кадра, затем герой переходит в другой биом и сохраняет игру.
## Исходное состояние: полупрозрачное дерево хранится только в metadata renderer-а, не в WorldState.
## Ожидаемый результат: устаревшие записи удаляются, переход сбрасывает кэш, сохранение не содержит визуальных таймеров.
func test_visibility_cache_is_transient_and_location_scoped() -> void:
	var game := make_game()
	game.player=Vector2(500,500)
	Occlusion.begin_frame(game,0.02)
	Occlusion.opacity(game,"gone",Rect2(410,410,192,192),602)
	var state:Dictionary=game.get_meta(Occlusion.META_KEY)
	state.entries.gone.seen_at=float(state.time)-1.0
	Occlusion.begin_frame(game,0.02)
	expect(state.entries.is_empty(),"tree visibility cache evicts objects not rendered for a short interval")
	Occlusion.opacity(game,"old_map",Rect2(410,410,192,192),602)
	game.current_location="forest"
	Occlusion.begin_frame(game,0.02)
	state=game.get_meta(Occlusion.META_KEY)
	expect(state.entries.is_empty() and state.location=="forest","moving to another location resets visual opacity state")
	var snapshot:Dictionary=game.SaveSystem.snapshot(game)
	expect(not str(snapshot).contains(Occlusion.META_KEY),"save snapshot does not contain transient tree opacity metadata")
	game.free()
