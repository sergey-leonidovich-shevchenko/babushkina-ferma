extends "res://tests/suites/suite_base.gd"

const Overlay := preload("res://scripts/systems/debug_overlay_system.gd")
const WildlifeNavigation := preload("res://scripts/systems/wildlife_navigation_system.gd")


class CountedNavigation extends RefCounted:
	var calls := 0
	var allowed := true

	## Считает настоящие запросы движения, чтобы тест бюджета не зависел от мощности компьютера.
	func is_walkable(_game: Node, _position: Vector2) -> bool:
		calls += 1
		return allowed


class WildlifeFixture extends Node:
	var NavigationSystem := CountedNavigation.new()


class OverlayFixture extends Node:
	var current_location := "cave"
	var camera_offset := Vector2.ZERO


## Запускает контракт общего render-бюджета фоновой диагностической сетки.
func run() -> void:
	test_physics_catchup_cannot_multiply_the_render_budget()
	test_overlay_update_uses_the_render_guard()
	test_stationary_wildlife_does_not_probe_ten_escape_directions()


## Сценарий: после медленного кадра движок исполняет восемь физических тиков до следующей отрисовки.
## Исходное состояние: отдельная F10-панель ещё не использовала бюджет текущего render-кадра.
## Ожидаемый результат: разрешён только первый пакет; новый кадр и независимая панель получают собственный пакет.
func test_physics_catchup_cannot_multiply_the_render_budget() -> void:
	var state := Overlay.default_state()
	expect(Overlay.claim_render_frame_budget(state, 100), "first physics tick receives the F10 render-frame budget")
	var extra_packets := 0
	for _tick in 8:
		if Overlay.claim_render_frame_budget(state, 100): extra_packets += 1
	expect(extra_packets == 0, "eight catch-up physics ticks cannot multiply the diagnostic grid budget")
	expect(Overlay.claim_render_frame_budget(state, 101), "next rendered frame can continue the pending navigation grid")
	expect(Overlay.claim_render_frame_budget(Overlay.default_state(), 101), "independent diagnostic states do not share a global starvation lock")


## Сценарий: входной update отладки получает восемь физических тиков с одинаковым номером render-кадра.
## Исходное состояние: панель открыта, рисование сетки выключено, история кадров пуста.
## Ожидаемый результат: update использует переданный frame-clock и публикует только одну запись этого кадра.
func test_overlay_update_uses_the_render_guard() -> void:
	var game := OverlayFixture.new()
	var state := Overlay.default_state()
	state.grid = false
	game.set_meta(Overlay.META_KEY, state)
	for _tick in 8: Overlay.update(game, 1.0 / 60.0, 100)
	expect(game.get_meta(Overlay.META_KEY).frame_history.size() == 1, "F10 update applies its frame-clock guard to repeated physics catch-up calls")
	game.free()


## Сценарий: зверь отдыхает после побега, затем делает горизонтальный шаг по свободной земле и к стене.
## Исходное состояние: навигационный двойник считает обращения, положение и дом зверя совпадают.
## Ожидаемый результат: покой не вызывает проверок; шаг проверяет только ненулевую ось и сохраняет запрет стены.
func test_stationary_wildlife_does_not_probe_ten_escape_directions() -> void:
	var game := WildlifeFixture.new()
	var start := Vector2(100, 100)
	var animal := {"position": start, "home": start}
	expect(WildlifeNavigation.steer(game, animal, Vector2.RIGHT, 0.0, 320.0) == start and game.NavigationSystem.calls == 0, "resting wildlife does not run ten redundant collision probes each physics tick")
	var moved := WildlifeNavigation.move(game, start, Vector2(4, 0), start, 320.0)
	expect(moved == start + Vector2(4, 0) and game.NavigationSystem.calls == 1, "horizontal wildlife motion performs only its real axis collision probe")
	game.NavigationSystem.allowed = false
	expect(WildlifeNavigation.move(game, start, Vector2(4, 0), start, 320.0) == start, "skipping empty axes never skips the actual wall collision")
	game.free()
