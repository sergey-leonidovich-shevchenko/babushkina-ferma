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
const WorldMapRenderer := preload("res://scripts/systems/world_map_renderer.gd")
const HudLayoutSystem := preload("res://scripts/systems/hud_layout_system.gd")
const UiScaleSystem := preload("res://scripts/systems/ui_scale_system.gd")

const MIN_VERTICAL_TEXT_PADDING := 4.0
const MIN_TOUCH_TARGET := 28.0
const AUDIT_TEXT_SCALE := 1.2
const AUDIT_LOCALES := ["ru", "en", "es", "de", "fr", "zh"]
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
	_check_hud(checks,game)
	_check_talent_tree(checks)
	_check_fishing(checks)
	var localization:=_check_localized_dynamic_text(checks,game)
	var failed:=checks.filter(func(check:Dictionary):return not bool(check.passed))
	return {"schema":3,"scope":"project_ui","surfaces":8,"checks":checks.size(),"passed":checks.size()-failed.size(),"failed":failed.size(),"localization":localization,"display_profiles":_display_profile_report(),"source_metrics":_source_metrics(),"issues":failed}


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
	_record(checks,"inventory.title.contained",InterfaceRenderer.INVENTORY_WINDOW.encloses(InterfaceRenderer.INVENTORY_TITLE_RECT),"Заголовок рюкзака выходит за художественный корпус")
	_record(checks,"inventory.close.contained",InterfaceRenderer.INVENTORY_WINDOW.encloses(InterfaceRenderer.INVENTORY_CLOSE_BUTTON) and InterfaceRenderer.INVENTORY_CLOSE_BUTTON.size.x>=MIN_TOUCH_TARGET,"Hit-зона крестика рюкзака не совпадает с художественной кнопкой")
	_record(checks,"inventory.detail.contained",InterfaceRenderer.INVENTORY_WINDOW.encloses(InterfaceRenderer.INVENTORY_DETAIL_RECT),"Карточка предмета выходит за окно")
	_record(checks,"inventory.equipment.contained",InterfaceRenderer.INVENTORY_WINDOW.encloses(InterfaceRenderer.INVENTORY_EQUIPMENT_RECT),"Манекен экипировки выходит за окно")
	for index in 36:
		var slot:=InterfaceRenderer.inventory_slot_rect(index); var icon:=InterfaceRenderer.inventory_icon_rect(index); _record(checks,"inventory.slot.%d.contained"%index,InterfaceRenderer.INVENTORY_WINDOW.encloses(slot),"Слот рюкзака выходит за окно"); _record(checks,"inventory.icon.%d.centered"%index,slot.encloses(icon) and icon.get_center().is_equal_approx(slot.get_center()),"Иконка не центрирована в слоте")
	for index in 10:
		var slot:=InterfaceRenderer.inventory_hotbar_rect(index); var icon:=InterfaceRenderer.hotbar_icon_rect(slot); _record(checks,"inventory.hotbar.%d.contained"%index,InterfaceRenderer.INVENTORY_HOTBAR_SKIN_RECT.encloses(slot),"Быстрый слот выходит за резную панель"); _record(checks,"inventory.hotbar.%d.centered"%index,slot.encloses(icon) and icon.get_center().is_equal_approx(slot.get_center()),"Иконка быстрого слота не центрирована")
	var filters:Array[Rect2]=[]
	for index in InterfaceRenderer.INVENTORY_FILTERS.size():
		var filter:=InterfaceRenderer.inventory_category_rect(index); filters.append(filter); _record(checks,"inventory.filter.%d.contained"%index,InterfaceRenderer.INVENTORY_WINDOW.encloses(filter),"Вкладка категории выходит за окно"); _record(checks,"inventory.filter.%d.touch"%index,filter.size.x>=MIN_TOUCH_TARGET and filter.size.y>=MIN_TOUCH_TARGET,"Вкладка категории меньше hit-зоны")
	for first in filters.size():
		for second in range(first+1,filters.size()): _record(checks,"inventory.filter.overlap.%d.%d"%[first,second],not filters[first].intersects(filters[second]),"Вкладки категорий пересекаются")
	var actions:Array[Rect2]=[]
	for data in [["use",InterfaceRenderer.USE_BUTTON],["equip",InterfaceRenderer.EQUIP_BUTTON],["drop",InterfaceRenderer.DROP_BUTTON],["sort",InterfaceRenderer.SORT_BUTTON]]:
		actions.append(data[1]); _record(checks,"inventory.action.%s.contained"%data[0],InterfaceRenderer.INVENTORY_WINDOW.encloses(data[1]),"Кнопка действия выходит за окно"); _record(checks,"inventory.action.%s.touch"%data[0],data[1].size.x>=MIN_TOUCH_TARGET and data[1].size.y>=MIN_TOUCH_TARGET,"Кнопка действия меньше hit-зоны")
	for first in actions.size():
		for second in range(first+1,actions.size()): _record(checks,"inventory.action.overlap.%d.%d"%[first,second],not actions[first].intersects(actions[second]),"Кнопки действий пересекаются")
	_record(checks,"inventory.tooltip.safe",InterfaceRenderer.INVENTORY_DETAIL_RECT.encloses(InterfaceRenderer.INVENTORY_TOOLTIP_RECT) and not InterfaceRenderer.INVENTORY_TOOLTIP_RECT.intersects(InterfaceRenderer.USE_BUTTON),"Описание предмета перекрывает кнопки действий")
	_record(checks,"inventory.last_row.safe",InterfaceRenderer.INVENTORY_GRID_PANEL.encloses(InterfaceRenderer.inventory_slot_rect(35)) and InterfaceRenderer.inventory_slot_rect(35).end.y<=InterfaceRenderer.INVENTORY_GRID_PANEL.end.y-7,"Последняя строка рюкзака перекрывает рамку или номер страницы")


