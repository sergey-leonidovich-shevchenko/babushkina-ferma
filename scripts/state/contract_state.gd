extends RefCounted

const DEFAULT_STATUSES := {"farmer":"available", "hunter":"available", "miner":"available"}

var offer_day: int = 0
var statuses: Dictionary = DEFAULT_STATUSES.duplicate(true)
var completed_total: int = 0
var board_open := false
var selected := 0


## Сбрасывает ежедневные предложения при первом обращении в новый игровой день.
func ensure_day(current_day: int) -> bool:
	if offer_day == current_day:
		return false
	offer_day = maxi(current_day, 1)
	statuses = DEFAULT_STATUSES.duplicate(true)
	selected = 0
	return true


## Возвращает безопасное состояние выбранного типа контракта.
func status(contract_id: String) -> String:
	return String(statuses.get(contract_id, "available"))


## Устанавливает только допустимое состояние известного ежедневного контракта.
func set_status(contract_id: String, value: String) -> bool:
	if not statuses.has(contract_id) or value not in ["available", "active", "completed"]:
		return false
	statuses[contract_id] = value
	return true


## Приводит загруженную репутацию, выбор и состояния контрактов к безопасным значениям.
func normalize() -> void:
	offer_day = maxi(offer_day, 0)
	completed_total = maxi(completed_total, 0)
	selected = clampi(selected, 0, 2)
	for contract_id in DEFAULT_STATUSES:
		var value := String(statuses.get(contract_id, "available"))
		statuses[contract_id] = value if value in ["available", "active", "completed"] else "available"
