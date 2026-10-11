extends RefCounted

const Data := preload("res://scripts/systems/livestock_data.gd")
const System := preload("res://scripts/systems/livestock_system.gd")
const Visual := preload("res://scripts/systems/livestock_visual_system.gd")
const Fence := preload("res://scripts/systems/fence_renderer.gd")
const Terrain := preload("res://scripts/systems/village_terrain_renderer.gd")

## Рисует животных, укрытия и ограды по глубине относительно героя, оставляя HUD свободным.
static func draw(game: Node2D, foreground: bool = false) -> void:
	if game.current_location!="overworld": return
	var records: Array[Dictionary] = []
	for prop in Data.PROPS: records.append({"kind":prop.kind,"position":prop.position,"frame":0,"flip":false})
	for animal in Data.ANIMALS:
		var pose := System.pose(game,animal)
		records.append({"kind":animal.kind,"position":pose.position,"frame":pose.frame,"flip":pose.flip,"animal":animal})
	for wall in Data.walls(): records.append({"wall":wall,"position":Vector2(wall.get_center().x,wall.end.y)})
	records.sort_custom(func(left,right): return left.position.y<right.position.y)
	for record in records:
		if (float(record.position.y)>game.player.y)!=foreground: continue
		if record.has("wall"):
			draw_fence(game,record.wall); continue
		Visual.draw(game,record.kind,record.frame,record.position,record.flip)
		if record.has("animal") and game.player.distance_to(record.position)<150:
			var memory: Dictionary=game.FarmLifeSystem.state(game).animals[record.animal.id]
			if int(memory.ready)>0:
				game.draw_ui_string(game.UI_FONT,record.position+Vector2(-32,-70),"+%d"%memory.ready,HORIZONTAL_ALIGNMENT_CENTER,64,13,Color("fff0bb"))
	if foreground and not bool(game.get_meta("capture_first_level_clean",false)): draw_status(game)

## Собирает ограду из существующих модулей; визуальный разрыв совпадает с физической калиткой.
static func draw_fence(game: Node2D, wall: Rect2) -> void:
	var vertical := wall.size.y>wall.size.x
	var length := wall.size.y if vertical else wall.size.x
	var count := maxi(1,ceili(length/24.0))
	for index in count:
		var offset := float(index)*24.0
		var step := minf(24.0,length-offset)
		var anchor := wall.position+Vector2(wall.size.x*0.5,offset+step) if vertical else wall.position+Vector2(offset+step*0.5,wall.size.y)
		var size := Vector2(16,step+8) if vertical else Vector2(step,28)
		game.draw_texture_rect_region(Fence.ATLAS,Rect2(anchor-Vector2(size.x*0.5,size.y),size),Terrain.fence_source(2 if vertical else 1))

## Показывает состояние ухода у ближайших кормушки и воды без постоянных подписей над всеми животными.
static func draw_status(game: Node2D) -> void:
	var value: Dictionary=game.FarmLifeSystem.state(game)
	for record in [{"position":Data.TROUGH,"field":"fed_day","label":"livestock_feed_hint"},{"position":Data.WATER,"field":"water_day","label":"livestock_water_hint"}]:
		if game.player.distance_to(record.position)>150: continue
		var complete: bool=value.animals.values().all(func(memory): return int(memory[record.field])==game.day)
		game.draw_ui_string(game.UI_FONT,record.position+Vector2(-80,20),("✓ " if complete else "E · ")+game.LocaleSystem.text(record.label),HORIZONTAL_ALIGNMENT_CENTER,160,12,Color("fff0bd"))
