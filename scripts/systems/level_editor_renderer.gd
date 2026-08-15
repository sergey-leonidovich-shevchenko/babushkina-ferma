extends RefCounted

const PANEL_FILL := Color(0.075,0.055,0.035,0.97)
const PANEL_BORDER := Color("d7a94f")
const BUTTON_FILL := Color("553b25")
const BUTTON_ACTIVE := Color("557544")
const TEXT := Color("fff0c8")
const MUTED := Color("c5ae83")
const SELECTED := Color("ffd45c")
static var _texture_cache: Dictionary = {}


## Удерживает загруженные редакторские текстуры между кадрами, чтобы GPU не показывал белый placeholder.
static func texture_for(path: String) -> Texture2D:
	if not _texture_cache.has(path): _texture_cache[path]=ResourceLoader.load(path) as Texture2D
	return _texture_cache[path]


## Рисует размещённые элементы одного смыслового слоя под или над игровыми объектами.
static func draw_layer(game: Node2D, layer: String) -> void:
	if not game.LevelEditorSystem.active(game): return
	var state:Dictionary=game.get_meta(game.LevelEditorSystem.META_KEY)
	for index in state.objects.size():
		var object:Dictionary=state.objects[index]
		if object.get("hidden",false) or String(object.layer)!=layer: continue
		draw_object(game,object,index==int(state.selected) and not bool(state.panel_hidden))
	if layer=="foreground":
		if not bool(state.panel_hidden):
			draw_grid(game,state)
			draw_drag_preview(game,state)


## Отрисовывает обычный спрайт либо технический референс импортированного runtime-объекта.
static func draw_object(game: Node2D, object: Dictionary, selected: bool) -> void:
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
	if bool(object.collision): game.draw_rect(bounds,Color(0.95,0.24,0.22,0.55),false,2.0)
	if selected:
		game.draw_rect(bounds.grow(4),SELECTED,false,3.0)
		for corner in [bounds.position,bounds.position+Vector2(bounds.size.x,0),bounds.end,bounds.position+Vector2(0,bounds.size.y)]: game.draw_rect(Rect2(corner-Vector2(4,4),Vector2(8,8)),Color("fff2a3"))
	if not String(object.name).is_empty() and (selected or bool(object.reference)):
		var label: Rect2 = Rect2(Vector2(center.x-90,bounds.position.y-25),Vector2(180,20)); game.draw_rect(label,Color(0.03,0.025,0.02,0.78)); game.draw_string(game.UI_FONT,label.position+Vector2(4,15),String(object.name),HORIZONTAL_ALIGNMENT_CENTER,label.size.x-8,12,TEXT)


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
	var source: Rect2 = game.LevelEditorSystem.selected_source(texture,state); var size: Vector2 = source.size if source.size!=Vector2.ZERO else texture.get_size(); var entry: Dictionary = game.LevelEditorSystem.AssetCatalogSystem.find(game.LevelEditorSystem.catalog(),String(state.selected_asset)); var position: Vector2 = game.LevelEditorSystem.placement_position(state,Vector2(state.mouse)+Vector2(game.camera_offset),String(entry.get("anchor","center"))); var destination: Rect2 = game.LevelEditorSystem.object_bounds({"position":position,"size":size,"anchor":entry.get("anchor","center"),"scale":1.0})
	if source.size==Vector2.ZERO: game.draw_texture_rect(texture,destination,false,Color(1,1,1,0.62))
	else: game.draw_texture_rect_region(texture,destination,source,Color(1,1,1,0.62))
	game.draw_rect(destination,Color("8ef09d"),false,2.0)


