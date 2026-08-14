extends "res://tests/suites/suite_base.gd"

const TEST_DRAFT := "user://level_designs/level_editor_suite.json"


## Запускает сценарии каталога, рисования, редактирования, импорта и обменного формата конструктора.
func run() -> void:
	test_catalog_contains_grouped_game_assets()
	test_f12_and_drag_drop_place_sprite_on_live_level()
	test_object_tools_and_history_preserve_layout()
	test_current_location_import_creates_editable_references()
	test_open_json_draft_round_trip_preserves_author_intent()
	test_runtime_integration_freezes_simulation_and_draws_editor_layers()


## Сценарий: каталог автоматически сканирует растровые ресурсы проекта и группирует их по назначению.
## Исходное состояние: кэш конструктора очищен, в assets/game лежат тайлы, дома, растения, герои и предметы.
## Ожидаемый результат: каждый найденный путь существует, а основные дизайнерские группы не пусты.
func test_catalog_contains_grouped_game_assets() -> void:
	var game := make_game()
	game.LevelEditorSystem._catalog.clear()
	var entries: Array[Dictionary] = game.LevelEditorSystem.catalog()
	var categories: Dictionary = {}
	var all_exist := true
	for entry in entries:
		categories[entry.category] = int(categories.get(entry.category,0))+1
		all_exist = all_exist and ResourceLoader.exists(entry.path)
	expect(entries.size() >= 200 and all_exist, "level editor scans every available raster asset lazily")
	expect(entries.all(func(entry: Dictionary): return not "preview" in String(entry.path).to_lower()), "catalog hides technical preview sheets that are not placeable game objects")
	for category in ["terrain","buildings","vegetation","characters","items","farming","fishing","ui"]:
		expect(int(categories.get(category,0)) > 0, "level editor catalog exposes populated group: %s" % category)
	game.free()


## Сценарий: дизайнер открывает конструктор и переносит выбранный тайл из панели прямо на живую карту.
## Исходное состояние: игра находится на первой локации, редактор закрыт, категория земли содержит спрайты.
## Ожидаемый результат: F12 открывает режим, drag-and-drop создаёт объект и привязывает центр к сетке 24 px.
func test_f12_and_drag_drop_place_sprite_on_live_level() -> void:
	var game := make_game()
	var open_event := key_event(KEY_F12,KEY_F12,true)
	expect(game.LevelEditorSystem.handle_input(game,open_event) and game.LevelEditorSystem.active(game), "F12 opens the level editor over the live location")
	var press := InputEventMouseButton.new(); press.button_index=MOUSE_BUTTON_LEFT; press.pressed=true; press.position=Vector2(40,135)
	game.LevelEditorSystem.handle_input(game,press)
	var dragging: Dictionary = game.get_meta(game.LevelEditorSystem.META_KEY)
	expect(dragging.drag_kind == "asset" and not String(dragging.selected_asset).is_empty(), "asset row starts drag-and-drop with a real sprite")
	var release := InputEventMouseButton.new(); release.button_index=MOUSE_BUTTON_LEFT; release.pressed=false; release.position=Vector2(515,347)
	game.LevelEditorSystem.handle_input(game,release)
	var state: Dictionary = game.get_meta(game.LevelEditorSystem.META_KEY)
	expect(state.objects.size()==1 and Vector2(state.objects[0].position)==Vector2(504,336), "dropped sprite is centered on the shared 24 px world grid")
	expect(state.objects[0].asset_path==dragging.selected_asset and Vector2(state.objects[0].size)>Vector2.ZERO, "placed object keeps its asset path and native sprite dimensions")
	game.free()


## Сценарий: размещённый элемент копируют, поворачивают, отражают, масштабируют, удаляют и возвращают.
## Исходное состояние: в черновике один выбранный спрайт с исходной трансформацией и пустой историей.
## Ожидаемый результат: инструменты меняют только выбранный объект, а undo/redo точно восстанавливают состояния.
func test_object_tools_and_history_preserve_layout() -> void:
	var game := make_game()
	var state: Dictionary = game.LevelEditorSystem.default_state(game)
	state.selected_asset="res://assets/game/tiles/grass.png"
	game.LevelEditorSystem.place_selected_asset(game,state,Vector2(500,300))
	game.LevelEditorSystem.duplicate_selected(state)
	expect(state.objects.size()==2 and state.objects[1].position==Vector2(state.objects[0].position)+Vector2(24,24), "duplicate is offset by one active grid cell")
	game.LevelEditorSystem.transform_selected(state,"rotate"); game.LevelEditorSystem.transform_selected(state,"flip_x"); game.LevelEditorSystem.transform_selected(state,"scale_up")
	expect(is_equal_approx(float(state.objects[1].rotation),PI*0.5) and state.objects[1].flip_x and is_equal_approx(float(state.objects[1].scale),1.25), "rotation flip and scale compose on the selected object")
	game.LevelEditorSystem.delete_selected(state)
	expect(state.objects.size()==1, "delete removes only the selected level object")
	game.LevelEditorSystem.undo(state); expect(state.objects.size()==2, "undo restores a deleted object")
	game.LevelEditorSystem.redo(state); expect(state.objects.size()==1, "redo reapplies the deletion")
	game.free()