## Проверяет общий каркас и альтернативные рабочие секции магазина, крафта, склада и кузницы.
static func _check_item_windows(checks:Array[Dictionary])->void:
	_record(checks,"items.shell.viewport",ItemWindowRenderer.VIEWPORT.encloses(ItemWindowRenderer.SHELL),"Корпус предметного окна выходит за viewport")
	_record(checks,"items.close.contained",ItemWindowRenderer.SHELL.encloses(ItemWindowRenderer.CLOSE_BUTTON),"Кнопка закрытия выходит за корпус")
	for data in [["craft",ItemWindowRenderer.CRAFT_SECTION],["shop_stock",ItemWindowRenderer.SHOP_STOCK_SECTION],["shop_table",ItemWindowRenderer.SHOP_TABLE_SECTION],["storage_left",ItemWindowRenderer.STORAGE_LEFT_SECTION],["storage_right",ItemWindowRenderer.STORAGE_RIGHT_SECTION],["forge",ItemWindowRenderer.FORGE_SECTION]]: _record(checks,"items.section.%s.contained"%data[0],ItemWindowRenderer.SHELL.encloses(data[1]),"Рабочая секция выходит за общий корпус")
	_record(checks,"items.storage.gap",ItemWindowRenderer.STORAGE_LEFT_SECTION.end.x<ItemWindowRenderer.STORAGE_RIGHT_SECTION.position.x,"Половины хранилища пересекаются")
	_record(checks,"items.craft.list",ItemWindowRenderer.CRAFT_SECTION.encloses(ItemWindowRenderer.CRAFT_LIST),"Список рецептов выходит за секцию")
	_record(checks,"items.craft.detail",ItemWindowRenderer.CRAFT_SECTION.encloses(ItemWindowRenderer.CRAFT_DETAIL),"Подробности рецепта выходят за секцию")
	_record(checks,"items.craft.columns",not ItemWindowRenderer.CRAFT_LIST.intersects(ItemWindowRenderer.CRAFT_DETAIL),"Список и подробности рецепта пересекаются")
	_record(checks,"items.craft.action",ItemWindowRenderer.CRAFT_DETAIL.encloses(ItemWindowRenderer.CRAFT_ACTION),"Подтверждение крафта выходит за секцию подробностей")
	_record(checks,"items.shop.table",ItemWindowRenderer.SHOP_TABLE_SECTION.encloses(ItemWindowRenderer.SHOP_TABLE),"Таблица товаров выходит за секцию")
	_record(checks,"items.shop.tooltip",ItemWindowRenderer.SHOP_STOCK_SECTION.encloses(ItemWindowRenderer.SHOP_TOOLTIP),"Карточка выбранного товара выходит за левую секцию лавки")
	for action in [ItemWindowRenderer.SHOP_BUY_ACTION,ItemWindowRenderer.SHOP_SELL_ACTION]: _record(checks,"items.shop.action.%d"%checks.size(),ItemWindowRenderer.SHOP_STOCK_SECTION.encloses(action) and not ItemWindowRenderer.SHOP_TOOLTIP.intersects(action),"Действие лавки перекрывает карточку товара")
	for action in [ItemWindowRenderer.FORGE_UPGRADE_ACTION,ItemWindowRenderer.FORGE_REPAIR_ACTION]: _record(checks,"items.forge.action.%d"%checks.size(),ItemWindowRenderer.FORGE_SECTION.encloses(action) and not InterfaceRenderer.FORGE_ROWS.intersects(action),"Действие кузницы перекрывает список улучшений")
	for index in 9:
		_record(checks,"items.craft.row.%d"%index,ItemWindowRenderer.CRAFT_LIST.encloses(ItemWindowRenderer.craft_row_rect(index)),"Строка рецепта выходит за список")
		_record(checks,"items.shop.row.%d"%index,ItemWindowRenderer.SHOP_TABLE.encloses(ItemWindowRenderer.shop_row_rect(index)),"Строка товара выходит за таблицу")
		_record(checks,"items.forge.row.%d"%index,ItemWindowRenderer.FORGE_SECTION.encloses(ItemWindowRenderer.forge_row_rect(index)),"Строка улучшения выходит за кузницу")
	for rows in [[ItemWindowRenderer.craft_row_rect(0),ItemWindowRenderer.craft_row_rect(1)],[ItemWindowRenderer.shop_row_rect(0),ItemWindowRenderer.shop_row_rect(1)],[ItemWindowRenderer.forge_row_rect(0),ItemWindowRenderer.forge_row_rect(1)]]: _record(checks,"items.row.pitch.%d"%checks.size(),not (rows[0] as Rect2).intersects(rows[1]),"Соседние строки предметного окна пересекаются")
	for data in [["one",InterfaceRenderer.STORAGE_TRANSFER_ONE],["all",InterfaceRenderer.STORAGE_TRANSFER_ALL]]:
		_record(checks,"items.storage.transfer.%s.contained"%data[0],ItemWindowRenderer.SHELL.encloses(data[1]),"Кнопка переноса выходит за корпус"); _record(checks,"items.storage.transfer.%s.touch"%data[0],data[1].size.x>=MIN_TOUCH_TARGET and data[1].size.y>=MIN_TOUCH_TARGET,"Кнопка переноса меньше hit-зоны"); _record(checks,"items.storage.transfer.%s.clear"%data[0],not data[1].intersects(ItemWindowRenderer.STORAGE_LEFT_SECTION) and not data[1].intersects(ItemWindowRenderer.STORAGE_RIGHT_SECTION),"Кнопка переноса лежит на рамке колонки")
	_record(checks,"items.storage.transfer.gap",not InterfaceRenderer.STORAGE_TRANSFER_ONE.intersects(InterfaceRenderer.STORAGE_TRANSFER_ALL),"Кнопки переноса пересекаются")


