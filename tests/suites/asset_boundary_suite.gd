extends "res://tests/suites/suite_base.gd"

const Catalog := preload("res://scripts/systems/level_editor_asset_catalog_system.gd")
const Actors := preload("res://scripts/editor/editor_actor_source_system.gd")


## Проверяет границу исходников реальным обходом конструктора и прямым чтением диагностических файлов.
func run() -> void:
	test_ignored_subtree_is_hidden_even_when_requested_directly()
	test_real_sources_stay_readable_without_entering_catalog()


## Сценарий: исходники лежат рядом с игровым спрайтом и могут запрашиваться напрямую.
## Исходное состояние: две собственные тестовые картинки и пустой барьер на родительской папке одной из них.
## Ожидаемый результат: F12 пропускает всё закрытое поддерево, а снятие барьера возвращает обе картинки.
func test_ignored_subtree_is_hidden_even_when_requested_directly() -> void:
	var folder := "user://pipeline-boundary-%s" % Time.get_ticks_usec()
	var nested := folder.path_join("drafts/nested")
	DirAccess.make_dir_recursive_absolute(nested)
	var image := Image.create(16,16,false,Image.FORMAT_RGBA8)
	image.fill(Color(0.8,0.6,0.3,1.0))
	image.save_png(folder.path_join("bench.png"))
	image.save_png(nested.path_join("draft.png"))
	var barrier := folder.path_join("drafts/.gdignore")
	var file := FileAccess.open(barrier,FileAccess.WRITE); file.close()
	var entries := Catalog.scan(folder)
	expect(entries.size()==1 and String(entries[0].path).ends_with("/bench.png"),"catalog excludes the ignored child but preserves its runtime sibling")
	expect(Catalog.scan(nested).is_empty(),"direct nested catalog query respects the ancestor barrier")
	DirAccess.remove_absolute(barrier)
	expect(Catalog.scan(folder).size()==2,"removing the barrier restores both images without filename heuristics")
	DirAccess.remove_absolute(folder.path_join("bench.png")); DirAccess.remove_absolute(nested.path_join("draft.png"))
	DirAccess.remove_absolute(nested); DirAccess.remove_absolute(folder.path_join("drafts")); DirAccess.remove_absolute(folder)


## Сценарий: исходники и эталоны доступны инструментам, но отсутствуют в палитре размещения.
## Исходное состояние: общие барьеры проекта и существующие полноценные шаблоны героя и бабушки.
## Ожидаемый результат: прямое чтение работает, а действующие мастер-листы актёров остаются игровыми ресурсами.
func test_real_sources_stay_readable_without_entering_catalog() -> void:
	for folder in ["res://docs", "res://assets/source", "res://assets/generated", "res://assets/inbox"]:
		expect(Catalog.scan(folder).is_empty(),"non-runtime tree is absent from F12: "+folder)
	var reference := Image.load_from_file(ProjectSettings.globalize_path("res://assets/generated/ui/compact_hud/16x9_ru_normal_120.png"))
	expect(reference!=null and not reference.is_empty(),"ignored reference image remains readable through raw image I/O")
	expect(not FileAccess.get_file_as_string("res://docs/SPRITE_STANDARD.md").is_empty(),"ignored documentation remains readable through FileAccess")
	var entries := Catalog.scan("res://assets/game/characters/hero_v3")
	expect(entries.any(func(entry: Dictionary): return String(entry.path)==Actors.HERO_WALK),"live hero master remains a supported runtime actor template")
