extends RefCounted

const Actions := preload("res://scripts/systems/storage_actions_system.gd")
const Locale := preload("res://scripts/systems/storage_actions_locale.gd")
const Style := preload("res://scripts/presentation/moon_theme.gd")
const KEYS := ["all","matching","bag","container"]
const CHEST := [Rect2(40,580,240,36),Rect2(288,580,240,36),Rect2(536,580,284,36),Rect2(828,580,284,36)]
const CABINET := [Rect2(40,580,240,36),Rect2(288,580,240,36),Rect2(536,580,284,36),Rect2(828,580,284,36)]

## Даёт общую геометрию четырёх действий для отрисовки, указателя и проверок.
static func rect(index: int, cabinet: bool) -> Rect2:
	return CABINET[index] if cabinet else CHEST[index]

## Выполняет только действие явно нажатой кнопки, не смешивая перенос всех вещей с переносом стека.
static func pointer(game: Node, point: Vector2, cabinet: bool) -> bool:
	if not Actions.available(game,cabinet): return false
	for index in KEYS.size():
		if not rect(index,cabinet).has_point(point): continue
		match index:
			0: Actions.deposit_all(game,cabinet)
			1: Actions.deposit_all(game,cabinet,true)
			2: Actions.sort_bag(game,cabinet)
			3: Actions.sort_container(game,cabinet)
		return true
	return false

## Рисует быстрые действия в существующем стиле каждого окна и затемняет недоступный перенос.
static func draw(game: Node, cabinet: bool, view: Dictionary = {}) -> void:
	for index in KEYS.size():
		var key:String=KEYS[index]
		var label:String=Locale.sort_label(game,key) if index>=2 else Locale.text(game,key)
		var enabled:=true
		if index<2: enabled=Actions.available(game,cabinet) and bool(view.get("matching" if index==1 else "all",false)) if not view.is_empty() else not Actions.candidates(game,cabinet,index==1).is_empty()
		Style.button(game,rect(index,cabinet),label,false,enabled)
