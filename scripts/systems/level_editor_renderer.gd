extends RefCounted

const AtlasPickerRenderer := preload("res://scripts/systems/level_editor_atlas_picker_renderer.gd")
const GroupRenderer := preload("res://scripts/systems/level_editor_group_renderer.gd")

const PANEL_FILL := Color(0.075,0.055,0.035,0.97)
const PANEL_BORDER := Color("d7a94f")
const BUTTON_FILL := Color("553b25")
const BUTTON_ACTIVE := Color("557544")
const TEXT := Color("fff0c8")
const MUTED := Color("c5ae83")
const SELECTED := Color("ffd45c")
const ROW_TEXT := Color("4b2c17")
const ROW_MUTED := Color("76563b")
const ROW_SELECTED := Color("75420f")
const CATALOG_ROW_DRAW_HEIGHT := 40.0
const CATALOG_TITLE_BASELINE := 17.0
const CATALOG_PATH_BASELINE := 28.0
const CATALOG_TITLE_SIZE := 9
const CATALOG_PATH_SIZE := 7
const HELP_RECT := Rect2(442,12,690,30)
const SELECTION_INFO_RECT := Rect2(442,50,330,104)
const VALIDATION_INFO_RECT := Rect2(782,50,350,106)
const TRANSITION_TEXTURES := {"dirt":"res://assets/game/tiles/editor/transitions/dirt_edge.png","gravel":"res://assets/game/tiles/editor/transitions/gravel_edge.png","sand":"res://assets/game/tiles/editor/transitions/sand_edge.png"}
const TRANSITION_CORNER_TEXTURES := {"dirt":"res://assets/game/tiles/editor/transitions/dirt_inner_corner.png","gravel":"res://assets/game/tiles/editor/transitions/gravel_inner_corner.png","sand":"res://assets/game/tiles/editor/transitions/sand_inner_corner.png"}
const TRANSITION_BITS := [1,2,4,8]
const TRANSITION_ROTATIONS := [0.0,PI*0.5,PI,-PI*0.5]
static var _texture_cache: Dictionary = {}


## Удерживает загруженные редакторские текстуры между кадрами, чтобы GPU не показывал белый placeholder.
static func texture_for(path: String) -> Texture2D:
	if not _texture_cache.has(path): _texture_cache[path]=ResourceLoader.load(path) as Texture2D
	return _texture_cache[path]


## Рисует размещённые элементы одного смыслового слоя под или над игровыми объектами.
static func draw_layer(game: Node2D, layer: String) -> void:
	if not game.LevelEditorSystem.active(game): return
	var state:Dictionary=game.get_meta(game.LevelEditorSystem.META_KEY)
	if bool(state.layer_visibility.get(layer,true)):
		for index in state.objects.size():
			var object:Dictionary=state.objects[index]
			if object.get("hidden",false) or String(object.layer)!=layer: continue
			draw_object(game,object,index==int(state.selected) and not bool(state.panel_hidden),bool(state.get("collision_view",true)))
	if layer=="foreground":
		if not bool(state.panel_hidden):
			draw_grid(game,state)
			draw_rectangle_preview(game,state)
			draw_drag_preview(game,state)
			GroupRenderer.draw_world(game,state)


