extends "res://tools/qa/world/lighting/inventory_game.gd"

var hidden_target := ""
var bad_hud := false
var hidden_passes: Array[String] = []


## Обычный корень использует production renderer; порча HUD существует только как контроль.
func _draw() -> void:
	super._draw()
	if bad_hud and not hud_only:
		draw_set_transform(Vector2.ZERO)
		draw_rect(Rect2(Vector2.ZERO, get_viewport_rect().size), Color(0.05, 0.08, 0.12, 0.45))


## Убирает только прежний проход врагов для пары видимости; AI и полный save не меняются.
func draw_enemy_nodes_and_gate() -> void:
	if not _omit_target_pass("enemy", "enemies"):
		super.draw_enemy_nodes_and_gate()


## Контроль без ресурсного прохода не удаляет жилу из настоящего игрового состояния.
func draw_resource_nodes() -> void:
	if not _omit_target_pass("resource", "resources"):
		super.draw_resource_nodes()


## Фасады рисуются корнем игры; контроль двери пропускает настоящий проход зданий.
func draw_buildings() -> void:
	if not _omit_target_pass("door", "buildings"):
		super.draw_buildings()


## Выход дома находится в проходе интерьера, а не в WorldBackground.
func draw_interior_objects() -> void:
	if not _omit_target_pass("door", "interior"):
		super.draw_interior_objects()


## Записывает действительный пропущенный вызов, не удаляя объекты из игрового состояния.
func _omit_target_pass(target: String, pass_name: String) -> bool:
	if hidden_target != target:
		return false
	hidden_passes.append(pass_name)
	return true
