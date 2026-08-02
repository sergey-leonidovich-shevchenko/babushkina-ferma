extends RefCounted

## Типизированное состояние домашнего сундука без правил интерфейса и перемещения предметов.

var owned := false
var counts: Dictionary = {}


## Возвращает количество предмета, лежащего в домашнем сундуке.
func count(kind: String) -> int:
	return maxi(int(counts.get(kind, 0)), 0)


## Изменяет количество предмета в сундуке, не допуская отрицательного остатка.
func change(kind: String, amount: int) -> bool:
	if kind.is_empty() or count(kind) + amount < 0:
		return false
	var updated := count(kind) + amount
	if updated == 0:
		counts.erase(kind)
	else:
		counts[kind] = updated
	return true


## Приводит загруженное содержимое сундука к неотрицательным целым значениям.
func normalize() -> void:
	for kind in counts.keys():
		var amount := maxi(int(counts[kind]), 0)
		if kind.is_empty() or amount == 0:
			counts.erase(kind)
		else:
			counts[kind] = amount