## Рисует всю панель каталога, настройки объекта, статус и строку горячих клавиш.
static func draw_panel(game: Node2D) -> void:
	if not game.LevelEditorSystem.active(game): return
	var state:Dictionary=game.get_meta(game.LevelEditorSystem.META_KEY)
	if bool(state.panel_hidden): return
	var panel:Rect2=game.LevelEditorSystem.PANEL; game.draw_rect(panel,PANEL_FILL); game.draw_rect(panel,PANEL_BORDER,false,3.0)
	game.draw_string(game.MENU_FONT,Vector2(24,43),"КОНСТРУКТОР УРОВНЕЙ",HORIZONTAL_ALIGNMENT_LEFT,270,18,TEXT)
	draw_button(game,game.LevelEditorSystem.CLOSE_BUTTON,"×",false)
	game.draw_string(game.UI_FONT,Vector2(24,67),"%s · %d объектов"%[state.level_name,state.objects.size()],HORIZONTAL_ALIGNMENT_LEFT,304,12,MUTED)
	draw_button(game,game.LevelEditorSystem.CATEGORY_PREV,"‹",false); draw_button(game,game.LevelEditorSystem.CATEGORY_NEXT,"›",false)
	var category:String=game.LevelEditorSystem.CATEGORIES[int(state.category)]; game.draw_string(game.UI_FONT,Vector2(62,102),game.LevelEditorSystem.CATEGORY_NAMES[category],HORIZONTAL_ALIGNMENT_CENTER,230,14,TEXT)
	draw_assets(game,state)
	draw_button(game,game.LevelEditorSystem.SELECT_TOOL_BUTTON,"V · ВЫБОР",state.tool=="select"); draw_button(game,game.LevelEditorSystem.PAINT_TOOL_BUTTON,"B · КИСТЬ",state.tool=="paint"); draw_button(game,game.LevelEditorSystem.ERASE_TOOL_BUTTON,"E · ЛАСТИК",state.tool=="erase")
	draw_button(game,game.LevelEditorSystem.NEW_BUTTON,"НОВЫЙ",false); draw_button(game,game.LevelEditorSystem.SAVE_BUTTON,"СОХР.",false); draw_button(game,game.LevelEditorSystem.LOAD_BUTTON,"ЗАГР.",false); draw_button(game,game.LevelEditorSystem.EXPORT_BUTTON,"ЭКСПОРТ",true)
	draw_button(game,game.LevelEditorSystem.IMPORT_BUTTON,"ИМПОРТ ЛОКАЦИИ",false); draw_button(game,game.LevelEditorSystem.VALIDATE_BUTTON,"R · ПРОВЕРКА",not state.validation.is_empty() and bool(state.validation.get("valid",false)))
	draw_button(game,game.LevelEditorSystem.GRID_BUTTON,"СЕТКА %d"%int(state.grid),false); draw_button(game,game.LevelEditorSystem.SLICE_BUTTON,"СРЕЗ %s"%("ALL" if int(state.slice_size)==0 else str(state.slice_size)),false); draw_button(game,game.LevelEditorSystem.LAYER_BUTTON,layer_name(String(state.layer)),true)
	draw_button(game,game.LevelEditorSystem.COLLISION_BUTTON,"КОЛЛИЗИЯ %s"%("ДА"if state.collision else"НЕТ"),bool(state.collision)); draw_button(game,game.LevelEditorSystem.LEVEL_NAME_BUTTON,"НАЗВАНИЕ УРОВНЯ",false)
	draw_button(game,game.LevelEditorSystem.OBJECT_NAME_BUTTON,"ПОДПИСЬ ОБЪЕКТА",false); draw_button(game,game.LevelEditorSystem.OBJECT_NOTE_BUTTON,"ЗАМЕТКА",false)
	var status: String = String(state.status); if not String(state.text_mode).is_empty(): status="▌ "+String(state.text_buffer)
	game.draw_rect(Rect2(20,607,314,22),Color("2c2119")); game.draw_string(game.UI_FONT,Vector2(25,623),status,HORIZONTAL_ALIGNMENT_LEFT,304,11,Color("ffe099"))
	draw_selection_info(game,state)
	draw_validation_info(game,state)
	game.draw_string(game.UI_FONT,Vector2(356,24),"F12 закрыть · B кисть · V выбор · E ластик · WASD камера · Ctrl+Z/Y · Q поворот · [ ] масштаб",HORIZONTAL_ALIGNMENT_LEFT,780,12,Color(1,0.95,0.78,0.92))


