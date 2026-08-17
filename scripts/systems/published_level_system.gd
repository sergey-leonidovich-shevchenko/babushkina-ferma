extends RefCounted

const META_KEY := "published_level_runtime"
const PUBLISHED_DIRECTORY := "res://level_designs/published"
const EXIT_RADIUS := 30.0


## Проверяет, запущен ли опубликованный черновик поверх выбранной базовой локации.
static func active(game:Node)->bool:
	return bool(game.get_meta(META_KEY,{}).get("active",false))


## Публикует проверенный документ атомарно и сразу запускает его для игрового теста.
static func publish_and_play(game:Node,state:Dictionary)->bool:
	var report:Dictionary=game.LevelEditorSystem.ValidationSystem.validate_runtime(state)
	state.validation=report
	if not bool(report.valid):
		state.status="ПУБЛИКАЦИЯ: исправь %d ошибок"%report.errors.size(); return false
	var document:Dictionary=game.LevelEditorSystem.document(state); document.format="babushkina-ferma-runtime-level"; document.runtime_validation=report
	var absolute:=ProjectSettings.globalize_path(PUBLISHED_DIRECTORY); DirAccess.make_dir_recursive_absolute(absolute)
	var path:=PUBLISHED_DIRECTORY.path_join(game.LevelEditorSystem.slugify(String(state.level_name))+".json"); var temporary:=path+".tmp"
	var file:=FileAccess.open(temporary,FileAccess.WRITE)
	if file==null: state.status="Не удалось создать runtime-файл"; return false
	file.store_string(JSON.stringify(document,"  ")); file.close()
	if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary),ProjectSettings.globalize_path(path))!=OK: state.status="Не удалось завершить публикацию"; return false
	state.status="ОПУБЛИКОВАНО: %s"%path
	return start_playtest(game,state,document,path)


## Запускает скомпилированные объекты, запоминая точку возврата в редактор.
static func start_playtest(game:Node,editor_state:Dictionary,document:Dictionary,path:String="")->bool:
	var objects:Array=editor_state.objects.duplicate(true); var spawn:=role_position(objects,"spawn")
	if spawn==Vector2.INF: editor_state.status="Для теста нужна точка SPAWN"; return false
	var runtime:={"active":true,"objects":objects,"level_name":String(document.get("level_name",editor_state.level_name)),"path":path,"base_location":String(editor_state.base_location),"return_location":game.current_location,"return_player":game.player,"return_camera":game.camera_offset,"started_msec":Time.get_ticks_msec()}
	game.set_meta(META_KEY,runtime); editor_state.active=false; editor_state.panel_hidden=false; game.set_meta(game.LevelEditorSystem.META_KEY,editor_state)
	game.current_location=String(editor_state.base_location); game.player=spawn; game.clear_movement_keys(); game.sync_background_location(); game.update_camera(); game.message="ТЕСТ УРОВНЯ · дойди до выхода · F12 вернуться"; game.play_sfx("travel"); game.queue_redraw()
	return true


## Завершает тест и возвращает дизайнера в тот же черновик и положение камеры.
static func finish_playtest(game:Node,completed:bool)->bool:
	if not active(game): return false
	var runtime:Dictionary=game.get_meta(META_KEY); runtime.active=false; game.set_meta(META_KEY,runtime)
	game.current_location=String(runtime.return_location); game.player=Vector2(runtime.return_player); game.camera_offset=Vector2(runtime.return_camera); game.sync_background_location()
	var editor:Dictionary=game.get_meta(game.LevelEditorSystem.META_KEY,game.LevelEditorSystem.default_state(game)); editor.active=true; editor.panel_hidden=false; editor.status="ТЕСТ ПРОЙДЕН · выход достижим" if completed else "Тест остановлен · карта сохранена"; game.set_meta(game.LevelEditorSystem.META_KEY,editor)
	game.clear_movement_keys(); game.message=String(editor.status); game.queue_redraw(); return true


## Обрабатывает ручной возврат из теста клавишей F12 или Escape.
static func handle_input(game:Node,event:InputEvent)->bool:
	if not active(game): return false
	if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_F12,KEY_ESCAPE]: return finish_playtest(game,false)
	return false


## Автоматически завершает тест, когда герой действительно достигает любой точки выхода.
static func update(game:Node)->void:
	if not active(game): return
	for object in game.get_meta(META_KEY).objects:
		if String(object.get("runtime_role",""))=="exit" and game.player.distance_to(Vector2(object.position))<=EXIT_RADIUS:
			finish_playtest(game,true); return


## Возвращает первую позицию объекта с указанной runtime-ролью либо бесконечную точку.
static func role_position(objects:Array,role:String)->Vector2:
	for object in objects:
		if String(object.get("runtime_role",""))==role: return Vector2(object.position)
	return Vector2.INF


## Возвращает точный редактируемый прямоугольник коллизии одного объекта.
static func collision_rect(object:Dictionary)->Rect2:
	var bounds:=object_bounds(object); var size:=Vector2(object.get("collision_size",bounds.size)); var offset:=Vector2(object.get("collision_offset",Vector2.ZERO))
	if size==Vector2.ZERO: size=bounds.size
	return Rect2(bounds.get_center()+offset-size*0.5,size)


## Возвращает визуальную область объекта по общему контракту якоря и масштаба редактора.
static func object_bounds(object:Dictionary)->Rect2:
	var size:=Vector2(object.get("size",Vector2(24,24)))*clampf(float(object.get("scale",1.0)),0.25,4.0); var position:=Vector2(object.position)
	match String(object.get("anchor","center")):
		"tile": return Rect2(position,size)
		"bottom": return Rect2(position-Vector2(size.x*0.5,size.y),size)
		_: return Rect2(position-size*0.5,size)


## Проверяет только опубликованные препятствия, оставляя базовую навигацию владельцу локации.
static func blocks_position(game:Node,position:Vector2,radius:float)->bool:
	if not active(game): return false
	for object in game.get_meta(META_KEY).objects:
		if bool(object.get("hidden",false)) or not bool(object.get("collision",false)): continue
		if circle_intersects_rect(position,radius,collision_rect(object)): return true
	return false


## Проверяет пересечение круглого героя с прямоугольной пользовательской коллизией.
static func circle_intersects_rect(center:Vector2,radius:float,rect:Rect2)->bool:
	var closest:=Vector2(clampf(center.x,rect.position.x,rect.end.x),clampf(center.y,rect.position.y,rect.end.y))
	return center.distance_squared_to(closest)<radius*radius
