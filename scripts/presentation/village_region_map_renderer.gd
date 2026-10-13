extends RefCounted

const Data := preload("res://scripts/systems/village_region_data.gd")
const Locale := preload("res://scripts/systems/village_region_locale.gd")
const Style := preload("res://scripts/presentation/moon_theme.gd")
const TOGGLE := Rect2(858,522,192,36)
const POINTS := {"overworld":Vector2(246,356),"village_garden":Vector2(246,238),"village_market":Vector2(476,356),"village_workyard":Vector2(706,238),"village_river":Vector2(706,474),"village_orchard":Vector2(246,474)}
const META := "village_region_map"

## Возвращает наружную область текущей комнаты, сохраняя точный район деревни для схемы проходов.
static func region(game: Node) -> String:
	if game.BuildingSystem.is_interior(game.current_location):
		return String(game.BuildingSystem.BUILDINGS[game.BuildingSystem.INTERIORS[game.current_location].building].location)
	return game.current_location

## Выбирает районную схему по умолчанию в стартовой области либо явному переключению пользователя.
static func active(game: Node) -> bool:
	return bool(game.get_meta(META,Data.contains(region(game))))

## Переключает районную схему и общую карту без перемещения героя или продвижения мира.
static func toggle(game: Node) -> void:
	game.set_meta(META,not active(game)); game.queue_redraw()

## Принимает клавиатуру и геймпад карты раньше игрового ввода и общей навигации рюкзака.
static func handle_input(game: Node, event: InputEvent) -> bool:
	if not game.world_map_open or game.world_guide_page!=0: return false
	var key:bool=event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_V
	var button:bool=event is InputEventJoypadButton and event.pressed and event.button_index==JOY_BUTTON_RIGHT_STICK
	if not key and not button: return false
	toggle(game); return true

## Даёт название перехода между общей картой и районами в общей нарисованной кнопке.
static func draw_toggle(game: Node) -> void:
	Style.button(game,TOGGLE,Locale.text(game,"world" if active(game) else "map"))

## Рисует связанную сеть из шести отдельных карт, текущий район, цель и дневные места жителей.
static func draw(game: Node2D) -> void:
	Style.panel(game,Rect2(62,154,1028,440)); Style.panel(game,Rect2(82,174,744,392),Style.INSET)
	var current:=region(game); var objective:String=game.QuestSystem.objective_region(game); var seen:={}
	for source in Data.IDS:
		for link in Data.passages(source):
			var pair:Array=[source,String(link.target)]; pair.sort(); var edge:String="/".join(pair)
			if seen.has(edge): continue
			seen[edge]=true; game.draw_line(POINTS[source],POINTS[link.target],Style.EDGE,3,true)
	for area in Data.IDS:
		var rect:=Rect2(POINTS[area]-Vector2(88,34),Vector2(176,68))
		Style.panel(game,rect,Style.SELECTED if area==current else Style.PANEL,Style.ACCENT if area in game.state.world.estate.discovered else Style.EDGE)
		if area==objective: game.draw_rect(rect.grow(3),Color("dfc16d"),false,2)
		Style.text(game,Rect2(rect.position+Vector2(8,6),Vector2(160,28)),game.LocaleSystem.location(area),12,Style.TEXT,HORIZONTAL_ALIGNMENT_CENTER)
		Style.text(game,Rect2(rect.position+Vector2(8,38),Vector2(160,22)),residents(game,area),10,Style.MUTED,HORIZONTAL_ALIGNMENT_CENTER)
	Style.panel(game,Rect2(838,174,232,392),Style.INSET)
	Style.text(game,Rect2(854,186,200,44),Locale.text(game,"map"),18,Style.TEXT)
	Style.text(game,Rect2(854,242,200,40),game.LocaleSystem.location(current),14,Style.ACCENT)
	Style.text(game,Rect2(854,296,200,26),Locale.text(game,"daytime"),12,Style.MUTED)
	game.draw_ui_multiline_string(game.UI_FONT,Vector2(854,350),Locale.text(game,"help"),HORIZONTAL_ALIGNMENT_LEFT,200,140,12,5,Style.MUTED)
	draw_toggle(game)

## Подписывает дневное назначение района короткими именами его жителей, а сада — назначением прогулки.
static func residents(game: Node, area: String) -> String:
	var result:=[]
	if area=="overworld": result.append(game.LocaleSystem.entity("grandmother")); result.append(short_name(game,"miron"))
	for npc in Data.NPC_AREAS:
		if Data.NPC_AREAS[npc]==area: result.append(short_name(game,npc))
	return " • ".join(result) if not result.is_empty() else Locale.text(game,"orchard")

## Берёт собственное имя из локализованного полного имени жителя без отдельного словаря дубликатов.
static func short_name(game: Node, npc: String) -> String:
	var parts:PackedStringArray=game.QuestSystem.npc_name(npc).split(" ")
	return parts[-1]