## Проверяет постоянный HUD, контекстные зоны и их физическую раскладку на трёх форматах экрана.
static func _check_hud(checks:Array[Dictionary],game:Node)->void:
	var moon = preload("res://scripts/presentation/moon_hud_renderer.gd")
	var modules:Array[Rect2]=[moon.STATUS,moon.CLOCK,preload("res://scripts/systems/menu_hub_system.gd").OPEN_BUTTON,moon.COINS,moon.LOCATION]
	for index in modules.size(): _record(checks,"hud.module.%d.contained"%index,InterfaceRenderer.VIEWPORT.encloses(modules[index]),"Модуль HUD выходит за холст")
	for first in modules.size():
		for second in range(first+1,modules.size()): _record(checks,"hud.overlap.%d.%d"%[first,second],not modules[first].intersects(modules[second]),"Модули HUD пересекаются")
	_record(checks,"hud.context.design.safe",HudLayoutSystem.layout_is_safe(),"Контекстные карточки пересекаются с постоянным HUD или hotbar")
	_record(checks,"hud.context.interior.tutorial.compact",HudLayoutSystem.INTERIOR_TUTORIAL_RECT.get_area()<28000.0 and HudLayoutSystem.INTERIOR_TUTORIAL_RECT.size.x<=304,"Обучение занимает слишком большую часть комнаты")
	_record(checks,"hud.context.interior.objective.compact",HudLayoutSystem.INTERIOR_OBJECTIVE_RECT.get_area()<32000.0,"Цель занимает слишком большую часть комнаты")
	_record(checks,"hud.context.interior.cards.clear",not HudLayoutSystem.INTERIOR_TUTORIAL_RECT.intersects(HudLayoutSystem.INTERIOR_OBJECTIVE_RECT),"Компактные карточки перекрывают друг друга")
	for profile in HudLayoutSystem.DISPLAY_PROFILES:
		var size:=Vector2(profile.size); var physical:Dictionary=HudLayoutSystem.physical_layout(size); var content:Rect2=physical.content; var safe_area:Rect2=physical.safe_area; var cards:Dictionary=physical.cards
		_record(checks,"hud.profile.%s.content"%profile.id,safe_area.grow(0.1).encloses(content) and is_equal_approx(content.size.x/content.size.y,16.0/9.0),"Дизайн-холст искажён или выходит за safe-area")
		for key in cards:
			var card:Rect2=cards[key]; _record(checks,"hud.profile.%s.%s.contained"%[profile.id,key],content.grow(0.1).encloses(card) and safe_area.grow(0.1).encloses(card),"Карточка HUD выходит за физическую safe-area")
		for first_key in cards:
			for second_key in cards:
				if String(first_key)>=String(second_key): continue
				_record(checks,"hud.profile.%s.%s.%s.overlap"%[profile.id,first_key,second_key],not (cards[first_key] as Rect2).intersects(cards[second_key] as Rect2),"Контекстные карточки пересекаются на физическом экране")
		for index in modules.size():
			var module:=UiScaleSystem.design_rect_to_screen(modules[index],size); _record(checks,"hud.profile.%s.module.%d"%[profile.id,index],content.encloses(module),"Модуль верхнего HUD выходит за физический холст")
		var interaction:Rect2=cards.interaction; _record(checks,"hud.profile.%s.interaction.touch"%profile.id,interaction.size.x>=MIN_TOUCH_TARGET and interaction.size.y>=MIN_TOUCH_TARGET,"Физическая зона взаимодействия слишком мала")
	var original_scale:=float(game.settings_state.text_scale); game.settings_state.text_scale=AUDIT_TEXT_SCALE
	_record(checks,"hud.notification.multiline",game.UiScaleSystem.fitted_multiline_font_size(game,game.UI_FONT,"Получено редкое снаряжение и открыта новая глава приключения",HudLayoutSystem.NOTIFICATION_RECT.size.x-90.0,36.0,11)>=7,"Уведомление не помещается в две читаемые строки")
	game.settings_state.text_scale=original_scale


## Проверяет дерево талантов, двадцать узлов, подробности и кнопку сброса в пределах книги.
static func _check_talent_tree(checks:Array[Dictionary])->void:
	_record(checks,"talent.panel.viewport",InterfaceRenderer.VIEWPORT.encloses(TalentRenderer.PANEL),"Книга талантов выходит за viewport")
	for data in [["title",TalentRenderer.TITLE_RIBBON],["tree",TalentRenderer.TREE_PANEL],["close",TalentRenderer.CLOSE_BUTTON]]: _record(checks,"talent.%s.contained"%data[0],TalentRenderer.PANEL.encloses(data[1]),"Элемент талантов выходит за книгу")
	_record(checks,"talent.level_badge.contained",TalentRenderer.DETAILS_RECT.encloses(TalentRenderer.LEVEL_BADGE),"Счётчик уровня выходит за панель подробностей")
	_record(checks,"talent.level_badge.title_gap",not TalentRenderer.LEVEL_BADGE.intersects(TalentRenderer.TITLE_RIBBON),"Счётчик уровня перекрывает заголовок")
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


