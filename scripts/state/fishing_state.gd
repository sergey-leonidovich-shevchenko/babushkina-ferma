extends RefCounted

var phase := "idle"
var timer := 0.0
var cast_power := 0.0
var cast_direction := 1.0
var bar_y := 0.72
var bar_velocity := 0.0
var bar_size := 0.24
var fish_y := 0.5
var fish_velocity := 0.0
var fish_target := 0.5
var fish_target_timer := 0.0
var catch_progress := 0.2
var perfect := true
var elapsed := 0.0
var fish_id := "river_perch"
var fish_name := "Речной окунь"
var fish_behavior := "mixed"
var fish_difficulty := 30.0
var fish_size := 0
var quality := "normal"
var treasure_visible := false
var treasure_appears_at := 1.0
var treasure_y := 0.5
var treasure_progress := 0.0
var treasure_caught := false
var treasure_loot := ""
var total_caught := 0
var best_sizes: Dictionary = {}
var result_text := ""
var traps: Array = []


## Возвращает мини-игру в безопасное исходное состояние, сохраняя рыбную коллекцию героя.
func reset_cast() -> void:
	phase = "idle"
	timer = 0.0
	cast_power = 0.0
	cast_direction = 1.0
	bar_y = 0.72
	bar_velocity = 0.0
	catch_progress = 0.2
	perfect = true
	elapsed = 0.0
	treasure_visible = false
	treasure_appears_at = 1.0
	treasure_progress = 0.0
	treasure_caught = false
	treasure_loot = ""
	result_text = ""


## Приводит постоянную статистику рыбалки после загрузки к допустимым значениям.
func normalize() -> void:
	total_caught = maxi(total_caught, 0)
	for fish_kind in best_sizes:
		best_sizes[fish_kind] = maxi(int(best_sizes[fish_kind]), 0)
	for trap in traps:
		trap.ready_day = maxi(int(trap.get("ready_day", 1)), 1)
	reset_cast()