## Отрисовывает обычный спрайт либо технический референс импортированного runtime-объекта.
static func draw_object(game: Node2D, object: Dictionary, selected: bool, show_collision:bool=true) -> void:
	var bounds: Rect2 = game.LevelEditorSystem.object_bounds(object); var size := bounds.size; var center := bounds.get_center()
	if bool(object.reference):
		var changed: bool = Vector2(object.position).distance_to(Vector2(object.original_position))>0.5
		if changed or selected:
			var color: Color = Color(0.35,0.8,1.0,0.22 if changed else 0.12); game.draw_rect(bounds,color); game.draw_rect(bounds,Color("6dd5ff"),false,2.0)
	else:
		var texture: Texture2D = texture_for(String(object.asset_path))
		if texture!=null:
			var source:Rect2=object.source
			if is_zero_approx(float(object.rotation)) and not bool(object.flip_x) and not bool(object.flip_y):
				if source.size==Vector2.ZERO: game.draw_texture_rect(texture,bounds,false)
				else: game.draw_texture_rect_region(texture,bounds,source)
			else:
				var scale_vector: Vector2 = Vector2(-1.0 if object.flip_x else 1.0,-1.0 if object.flip_y else 1.0); game.draw_set_transform(center-game.camera_offset,float(object.rotation),scale_vector)
				var destination: Rect2 = Rect2(-size*0.5,size)
				if source.size==Vector2.ZERO: game.draw_texture_rect(texture,destination,false)
				else: game.draw_texture_rect_region(texture,destination,source)
				game.draw_set_transform(-game.camera_offset)
		draw_surface_transitions(game,object,bounds)
	if show_collision and bool(object.collision):
		var collision_rect:Rect2=game.LevelEditorSystem.RuntimeAuthoringSystem.collision_rect(object,bounds); game.draw_rect(collision_rect,Color(0.95,0.24,0.22,0.72),false,2.0)
		game.draw_line(collision_rect.position,collision_rect.end,Color(0.95,0.24,0.22,0.22),1.0); game.draw_line(Vector2(collision_rect.end.x,collision_rect.position.y),Vector2(collision_rect.position.x,collision_rect.end.y),Color(0.95,0.24,0.22,0.22),1.0)
	if selected:
		game.draw_rect(bounds.grow(4),SELECTED,false,3.0)
		for corner in [bounds.position,bounds.position+Vector2(bounds.size.x,0),bounds.end,bounds.position+Vector2(0,bounds.size.y)]: game.draw_rect(Rect2(corner-Vector2(4,4),Vector2(8,8)),Color("fff2a3"))
	if not String(object.name).is_empty() and (selected or bool(object.reference)):
		var label: Rect2 = Rect2(Vector2(center.x-90,bounds.position.y-25),Vector2(180,20)); game.draw_rect(label,Color(0.03,0.025,0.02,0.78)); game.draw_ui_string(game.UI_FONT,label.position+Vector2(4,15),String(object.name),HORIZONTAL_ALIGNMENT_CENTER,label.size.x-8,12,TEXT)
	draw_runtime_role(game,object,bounds)


## Показывает игровые маркеры старта, выхода и взаимодействия прямо на рабочем холсте.
static func draw_runtime_role(game:Node2D,object:Dictionary,bounds:Rect2)->void:
	var role:=String(object.get("runtime_role",""))
	if role.is_empty(): return
	var colors:={"spawn":Color("65d98a"),"exit":Color("64c7ff"),"interaction":Color("d89bff")}; var color:Color=colors.get(role,Color.WHITE)
	var marker:=Rect2(Vector2(bounds.get_center().x-35,bounds.position.y-45),Vector2(70,18)); game.draw_rect(marker,Color(0.02,0.025,0.02,0.88)); game.draw_rect(marker,color,false,2.0)
	game.draw_ui_string(game.UI_FONT,marker.position+Vector2(4,13),role.to_upper(),HORIZONTAL_ALIGNMENT_CENTER,marker.size.x-8,10,color)


## Накладывает на края тайла переходы к более плотному соседнему покрытию без создания зазоров в сетке.
static func draw_surface_transitions(game: Node2D, object: Dictionary, bounds: Rect2) -> void:
	var masks:Dictionary=object.get("transition_masks",{}); var corner_masks:Dictionary=object.get("transition_corner_masks",{})
	if masks.is_empty() and corner_masks.is_empty(): return
	for surface in masks:
		var path:=String(TRANSITION_TEXTURES.get(String(surface),"")); var texture:=texture_for(path) if not path.is_empty() else null
		if texture==null: continue
		var mask:=int(masks[surface])
		for direction_index in TRANSITION_BITS.size():
			if mask&TRANSITION_BITS[direction_index]==0: continue
			game.draw_set_transform(bounds.get_center()-game.camera_offset,float(TRANSITION_ROTATIONS[direction_index]))
			game.draw_texture_rect(texture,Rect2(-bounds.size*0.5,bounds.size),false)
			game.draw_set_transform(-game.camera_offset)
	for surface in corner_masks:
		var path:=String(TRANSITION_CORNER_TEXTURES.get(String(surface),"")); var texture:=texture_for(path) if not path.is_empty() else null
		if texture==null: continue
		var mask:=int(corner_masks[surface])
		for direction_index in TRANSITION_BITS.size():
			if mask&TRANSITION_BITS[direction_index]==0: continue
			game.draw_set_transform(bounds.get_center()-game.camera_offset,float(TRANSITION_ROTATIONS[direction_index]))
			game.draw_texture_rect(texture,Rect2(-bounds.size*0.5,bounds.size),false)
			game.draw_set_transform(-game.camera_offset)