## Рисует шесть видимых строк ресурсов с настоящими миниатюрами и путями файлов.
static func draw_assets(game: Node2D, state: Dictionary) -> void:
	var entries: Array[Dictionary] = game.LevelEditorSystem.visible_catalog(state); var start: int = clampi(int(state.scroll),0,maxi(entries.size()-game.LevelEditorSystem.VISIBLE_ASSETS,0))
	for row in game.LevelEditorSystem.VISIBLE_ASSETS:
		var index: int = start+row; var rect: Rect2 = Rect2(22,122+row*game.LevelEditorSystem.ASSET_ROW_HEIGHT,310,42); var selected: bool = index<entries.size() and entries[index].path==state.selected_asset; game.draw_rect(rect,BUTTON_ACTIVE if selected else Color("3c2c20")); game.draw_rect(rect,SELECTED if selected else Color("75563a"),false,1.5)
		if index>=entries.size(): continue
		var entry:Dictionary=entries[index]; var texture: Texture2D = texture_for(String(entry.path))
		if texture!=null:
			var source: Rect2 = game.LevelEditorSystem.selected_source(texture,state) if selected else Rect2(); var texture_size: Vector2 = source.size if source.size!=Vector2.ZERO else texture.get_size(); var scale: float = minf(34.0/maxf(texture_size.x,1),34.0/maxf(texture_size.y,1)); var thumb: Rect2 = Rect2(Vector2(28,126+row*game.LevelEditorSystem.ASSET_ROW_HEIGHT)+(Vector2(36,34)-texture_size*scale)*0.5,texture_size*scale)
			if source.size==Vector2.ZERO: game.draw_texture_rect(texture,thumb,false)
			else: game.draw_texture_rect_region(texture,thumb,source)
		game.draw_string(game.UI_FONT,Vector2(70,141+row*game.LevelEditorSystem.ASSET_ROW_HEIGHT),String(entry.name).left(31),HORIZONTAL_ALIGNMENT_LEFT,252,12,TEXT)
		game.draw_string(game.UI_FONT,Vector2(70,157+row*game.LevelEditorSystem.ASSET_ROW_HEIGHT),String(entry.path).trim_prefix("res://assets/game/").left(42),HORIZONTAL_ALIGNMENT_LEFT,252,9,MUTED)


## Показывает краткие технические параметры выбранного объекта справа от панели.
static func draw_selection_info(game: Node2D, state: Dictionary) -> void:
	if not game.LevelEditorSystem.valid_selection(state): return
	var object:Dictionary=state.objects[state.selected]; var rect:=Rect2(356,42,300,82); game.draw_rect(rect,Color(0.04,0.03,0.02,0.88)); game.draw_rect(rect,SELECTED,false,2)
	var lines: Array[String] = ["%s · #%s"%[object.name,object.id],"x %.0f · y %.0f · %.0f×%.0f"%[object.position.x,object.position.y,object.size.x,object.size.y],"%s · %s · scale %.2f · collision %s"%[layer_name(object.layer),String(object.get("anchor","center")),game.LevelEditorSystem.object_scale(object),"да"if object.collision else"нет"]]
	for index in lines.size(): game.draw_string(game.UI_FONT,rect.position+Vector2(10,22+index*21),lines[index],HORIZONTAL_ALIGNMENT_LEFT,rect.size.x-20,12,TEXT)


## Показывает справа первые проблемы последней проверки, не перекрывая рабочий холст.
static func draw_validation_info(game: Node2D, state: Dictionary) -> void:
	if state.validation.is_empty(): return
	var report:Dictionary=state.validation; var issues:Array=[]; issues.append_array(report.get("errors",[])); issues.append_array(report.get("warnings",[])); var rect:=Rect2(670,42,458,34+mini(issues.size(),4)*18); game.draw_rect(rect,Color(0.04,0.03,0.02,0.90)); game.draw_rect(rect,Color("72d68a") if report.valid else Color("ef6961"),false,2)
	game.draw_string(game.UI_FONT,rect.position+Vector2(10,21),game.LevelEditorSystem.ValidationSystem.summary(report),HORIZONTAL_ALIGNMENT_LEFT,rect.size.x-20,12,TEXT)
	for index in mini(issues.size(),4): game.draw_string(game.UI_FONT,rect.position+Vector2(10,41+index*18),"• "+String(issues[index]).left(64),HORIZONTAL_ALIGNMENT_LEFT,rect.size.x-20,10,MUTED)


## Рисует одну кнопку в едином деревянно-золотом стиле интерфейса игры.
static func draw_button(game: Node2D, rect: Rect2, label: String, active: bool) -> void:
	game.draw_rect(rect,BUTTON_ACTIVE if active else BUTTON_FILL); game.draw_rect(rect,SELECTED if active else PANEL_BORDER,false,1.5); game.draw_string(game.UI_FONT,rect.position+Vector2(4,20),label,HORIZONTAL_ALIGNMENT_CENTER,rect.size.x-8,11,TEXT)


## Переводит внутренний идентификатор слоя в короткую русскую подпись.
static func layer_name(layer: String) -> String:
	return {"background":"ФОН","ground":"ЗЕМЛЯ","objects":"ОБЪЕКТЫ","foreground":"ПЕРЕДНИЙ"}.get(layer,layer)
