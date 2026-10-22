extends RefCounted

const Cabinet := preload("res://scripts/systems/dev_cabinet_system.gd")
const Actions := preload("res://scripts/systems/storage_actions_system.gd")
const Layout := preload("res://scripts/presentation/storage_grid_layout.gd")

## Хранит раздельные выбор и строки сторон вне игровых сохранений, синхронизируя прежние публичные поля.
static func state(game: Node, cabinet: bool) -> Dictionary:
	var key:="storage_grid_cabinet" if cabinet else "storage_grid_chest"
	if not game.has_meta(key): game.set_meta(key,{"side":1 if cabinet else 0,"selected":[0,0],"rows":[0,0],"drag":-1,"drag_offset":0.0,"touch":-1,"touch_y":0.0,"axes":{}})
	var value:Dictionary=game.get_meta(key)
	if cabinet: value.selected[1]=int(Cabinet.state(game).selected)
	else: value.side=game.storage_side; value.selected[game.storage_side]=game.storage_selected
	return value

## Возвращает весь положительный рюкзак слева и действующий отфильтрованный контейнер справа.
static func items(game: Node, cabinet: bool, side: int) -> Array:
	if side==0: return game.StorageSystem.inventory_items(game)
	return Cabinet.items(game) if cabinet else game.StorageSystem.stored_items(game)

## Ограничивает строку по полному списку, сохраняя построчную прокрутку вместо страниц.
static func maximum_row(game: Node, cabinet: bool, side: int) -> int:
	return maxi(0,ceili(items(game,cabinet,side).size()/float(Layout.columns(side)))-Layout.ROWS)

## Даёт первый индекс видимой строки, не привязывая колесо к перемещению выбранного предмета.
static func start(game: Node, cabinet: bool, side: int) -> int:
	var value:=state(game,cabinet); value.rows[side]=clampi(value.rows[side],0,maximum_row(game,cabinet,side))
	return int(value.rows[side])*Layout.columns(side)

## Выбирает сторону и предмет; при клавиатурном движении мягко доводит прокрутку до нужной строки.
static func select(game: Node, cabinet: bool, side: int, index: int, reveal: bool=true) -> void:
	var value:=state(game,cabinet); value.side=side; value.selected[side]=clampi(index,0,maxi(0,items(game,cabinet,side).size()-1))
	if cabinet:
		if side==1: Cabinet.state(game).selected=value.selected[side]
	else: game.storage_side=side; game.storage_selected=value.selected[side]
	if reveal:
		var row:=int(value.selected[side])/Layout.columns(side)
		if row<int(value.rows[side]): value.rows[side]=row
		elif row>=int(value.rows[side])+Layout.ROWS: value.rows[side]=row-Layout.ROWS+1
		start(game,cabinet,side)
	game.queue_redraw()

## Переключает активную сторону, сохраняя её прежние выбор и прокрутку.
static func switch_side(game: Node, cabinet: bool) -> void:
	var value:=state(game,cabinet); var side:=1-int(value.side)
	select(game,cabinet,side,value.selected[side])

## Перемещает клавиатурный фокус в пределах полного списка активной стороны.
static func move(game: Node, cabinet: bool, offset: int) -> void:
	var value:=state(game,cabinet); select(game,cabinet,value.side,int(value.selected[value.side])+offset)

## Прокручивает только сторону под указателем ровно на заданное число строк.
static func scroll(game: Node, cabinet: bool, side: int, rows: int) -> void:
	var value:=state(game,cabinet); value.rows[side]=clampi(int(value.rows[side])+rows,0,maximum_row(game,cabinet,side)); game.queue_redraw()

## Определяет контейнер под указателем, включая независимую полосу прокрутки.
static func side_at(point: Vector2) -> int:
	for side in 2:
		if Layout.PANELS[side].has_point(point): return side
	return -1

## Обновляет центральную карточку только на настоящей непустой ячейке и никогда не переносит предмет.
static func focus(game: Node, cabinet: bool, point: Vector2) -> bool:
	var side:=side_at(point)
	if side<0: return false
	var first:=start(game,cabinet,side); var choices:=items(game,cabinet,side)
	for visible in Layout.columns(side)*Layout.ROWS:
		if first+visible<choices.size() and Layout.slot(side,visible).has_point(point): select(game,cabinet,side,first+visible,false); return true
	return false

## Возвращает предмет активной стороны, ограничивая выбор после переноса или сортировки.
static func selected(game: Node, cabinet: bool) -> String:
	var value:=state(game,cabinet); var side:int=value.side; var choices:=items(game,cabinet,side)
	if choices.is_empty(): return ""
	var index:=clampi(value.selected[side],0,choices.size()-1)
	return String(choices[index])

## Показывает реальный остаток каждого вида с обеих сторон.
static func count(game: Node, cabinet: bool, side: int, kind: String) -> int:
	return game.inventory_item_count(kind) if side==0 else int(Actions.contents(game,cabinet).get(kind,0))

## Переносит только явную команду из активной стороны и сохраняет существующие ограничения предметов.
static func transfer(game: Node, cabinet: bool, requested: int) -> bool:
	if not Actions.available(game,cabinet): return false
	var value:=state(game,cabinet); var side:int=value.side; var kind:=selected(game,cabinet)
	if kind.is_empty(): return false
	var amount:=count(game,cabinet,side,kind) if requested<0 else mini(requested,count(game,cabinet,side,kind))
	var success:=false
	if cabinet:
		if side==1:
			if kind in Cabinet.UNIQUE and requested!=1: return false
			success=Cabinet.take(game,kind,amount)
		else:
			success=Actions.deposit_cabinet(game,kind,amount)
			if success: Cabinet.refresh_selection(game,Cabinet.selected(game)); Actions.notice(game,true,game.LocaleSystem.text("chest_deposited",[game.inventory_item_name(kind),amount]))
	else: success=game.StorageSystem.deposit(game,kind,amount) if side==0 else game.StorageSystem.withdraw(game,kind,amount)
	select(game,cabinet,side,int(value.selected[side]),false); start(game,cabinet,side)
	return success

## Перетаскивает бегунок по непрерывной дорожке, переводя положение в целую строку.
static func drag(game: Node, cabinet: bool, point: Vector2) -> void:
	var value:=state(game,cabinet); var side:int=value.drag
	if side<0: return
	var track:=Layout.track(side); var thumb:=Layout.thumb(side,value.rows[side],items(game,cabinet,side).size())
	value.rows[side]=clampi(roundi((point.y-track.position.y-float(value.drag_offset))/maxf(1,track.size.y-thumb.size.y)*maximum_row(game,cabinet,side)),0,maximum_row(game,cabinet,side)); game.queue_redraw()

## Начинает перетаскивание бегунка либо перемещает его к нажатому месту дорожки.
static func begin_drag(game: Node, cabinet: bool, point: Vector2) -> bool:
	for side in 2:
		if not Layout.track(side).grow(3).has_point(point): continue
		var value:=state(game,cabinet); var thumb:=Layout.thumb(side,value.rows[side],items(game,cabinet,side).size())
		value.drag=side; value.drag_offset=point.y-thumb.position.y if thumb.has_point(point) else thumb.size.y/2; drag(game,cabinet,point); return true
	return false
