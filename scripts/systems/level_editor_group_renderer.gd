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
	game.DebugUiKitSystem.draw_panel(game,GroupSystem.PANEL,true); game.draw_ui_string(game.MENU_FONT,Vector2(932,376),"СЛОИ · %d ВЫБРАНО"%state.selected_ids.size(),HORIZONTAL_ALIGNMENT_LEFT,194,15,TEXT)
	for index in GroupSystem.LAYERS.size():
		var layer:String=GroupSystem.LAYERS[index]; var rect:=Rect2(GroupSystem.ROWS_START+Vector2(0,index*GroupSystem.ROW_HEIGHT),Vector2(200,32)); game.DebugUiKitSystem.draw_catalog_row(game,rect,String(state.layer)==layer,true)
		game.draw_ui_string(game.UI_FONT,rect.position+Vector2(8,21),{"foreground":"ПЕРЕДНИЙ","objects":"ОБЪЕКТЫ","ground":"ЗЕМЛЯ","background":"ФОН"}[layer],HORIZONTAL_ALIGNMENT_LEFT,100,10,ROW_TEXT)
		game.draw_ui_string(game.UI_FONT,rect.position+Vector2(108,21),"◉" if bool(state.layer_visibility.get(layer,true)) else "○",HORIZONTAL_ALIGNMENT_CENTER,40,13,ROW_SELECTED); game.draw_ui_string(game.UI_FONT,rect.position+Vector2(156,21),"◆" if bool(state.layer_locked.get(layer,false)) else "◇",HORIZONTAL_ALIGNMENT_CENTER,40,11,ROW_SELECTED)
