extends RefCounted

const AtlasPickerSystem := preload("res://scripts/systems/level_editor_atlas_picker_system.gd")
const TEXT := Color("fff0c8")
const MUTED := Color("c5ae83")
const SELECTED := Color("ffd45c")


## Рисует модальное окно равномерных кадров или произвольного source-rect поверх живой карты.
static func draw(game: Node2D, state: Dictionary) -> void:
	if not bool(state.get("atlas_picker_open",false)): return
	var texture:Texture2D=game.LevelEditorRenderer.texture_for(String(state.selected_asset))
	if texture==null: return
	game.draw_rect(Rect2(0,0,1152,648),Color(0.01,0.008,0.006,0.64)); game.DebugUiKitSystem.draw_panel(game,AtlasPickerSystem.PANEL,true)
	game.draw_ui_string(game.MENU_FONT,Vector2(430,72),"ВЫБОР СПРАЙТА ИЗ ЛИСТА",HORIZONTAL_ALIGNMENT_LEFT,640,18,TEXT)
	draw_button(game,AtlasPickerSystem.CLOSE_BUTTON,"×",false); draw_button(game,AtlasPickerSystem.GRID_TAB,"СЕТКА КАДРОВ",String(state.get("source_mode","grid"))=="grid"); draw_button(game,AtlasPickerSystem.CUSTOM_TAB,"СВОЯ ОБЛАСТЬ",String(state.get("source_mode","grid"))=="custom")
	draw_button(game,AtlasPickerSystem.SLICE_PREV,"‹",false); draw_button(game,AtlasPickerSystem.SLICE_LABEL,"ЯЧЕЙКА %s"%("ALL" if int(state.slice_size)<=0 else "%d px"%int(state.slice_size)),true); draw_button(game,AtlasPickerSystem.SLICE_NEXT,"›",false)
	if String(state.get("source_mode","grid"))=="custom": draw_custom(game,state,texture)
	else: draw_grid(game,state,texture)
	game.draw_ui_string(game.UI_FONT,Vector2(430,588),"Двойной клик — выбрать и закрыть · Tab — режим · Esc — закрыть",HORIZONTAL_ALIGNMENT_LEFT,672,11,MUTED)


## Показывает до 32 настоящих кадров активной страницы с номерами и рамкой выбора.
static func draw_grid(game: Node2D, state: Dictionary, texture: Texture2D) -> void:
	var count:=AtlasPickerSystem.frame_count(texture,state); var page:=clampi(int(state.get("atlas_page",0)),0,AtlasPickerSystem.page_count(texture,state)-1); var start:=page*AtlasPickerSystem.PAGE_SIZE
	for local_index in AtlasPickerSystem.PAGE_SIZE:
		var index:=start+local_index; var column:=local_index%AtlasPickerSystem.GRID_COLUMNS; var row:=local_index/AtlasPickerSystem.GRID_COLUMNS; var rect:=Rect2(AtlasPickerSystem.GRID_AREA.position+Vector2(column*AtlasPickerSystem.GRID_CELL.x,row*AtlasPickerSystem.GRID_CELL.y),AtlasPickerSystem.GRID_CELL-Vector2(4,4)); var active:=index==int(state.slice_index)
		game.DebugUiKitSystem.draw_catalog_row(game,rect,active)
		if index>=count: continue
		var preview_state:=state.duplicate(); preview_state.slice_index=index; preview_state.source_mode="grid"; var source:=AtlasPickerSystem.selected_source(texture,preview_state); var source_size:=source.size if source.size!=Vector2.ZERO else texture.get_size(); var scale:=minf(68.0/maxf(source_size.x,1),68.0/maxf(source_size.y,1)); var destination:=Rect2(rect.position+Vector2((rect.size.x-source_size.x*scale)*0.5,10),source_size*scale)
		if source.size==Vector2.ZERO: game.draw_texture_rect(texture,destination,false)
		else: game.draw_texture_rect_region(texture,destination,source)
		game.draw_ui_string(game.UI_FONT,rect.position+Vector2(4,rect.size.y-5),"#%d"%(index+1),HORIZONTAL_ALIGNMENT_LEFT,rect.size.x-8,9,SELECTED if active else MUTED)
	draw_button(game,AtlasPickerSystem.PAGE_PREV,"‹ СТРАНИЦА",false); draw_button(game,AtlasPickerSystem.PAGE_LABEL,"%d / %d · %d кадров"%[page+1,AtlasPickerSystem.page_count(texture,state),count],true); draw_button(game,AtlasPickerSystem.PAGE_NEXT,"СТРАНИЦА ›",false)


## Показывает полный исходник и точную рамку пользовательского прямоугольника в его масштабе.
static func draw_custom(game: Node2D, state: Dictionary, texture: Texture2D) -> void:
	var area:=AtlasPickerSystem.CUSTOM_AREA; game.draw_rect(area,Color(0.04,0.055,0.06,0.96)); var destination:=AtlasPickerSystem.texture_destination(texture); game.draw_texture_rect(texture,destination,false)
	var source:=Rect2(state.get("custom_source",Rect2(Vector2.ZERO,texture.get_size()))); var scale:=destination.size/texture.get_size(); var selection:=Rect2(destination.position+source.position*scale,source.size*scale); game.draw_rect(selection,Color(1.0,0.84,0.35,0.12)); game.draw_rect(selection,SELECTED,false,2.0)
	game.draw_ui_string(game.UI_FONT,Vector2(430,548),AtlasPickerSystem.source_label(state)+" · протяни рамку мышью",HORIZONTAL_ALIGNMENT_CENTER,672,12,TEXT)


## Рисует управляющую кнопку в общем резном стиле конструктора.
static func draw_button(game: Node2D, rect: Rect2, label: String, active: bool) -> void:
	game.DebugUiKitSystem.draw_button(game,rect,label,active,true,true)
