extends RefCounted

const WINDOW := Rect2(160,444,832,176)
const PORTRAIT := Rect2(176,461,64,100)
const NAME := Rect2(256,455,520,24)
const FRIENDSHIP := Rect2(842,455,86,24)
const CLOSE := Rect2(944,450,44,44)
const TITLE := Rect2(256,482,672,18)
const BODY := Rect2(256,505,716,44)
const GIFT := Rect2(820,559,154,44)
const HELP := Rect2(256,604,718,14)
const BODY_SIZE := 15

## Возвращает короткую кнопку ответа из той же геометрии, которую проверяет указатель.
static func choice_rect(index: int, count: int) -> Rect2:
	var total:=maxi(1,count); var width:=minf(156,(548.0-12*(total-1))/total)
	return Rect2(256+index*(width+12),559,width,44)

## Находит ответ под мышью или пальцем без попадания в соседнюю кнопку подарка.
static func choice_at(point: Vector2, count: int) -> int:
	for index in count:
		if choice_rect(index,count).has_point(point): return index
	return -1
