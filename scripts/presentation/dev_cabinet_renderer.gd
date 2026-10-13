extends RefCounted

const Layout := preload("res://scripts/presentation/storage_grid_layout.gd")
const COLUMNS := 7
const VISIBLE := 35
const SEARCH := Layout.SEARCH
const REFILL := Layout.REFILL
const CLOSE := Layout.CLOSE
const AMOUNTS := [1,10,100,999]
const DETAIL_TITLE := Layout.TITLE

## Сохраняет одинаковые вкладки для рисунка и всех устройств ввода.
static func tab_rect(index: int) -> Rect2:
	return Rect2(40+index*134,96,128,34)

## Даёт ячейку видимой строки правой стороны шкафа.
static func slot_rect(index: int) -> Rect2:
	return Layout.slot(1,index)

## Даёт малую иконку с безопасным прозрачным краем.
static func icon_rect(index: int) -> Rect2:
	return Layout.icon(1,index)

## Даёт отдельную подпись количества без названия предмета в сетке.
static func count_rect(index: int) -> Rect2:
	return Layout.count(1,index)

## Даёт одно из четырёх количеств в центральной карточке.
static func take_rect(index: int) -> Rect2:
	return Layout.transfer(index)

## Возвращает первую видимую строку, сохраняя привычный публичный контракт.
static func start(game: Node) -> int:
	return preload("res://scripts/systems/storage_grid_system.gd").start(game,true,1)

## Делегирует общий трёхколоночный интерфейс шкафа без дублирования сундука.
static func draw(game: Node2D) -> void:
	if preload("res://scripts/systems/dev_cabinet_system.gd").active(game): preload("res://scripts/presentation/storage_grid_renderer.gd").draw(game,true)
