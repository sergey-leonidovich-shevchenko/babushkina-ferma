extends RefCounted

const MoonStyle := preload("res://scripts/presentation/moon_theme.gd")
const Hub := preload("res://scripts/systems/menu_hub_system.gd")
const Journal := preload("res://scripts/systems/quest_journal_system.gd")
const Pause := preload("res://scripts/presentation/moon_pause_renderer.gd")
const Hud := preload("res://scripts/presentation/moon_hud_renderer.gd")
const Clock := preload("res://scripts/presentation/celestial_clock_renderer.gd")

## Проверяет реальные области нового меню и метрики всех его динамических подписей на текущей локали.
static func check(game: Node) -> Array[Dictionary]:
	var checks: Array[Dictionary] = []
	for index in Hub.PAGES.size(): line(checks,game,"tab_%d"%index,MoonStyle.word(game,["inventory","journal","hero","world"][index]),Hub.tab_rect(index).grow(-6).size,MoonStyle.BODY_SIZE,9)
	line(checks,game,"paused",MoonStyle.word(game,"paused"),Vector2(191,38),11,8)
	for index in 2: line(checks,game,"group_%d"%index,MoonStyle.word(game,"story" if index==0 else "side"),Journal.group_rect(index).grow(-6).size,MoonStyle.BODY_SIZE,9)
	for index in 3: line(checks,game,"status_%d"%index,MoonStyle.word(game,["active","history","all"][index]),Journal.status_rect(index).grow(-6).size,MoonStyle.BODY_SIZE,9)
	for filter_id in game.InventorySystem.FILTERS:
		var key: String = "inventory_all" if filter_id=="all" else "category_short_"+filter_id
		line(checks,game,"category_"+filter_id,MoonStyle.sentence_case(game.LocaleSystem.ui(key)),Vector2(88,22),MoonStyle.BODY_SIZE,9)
	for slot in ["head","body","legs","hands","offhand","ring"]: line(checks,game,"equipment_"+slot,game.LocaleSystem.ui("offhand_short" if slot=="offhand" else slot),Vector2(86,20),MoonStyle.LABEL_SIZE,9)
	for kind in game.InventorySystem.ITEM_DATA:
		multiline(checks,game,"item_"+kind,game.inventory_item_name(kind),Vector2(176,42),16,9)
		multiline(checks,game,"effect_"+kind,game.ItemPresentationSystem.effect_text(game,kind),Vector2(242,38),MoonStyle.BODY_SIZE,9)
	for key in ["detail_tool","detail_food","detail_equipment","detail_quest","detail_resource"]: multiline(checks,game,key,game.LocaleSystem.ui(key),Vector2(242,52),MoonStyle.BODY_SIZE,9)
	for mission_id in game.QuestSystem.MISSIONS:
		var mission: Dictionary = game.QuestSystem.mission_data(mission_id)
		line(checks,game,"mission_"+mission_id,mission.title,Vector2(615,27),18,10,game.MENU_FONT)
		multiline(checks,game,"description_"+mission_id,mission.description,Vector2(800,34),MoonStyle.BODY_SIZE,9)
	line(checks,game,"calendar",game.LocaleSystem.ui("day_short",[999])+" · "+game.LocaleSystem.ui("season_autumn"),Clock.calendar_rect(Hud.CLOCK).size,MoonStyle.LABEL_SIZE,9)
	line(checks,game,"hud_hp","999 / 999",Hud.HEALTH_VALUE.size,MoonStyle.LABEL_SIZE,11)
	for track in [Hud.MANA,Hud.STAMINA]: line(checks,game,"hud_resource_%d"%track.position.x,"9999",Vector2(track.size.x-32,18),MoonStyle.LABEL_SIZE,11)
	for index in game.MenuSystem.PAUSE_ITEMS.size():
		line(checks,game,"pause_action_%d" % index,MoonStyle.sentence_case(game.LocaleSystem.ui(game.MenuSystem.PAUSE_ITEMS[index])),Pause.label_rect(index).size,MoonStyle.BODY_SIZE,9)
	multiline(checks,game,"pause_context",game.WorldSystem.name(game.current_location),Pause.CONTEXT.size,MoonStyle.LABEL_SIZE,9)
	multiline(checks,game,"pause_last_save",game.LocaleSystem.ui("last_save"),Pause.SAVE_LABEL.size,11,9)
	multiline(checks,game,"pause_save_details",Pause.save_details(game),Pause.SAVE_DETAILS.size,11,9)
	return checks

## Проверяет однострочный текст с тем же вписыванием по ширине и высоте, которое использует тема.
static func line(checks: Array[Dictionary], game: Node, key: String, label: String, area: Vector2, preferred: int, minimum: int, font: Font = null) -> void:
	if font==null: font=game.UI_FONT
	var fitted: int = game.UiScaleSystem.fitted_singleline_font_size(game,font,label,area.x,area.y,preferred)
	record(checks,game,key,fitted>=minimum and font.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,fitted).x<=area.x+0.1 and font.get_height(fitted)<=area.y+0.1)

## Проверяет многострочный текст в фактических контейнерах предмета и карточки задания.
static func multiline(checks: Array[Dictionary], game: Node, key: String, label: String, area: Vector2, preferred: int, minimum: int) -> void:
	var fitted: int = game.UiScaleSystem.fitted_multiline_font_size(game,game.UI_FONT,label,area.x,area.y,preferred)
	var measured: Vector2 = game.UI_FONT.get_multiline_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,area.x,fitted)
	record(checks,game,key,fitted>=minimum and measured.y<=area.y+0.1)

## Добавляет локализованный результат проверки в общий машинный отчёт проекта.
static func record(checks: Array[Dictionary], game: Node, key: String, passed: bool) -> void:
	checks.append({"code":"locale.moon_menu.%s.%s"%[game.LocaleSystem.current,key],"passed":passed,"message":"" if passed else "Подпись нового меню не помещается с читаемым размером"})