## Сценарий: уже существующая игровая локация становится основой нового дизайнерского черновика.
## Исходное состояние: первая локация содержит здания, NPC, декорации и коллизии runtime-систем.
## Ожидаемый результат: импорт создаёт именованные референсы с исходной позицией, размерами и техническим id.
func test_current_location_import_creates_editable_references() -> void:
	var game := make_game()
	var state: Dictionary = game.LevelEditorSystem.default_state(game)
	game.LevelEditorSystem.import_current_level(game,state)
	var first: Dictionary = state.objects[0] if not state.objects.is_empty() else {}
	expect(state.objects.size()>5 and bool(first.get("reference",false)), "current level imports its runtime objects as editable references")
	expect(not String(first.get("runtime_id","")).is_empty() and Vector2(first.get("size",Vector2.ZERO))>Vector2.ZERO, "imported reference keeps technical id and visible bounds")
	expect(first.get("position",Vector2.ZERO)==first.get("original_position",Vector2.ONE), "import records original coordinates for an unambiguous redesign diff")
	game.free()


## Сценарий: автор подписывает уровень и объект, сохраняет JSON, затем открывает его в чистом состоянии.
## Исходное состояние: один размещённый тайл имеет слой, коллизию, заметку, поворот и масштаб.
## Ожидаемый результат: открытый формат и повторная загрузка без потерь сохраняют все дизайнерские решения.
func test_open_json_draft_round_trip_preserves_author_intent() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_DRAFT))
	var game := make_game()
	var state: Dictionary = game.LevelEditorSystem.default_state(game)
	state.level_name="level editor suite"; state.level_notes="Общий замысел тестового уровня"; state.selected_asset="res://assets/game/tiles/grass.png"; state.layer="ground"; state.collision=true
	game.LevelEditorSystem.place_selected_asset(game,state,Vector2(321,222)); state.objects[0].name="Тихая поляна"; state.objects[0].notes="Оставить проход справа"; state.objects[0].rotation=PI*0.5; state.objects[0].scale=1.5
	var payload: Dictionary = game.LevelEditorSystem.document(state)
	expect(payload.format=="babushkina-ferma-level-draft" and payload.objects[0].notes=="Оставить проход справа", "export document is self-describing and keeps author notes")
	expect(game.LevelEditorSystem.save_draft(game,state,false) and FileAccess.file_exists(TEST_DRAFT), "draft saves into the user level-design directory")
	var restored: Dictionary = game.LevelEditorSystem.default_state(game)
	expect(game.LevelEditorSystem.load_draft(game,restored,TEST_DRAFT), "saved level draft can be loaded for later editing")
	var object: Dictionary = restored.objects[0]
	expect(restored.level_notes==state.level_notes and object.name=="Тихая поляна" and object.layer=="ground" and object.collision, "draft round-trip preserves labels notes layers and collision intent")
	expect(is_equal_approx(float(object.rotation),PI*0.5) and is_equal_approx(float(object.scale),1.5), "draft round-trip preserves object transforms")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_DRAFT)); game.free()


## Сценарий: конструктор подключён к единственному игровому циклу, отрисовке и диагностической панели.
## Исходное состояние: исходники интеграционных модулей и список доступных F10-команд читаются напрямую.
## Ожидаемый результат: режим останавливает симуляцию, рисует все четыре слоя и доступен как включённая команда.
func test_runtime_integration_freezes_simulation_and_draws_editor_layers() -> void:
	var core := FileAccess.get_file_as_string("res://scripts/game_core.gd")
	var render := FileAccess.get_file_as_string("res://scripts/systems/render_system.gd")
	var debug := FileAccess.get_file_as_string("res://scripts/systems/debug_overlay_system.gd")
	expect(core.contains("LevelEditorSystem.active(self)") and core.contains("LevelEditorSystem.handle_input(self,event)"), "live editor owns input and pauses gameplay simulation while open")
	for layer in ["background","ground","objects","foreground"]:
		expect(render.contains("LevelEditorRenderer.draw_layer(game,\"%s\")"%layer), "renderer composes level-editor layer: %s"%layer)
	expect(debug.contains('"action":"level_editor"') and debug.contains('"enabled":true'), "F10 panel exposes the enabled level-constructor command")
