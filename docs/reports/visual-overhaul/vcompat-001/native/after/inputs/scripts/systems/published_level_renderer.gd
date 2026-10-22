extends RefCounted


## Рисует один слой опубликованного уровня теми же ресурсами, source-rect и якорями, что конструктор.
static func draw_layer(game:Node2D,layer:String)->void:
	if not game.PublishedLevelSystem.active(game): return
	for object in game.get_meta(game.PublishedLevelSystem.META_KEY).objects:
		if bool(object.get("hidden",false)) or bool(object.get("reference",false)) or String(object.get("layer","objects"))!=layer or String(object.get("runtime_role",""))=="spawn": continue
		game.LevelEditorRenderer.draw_object(game,object,false,false)
	if layer=="foreground": draw_test_hint(game)


## Показывает компактное условие теста без перекрытия игрового мира редакторской панелью.
static func draw_test_hint(game:Node2D)->void:
	var rect:=Rect2(game.camera_offset+Vector2(376,18),Vector2(400,42)); game.draw_rect(rect,Color(0.03,0.04,0.025,0.88)); game.draw_rect(rect,Color("efc966"),false,2.0)
	game.draw_ui_string(game.UI_FONT,rect.position+Vector2(12,27),"ТЕСТ УРОВНЯ · ДОЙДИ ДО ВЫХОДА · F12 НАЗАД",HORIZONTAL_ALIGNMENT_CENTER,rect.size.x-24,12,Color("fff0c8"))
