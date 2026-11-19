extends "res://tests/suites/suite_base.gd"

const Visual := preload("res://scripts/systems/hero_visual_system.gd")


## Проверяет настоящие синхронные callbacks и отсутствие флага между draw и мирами.
func run() -> void:
	test_nested_worlds_restore_their_own_scope()
	test_existing_scope_and_inline_preview_are_preserved()


## Сценарий: рендер первого мира вызывает второй, затем возвращается к прежнему миру.
## Ожидается: чужой inline-контакт разрешён; вложенный отдельный проход не оставляет метаданных.
func test_nested_worlds_restore_their_own_scope() -> void:
	var first := Node2D.new()
	var second := Node2D.new()
	var seen: Array[String] = []
	var inline_second := func() -> void:
		expect(not second.has_meta(Visual.CONTACT_SCOPE), "preview keeps its inline contact")
		expect(in_ground_pass(first), "outer world retains its own scope")
		seen.append("inline")
	var nested_second := func() -> void:
		expect(in_ground_pass(second), "nested world owns its contact scope")
		seen.append("nested")
	var outer := func() -> void:
		Visual.draw_player_pass(second, inline_second, false)
		Visual.draw_player_pass(second, nested_second, true)
		expect(not second.has_meta(Visual.CONTACT_SCOPE), "nested world restores absent metadata")
		seen.append("outer")
	Visual.draw_player_pass(first, outer, true)
	expect(seen == ["inline", "nested", "outer"], "each actual body callback runs once in order")
	expect(not first.has_meta(Visual.CONTACT_SCOPE), "outer draw leaves no persistent flag")
	first.free()
	second.free()


## Сценарий: вложенный render использует тот же canvas; отдельно выполняется обычное превью.
## Ожидается: существующее значение восстанавливается побайтно, default API не получает флаг.
func test_existing_scope_and_inline_preview_are_preserved() -> void:
	var canvas := Node2D.new()
	canvas.set_meta(Visual.CONTACT_SCOPE, false)
	var nested := func() -> void:
		expect(in_ground_pass(canvas), "same-world nested draw sees active scope")
	var body := func() -> void:
		Visual.draw_player_pass(canvas, nested, true)
		expect(in_ground_pass(canvas), "nested draw restores parent scope")
	Visual.draw_player_pass(canvas, body, true)
	expect(not in_ground_pass(canvas), "pre-existing false value is restored")
	canvas.remove_meta(Visual.CONTACT_SCOPE)
	var preview := func() -> void:
		expect(
			not canvas.has_meta(Visual.CONTACT_SCOPE),
			"standalone preview has default inline contact"
		)
	Visual.draw_player_pass(canvas, preview, false)
	expect(not canvas.has_meta(Visual.CONTACT_SCOPE), "preview leaves metadata unchanged")
	canvas.free()


## Читает фактический bool-флаг callback без Variant-аргумента в assertion.
func in_ground_pass(canvas: Node2D) -> bool:
	var active: bool = canvas.get_meta(Visual.CONTACT_SCOPE, false)
	return active
