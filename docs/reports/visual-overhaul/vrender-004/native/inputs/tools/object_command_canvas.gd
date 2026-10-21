extends Node2D

const Command := preload("res://scripts/presentation/object_draw_command.gd")
const Replay := preload("res://scripts/presentation/object_draw_replay.gd")
const Points := preload("res://tools/visual_camera_points.gd")
var game: Node
var packet := {}
var submitted := {}
var legacy := true
var scope_world := "overworld"
var scope_layer := "behind_actors"
var observe := false
var records := []
var fallback_calls := 0

## В отдельном QA-узле сравнивает реальный draw с командой, сохраняя полный мир и материалы.
func _draw() -> void:
	var before: Dictionary=game.SaveSystem.snapshot(game) if observe else {}
	var own:=material;var parent_material:Material=game.material;var previous:=transform;var count:=fallback_calls
	var result:="legacy"
	if legacy: _legacy()
	else: result=Replay.draw(self,submitted,scope_world,scope_layer,_fallback)
	if observe:
		records.append({"before":before,"after":game.SaveSystem.snapshot(game),"result":result,"fallback_calls":fallback_calls-count,
			"own_material_equal":own==material,"parent_material_equal":parent_material==game.material,"transform_equal":previous==transform,
			"frame":Engine.get_process_frames(),"packet":describe(packet),"submitted_valid":Command.valid(submitted)})

## Использует именно прежние CanvasItem-команды, независимо от неисправного нового пакета.
func _legacy() -> void:
	if packet.source==Rect2(Vector2.ZERO,packet.texture.get_size()): draw_texture_rect(packet.texture,packet.bounds,false,packet.modulate)
	else: draw_texture_rect_region(packet.texture,packet.bounds,packet.source,packet.modulate)

## Считает только действительные возвраты к старому пути, не заменяя их ожидаемым результатом.
func _fallback() -> void:
	fallback_calls+=1;_legacy()

## Экспортирует координаты и идентичность ресурсов без записи объектов игры в JSON.
static func describe(value: Dictionary) -> Dictionary:
	return {"version":value.version,"id":value.id,"world":value.world,"space":value.space,"anchor":Points.pair(value.anchor),
		"bounds":rect(value.bounds),"source":rect(value.source),"local_uv":rect(value.local_uv),"layer":value.layer,
		"modulate":[value.modulate.r,value.modulate.g,value.modulate.b,value.modulate.a],
		"texture_path":value.texture.resource_path,"texture_size":Points.pair(value.texture.get_size()),
		"material_id":value.material.get_instance_id() if value.material!=null else 0}

## Сохраняет прямоугольник числовыми значениями вместо строкового представления Variant.
static func rect(value: Rect2) -> Array:
	return [value.position.x,value.position.y,value.size.x,value.size.y]
