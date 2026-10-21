extends RefCounted

const SELECTABLE := [0,1,3]
const NAMES := {0:"south",1:"west",3:"east"}

## Оставляет видимой лицевую сторону; старое направление вверх использует передний рисунок.
static func visible(direction: int) -> int:
	var value:=posmod(direction,4)
	return 0 if value==2 else value

## Перебирает три полезных ракурса в обоих направлениях без глухой задней стороны.
static func next(direction: int, offset: int=1) -> int:
	return SELECTABLE[posmod(SELECTABLE.find(visible(direction))+offset,SELECTABLE.size())]