## Прогоняет динамический текст игровых журналов и пяти предметных окон на шести языках при масштабе 120%.
static func _check_localized_dynamic_text(checks:Array[Dictionary],game:Node)->Dictionary:
	var original_locale:=String(game.LocaleSystem.current); var original_scale:=float(game.settings_state.text_scale); var by_surface:={"fishing":0,"world_guide":0,"quest_log":0,"talent_tree":0,"inventory":0,"shop":0,"crafting":0,"storage":0,"forge":0,"hud":0}; var before:=checks.size()
	game.settings_state.text_scale=AUDIT_TEXT_SCALE
	for locale in AUDIT_LOCALES:
		game.LocaleSystem.set_locale(locale,false)
		_check_fishing_text(checks,game,locale,by_surface)
		_check_world_guide_text(checks,game,locale,by_surface)
		_check_quest_text(checks,game,locale,by_surface)
		_check_talent_text(checks,game,locale,by_surface)
		_check_inventory_text(checks,game,locale,by_surface)
		_check_shop_text(checks,game,locale,by_surface)
		_check_crafting_text(checks,game,locale,by_surface)
		_check_storage_text(checks,game,locale,by_surface)
		_check_forge_text(checks,game,locale,by_surface)
		_check_hud_text(checks,game,locale,by_surface)
		var moon_checks: Array[Dictionary] = preload("res://scripts/presentation/moon_ui_audit.gd").check(game)
		checks.append_array(moon_checks); by_surface.moon_menu=int(by_surface.get("moon_menu",0))+moon_checks.size()
	game.LocaleSystem.set_locale(original_locale,false); game.settings_state.text_scale=original_scale
	return {"locales":AUDIT_LOCALES.duplicate(),"text_scale":AUDIT_TEXT_SCALE,"surfaces":by_surface,"contracts":checks.size()-before}


## Проверяет названия рыб, состояния мини-игры, подсказки и итоговую карточку улова.
static func _check_fishing_text(checks:Array[Dictionary],game:Node,locale:String,counts:Dictionary)->void:
	var contracts:Array=[]
	contracts.append_array([["cast_title",game.LocaleSystem.text("fish_cast_title"),336.0,20,10],["release",game.LocaleSystem.text("fish_release"),336.0,12,8],["minigame_title",game.LocaleSystem.text("fish_minigame_title"),370.0,20,10],["perfect",game.LocaleSystem.text("fish_perfect"),132.0,14,8],["catch_title",game.LocaleSystem.text("fish_catch_title"),402.0,20,10],["escaped",game.LocaleSystem.text("fish_escaped"),402.0,20,10],["result_xp",game.LocaleSystem.text("fish_result_xp",[999]),270.0,10,7],["new_record",game.LocaleSystem.text("fish_new_record"),270.0,11,7],["result_close",game.LocaleSystem.text("fish_result_close"),402.0,10,7]])
	for key in ["shallow","middle","deep"]: contracts.append(["depth_"+key,game.LocaleSystem.text("fish_depth_"+key),100.0,9,7])
	for key in ["common","uncommon","rare","legendary"]: contracts.append(["rarity_"+key,game.LocaleSystem.text("fish_rarity_"+key),132.0,9,7])
	for key in ["mixed","smooth","sinker","floater","dart"]: contracts.append(["behavior_"+key,game.LocaleSystem.text("fish_behavior_"+key),132.0,9,7])
	for key in ["perfect","good","late"]: contracts.append(["hook_"+key,game.LocaleSystem.text("fish_hook_"+key),132.0,9,7])
	for key in ["progress","tension"]: contracts.append(["escape_"+key,game.LocaleSystem.text("fish_escape_"+key),402.0,13,8])
	contracts.append(["progress",game.LocaleSystem.text("fish_catch_progress",[100]),132.0,10,7]); contracts.append(["tension",game.LocaleSystem.text("fish_tension",[100]),132.0,9,7]); contracts.append(["streak",game.LocaleSystem.text("fish_streak",["99.9s","x1.6"]),132.0,9,7]); contracts.append(["hold",game.LocaleSystem.text("fish_hold_hint").replace("\n"," / "),132.0,9,7])
	for fish in game.FishingSystem.FISH_CATALOG: contracts.append(["fish_"+String(fish.id),game.LocaleSystem.text(String(fish.name_key)),132.0,12,8])
	for contract in contracts: _record_text_contract(checks,game,"fishing",locale,contract); counts.fishing=int(counts.fishing)+1


