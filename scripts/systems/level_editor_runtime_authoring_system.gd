extends RefCounted


## Возвращает отдельную игровую коллизию, которую дизайнер подгоняет независимо от изображения.
static func collision_rect(object:Dictionary,bounds:Rect2)->Rect2:
	var size:=Vector2(object.get("collision_size",bounds.size)); var offset:=Vector2(object.get("collision_offset",Vector2.ZERO))
	if size==Vector2.ZERO: size=bounds.size
	return Rect2(bounds.get_center()+offset-size*0.5,size)


## Переключает игровую роль выбранного объекта и гарантирует единственность точки появления героя.
static func cycle_role(editor_system,state:Dictionary)->void:
	if not editor_system.valid_selection(state): state.status="Сначала выбери объект для игровой роли"; return
	var roles:=["","spawn","exit","interaction"]; editor_system.push_history(state)
	var current:=String(state.objects[state.selected].get("runtime_role","")); var next:=String(roles[(roles.find(current)+1)%roles.size()])
	if next=="spawn":
		for index in state.objects.size():
			if index!=int(state.selected) and String(state.objects[index].get("runtime_role",""))=="spawn": state.objects[index].runtime_role=""
	state.objects[state.selected].runtime_role=next; state.validation={}; state.status="Роль: %s"%(next.to_upper() if not next.is_empty() else "НЕТ")


## Изменяет размер коллизии через Shift+стрелки или её смещение через Alt+стрелки.
static func edit_collision(editor_system,state:Dictionary,direction:Vector2,resize:bool)->void:
	if not editor_system.valid_selection(state): state.status="Сначала выбери объект с коллизией"; return
	editor_system.push_history(state); var object:Dictionary=state.objects[state.selected]; var step:=maxi(1,int(state.grid)/2)
	if resize:
		var size:=Vector2(object.get("collision_size",editor_system.object_bounds(object).size)); size+=direction*step; object.collision_size=Vector2(maxf(step,size.x),maxf(step,size.y)); state.status="Коллизия %.0f×%.0f"%[object.collision_size.x,object.collision_size.y]
	else:
		object.collision_offset=Vector2(object.get("collision_offset",Vector2.ZERO))+direction*step; state.status="Смещение коллизии %.0f, %.0f"%[object.collision_offset.x,object.collision_offset.y]
	object.collision=true; state.objects[state.selected]=object; state.validation={}


## Обрабатывает только runtime-команды публикации, ролей и геометрии, не раздувая основной редактор.
static func handle_key(game:Node,state:Dictionary,event:InputEventKey)->bool:
	if event.keycode in [KEY_UP,KEY_RIGHT,KEY_DOWN,KEY_LEFT] and (event.shift_pressed or event.alt_pressed):
		var directions:Dictionary={KEY_UP:Vector2(0,-1),KEY_RIGHT:Vector2(1,0),KEY_DOWN:Vector2(0,1),KEY_LEFT:Vector2(-1,0)}; edit_collision(game.LevelEditorSystem,state,Vector2(directions[event.keycode]),event.shift_pressed); return true
	if event.keycode==KEY_T: game.PublishedLevelSystem.publish_and_play(game,state); return true
	if event.keycode==KEY_M: cycle_role(game.LevelEditorSystem,state); return true
	if event.keycode==KEY_C: state.collision_view=not bool(state.get("collision_view",true)); state.status="Контуры коллизий включены" if state.collision_view else "Контуры коллизий скрыты"; return true
	return false
