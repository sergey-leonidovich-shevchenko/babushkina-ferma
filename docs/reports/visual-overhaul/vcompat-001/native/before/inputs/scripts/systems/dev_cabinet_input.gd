extends RefCounted

const Cabinet := preload("res://scripts/systems/dev_cabinet_system.gd")
const Grid := preload("res://scripts/systems/storage_grid_system.gd")
const Controls := preload("res://scripts/systems/storage_grid_input.gd")

## Меняет фокус активной стороны через общий построчный интерфейс.
static func move(game: Node, offset: int) -> void:
	Grid.move(game,true,offset)

## Меняет поиск только в содержимом шкафа и сбрасывает его первую строку.
static func query(game: Node, text: String) -> void:
	Controls.query(game,text)

## Фокусирует настоящую ячейку без выдачи вещей и без выхода из поиска.
static func focus_slot(game: Node, point: Vector2) -> bool:
	return false if Cabinet.state(game).searching else Grid.focus(game,true,point)

## Делегирует указатель общим сеткам и центральным командам переноса.
static func pointer(game: Node, point: Vector2) -> void:
	Controls.pointer(game,point,true)

## Сохраняет самостоятельное редактирование текстового поиска.
static func search_key(game: Node, event: InputEventKey) -> void:
	Controls.search_key(game,event)

## Даёт клавиатуре общий выбор сторон, строк и количеств.
static func keyboard(game: Node, event: InputEventKey) -> void:
	Controls.keyboard(game,event,true)

## Даёт геймпаду тот же фокус и направления переноса.
static func controller(game: Node, event: InputEvent) -> void:
	Controls.controller(game,event,true)

## Перехватывает открытый шкаф раньше боя, движения и обычного рюкзака.
static func handle_input(game: Node, event: InputEvent) -> bool:
	if not Cabinet.active(game): return false
	if not Cabinet.at_cabinet(game): Cabinet.close(game); return true
	Controls.handle(game,event,true); return true