## Проверяет пять вкладок энциклопедии, карту, календарь, бестиарий, коллекцию и рецепты.
static func _check_world_guide_text(checks:Array[Dictionary],game:Node,locale:String,counts:Dictionary)->void:
	var contracts:Array=[["title",game.LocaleSystem.ui("world_guide"),452.0,19,10],["forecast",game.LocaleSystem.ui("guide_week_forecast"),420.0,15,9],["year",game.LocaleSystem.ui("guide_valley_year"),360.0,12,8],["collection",game.LocaleSystem.ui("guide_fish_collection"),600.0,14,8],["legend",game.LocaleSystem.ui("map_legend"),192.0,9,7],["unknown",game.LocaleSystem.ui("map_unknown"),112.0,8,7],["enemy_stats",game.LocaleSystem.ui("guide_enemy_stats",[999,99]),210.0,8,7],["find_enemy",game.LocaleSystem.ui("guide_find_enemy"),118.0,8,7],["recipe_open",game.LocaleSystem.ui("guide_recipe_open"),442.0,11,8],["recipe_locked",game.LocaleSystem.ui("guide_recipe_locked"),442.0,11,8]]
	for key in WorldMapRenderer.PAGE_LABEL_KEYS: contracts.append([key,game.LocaleSystem.ui(key),158.0,10,7])
	for key in ["market","festival","traveler","raid"]: contracts.append(["event_"+key,game.LocaleSystem.ui("guide_event_"+key),91.0,7,7])
	for key in ["spring","summer","autumn","winter"]: contracts.append(["season_"+key,game.LocaleSystem.ui("season_"+key),130.0,12,7])
	for key in ["clear","rain","wind","snow","storm"]: contracts.append(["weather_"+key,game.LocaleSystem.ui("weather_"+key),111.0,10,7])
	for location in game.WorldMapSystem.LOCATIONS: contracts.append(["location_"+String(location),game.LocaleSystem.location(String(location)),192.0,16,8])
	for fish in game.FishingSystem.FISH_CATALOG: contracts.append(["record_"+String(fish.id),game.LocaleSystem.text(String(fish.name_key)),136.0,11,7])
	for contract in contracts: _record_text_contract(checks,game,"world_guide",locale,contract); counts.world_guide=int(counts.world_guide)+1
	_record_multiline_contract(checks,game,"world_guide",locale,["map_close",game.LocaleSystem.ui("map_close"),190.0,176.0,10,7]); counts.world_guide=int(counts.world_guide)+1


## Проверяет заголовки, состояния, описания, цели и навигацию всех сюжетных и побочных миссий.
static func _check_quest_text(checks:Array[Dictionary],game:Node,locale:String,counts:Dictionary)->void:
	var contracts:Array=[["header",game.LocaleSystem.ui("quest_log"),444.0,24,12],["page",game.LocaleSystem.ui("quest_page",[99,99]),292.0,11,8],["close",game.LocaleSystem.ui("quest_close"),190.0,9,7]]
	for state_key in ["locked","available","active","completed"]: contracts.append(["state_"+state_key,game.LocaleSystem.ui(state_key).to_upper(),180.0,11,8])
	for mission_id in game.QuestSystem.MISSIONS:
		var mission:Dictionary=game.QuestSystem.mission_data(String(mission_id)); contracts.append([String(mission_id)+"_type",mission.type,74.0,10,7]); contracts.append([String(mission_id)+"_title",mission.title,510.0,18,9]); contracts.append([String(mission_id)+"_description",mission.description,676.0,11,8]); contracts.append([String(mission_id)+"_objective",game.LocaleSystem.ui("quest_talk_to",[mission.giver]),462.0,10,7])
	for contract in contracts: _record_text_contract(checks,game,"quest_log",locale,contract); counts.quest_log=int(counts.quest_log)+1


## Проверяет четыре ветви, двадцать способностей, статусы, зависимости и управляющие подписи дерева талантов.
static func _check_talent_text(checks:Array[Dictionary],game:Node,locale:String,counts:Dictionary)->void:
	var contracts:Array=[["title",game.TalentSystem.word(game,"title"),444.0,20,10],["level_points",game.LocaleSystem.ui("level_points",[20,99]).to_upper(),140.0,9,7],["learned",game.TalentSystem.word(game,"learned"),128.0,8,7],["available",game.TalentSystem.word(game,"available"),128.0,8,7],["locked",game.TalentSystem.word(game,"locked"),128.0,8,7],["rank",game.TalentSystem.word(game,"rank",false,[3,3]),128.0,8,7],["learn_hint",game.TalentSystem.word(game,"learn_hint"),480.0,9,7],["close",game.TalentSystem.word(game,"close"),216.0,8,7],["respec",game.TalentSystem.word(game,"respec",false,[9999]),200.0,8,7]]
	for group in game.TalentSystem.GROUPS: contracts.append(["group_"+String(group.id),game.TalentSystem.word(game,"group_"+String(group.id)),164.0,10,7])
	for talent in game.TalentSystem.TALENTS:
		var talent_id:=String(talent.id); contracts.append([talent_id+"_node",game.TalentSystem.word(game,talent_id),128.0,10,7]); contracts.append([talent_id+"_detail",game.TalentSystem.word(game,talent_id),488.0,15,9]); _record_multiline_contract(checks,game,"talent_tree",locale,[talent_id+"_description",game.TalentSystem.word(game,talent_id,true),488.0,48.0,11,8]); counts.talent_tree=int(counts.talent_tree)+1
	for contract in contracts: _record_text_contract(checks,game,"talent_tree",locale,contract); counts.talent_tree=int(counts.talent_tree)+1


