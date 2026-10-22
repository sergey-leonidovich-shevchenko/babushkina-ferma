extends RefCounted

const GroupSystem := preload("res://scripts/systems/level_editor_group_system.gd")
const TEXT := Color("fff0c8")
const SELECTED := Color("ffd45c")
const ROW_TEXT := Color("4b2c17")
const ROW_SELECTED := Color("75420f")


## Рисует рамки всех выбранных объектов и текущую область рамочного выделения.
static func draw_world(game: Node2D, state: Dictionary) -> void:
	for object in state.objects:
		if int(object.id) in state.selected_ids and bool(state.layer_visibility.get(String(object.layer),true)): game.draw_rect(game.LevelEditorSystem.object_bounds(object).grow(3),SELECTED,false,2.0)
	if String(state.get("drag_kind",""))=="marquee":
		var rect:=GroupSystem.selection_rect(state); game.draw_rect(rect,Color(0.42,0.82,1.0,0.16)); game.draw_rect(rect,Color("71c8ff"),false,2.0)


## Рисует компактную панель видимости и блокировки четырёх слоёв редактора.
static func draw_panel(game: Node2D, state: Dictionary) -> void:
	game.DebugUiKitSystem.draw_panel(game,GroupSystem.PANEL,true); var header:Dictionary=game.DebugUiKitSystem.fit_label(game.UI_FONT,"СЛОИ  •  ВЫБРАНО: %d"%state.selected_ids.size(),GroupSystem.HEADER.size.x-4,10,8); game.draw_ui_string(game.UI_FONT,GroupSystem.HEADER.position+Vector2(2,17),String(header.text),HORIZONTAL_ALIGNMENT_LEFT,GroupSystem.HEADER.size.x-4,int(header.size),TEXT)
	for index in GroupSystem.LAYERS.size():
		var layer:String=GroupSystem.LAYERS[index]; var rect:=Rect2(GroupSystem.ROWS_START+Vector2(0,index*GroupSystem.ROW_HEIGHT),Vector2(176,28)); game.DebugUiKitSystem.draw_catalog_row(game,rect,String(state.layer)==layer,true)
		var fitted:Dictionary=game.DebugUiKitSystem.fit_label(game.UI_FONT,{"foreground":"ПЕРЕДНИЙ","objects":"ОБЪЕКТЫ","ground":"ЗЕМЛЯ","background":"ФОН"}[layer],74,9,7); game.draw_ui_string(game.UI_FONT,rect.position+Vector2(16,19),String(fitted.text),HORIZONTAL_ALIGNMENT_LEFT,74,int(fitted.size),ROW_TEXT)
		game.draw_ui_string(game.UI_FONT,rect.position+Vector2(96,20),"◉" if bool(state.layer_visibility.get(layer,true)) else "○",HORIZONTAL_ALIGNMENT_CENTER,34,12,ROW_SELECTED); game.draw_ui_string(game.UI_FONT,rect.position+Vector2(138,20),"◆" if bool(state.layer_locked.get(layer,false)) else "◇",HORIZONTAL_ALIGNMENT_CENTER,28,10,ROW_SELECTED)
