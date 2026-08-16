extends RefCounted

const DEFAULT_UPGRADES := {
	"sword":0, "crystal_sword":0, "bow":0, "arrows":0, "orc_blade":0, "pirate_cutlass":0,
	"iron_spear":0, "war_hammer":0, "moon_staff":0,
	"iron_helmet":0, "guardian_armor":0, "oak_shield":0, "travel_boots":0,
}

var upgrades: Dictionary = DEFAULT_UPGRADES.duplicate(true)


## Возвращает безопасный уровень улучшения выбранного предмета.
func level(kind: String) -> int:
	return clampi(int(upgrades.get(kind, 0)), 0, 3)


## Устанавливает уровень известного улучшения в диапазоне от нуля до трёх.
func set_level(kind: String, value: int) -> bool:
	if not upgrades.has(kind):
		return false
	upgrades[kind] = clampi(value, 0, 3)
	return true


## Нормализует загруженные уровни и добавляет отсутствующие записи новой версии.
func normalize() -> void:
	for kind in DEFAULT_UPGRADES:
		upgrades[kind] = clampi(int(upgrades.get(kind, 0)), 0, 3)