## Накладывает лёгкую модульную сетку только на видимую область рабочего холста.
static func draw_grid(game: Node2D, state: Dictionary) -> void:
	var grid: int = int(state.grid); var start_x: int = floori(game.camera_offset.x/grid)*grid; var start_y: int = floori(game.camera_offset.y/grid)*grid; var end_x: int = ceili((game.camera_offset.x+1152)/grid)*grid; var end_y: int = ceili((game.camera_offset.y+648)/grid)*grid
	for x in range(start_x,end_x+1,grid): game.draw_line(Vector2(x,start_y),Vector2(x,end_y),Color(1.0,0.91,0.62,0.13),1.0)
	for y in range(start_y,end_y+1,grid): game.draw_line(Vector2(start_x,y),Vector2(end_x,y),Color(1.0,0.91,0.62,0.13),1.0)


## Показывает полупрозрачный спрайт у курсора во время переноса из каталога.
static func draw_drag_preview(game: Node2D, state: Dictionary) -> void:
	if String(state.selected_asset).is_empty() or String(state.tool)!="paint": return
	var texture: Texture2D = texture_for(String(state.selected_asset))
	if texture==null:return
	var source: Rect2 = game.LevelEditorSystem.selected_source(texture,state)
	var entry: Dictionary = game.LevelEditorSystem.AssetCatalogSystem.find(game.LevelEditorSystem.catalog(),String(state.selected_asset))
	var size:=Vector2(entry.get("display_size",Vector2.ZERO))
	if size==Vector2.ZERO: size=source.size if source.size!=Vector2.ZERO else texture.get_size()
	if String(state.get("source_mode","grid"))=="custom" and source.size!=Vector2.ZERO: size=source.size
	if String(entry.get("anchor","center"))=="tile": size=Vector2.ONE*int(state.grid)
	var position: Vector2 = game.LevelEditorSystem.placement_position(state,Vector2(state.mouse)+Vector2(game.camera_offset),String(entry.get("anchor","center")))
	var destination: Rect2 = game.LevelEditorSystem.object_bounds({"position":position,"size":size,"anchor":entry.get("anchor","center"),"scale":1.0})
	if source.size==Vector2.ZERO: game.draw_texture_rect(texture,destination,false,Color(1,1,1,0.62))
	else: game.draw_texture_rect_region(texture,destination,source,Color(1,1,1,0.62))
	game.draw_rect(destination,Color("8ef09d"),false,2.0)


## Показывает полупрозрачную область будущей прямоугольной заливки до отпускания мыши.
static func draw_rectangle_preview(game: Node2D, state: Dictionary) -> void:
	if String(state.drag_kind)!="fill": return
	var start:=Vector2i(state.rectangle_start); var finish:=Vector2i(state.rectangle_end); var minimum:=Vector2i(mini(start.x,finish.x),mini(start.y,finish.y)); var maximum:=Vector2i(maxi(start.x,finish.x),maxi(start.y,finish.y)); var grid:=int(state.grid)
	var rect:=Rect2(Vector2(minimum)*grid,Vector2(maximum-minimum+Vector2i.ONE)*grid)
	game.draw_rect(rect,Color(0.42,0.95,0.55,0.18)); game.draw_rect(rect,Color("8ef09d"),false,2.0)


