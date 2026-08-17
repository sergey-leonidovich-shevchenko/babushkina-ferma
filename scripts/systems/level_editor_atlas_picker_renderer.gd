extends RefCounted

const AtlasPickerSystem := preload("res://scripts/systems/level_editor_atlas_picker_system.gd")
const TEXT := Color("fff0c8")
const MUTED := Color("c5ae83")
const SELECTED := Color("ffd45c")
const ROW_TEXT := Color("4b2c17")
const CARD_GAP := Vector2.ZERO
const PREVIEW_INSET := Vector2(17,13)
const FRAME_BADGE_OFFSET := Vector2(18,14)
const FRAME_BADGE_SIZE := Vector2(26,16)
const FRAME_BADGE_TEXT := Color("ffe3a0")
static var _visible_source_cache: Dictionary = {}


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
		var index:=start+local_index; var column:=local_index%AtlasPickerSystem.GRID_COLUMNS; var row:=local_index/AtlasPickerSystem.GRID_COLUMNS; var rect:=Rect2(AtlasPickerSystem.GRID_AREA.position+Vector2(column*AtlasPickerSystem.GRID_CELL.x,row*AtlasPickerSystem.GRID_CELL.y),AtlasPickerSystem.GRID_CELL-CARD_GAP); var active:=index==int(state.slice_index)
		game.DebugUiKitSystem.draw_catalog_row(game,rect,active,true)
		if index>=count: continue
		var preview_state:=state.duplicate(); preview_state.slice_index=index; preview_state.source_mode="grid"; var source:=AtlasPickerSystem.selected_source(texture,preview_state); var exact_source:=source if source.size!=Vector2.ZERO else Rect2(Vector2.ZERO,texture.get_size()); var preview_source:=visible_preview_source(texture,exact_source); var content:=Rect2(rect.position+PREVIEW_INSET,rect.size-PREVIEW_INSET*2.0); var scale:=minf(content.size.x/maxf(preview_source.size.x,1),content.size.y/maxf(preview_source.size.y,1)); var preview_size:=preview_source.size*scale; var destination:=Rect2(content.position+(content.size-preview_size)*0.5,preview_size)
		game.draw_texture_rect_region(texture,destination,preview_source)
		var badge:=Rect2(rect.position+FRAME_BADGE_OFFSET,FRAME_BADGE_SIZE); game.draw_rect(badge,Color(0.16,0.09,0.035,0.84)); game.draw_rect(badge,Color(0.86,0.64,0.25,0.72),false,1.0); game.draw_ui_string(game.UI_FONT,badge.position+Vector2(2,12),"#%d"%(index+1),HORIZONTAL_ALIGNMENT_CENTER,badge.size.x-4,8,FRAME_BADGE_TEXT)
	draw_button(game,AtlasPickerSystem.PAGE_PREV,"‹ НАЗАД",false); draw_button(game,AtlasPickerSystem.PAGE_LABEL,"%d / %d · %d кадров"%[page+1,AtlasPickerSystem.page_count(texture,state),count],true); draw_button(game,AtlasPickerSystem.PAGE_NEXT,"ВПЕРЁД ›",false)


## Находит непрозрачную часть точного кадра, чтобы визуально центрировать спрайт, не меняя область его выбора и размещения.
static func visible_preview_source(texture: Texture2D, exact_source: Rect2) -> Rect2:
	var key:="%s:%d:%d:%d:%d"%[texture.resource_path,int(exact_source.position.x),int(exact_source.position.y),int(exact_source.size.x),int(exact_source.size.y)]
	if _visible_source_cache.has(key): return Rect2(_visible_source_cache[key])
	var image:=texture.get_image(); var bounds:=Rect2i(Vector2i(exact_source.position),Vector2i(exact_source.size)); var used:=image.get_region(bounds).get_used_rect(); var result:=exact_source if used.size==Vector2i.ZERO else Rect2(Vector2i(bounds.position+used.position),used.size)
	_visible_source_cache[key]=result
	return result


## Показывает полный исходник и точную рамку пользовательского прямоугольника в его масштабе.
static func draw_custom(game: Node2D, state: Dictionary, texture: Texture2D) -> void:
	var area:=AtlasPickerSystem.CUSTOM_AREA; game.draw_rect(area,Color(0.04,0.055,0.06,0.96)); var destination:=AtlasPickerSystem.texture_destination(texture); game.draw_texture_rect(texture,destination,false)
	var source:=Rect2(state.get("custom_source",Rect2(Vector2.ZERO,texture.get_size()))); var scale:=destination.size/texture.get_size(); var selection:=Rect2(destination.position+source.position*scale,source.size*scale); game.draw_rect(selection,Color(1.0,0.84,0.35,0.12)); game.draw_rect(selection,SELECTED,false,2.0)
	game.draw_ui_string(game.UI_FONT,Vector2(430,548),AtlasPickerSystem.source_label(state)+" · протяни рамку мышью",HORIZONTAL_ALIGNMENT_CENTER,672,12,TEXT)


## Рисует управляющую кнопку в общем резном стиле конструктора.
static func draw_button(game: Node2D, rect: Rect2, label: String, active: bool) -> void:
	game.DebugUiKitSystem.draw_button(game,rect,label,active,true,true)
