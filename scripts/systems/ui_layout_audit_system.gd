extends RefCounted

const LevelEditorSystem := preload("res://scripts/systems/level_editor_system.gd")
const LevelEditorRenderer := preload("res://scripts/systems/level_editor_renderer.gd")
const AtlasPickerSystem := preload("res://scripts/systems/level_editor_atlas_picker_system.gd")
const AtlasPickerRenderer := preload("res://scripts/systems/level_editor_atlas_picker_renderer.gd")
const GroupSystem := preload("res://scripts/systems/level_editor_group_system.gd")
const InterfaceRenderer := preload("res://scripts/systems/interface_renderer.gd")
const ItemWindowRenderer := preload("res://scripts/systems/item_window_renderer.gd")
const TalentRenderer := preload("res://scripts/systems/talent_renderer.gd")
const FishingRenderer := preload("res://scripts/systems/fishing_renderer.gd")

const MIN_VERTICAL_TEXT_PADDING := 4.0
const MIN_TOUCH_TARGET := 28.0
const EDITOR_BUTTONS := [
	[LevelEditorSystem.CATEGORY_PREV,"‹"],[LevelEditorSystem.SEARCH_BUTTON,"ЗЕМЛЯ · ПОИСК /"],[LevelEditorSystem.CATEGORY_NEXT,"›"],[LevelEditorSystem.FAVORITES_BUTTON,"★ 999"],
	[LevelEditorSystem.SELECT_TOOL_BUTTON,"ВЫБОР"],[LevelEditorSystem.PAINT_TOOL_BUTTON,"КИСТЬ"],[LevelEditorSystem.FILL_TOOL_BUTTON,"ОБЛАСТЬ"],[LevelEditorSystem.PICKER_TOOL_BUTTON,"ПИПЕТКА"],[LevelEditorSystem.ERASE_TOOL_BUTTON,"ЛАСТИК"],
	[LevelEditorSystem.NEW_BUTTON,"НОВЫЙ"],[LevelEditorSystem.SAVE_BUTTON,"СОХР."],[LevelEditorSystem.LOAD_BUTTON,"ЗАГР."],[LevelEditorSystem.EXPORT_BUTTON,"ЭКСПОРТ"],[LevelEditorSystem.IMPORT_BUTTON,"ИМПОРТ"],
	[LevelEditorSystem.PUBLISH_BUTTON,"▶  T · ЗАПУСТИТЬ УРОВЕНЬ"],[LevelEditorSystem.VALIDATE_BUTTON,"✓  R · ПРОВЕРИТЬ КАРТУ"],
	[LevelEditorSystem.GRID_BUTTON,"СЕТКА 96"],[LevelEditorSystem.SLICE_BUTTON,"СРЕЗ 256"],[LevelEditorSystem.LAYER_BUTTON,"ПЕРЕДНИЙ"],
	[LevelEditorSystem.COLLISION_BUTTON,"КОЛЛИЗИЯ: НЕТ"],[LevelEditorSystem.LEVEL_NAME_BUTTON,"ИМЯ УРОВНЯ"],[LevelEditorSystem.ROLE_BUTTON,"M · INTERACTION"],
	[LevelEditorSystem.OBJECT_NAME_BUTTON,"ПОДПИСЬ ОБЪЕКТА"],[LevelEditorSystem.OBJECT_NOTE_BUTTON,"ЗАМЕТКА ДИЗАЙНЕРА"]
]
const ATLAS_BUTTONS := [
	[AtlasPickerSystem.CLOSE_BUTTON,"×"],[AtlasPickerSystem.GRID_TAB,"СЕТКА КАДРОВ"],[AtlasPickerSystem.CUSTOM_TAB,"СВОЯ ОБЛАСТЬ"],
	[AtlasPickerSystem.SLICE_PREV,"‹"],[AtlasPickerSystem.SLICE_LABEL,"ЯЧЕЙКА 256 px"],[AtlasPickerSystem.SLICE_NEXT,"›"],
	[AtlasPickerSystem.PAGE_PREV,"‹ НАЗАД"],[AtlasPickerSystem.PAGE_LABEL,"99 / 99 · 9999 кадров"],[AtlasPickerSystem.PAGE_NEXT,"ВПЕРЁД ›"]
]


## Собирает воспроизводимый отчёт по геометрии, тексту и доступности трёх поверхностей конструктора.
static func project_report(game: Node) -> Dictionary:
	var checks:Array[Dictionary]=[]
	_check_button_group(checks,game,"editor",LevelEditorSystem.PANEL,EDITOR_BUTTONS)
	_check_button_group(checks,game,"atlas",AtlasPickerSystem.PANEL,ATLAS_BUTTONS)
	_check_editor_catalog(checks,game)
	_check_atlas_grid(checks)
	_check_layer_palette(checks)
	_check_inventory(checks)
	_check_item_windows(checks)
	_check_hud(checks)
	_check_talent_tree(checks)
	_check_fishing(checks)
	var failed:=checks.filter(func(check:Dictionary):return not bool(check.passed))
	return {"schema":1,"scope":"project_ui","surfaces":8,"checks":checks.size(),"passed":checks.size()-failed.size(),"failed":failed.size(),"source_metrics":_source_metrics(),"issues":failed}