## Проверяет заголовки, категории, карточку предмета, экипировку и все локализованные имена рюкзака.
static func _check_inventory_text(checks:Array[Dictionary],game:Node,locale:String,counts:Dictionary)->void:
	var contracts:Array=[["title",game.LocaleSystem.ui("backpack_column"),240.0,27,13],["quick_access",game.LocaleSystem.ui("quick_access").get_slice(" • ",0),278.0,13,8],["sort",game.LocaleSystem.ui("sort_inventory"),167.0,10,7],["empty",game.LocaleSystem.ui("empty_slot"),195.0,14,9],["quantity",game.LocaleSystem.ui("quantity",[9999]),185.0,11,8],["sell",game.LocaleSystem.ui("sell_value",[9999]),185.0,10,7],["equipment",game.LocaleSystem.ui("equipment"),194.0,16,9],["use",game.LocaleSystem.ui("eat"),187.0,10,7],["equip",game.LocaleSystem.ui("equip"),86.0,10,7],["drop",game.LocaleSystem.ui("drop_item"),87.0,10,7],["row",game.LocaleSystem.ui("row",[99,99]),91.0,8,7],["compare",game.LocaleSystem.ui("item_compare"),184.0,8,6],["equipped",game.LocaleSystem.ui("item_equipped"),184.0,8,6],["durability",game.LocaleSystem.ui("item_durability",[100]),184.0,9,7]]
	var tooltip:Dictionary=InterfaceRenderer.ItemTooltipRenderer.content_layout(InterfaceRenderer.INVENTORY_TOOLTIP_RECT,false,false)
	for rarity_id in game.ItemPresentationSystem.RARITY_ORDER: contracts.append(["rarity_"+String(rarity_id),game.LocaleSystem.ui("item_rarity_"+String(rarity_id)),tooltip.rarity.size.x,10,8])
	for stat_id in ["damage","defense","health","speed"]: contracts.append(["stat_"+stat_id,game.LocaleSystem.ui("item_stat_"+stat_id)+"  999%  (+999%)",184.0,8,6])
	for filter_id in game.InventorySystem.FILTERS:
		var key:="inventory_all" if filter_id=="all" else "category_short_"+String(filter_id); contracts.append(["filter_"+String(filter_id),game.LocaleSystem.ui(key),61.0,10,7])
	for slot in ["head","body","legs","hands","offhand","ring"]: contracts.append(["slot_"+slot,game.LocaleSystem.ui("offhand_short" if slot=="offhand" else slot),53.0,8,7])
	for kind in game.InventorySystem.ITEM_DATA:
		_record_multiline_contract(checks,game,"inventory",locale,["item_"+String(kind),game.inventory_item_name(String(kind)),tooltip.title.size.x,tooltip.title.size.y,14,10]); counts.inventory=int(counts.inventory)+1
	for kind in game.ItemPresentationSystem.FOOD_EFFECTS:
		var effect:String=game.ItemPresentationSystem.effect_text(game,String(kind)); _record_multiline_contract(checks,game,"inventory",locale,["effect_"+String(kind),effect,tooltip.inner.size.x,38.0,11,8]); counts.inventory=int(counts.inventory)+1
	for detail_key in ["detail_tool","detail_food","detail_equipment","detail_quest","detail_resource"]:
		_record_multiline_contract(checks,game,"inventory",locale,[detail_key,game.LocaleSystem.ui(detail_key),tooltip.description.size.x,tooltip.description.size.y,11,8]); counts.inventory=int(counts.inventory)+1
	for contract in contracts: _record_text_contract(checks,game,"inventory",locale,contract); counts.inventory=int(counts.inventory)+1


## Проверяет заголовки лавки, колонки цен, справку и каждую строку фактического ассортимента.
static func _check_shop_text(checks:Array[Dictionary],game:Node,locale:String,counts:Dictionary)->void:
	var contracts:Array=[["title",game.LocaleSystem.ui("shop"),652.0,28,14],["stock",game.LocaleSystem.ui("grandma_stock"),230.0,18,10],["product",game.LocaleSystem.ui("product"),280.0,13,8],["buy",game.LocaleSystem.ui("buy"),78.0,13,8],["sell",game.LocaleSystem.ui("sell"),78.0,13,8],["help_footer",game.LocaleSystem.ui("shop_help"),820.0,11,8]]
	for product in game.shop_products:
		var label:String=game.inventory_item_name(String(product.kind))
		if bool(product.get("seed",false)):
			var crop_kind:String=game.CropCatalogSystem.crop_for_seed(String(product.kind))
			if not crop_kind.is_empty(): label+="  •  "+game.LocaleSystem.ui("growth_seconds_short",[roundi(game.CropCatalogSystem.growth_duration(crop_kind))])
		contracts.append(["product_"+String(product.kind),label,290.0,11,7])
	_record_multiline_contract(checks,game,"shop",locale,["help_card",game.LocaleSystem.ui("shop_help"),218.0,62.0,11,7]); counts.shop=int(counts.shop)+1
	for contract in contracts: _record_text_contract(checks,game,"shop",locale,contract); counts.shop=int(counts.shop)+1


