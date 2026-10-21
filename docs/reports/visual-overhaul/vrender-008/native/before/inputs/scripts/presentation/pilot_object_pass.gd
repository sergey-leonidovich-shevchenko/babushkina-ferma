extends RefCounted

const Command:=preload("res://scripts/presentation/object_draw_command.gd")
const Replay:=preload("res://scripts/presentation/object_draw_replay.gd")
const Board:=preload("res://scripts/presentation/village_board_visual.gd")
const Editor:=preload("res://scripts/systems/level_editor_system.gd")
const FLAG:=&"pilot_object_pass_enabled"
const TRACE:=&"pilot_object_pass_trace"
const SCOPE:=Rect2(240,312,960,576)
const POSITION:=Vector2(648,576)
const GROUND:=POSITION+Vector2(0,24)
const LAYER:="behind_actors"
static var _packets:={}
static var _builds:=0

## По умолчанию включает выбранный проход; неизвестное значение флага безопасно возвращает прежний путь.
static func enabled(game:Node)->bool:
	var value:Variant=game.get_meta(FLAG,true)
	return typeof(value)==TYPE_BOOL and value

## Ограничивает новый маршрут одним телом доски внутри эталонного участка и одной прежней фазой.
static func selected(game:Node,prop:Dictionary,foreground:bool)->bool:
	return game.current_location=="overworld" and not foreground and not Editor.active(game) and prop.get("kind","")=="board" and prop.get("position",Vector2.INF)==POSITION and SCOPE.encloses(Board.destination("board",GROUND))

## Кеширует не более трёх чистых read-only команд без ссылки на игру, callback, узел или очередь.
static func packet(direction:int=0)->Dictionary:
	var side:int=Board.Facing.visible(direction)
	if _packets.has(side):return _packets[side]
	var texture:Texture2D=Board.Resources.sampled_texture("prop.village_board",Board.Facing.NAMES[side])
	if texture==null:return {}
	var result:=Command.create({"version":1,"id":"pilot:board:648:576","world":"overworld","space":"world","anchor":GROUND,"bounds":Board.destination("board",GROUND,side),"texture":texture,"source":Rect2(Vector2.ZERO,texture.get_size()),"material":null,"modulate":Color.WHITE,"local_uv":Rect2(0,0,1,1),"layer":LAYER})
	if not result.is_empty():_packets[side]=result;_builds+=1
	return result

## Выполняет ровно выбранный проход либо старый callback; диагностика существует только по явному QA-запросу.
static func draw(game:Node2D,prop:Dictionary,foreground:bool,legacy:Callable)->String:
	var trace:Variant=game.get_meta(TRACE) if game.has_meta(TRACE) else null;var observing:bool=trace is Array and trace.size()<8
	var chosen:=selected(game,prop,foreground);var active:=enabled(game)
	if not observing:return _dispatch(game,chosen,active,legacy)
	var calls:=[0]
	var fallback:=func():calls[0]+=1;legacy.call()
	var outcome:=_dispatch(game,chosen,active,fallback)
	trace.append({"position":[prop.position.x,prop.position.y],"world":game.current_location,"foreground":foreground,"editor":Editor.active(game),"selected":chosen,"flag":active,"route":outcome,"fallback_calls":calls[0]})
	return outcome

## Выполняет старый callback либо атомарный replay без диагностических массивов на обычном пути.
static func _dispatch(game:Node2D,chosen:bool,active:bool,legacy:Callable)->String:
	if not chosen or not active:legacy.call();return "legacy"
	return Replay.draw(game,packet(),game.current_location,LAYER,legacy)
