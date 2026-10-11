extends RefCounted

const MoonStyle := preload("res://scripts/presentation/moon_theme.gd")
const PAGES := ["inventory", "quests", "hero", "world"]
const CLOSE := Rect2(1094, 18, 38, 38)
const OPEN_BUTTON := Rect2(1088, 16, 46, 46)

## Проверяет, открыт ли один из разделов единого полноэкранного меню.
static func active(game: Node) -> bool:
	return game.inventory_open or game.quest_log_open or game.skill_menu_open or game.world_map_open

## Возвращает раздел по действующим флагам, сохраняя совместимость с загрузкой и прежними клавишами.
static func page(game: Node) -> String:
	if game.quest_log_open: return "quests"
	if game.skill_menu_open: return "hero"
	if game.world_map_open: return "world"
	return "inventory"

## Открывает ровно один раздел и сбрасывает удерживаемые действия до остановки мира.
static func open(game: Node, target: String) -> void:
	close(game)
	match target:
		"quests": game.quest_log_open = true; game.notify_tutorial("journal")
		"hero": game.skill_menu_open = true
		"world": game.world_map_open = true; game.notify_tutorial("world_map")
		_: game.inventory_open = true; game.InventorySystem.ensure_counted_items(game); game.InventorySystem.keep_selection_visible(game); game.notify_tutorial("inventory")
	game.clear_movement_keys()
	game.inventory_move_from = -1
	game.state.player.blocking = false
	game.UiFeedbackSystem.update(game,0.0)
	game.queue_redraw()

## Закрывает все разделы меню одновременно, исключая скрытое окно, удерживающее паузу.
static func close(game: Node) -> void:
	game.inventory_open = false; game.quest_log_open = false; game.skill_menu_open = false; game.world_map_open = false
	game.clear_movement_keys()
	game.queue_redraw()

## Возвращает одинаковую область верхней вкладки для рисунка, мыши и касания.
static func tab_rect(index: int) -> Rect2:
	return Rect2(252 + index * 154, 18, 144, 38)

## Рисует общую верхнюю навигацию и явную отметку остановленной симуляции.
static func draw_chrome(game: Node) -> void:
	if not active(game): return
	game.draw_rect(Rect2(0,0,1152,76), MoonStyle.BACKGROUND)
	game.draw_line(Vector2(24,75),Vector2(1128,75),MoonStyle.EDGE,1)
	MoonStyle.title(game, Rect2(26,19,214,32), MoonStyle.word(game,"moon"), 20)
	var labels := [MoonStyle.word(game,"inventory"),MoonStyle.word(game,"journal"),MoonStyle.word(game,"hero"),MoonStyle.word(game,"world")]
	for index in PAGES.size(): MoonStyle.button(game,tab_rect(index),labels[index],page(game)==PAGES[index])
	MoonStyle.text(game,Rect2(884,18,191,38),"Ⅱ  "+MoonStyle.word(game,"paused"),11,MoonStyle.MUTED,HORIZONTAL_ALIGNMENT_CENTER)
	MoonStyle.button(game,CLOSE,"×")

## Перехватывает навигацию раньше отдельных страниц и не отдаёт мышь скрытому игровому HUD.
static func handle_input(game: Node, event: InputEvent) -> bool:
	if not active(game): return false
	if game.inventory_open and event is InputEventJoypadMotion and handle_inventory_trigger(game,event): return true
	if game.quest_log_open and preload("res://scripts/systems/quest_journal_system.gd").handle_input(game,event): return true
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE: close(game); return true
		if game.inventory_open and event.keycode==KEY_M: return false
		var shortcut := {KEY_I:"inventory",KEY_TAB:"inventory",KEY_J:"quests",KEY_K:"hero",KEY_M:"world"}
		if shortcut.has(event.keycode):
			var target: String = shortcut[event.keycode]
			if page(game)==target: close(game)
			else: open(game,target)
			return true
	if event is InputEventJoypadButton and event.pressed:
		if event.button_index == JOY_BUTTON_B: close(game); return true
		if event.button_index==JOY_BUTTON_Y and game.skill_menu_open: game.CompanionSystem.cycle_command(game); return true
		if event.button_index in [JOY_BUTTON_LEFT_SHOULDER,JOY_BUTTON_RIGHT_SHOULDER]:
			open(game,PAGES[posmod(PAGES.find(page(game)) + (-1 if event.button_index==JOY_BUTTON_LEFT_SHOULDER else 1),PAGES.size())]); return true
	var pointer: bool = (event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT) or (event is InputEventScreenTouch and event.pressed)
	if pointer:
		if CLOSE.has_point(event.position): close(game); return true
		for index in PAGES.size():
			if tab_rect(index).has_point(event.position): open(game,PAGES[index]); return true
	return false

## Переключает категории рюкзака триггерами один раз за нажатие, оставляя плечи общей навигации.
static func handle_inventory_trigger(game: Node, event: InputEventJoypadMotion) -> bool:
	if event.axis not in [JOY_AXIS_TRIGGER_LEFT,JOY_AXIS_TRIGGER_RIGHT]: return false
	var key := "moon_trigger_%d"%event.axis
	var pressed: bool = event.axis_value>=0.5
	if pressed and not bool(game.get_meta(key,false)):
		game.InventorySystem.cycle_filter(game,-1 if event.axis==JOY_AXIS_TRIGGER_LEFT else 1)
		game.queue_redraw()
	game.set_meta(key,pressed)
	return true