## Рисует всю панель каталога, настройки объекта, статус и строку горячих клавиш.
static func draw_panel(game: Node2D) -> void:
	if not game.LevelEditorSystem.active(game): return
	var state:Dictionary=game.get_meta(game.LevelEditorSystem.META_KEY)
	if bool(state.panel_hidden): return
	var panel:Rect2=game.LevelEditorSystem.PANEL; game.DebugUiKitSystem.draw_panel(game,panel,true)
	game.draw_ui_string(game.MENU_FONT,Vector2(24,42),"КОНСТРУКТОР УРОВНЕЙ",HORIZONTAL_ALIGNMENT_LEFT,352,17,TEXT)
	draw_button(game,game.LevelEditorSystem.CLOSE_BUTTON,"×",false)
	var level_summary:Dictionary=game.DebugUiKitSystem.fit_label(game.UI_FONT,"%s  •  %d объектов"%[state.level_name,state.objects.size()],352,11,8); game.draw_ui_string(game.UI_FONT,Vector2(24,65),String(level_summary.text),HORIZONTAL_ALIGNMENT_LEFT,352,int(level_summary.size),MUTED)
	draw_button(game,game.LevelEditorSystem.CATEGORY_PREV,"‹",false); draw_button(game,game.LevelEditorSystem.CATEGORY_NEXT,"›",false)
	var category:String=game.LevelEditorSystem.CATEGORIES[int(state.category)]; var search:=String(state.get("search","")); draw_button(game,game.LevelEditorSystem.SEARCH_BUTTON,("⌕ "+search.left(19)) if not search.is_empty() else (game.LevelEditorSystem.CATEGORY_NAMES[category]+" · ПОИСК /"),not search.is_empty()); draw_button(game,game.LevelEditorSystem.FAVORITES_BUTTON,"★ %d"%state.favorites.size(),bool(state.favorites_only))
	draw_assets(game,state)
	draw_section_label(game,318,"ИНСТРУМЕНТЫ")
	draw_button(game,game.LevelEditorSystem.SELECT_TOOL_BUTTON,"ВЫБОР",state.tool=="select"); draw_button(game,game.LevelEditorSystem.PAINT_TOOL_BUTTON,"КИСТЬ",state.tool=="paint"); draw_button(game,game.LevelEditorSystem.FILL_TOOL_BUTTON,"ОБЛАСТЬ",state.tool=="fill"); draw_button(game,game.LevelEditorSystem.PICKER_TOOL_BUTTON,"ПИПЕТКА",state.tool=="picker"); draw_button(game,game.LevelEditorSystem.ERASE_TOOL_BUTTON,"ЛАСТИК",state.tool=="erase")
	draw_section_label(game,375,"ФАЙЛ И ТЕСТ")
	draw_button(game,game.LevelEditorSystem.NEW_BUTTON,"НОВЫЙ",false); draw_button(game,game.LevelEditorSystem.SAVE_BUTTON,"СОХР.",false); draw_button(game,game.LevelEditorSystem.LOAD_BUTTON,"ЗАГР.",false); draw_button(game,game.LevelEditorSystem.EXPORT_BUTTON,"ЭКСПОРТ",true)
	draw_button(game,game.LevelEditorSystem.IMPORT_BUTTON,"ИМПОРТ",false); draw_button(game,game.LevelEditorSystem.PUBLISH_BUTTON,"▶  T · ЗАПУСТИТЬ УРОВЕНЬ",true); draw_button(game,game.LevelEditorSystem.VALIDATE_BUTTON,"✓  R · ПРОВЕРИТЬ КАРТУ",not state.validation.is_empty() and bool(state.validation.get("valid",false)))
	draw_section_label(game,458,"КАРТА")
	draw_button(game,game.LevelEditorSystem.GRID_BUTTON,"СЕТКА %d"%int(state.grid),false); draw_button(game,game.LevelEditorSystem.SLICE_BUTTON,"СРЕЗ %s"%("ALL" if int(state.slice_size)==0 else str(state.slice_size)),false); draw_button(game,game.LevelEditorSystem.LAYER_BUTTON,layer_name(String(state.layer)),true)
	draw_section_label(game,505,"ВЫБРАННЫЙ ОБЪЕКТ")
	draw_button(game,game.LevelEditorSystem.COLLISION_BUTTON,"КОЛЛИЗИЯ: %s"%("ДА"if state.collision else"НЕТ"),bool(state.collision)); draw_button(game,game.LevelEditorSystem.LEVEL_NAME_BUTTON,"ИМЯ УРОВНЯ",false); draw_button(game,game.LevelEditorSystem.ROLE_BUTTON,"M · РОЛЬ",game.LevelEditorSystem.valid_selection(state) and not String(state.objects[state.selected].get("runtime_role","")).is_empty())
	draw_button(game,game.LevelEditorSystem.OBJECT_NAME_BUTTON,"ПОДПИСЬ ОБЪЕКТА",false); draw_button(game,game.LevelEditorSystem.OBJECT_NOTE_BUTTON,"ЗАМЕТКА ДИЗАЙНЕРА",false)
	var status: String = String(state.status); if not String(state.text_mode).is_empty(): status="▌ "+String(state.text_buffer)
	game.DebugUiKitSystem.draw_readout(game,Rect2(20,592,400,30),true); var status_fit:Dictionary=game.DebugUiKitSystem.fit_label(game.UI_FONT,status,382,10,8); game.draw_ui_string(game.UI_FONT,Vector2(29,612),String(status_fit.text),HORIZONTAL_ALIGNMENT_LEFT,382,int(status_fit.size),Color("ffe099"))
	draw_selection_info(game,state)
	draw_validation_info(game,state)
	var help_rect:=HELP_RECT; game.DebugUiKitSystem.draw_readout(game,help_rect,true); game.draw_ui_string(game.UI_FONT,help_rect.position+Vector2(12,20),"F12 закрыть  •  T тест  •  M роль  •  C контуры  •  Shift/Alt + стрелки — collision-box",HORIZONTAL_ALIGNMENT_CENTER,help_rect.size.x-24,10,Color(1,0.95,0.78,0.92))
	GroupRenderer.draw_panel(game,state)
	AtlasPickerRenderer.draw(game,state)