## Проверяет оба заголовка станций, рецепты, компактные ингредиенты и полные подробности результата.
static func _check_crafting_text(checks:Array[Dictionary],game:Node,locale:String,counts:Dictionary)->void:
	var contracts:Array=[["workbench",game.LocaleSystem.ui("workbench"),652.0,28,14],["cauldron",game.LocaleSystem.ui("cauldron_title"),652.0,28,14],["help",game.LocaleSystem.ui("craft_help"),820.0,11,8]]
	contracts.append(["furnace_title",game.LocaleSystem.ui("furnace_title",[3]),652.0,28,14])
	contracts.append(["furnace_help",game.LocaleSystem.ui("furnace_help"),820.0,12,8])
	for pair in [["furnace_action",182.0],["furnace_load",118.0],["furnace_upgrade",142.0]]: contracts.append([pair[0],game.LocaleSystem.ui(pair[0]),pair[1],11,8])
	for fuel in game.FurnaceSystem.Data.FUELS: contracts.append(["fuel_"+fuel,game.inventory_item_name(fuel)+" ×9999",150.0,11,8])
	var heat:String=game.LocaleSystem.ui("furnace_status",[360.0,3,3])+"\n"+game.LocaleSystem.ui("furnace_remaining",[98.5])
	_record_multiline_contract(checks,game,"crafting",locale,["furnace_heat",heat,210.0,34.0,11,8]); counts.crafting=int(counts.crafting)+1
	var parts:Array[String]=[]
	for kind in game.FurnaceSystem.Data.UPGRADES[1].inputs: parts.append(game.inventory_item_name(kind)+" ×"+str(game.FurnaceSystem.Data.UPGRADES[1].inputs[kind]))
	_record_multiline_contract(checks,game,"crafting",locale,["furnace_upgrade_cost",game.LocaleSystem.ui("furnace_upgrade_cost",[200,", ".join(parts)]),450.0,36.0,10,8]); counts.crafting=int(counts.crafting)+1
	contracts.append(["create",game.LocaleSystem.ui("craft_action"),ItemWindowRenderer.CRAFT_ACTION.size.x-28,14,10])
	for category in ["processing","construction","equipment","general","food"]: contracts.append(["category_"+category,game.LocaleSystem.ui("craft_category_"+category),226.0,12,8])
	for recipe in game.CraftingSystem.RECIPES:
		var recipe_id:=String(recipe.output); contracts.append([recipe_id+"_row",game.inventory_item_name(recipe_id),178.0,12,7]); contracts.append([recipe_id+"_cost",game.CraftingSystem.row_ingredients_text(game,recipe),222.0,10,7])
		_record_multiline_contract(checks,game,"crafting",locale,[recipe_id+"_detail",game.inventory_item_name(recipe_id),226.0,40.0,17,10]); counts.crafting=int(counts.crafting)+1
		_record_multiline_contract(checks,game,"crafting",locale,[recipe_id+"_ingredients",game.CraftingSystem.ingredients_text(game,recipe),210.0,42.0,12,8]); counts.crafting=int(counts.crafting)+1
		_record_multiline_contract(checks,game,"crafting",locale,[recipe_id+"_effect",preload("res://scripts/systems/item_presentation_system.gd").effect_text(game,recipe_id),210.0,34.0,11,8]); counts.crafting=int(counts.crafting)+1
		_record_multiline_contract(checks,game,"crafting",locale,[recipe_id+"_summary",game.CraftingSystem.production_summary(game,recipe),210.0,32.0,11,8]); counts.crafting=int(counts.crafting)+1
	for contract in contracts: _record_text_contract(checks,game,"crafting",locale,contract); counts.crafting=int(counts.crafting)+1


## Проверяет обе колонки сундука, кнопки переноса, справку и любое имя предмета в строке хранения.
static func _check_storage_text(checks:Array[Dictionary],game:Node,locale:String,counts:Dictionary)->void:
	var contracts:Array=[["title",game.LocaleSystem.ui("home_storage"),652.0,28,14],["backpack",game.LocaleSystem.ui("backpack_column"),430.0,16,9],["chest",game.LocaleSystem.ui("chest_column"),430.0,16,9],["one",game.LocaleSystem.ui("transfer_one"),120.0,12,9],["all",game.LocaleSystem.ui("transfer_all"),120.0,12,9],["help",game.LocaleSystem.ui("storage_help"),820.0,12,8]]
	for kind in game.InventorySystem.ITEM_DATA: contracts.append(["item_"+String(kind),game.inventory_item_name(String(kind)),290.0,11,8])
	for contract in contracts: _record_text_contract(checks,game,"storage",locale,contract); counts.storage=int(counts.storage)+1


## Проверяет названия улучшений, уровни, компактные стоимости, прочность и полную локализованную справку кузницы.
static func _check_forge_text(checks:Array[Dictionary],game:Node,locale:String,counts:Dictionary)->void:
	var help:String="%s • %d–%d/%d"%[game.LocaleSystem.ui("forge_help_with_repair"),99,99,99]
	var contracts:Array=[["title",game.LocaleSystem.ui("forge_title"),652.0,28,14],["help",help,820.0,11,7],["level",game.LocaleSystem.ui("upgrade_level",[3,3]),130.0,10,7],["maximum",game.LocaleSystem.ui("upgrade_max"),278.0,9,7],["durability","◆ 100%",110.0,9,7]]
	contracts.append(["upgrade_action",game.LocaleSystem.ui("forge_upgrade_action"),186.0,12,10]); contracts.append(["repair_action",game.LocaleSystem.ui("forge_repair_action")+"  ·  10 ●",186.0,12,10])
	for upgrade in game.ForgeSystem.UPGRADES:
		var kind:=String(upgrade.kind); contracts.append([kind+"_name",game.inventory_item_name(kind),220.0,12,8]); contracts.append([kind+"_cost",game.ForgeSystem.cost_text(game,upgrade,true),278.0,9,7])
	for contract in contracts: _record_text_contract(checks,game,"forge",locale,contract); counts.forge=int(counts.forge)+1