## Проверяет принадлежность кнопок контейнеру, минимальную hit-зону, отсутствие пересечений и текстовую safe-area.
static func _check_button_group(checks:Array[Dictionary],game:Node,prefix:String,container:Rect2,buttons:Array)->void:
	for index in buttons.size():
		var rect:Rect2=buttons[index][0]; var label:=String(buttons[index][1]); _record(checks,"%s.button.%d.contained"%[prefix,index],container.encloses(rect),"Кнопка выходит за родительскую панель")
		_record(checks,"%s.button.%d.touch"%[prefix,index],rect.size.x>=MIN_TOUCH_TARGET and rect.size.y>=MIN_TOUCH_TARGET,"Кнопка меньше минимальной hit-зоны")
		var layout:Dictionary=game.DebugUiKitSystem.button_text_layout(rect,true); var fitted:Dictionary=game.DebugUiKitSystem.fit_label(game.UI_FONT,label,float(layout.width),int(layout.preferred_size),int(layout.minimum_size)); var font_size:=int(fitted.size); var top:float=float(layout.baseline)-game.UI_FONT.get_ascent(font_size); var bottom:float=rect.size.y-(float(layout.baseline)+game.UI_FONT.get_descent(font_size))
		_record(checks,"%s.button.%d.text"%[prefix,index],game.UI_FONT.get_string_size(String(fitted.text),HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x<=float(layout.width) and top>=MIN_VERTICAL_TEXT_PADDING and bottom>=MIN_VERTICAL_TEXT_PADDING,"Подпись касается резной рамки")
	for first in buttons.size():
		for second in range(first+1,buttons.size()): _record(checks,"%s.overlap.%d.%d"%[prefix,first,second],not (buttons[first][0] as Rect2).intersects(buttons[second][0] as Rect2),"Кнопки пересекаются")


## Проверяет независимые вертикальные зоны миниатюры, названия и пути в карточке каталога.
static func _check_editor_catalog(checks:Array[Dictionary],game:Node)->void:
	var title_top:float=LevelEditorRenderer.CATALOG_TITLE_BASELINE-game.UI_FONT.get_ascent(LevelEditorRenderer.CATALOG_TITLE_SIZE); var path_bottom:float=LevelEditorRenderer.CATALOG_PATH_BASELINE+game.UI_FONT.get_descent(LevelEditorRenderer.CATALOG_PATH_SIZE)
	_record(checks,"editor.catalog.title_top",title_top>=6.0,"Название касается верхней кромки карточки")
	_record(checks,"editor.catalog.line_gap",LevelEditorRenderer.CATALOG_PATH_BASELINE-LevelEditorRenderer.CATALOG_TITLE_BASELINE>=10.0,"Название и путь визуально слипаются")
	_record(checks,"editor.catalog.path_bottom",LevelEditorRenderer.CATALOG_ROW_DRAW_HEIGHT-path_bottom>=7.0,"Путь касается нижней кромки карточки")


## Проверяет, что сетка атласа кратна ячейкам, а номер кадра живёт во внутреннем бейдже.
static func _check_atlas_grid(checks:Array[Dictionary])->void:
	_record(checks,"atlas.grid.contained",AtlasPickerSystem.PANEL.encloses(AtlasPickerSystem.GRID_AREA),"Сетка кадров выходит за модальное окно")
	_record(checks,"atlas.grid.columns",is_equal_approx(AtlasPickerSystem.GRID_AREA.size.x,AtlasPickerSystem.GRID_CELL.x*AtlasPickerSystem.GRID_COLUMNS),"Ширина сетки не кратна колонкам")
	_record(checks,"atlas.grid.rows",is_equal_approx(AtlasPickerSystem.GRID_AREA.size.y,AtlasPickerSystem.GRID_CELL.y*AtlasPickerSystem.GRID_ROWS),"Высота сетки не кратна строкам")
	var cell:=Rect2(Vector2.ZERO,AtlasPickerSystem.GRID_CELL); var badge:=Rect2(AtlasPickerRenderer.FRAME_BADGE_OFFSET,AtlasPickerRenderer.FRAME_BADGE_SIZE)
	_record(checks,"atlas.frame_badge.contained",cell.encloses(badge),"Номер кадра выходит за карточку")
	_record(checks,"atlas.frame_badge.safe",badge.position.x>=AtlasPickerRenderer.PREVIEW_INSET.x and badge.position.y>=AtlasPickerRenderer.PREVIEW_INSET.y,"Номер кадра лежит на деревянной кромке")


## Проверяет четыре строки палитры слоёв и их устойчивый шаг внутри отдельного корпуса.
static func _check_layer_palette(checks:Array[Dictionary])->void:
	_record(checks,"layers.header.contained",GroupSystem.PANEL.encloses(GroupSystem.HEADER),"Заголовок слоёв выходит за панель")
	for index in GroupSystem.LAYERS.size():
		var rect:=Rect2(GroupSystem.ROWS_START+Vector2(0,index*GroupSystem.ROW_HEIGHT),Vector2(176,28)); _record(checks,"layers.row.%d.contained"%index,GroupSystem.PANEL.encloses(rect),"Строка слоя выходит за панель")
		if index>0:
			var previous:=Rect2(GroupSystem.ROWS_START+Vector2(0,(index-1)*GroupSystem.ROW_HEIGHT),Vector2(176,28)); _record(checks,"layers.row.%d.gap"%index,rect.position.y-previous.end.y>=4.0,"Строки слоёв слипаются")


## Проверяет сетку рюкзака, категории, действия и десять быстрых слотов относительно художественного корпуса.
static func _check_inventory(checks:Array[Dictionary])->void:
	for index in 36:
		var slot:=InterfaceRenderer.inventory_slot_rect(index); var icon:=InterfaceRenderer.inventory_icon_rect(index); _record(checks,"inventory.slot.%d.contained"%index,InterfaceRenderer.INVENTORY_WINDOW.encloses(slot),"Слот рюкзака выходит за окно"); _record(checks,"inventory.icon.%d.centered"%index,slot.encloses(icon) and icon.get_center().is_equal_approx(slot.get_center()),"Иконка не центрирована в слоте")
	for index in 10:
		var slot:=InterfaceRenderer.inventory_hotbar_rect(index); var icon:=InterfaceRenderer.hotbar_icon_rect(slot); _record(checks,"inventory.hotbar.%d.contained"%index,InterfaceRenderer.INVENTORY_HOTBAR_SKIN_RECT.encloses(slot),"Быстрый слот выходит за резную панель"); _record(checks,"inventory.hotbar.%d.centered"%index,slot.encloses(icon) and icon.get_center().is_equal_approx(slot.get_center()),"Иконка быстрого слота не центрирована")
	for index in InterfaceRenderer.INVENTORY_FILTERS.size(): _record(checks,"inventory.filter.%d.contained"%index,InterfaceRenderer.INVENTORY_WINDOW.encloses(InterfaceRenderer.inventory_category_rect(index)),"Вкладка категории выходит за окно")
	for data in [["use",InterfaceRenderer.USE_BUTTON],["equip",InterfaceRenderer.EQUIP_BUTTON],["drop",InterfaceRenderer.DROP_BUTTON],["sort",InterfaceRenderer.SORT_BUTTON]]: _record(checks,"inventory.action.%s.contained"%data[0],InterfaceRenderer.INVENTORY_WINDOW.encloses(data[1]),"Кнопка действия выходит за окно")


## Проверяет общий каркас и альтернативные рабочие секции магазина, крафта, склада и кузницы.
static func _check_item_windows(checks:Array[Dictionary])->void:
	_record(checks,"items.shell.viewport",ItemWindowRenderer.VIEWPORT.encloses(ItemWindowRenderer.SHELL),"Корпус предметного окна выходит за viewport")
	_record(checks,"items.close.contained",ItemWindowRenderer.SHELL.encloses(ItemWindowRenderer.CLOSE_BUTTON),"Кнопка закрытия выходит за корпус")
	for data in [["craft",ItemWindowRenderer.CRAFT_SECTION],["shop_stock",ItemWindowRenderer.SHOP_STOCK_SECTION],["shop_table",ItemWindowRenderer.SHOP_TABLE_SECTION],["storage_left",ItemWindowRenderer.STORAGE_LEFT_SECTION],["storage_right",ItemWindowRenderer.STORAGE_RIGHT_SECTION],["forge",ItemWindowRenderer.FORGE_SECTION]]: _record(checks,"items.section.%s.contained"%data[0],ItemWindowRenderer.SHELL.encloses(data[1]),"Рабочая секция выходит за общий корпус")
	_record(checks,"items.storage.gap",ItemWindowRenderer.STORAGE_LEFT_SECTION.end.x<ItemWindowRenderer.STORAGE_RIGHT_SECTION.position.x,"Половины хранилища пересекаются")


## Проверяет шесть независимых модулей постоянного HUD и их принадлежность дизайн-viewport.
static func _check_hud(checks:Array[Dictionary])->void:
	var modules:Array[Rect2]=[InterfaceRenderer.PLAYER_PORTRAIT_RECT,InterfaceRenderer.PLAYER_BARS_RECT,InterfaceRenderer.CLOCK_BADGE,InterfaceRenderer.LOCATION_BADGE,InterfaceRenderer.SKILL_BUTTON,InterfaceRenderer.QUEST_BUTTON]
	for index in modules.size(): _record(checks,"hud.module.%d.contained"%index,InterfaceRenderer.VIEWPORT.encloses(modules[index]) and InterfaceRenderer.HUD_RECT.encloses(modules[index]),"Модуль HUD выходит за верхний корпус")
	for first in modules.size():
		for second in range(first+1,modules.size()): _record(checks,"hud.overlap.%d.%d"%[first,second],not modules[first].intersects(modules[second]),"Модули HUD пересекаются")


## Проверяет дерево талантов, двадцать узлов, подробности и кнопку сброса в пределах книги.
static func _check_talent_tree(checks:Array[Dictionary])->void:
	_record(checks,"talent.panel.viewport",InterfaceRenderer.VIEWPORT.encloses(TalentRenderer.PANEL),"Книга талантов выходит за viewport")
	for data in [["title",TalentRenderer.TITLE_RIBBON],["tree",TalentRenderer.TREE_PANEL],["close",TalentRenderer.CLOSE_BUTTON]]: _record(checks,"talent.%s.contained"%data[0],TalentRenderer.PANEL.encloses(data[1]),"Элемент талантов выходит за книгу")
	var nodes:Array[Rect2]=[]
	for index in 20:
		var rect:=TalentRenderer.node_rect(index); nodes.append(rect); _record(checks,"talent.node.%d.contained"%index,TalentRenderer.TREE_PANEL.encloses(rect),"Узел таланта выходит за дерево")
	for first in nodes.size():
		for second in range(first+1,nodes.size()): _record(checks,"talent.overlap.%d.%d"%[first,second],not nodes[first].intersects(nodes[second]),"Узлы талантов пересекаются")
	_record(checks,"talent.respec.contained",TalentRenderer.TREE_PANEL.encloses(TalentRenderer.RESPEC_BUTTON),"Кнопка сброса выходит за дерево")


## Проверяет три независимые шкалы мини-игры рыбалки и их положение внутри резной панели.
static func _check_fishing(checks:Array[Dictionary])->void:
	var tracks:Array[Rect2]=[FishingRenderer.WATER_TRACK,FishingRenderer.PROGRESS_TRACK,FishingRenderer.TENSION_TRACK]
	for index in tracks.size(): _record(checks,"fishing.track.%d.contained"%index,FishingRenderer.PANEL.encloses(tracks[index]),"Шкала рыбалки выходит за панель")
	for first in tracks.size():
		for second in range(first+1,tracks.size()): _record(checks,"fishing.overlap.%d.%d"%[first,second],not tracks[first].intersects(tracks[second]),"Шкалы рыбалки пересекаются")
	_record(checks,"fishing.panel.viewport",InterfaceRenderer.VIEWPORT.encloses(FishingRenderer.PANEL),"Панель рыбалки выходит за viewport")


## Добавляет одну атомарную проверку с кодом и объяснением только при нарушении.
static func _record(checks:Array[Dictionary],code:String,passed:bool,message:String)->void:
	checks.append({"code":code,"passed":passed,"message":"" if passed else message})


## Инвентаризирует renderer-модули и текстовые вызовы, показывая размер оставшейся зоны ручного риска.
static func _source_metrics()->Dictionary:
	var paths:Array[String]=[]; _collect_renderers("res://scripts/systems",paths); var text_calls:=0; var fitted_calls:=0; var multiline_calls:=0
	for path in paths:
		var source:=FileAccess.get_file_as_string(path); text_calls+=source.count("draw_ui_string("); fitted_calls+=source.count("fit_label("); multiline_calls+=source.count("draw_multiline_string(")
	return {"renderer_modules":paths.size(),"text_draw_calls":text_calls,"adaptive_fit_calls":fitted_calls,"multiline_draw_calls":multiline_calls}


## Рекурсивно собирает только production-renderer файлы, исключая тесты и инструменты.
static func _collect_renderers(directory:String,result:Array[String])->void:
	var access:=DirAccess.open(directory)
	if access==null: return
	access.list_dir_begin()
	var entry:=access.get_next()
	while not entry.is_empty():
		var path:=directory.path_join(entry)
		if access.current_is_dir():
			if not entry.begins_with("."): _collect_renderers(path,result)
		elif entry.ends_with("_renderer.gd"): result.append(path)
		entry=access.get_next()
	access.list_dir_end(); result.sort()
