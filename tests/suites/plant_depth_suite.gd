extends RefCounted
const Points:=preload("res://tools/qa/camera/visual_camera_points.gd")
const Depth:=preload("res://scripts/systems/tree_occlusion_system.gd")

## Проверяет границу глубины, единственный dispatch, устойчивые равные опоры и очистку временных callback-ов.
static func run(c:SceneTree)->void:
	_test_boundary(c)
	_test_single_dispatch(c)
	_test_equal_order(c)
	_test_fallback_and_lifecycle(c)
	_test_bounded_trace(c)

## Создаёт штатную сцену без пользовательских слотов и автоматической симуляции.
static func fixture()->Node:
	var g:=Points.create_game();g._ready();Points.configure(g,Points.registry().points[0]);g.player=Vector2(696,696);g.update_camera()
	return g

## Сценарий: отображаемая стопа пересекает точную границу и равную линию земли без округления.
static func _test_boundary(c:SceneTree)->void:
	for offset in [-24.0,-6.125,-6.0,-5.875,0.0,24.0]:
		c.expect(Depth.is_foreground(Vector2(0,800+offset),800)==(offset< -6.0),"strict ground boundary is stable at "+str(offset))
	c.expect(not Depth.is_foreground(Vector2(700,800),800),"hero draws after a plant with exactly equal ground_y")

## Сценарий: один составной куст по ошибке запрошен повторно до и после переднего прохода.
static func _test_single_dispatch(c:SceneTree)->void:
	var g:=fixture();var calls:=[0];var paint:=func():calls[0]+=1
	Depth.begin_frame(g,0.02);var saved:Dictionary=g.SaveSystem.snapshot(g)
	c.expect(Depth.submit_body(g,"bush",Rect2(660,650,72,72),730,paint)=="front" and calls[0]==0,"foreground body is queued without an opaque underlay")
	c.expect(Depth.submit_body(g,"bush",Rect2(660,650,72,72),730,paint)=="duplicate","duplicate body cannot create a second packet")
	c.expect(g.get_meta(Depth.META_KEY).queue.size()==1,"one foreground key has one packet")
	Depth.draw_foreground(g)
	c.expect(calls[0]==1 and g.get_meta(Depth.META_KEY).queue.is_empty(),"flush calls body once and releases its callback")
	Depth.draw_foreground(g);Depth.submit_body(g,"bush",Rect2(660,650,72,72),730,paint)
	c.expect(calls[0]==1,"repeated foreground and late repeated submit cannot redraw the plant")
	Depth.begin_frame(g,0.02)
	c.expect(Depth.submit_body(g,"bush",Rect2(660,650,72,72),696,paint)=="back" and calls[0]==2,"equal ground body draws before hero once")
	c.expect(saved==g.SaveSystem.snapshot(g),"dispatch and queue state never change the complete save")
	g.free()

## Сценарий: два равных корня поступают в обратном порядке; соседние глубины сохраняют приоритет Y.
static func _test_equal_order(c:SceneTree)->void:
	var g:=fixture();g.set_meta(Depth.TRACE,[])
	for order in [["z","a"],["a","z"]]:
		Depth.begin_frame(g,0.02);var seen:=[]
		for key in order:Depth.submit_body(g,key,Rect2(660,650,72,72),730,func():seen.append(key))
		Depth.draw_foreground(g)
		c.expect(seen==["a","z"],"equal roots use the same key order for either submission order")
	Depth.begin_frame(g,0.02);var seen:=[]
	Depth.submit_body(g,"a",Rect2(660,650,72,72),740,func():seen.append("far_y"))
	Depth.submit_body(g,"z",Rect2(660,650,72,72),730,func():seen.append("near_y"))
	Depth.draw_foreground(g)
	c.expect(seen==["near_y","far_y"],"ground_y sorts before stable key")
	Depth.begin_frame(g,0.02);var snapshot:Vector2=g.get_meta(Depth.META_KEY).hero_ground;g.player+=Vector2(0,120)
	c.expect(Depth.submit_body(g,"snapshot",Rect2(660,650,72,72),730,func():pass)=="front" and snapshot==Vector2(696,696),"all plants use one captured presentation ground in the frame")
	Depth.draw_foreground(g);g.free()

## Сценарий: ручной редактор, другие карты, выключенный флаг, отсечение и перенос между submit/flush.
static func _test_fallback_and_lifecycle(c:SceneTree)->void:
	var g:=fixture();var calls:=[0];var paint:=func():calls[0]+=1
	for mode in ["off","invalid","editor","map"]:
		match mode:
			"off":g.set_meta(Depth.DEPTH_FLAG,false)
			"invalid":g.set_meta(Depth.DEPTH_FLAG,1)
			"editor":g.remove_meta(Depth.DEPTH_FLAG);g.set_meta(g.LevelEditorSystem.META_KEY,{"active":true})
			"map":g.remove_meta(g.LevelEditorSystem.META_KEY);g.current_location="village_market"
		var prior:int=calls[0]
		c.expect(Depth.submit_body(g,"legacy",Rect2(660,650,72,72),730,paint)=="legacy" and calls[0]==prior+1,"fallback invokes old complete body exactly once: "+mode)
	g.current_location="overworld";g.remove_meta(Depth.DEPTH_FLAG);Depth.begin_frame(g,0.02)
	var prior:int=calls[0]
	c.expect(Depth.submit_body(g,"outside",Rect2(-2000,-2000,48,48),730,paint)=="culled" and calls[0]==prior,"off-camera body avoids packet and draw")
	c.expect(Depth.submit_body(g,"bad",Rect2(660,650,72,72),730,Callable())=="rejected","missing body callback is safely rejected")
	Depth.submit_body(g,"old-map",Rect2(660,650,72,72),730,paint);g.current_location="village_market";Depth.draw_foreground(g)
	c.expect(calls[0]==prior and g.get_meta(Depth.META_KEY).queue.is_empty(),"foreign-world flush discards old callback without drawing")
	g.current_location="overworld";Depth.begin_frame(g,0.02)
	c.expect(g.get_meta(Depth.META_KEY).seen.is_empty(),"next frame/world has no stale plant ownership")
	c.expect(not str(g.SaveSystem.snapshot(g)).contains(Depth.META_KEY),"save schema contains no queue, root keys or callbacks")
	g.free()

## Сценарий: диагностическая трасса ограничена, но не обрезает настоящий рисунок и не растёт между кадрами.
static func _test_bounded_trace(c:SceneTree)->void:
	var g:=fixture();Depth.begin_frame(g,0.02);var calls:=[0];var paint:=func():calls[0]+=1
	Depth.submit_body(g,"normal",Rect2(660,650,72,72),696,paint)
	c.expect(not g.has_meta(Depth.TRACE),"ordinary drawing never allocates a diagnostic trace")
	g.set_meta(Depth.TRACE,[])
	for n in 600:Depth.submit_body(g,"body:"+str(n),Rect2(660,650,72,72),696,paint)
	c.expect(calls[0]==601 and g.get_meta(Depth.TRACE).size()==512,"bounded QA trace does not suppress any real body")
	Depth.begin_frame(g,0.02)
	c.expect(g.get_meta(Depth.META_KEY).seen.is_empty() and g.get_meta(Depth.META_KEY).queue.is_empty(),"new frame releases duplicate keys and temporary callbacks")
	g.free()