## Проверяет обучение, цели, открытия, уведомления, эффекты и действия адаптивного HUD на шести языках.
static func _check_hud_text(checks:Array[Dictionary],game:Node,locale:String,counts:Dictionary)->void:
	var contracts:Array=[["tutorial_progress",game.LocaleSystem.ui("tutorial_step_compact",[158]),244.0,11,9],["new_nearby",game.LocaleSystem.ui("new_nearby"),214.0,9,8],["story_title",game.LocaleSystem.ui("hud_story_objective"),224.0,11,8],["grandmother_title",game.LocaleSystem.ui("hud_grandmother_quest"),224.0,11,8],["carrots",game.LocaleSystem.ui("hud_carrot_progress",[99,99]),266.0,12,9]]
	for action_key in ["interact","talk","shop","sell","craft","sleep","open","pickup","mine","collect","feed","repair","upgrade","gate","exit","enter"]: contracts.append(["context_"+action_key,game.LocaleSystem.ui("context_action",[game.LocaleSystem.ui("context_"+action_key)]),240.0,11,7])
	for location in game.WorldSystem.LOCATIONS: contracts.append(["location_"+String(location),game.WorldSystem.name(String(location)),282.0,14,9])
	for mission_id in game.QuestSystem.MISSIONS:
		var mission:Dictionary=game.QuestSystem.mission_data(String(mission_id)); contracts.append([String(mission_id)+"_title",mission.title,224.0,11,7]); _record_multiline_contract(checks,game,"hud",locale,[String(mission_id)+"_objective",game.QuestSystem.objective_text(game,String(mission_id)),266.0,41.0,12,8])
	for kind in game.InventorySystem.ITEM_DATA: contracts.append(["notification_"+String(kind),game.LocaleSystem.ui("new_item",[game.inventory_item_name(String(kind))]),382.0,11,7])
	for contract in contracts: _record_text_contract(checks,game,"hud",locale,contract); counts.hud=int(counts.hud)+1
	for step in game.tutorial_steps:
		_record_multiline_contract(checks,game,"hud",locale,["tutorial_"+String(step.event),game.LocaleSystem.tutorial(String(step.event)),268.0,38.0,11,8]); counts.hud=int(counts.hud)+1
	for hint_kind in ["grandmother","shop","workbench","farm","pond","cave","bridge","slime","home_chest","forge","contracts"]:
		var hint:Dictionary=game.DiscoverySystem.static_hint(game,hint_kind); _record_text_contract(checks,game,"hud",locale,["discovery_"+hint_kind+"_title",hint.title,254.0,13,8]); counts.hud=int(counts.hud)+1
		_record_multiline_contract(checks,game,"hud",locale,["discovery_"+hint_kind+"_text",hint.text,254.0,32.0,11,8]); counts.hud=int(counts.hud)+1


## Формирует компактную машинную сводку размеров трёх проверяемых физических экранов.
static func _display_profile_report()->Array[Dictionary]:
	var result:Array[Dictionary]=[]
	for profile in HudLayoutSystem.DISPLAY_PROFILES: result.append({"id":profile.id,"label":profile.label,"width":profile.size.x,"height":profile.size.y})
	return result


## Фиксирует однострочный контракт по реальной метрике шрифта после пользовательского масштабирования.
static func _record_text_contract(checks:Array[Dictionary],game:Node,surface:String,locale:String,contract:Array)->void:
	var effective:int=game.UiScaleSystem.fitted_font_size(game,game.UI_FONT,String(contract[1]),float(contract[2]),int(contract[3])); var actual:float=game.UI_FONT.get_string_size(String(contract[1]),HORIZONTAL_ALIGNMENT_LEFT,-1,effective).x
	_record(checks,"locale.%s.%s.%s"%[surface,locale,String(contract[0])],actual<=float(contract[2])+0.1 and effective>=int(contract[4]),"Текст не помещается с минимально читаемым размером")


## Фиксирует многострочный контракт, учитывая одновременно ширину, высоту и полный объём перевода.
static func _record_multiline_contract(checks:Array[Dictionary],game:Node,surface:String,locale:String,contract:Array)->void:
	var effective:int=game.UiScaleSystem.fitted_multiline_font_size(game,game.UI_FONT,String(contract[1]),float(contract[2]),float(contract[3]),int(contract[4])); var actual:Vector2=game.UI_FONT.get_multiline_string_size(String(contract[1]),HORIZONTAL_ALIGNMENT_LEFT,float(contract[2]),effective)
	_record(checks,"locale.%s.%s.%s"%[surface,locale,String(contract[0])],actual.y<=float(contract[3])+0.1 and effective>=int(contract[5]),"Многострочный текст не помещается с минимально читаемым размером")


## Добавляет одну атомарную проверку с кодом и объяснением только при нарушении.
static func _record(checks:Array[Dictionary],code:String,passed:bool,message:String)->void:
	checks.append({"code":code,"passed":passed,"message":"" if passed else message})


## Инвентаризирует renderer-модули и текстовые вызовы, показывая размер оставшейся зоны ручного риска.
static func _source_metrics()->Dictionary:
	var paths:Array[String]=[]; _collect_renderers("res://scripts/systems",paths); var text_calls:=0; var fitted_calls:=0; var multiline_calls:=0
	for path in paths:
		var source:=FileAccess.get_file_as_string(path); text_calls+=source.count("draw_ui_string("); fitted_calls+=source.count("fit_label("); multiline_calls+=source.count("draw_multiline_string(")
	return {"renderer_modules":paths.size(),"adaptive_single_line_calls":text_calls,"explicit_fit_calls":fitted_calls,"adaptive_multiline_calls":paths.reduce(func(total,path):return total+FileAccess.get_file_as_string(path).count("draw_ui_multiline_string("),0),"raw_multiline_calls":multiline_calls}


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
