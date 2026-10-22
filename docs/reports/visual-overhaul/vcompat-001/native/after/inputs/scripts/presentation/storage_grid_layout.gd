extends RefCounted

const ROWS := 5
const PANELS := [Rect2(32,178,330,392),Rect2(650,178,470,392)]
const DETAIL := Rect2(378,178,256,392)
const TITLE := Rect2(394,208,224,48)
const SEARCH := Rect2(650,140,280,32)
const REFILL := Rect2(946,140,174,32)
const CLOSE := Rect2(1070,26,42,38)

## Даёт одинаковое число колонок для отрисовки, клавиатуры и указателя каждой стороны.
static func columns(side: int) -> int:
	return 5 if side==0 else 7

## Даёт полную область пяти видимых строк независимо от текущей прокрутки.
static func grid(side: int) -> Rect2:
	return Rect2(44 if side==0 else 662,224,300 if side==0 else 434,320)

## Возвращает ячейку без подписи, с отдельной полосой для количества.
static func slot(side: int, visible: int) -> Rect2:
	return Rect2(grid(side).position+Vector2((visible%columns(side))*(60 if side==0 else 62),(visible/columns(side))*64),Vector2(56,60))

## Сохраняет безопасные края маленькой иконки внутри ячейки.
static func icon(side: int, visible: int) -> Rect2:
	return Rect2(slot(side,visible).position+Vector2(8,3),Vector2(40,40))

## Отделяет число от рисунка и соседней строки.
static func count(side: int, visible: int) -> Rect2:
	return Rect2(slot(side,visible).position+Vector2(3,46),Vector2(50,12))

## Размещает четыре количества в центральной карточке, отдельно от обеих сеток.
static func transfer(index: int) -> Rect2:
	return Rect2(390+(index%2)*124,486+(index/2)*40,116,32)

## Возвращает независимую дорожку полосы прокрутки выбранной стороны.
static func track(side: int) -> Rect2:
	return Rect2(346 if side==0 else 1102,224,10,320)

## Вычисляет положение и размер бегунка по фактическому числу строк.
static func thumb(side: int, row: int, total: int) -> Rect2:
	var rect:=track(side); var rows:=maxi(ROWS,ceili(total/float(columns(side)))); var height:=maxf(24,rect.size.y*ROWS/rows)
	return Rect2(rect.position+Vector2(0,(rect.size.y-height)*row/maxi(1,rows-ROWS)),Vector2(rect.size.x,height))
