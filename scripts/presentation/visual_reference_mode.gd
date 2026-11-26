extends RefCounted

const RenderProbe := preload("res://scripts/presentation/overworld_render_probe.gd")
const META := &"visual_reference_hud"
const EFFECTS := [
	"water_overlays", "ambient_motion", "orchard_weather", "atmosphere", "action_feedback"
]


## Включает временный режим съёмки деревни без записи пользовательских файлов.
static func enable(game: Node, hud: bool = true) -> bool:
	if game.get("current_location") != "overworld":
		return false
	game.set_meta(META, hud)
	game.call("queue_redraw")
	return true


## Возвращает обычную отрисовку без изменения времени, камеры и ресурсов героя.
static func disable(game: Node) -> void:
	if game.has_meta(META):
		game.remove_meta(META)
	game.call("queue_redraw")


## Ограничивает диагностический профиль деревней, не меняя поведение остальных карт.
static func active(game: Node) -> bool:
	return game.has_meta(META) and game.get("current_location") == "overworld"


## Сохраняет прежние декоративные проходы во всех обычных игровых кадрах.
static func effects_enabled(game: Node) -> bool:
	return not active(game)


## Управляет экранным интерфейсом и соседними мировыми подписями независимо от камеры.
static func hud_visible(game: Node) -> bool:
	if RenderProbe.omits(game, RenderProbe.UI):
		return false
	return not active(game) or game.get_meta(META) == true