## Рисует шесть видимых строк ресурсов с настоящими миниатюрами и путями файлов.
static func draw_assets(game: Node2D, state: Dictionary) -> void:
	var entries: Array[Dictionary] = game.LevelEditorSystem.visible_catalog(state); var start: int = clampi(int(state.scroll),0,maxi(entries.size()-game.LevelEditorSystem.VISIBLE_ASSETS,0))
	for row in game.LevelEditorSystem.VISIBLE_ASSETS:
		var index: int = start+row; var rect: Rect2 = Rect2(game.LevelEditorSystem.ASSET_ROWS.position+Vector2(0,row*game.LevelEditorSystem.ASSET_ROW_HEIGHT),Vector2(game.LevelEditorSystem.ASSET_ROWS.size.x,CATALOG_ROW_DRAW_HEIGHT)); var selected: bool = index<entries.size() and entries[index].path==state.selected_asset; game.DebugUiKitSystem.draw_catalog_row(game,rect,selected,true)
		if index>=entries.size(): continue
		var entry:Dictionary=entries[index]; var texture: Texture2D = texture_for(String(entry.path))
		if texture!=null:
			var slice_size:=int(entry.get("slice_size",0)); var source:Rect2=game.LevelEditorSystem.selected_source(texture,state) if selected else (Rect2(0,0,slice_size,slice_size) if slice_size>0 else Rect2()); var texture_size: Vector2 = source.size if source.size!=Vector2.ZERO else texture.get_size(); var scale: float = minf(28.0/maxf(texture_size.x,1),28.0/maxf(texture_size.y,1)); var thumb: Rect2 = Rect2(rect.position+Vector2(9,6)+(Vector2(32,28)-texture_size*scale)*0.5,texture_size*scale)
			if source.size==Vector2.ZERO: game.draw_texture_rect(texture,thumb,false)
			else: game.draw_texture_rect_region(texture,thumb,source)
		var badge:="  ◈" if not String(entry.get("unique_key","")).is_empty() else ("  ▦%d"%int(entry.get("frame_count",1)) if bool(entry.get("sliced",false)) else "")
		var fitted:Dictionary=game.DebugUiKitSystem.fit_label(game.UI_FONT,String(entry.name)+badge,304,CATALOG_TITLE_SIZE,8); game.draw_ui_string(game.UI_FONT,rect.position+Vector2(48,CATALOG_TITLE_BASELINE),String(fitted.text),HORIZONTAL_ALIGNMENT_LEFT,304,int(fitted.size),ROW_TEXT)
		var path_label:Dictionary=game.DebugUiKitSystem.fit_label(game.UI_FONT,String(entry.path).trim_prefix("res://assets/game/"),304,CATALOG_PATH_SIZE,CATALOG_PATH_SIZE); game.draw_ui_string(game.UI_FONT,rect.position+Vector2(48,CATALOG_PATH_BASELINE),String(path_label.text),HORIZONTAL_ALIGNMENT_LEFT,304,int(path_label.size),ROW_MUTED)
		game.draw_ui_string(game.UI_FONT,rect.position+Vector2(rect.size.x-34,26),"★" if String(entry.path) in state.favorites else "☆",HORIZONTAL_ALIGNMENT_CENTER,28,12,ROW_SELECTED if String(entry.path) in state.favorites else ROW_MUTED)


## Показывает краткие технические параметры выбранного объекта справа от панели.
static func draw_selection_info(game: Node2D, state: Dictionary) -> void:
	if not game.LevelEditorSystem.valid_selection(state): return
	var object:Dictionary=state.objects[state.selected]; var rect:=SELECTION_INFO_RECT; game.DebugUiKitSystem.draw_readout(game,rect,true); var collision:Rect2=game.LevelEditorSystem.RuntimeAuthoringSystem.collision_rect(object,game.LevelEditorSystem.object_bounds(object))
	var lines: Array[String] = ["%s · #%s"%[object.name,object.id],"x %.0f · y %.0f · %.0f×%.0f"%[object.position.x,object.position.y,object.size.x,object.size.y],"%s · %s · scale %.2f · collision %s"%[layer_name(object.layer),String(object.get("anchor","center")),game.LevelEditorSystem.object_scale(object),"да"if object.collision else"нет"],"роль %s · box %.0f×%.0f + %.0f,%.0f"%[String(object.get("runtime_role","нет")) if not String(object.get("runtime_role","")).is_empty() else "нет",collision.size.x,collision.size.y,Vector2(object.get("collision_offset",Vector2.ZERO)).x,Vector2(object.get("collision_offset",Vector2.ZERO)).y]]
	for index in lines.size(): var fitted:Dictionary=game.DebugUiKitSystem.fit_label(game.UI_FONT,lines[index],rect.size.x-20,11,8); game.draw_ui_string(game.UI_FONT,rect.position+Vector2(10,22+index*21),String(fitted.text),HORIZONTAL_ALIGNMENT_LEFT,rect.size.x-20,int(fitted.size),TEXT)


## Показывает справа первые проблемы последней проверки, не перекрывая рабочий холст.
static func draw_validation_info(game: Node2D, state: Dictionary) -> void:
	if state.validation.is_empty(): return
	var report:Dictionary=state.validation; var issues:Array=[]; issues.append_array(report.get("errors",[])); issues.append_array(report.get("warnings",[])); var rect:=Rect2(VALIDATION_INFO_RECT.position,Vector2(VALIDATION_INFO_RECT.size.x,34+mini(issues.size(),4)*18)); game.DebugUiKitSystem.draw_readout(game,rect,true); game.draw_rect(rect,Color("72d68a") if report.valid else Color("ef6961"),false,2)
	var summary:Dictionary=game.DebugUiKitSystem.fit_label(game.UI_FONT,game.LevelEditorSystem.ValidationSystem.summary(report),rect.size.x-20,11,8); game.draw_ui_string(game.UI_FONT,rect.position+Vector2(10,21),String(summary.text),HORIZONTAL_ALIGNMENT_LEFT,rect.size.x-20,int(summary.size),TEXT)
	for index in mini(issues.size(),4): var fitted:Dictionary=game.DebugUiKitSystem.fit_label(game.UI_FONT,"• "+String(issues[index]),rect.size.x-20,9,7); game.draw_ui_string(game.UI_FONT,rect.position+Vector2(10,41+index*18),String(fitted.text),HORIZONTAL_ALIGNMENT_LEFT,rect.size.x-20,int(fitted.size),MUTED)


## Рисует одну кнопку в едином деревянно-золотом стиле интерфейса игры.
static func draw_button(game: Node2D, rect: Rect2, label: String, active: bool) -> void:
	game.DebugUiKitSystem.draw_button(game,rect,label,active,true,true)


## Разделяет плотную панель коротким заголовком и линией, создавая читаемую визуальную иерархию.
static func draw_section_label(game:Node2D,baseline:float,label:String)->void:
	game.draw_ui_string(game.UI_FONT,Vector2(24,baseline),label,HORIZONTAL_ALIGNMENT_LEFT,126,8,Color("d9b96f")); game.draw_line(Vector2(142,baseline-3),Vector2(416,baseline-3),Color(0.85,0.68,0.32,0.28),1.0)


## Переводит внутренний идентификатор слоя в короткую русскую подпись.
static func layer_name(layer: String) -> String:
	return {"background":"ФОН","ground":"ЗЕМЛЯ","objects":"ОБЪЕКТЫ","foreground":"ПЕРЕДНИЙ"}.get(layer,layer)
