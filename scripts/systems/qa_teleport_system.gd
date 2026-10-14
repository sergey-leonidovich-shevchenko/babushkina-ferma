extends RefCounted

const KIND := "qa_teleport_stone"
const META := "qa_teleport"
const SETTING := "development/qa_teleport_enabled"
const Cabinet := preload("res://scripts/systems/dev_cabinet_system.gd")
const Locale := preload("res://scripts/systems/qa_teleport_locale.gd")
const Recovery := preload("res://scripts/systems/recovery_system.gd")
const Villages := preload("res://scripts/systems/village_region_data.gd")
const Caves := preload("res://scripts/systems/cave_room_data.gd")
const GROUPS := ["all", "world", "village", "cave", "interior"]
const ROWS := 8

## Отключает тестовый предмет отдельным флагом, в том числе если он остался в старом сохранении.
static func enabled() -> bool:
	return bool(ProjectSettings.get_setting(SETTING, false)) and Cabinet.enabled()

## Собирает все игровые карты из действующих реестров без дублирования комнат и районов.
static func locations(game: Node) -> Array:
	var result: Array = game.WorldSystem.LOCATIONS.duplicate()
	for ids in [game.WorldMapSystem.LOCATIONS.keys(), Villages.IDS, Caves.IDS, game.BuildingSystem.INTERIORS.keys()]:
		for id in ids:
			if id not in result: result.append(id)
	return result

## Назначает каждому месту единственный раздел списка.
static func group(game: Node, location: String) -> String:
	if game.BuildingSystem.is_interior(location): return "interior"
	if location in Villages.IDS: return "village"
	if location in Caves.IDS: return "cave"
	return "world"

## Хранит только временный выбор интерфейса, который не попадает в сохранения.
static func state(game: Node) -> Dictionary:
	if not game.has_meta(META): game.set_meta(META, {"open":false, "group":"all", "query":"", "searching":false, "selected":0, "scroll":0, "notice":"", "drag":0.0})
	return game.get_meta(META)

## Проверяет окно без создания метаданных и закрывает доступ при выключенном режиме разработки.
static func active(game: Node) -> bool:
	return enabled() and bool(game.get_meta(META, {}).get("open", false)) and not game.title_screen and not game.language_screen

## Фильтрует полный каталог по локализованному имени и техническому идентификатору.
static func entries(game: Node) -> Array:
	var value := state(game); var result := []; var query := String(value.query).strip_edges().to_lower()
	for id in locations(game):
		if value.group != "all" and group(game, id) != value.group: continue
		if not query.is_empty() and not String(id).contains(query) and not game.LocaleSystem.location(id).to_lower().contains(query): continue
		result.append(id)
	return result

## Не позволяет выделению и прокрутке выйти за отфильтрованные строки.
static func select(game: Node, index: int) -> void:
	var value := state(game); var count := entries(game).size()
	value.selected = clampi(index, 0, maxi(0, count-1))
	value.scroll = clampi(value.scroll, maxi(0, value.selected-ROWS+1), value.selected)
	value.scroll = clampi(value.scroll, 0, maxi(0, count-ROWS))
	game.queue_redraw()

## Открывает список из рюкзака либо хотбара, исключая чужие модальные окна и редакторские стенды.
static func open(game: Node) -> bool:
	if not enabled(): game.message = Locale.text(game, "disabled"); return false
	if game.inventory_item_count(KIND) <= 0 or game.title_screen or game.language_screen: return false
	if game.menu_state.pause_open or game.menu_state.settings_open or game.GameLoop.modal_active(game): return false
	if game.LevelEditorSystem.active(game) or game.PublishedLevelSystem.active(game) or game.DebugPlaygroundSystem.active(game): return false
	if game.GameLoop.gameplay_window_open(game) and not game.inventory_open and not active(game): return false
	preload("res://scripts/systems/menu_hub_system.gd").close(game)
	var value := state(game); value.open = true; value.notice = ""; value.searching = false
	game.clear_movement_keys(); game.inventory_move_from = -1; game.state.player.blocking = false
	game.notify_tutorial("qa_teleport"); select(game, value.selected)
	return true

## Закрывает выбор без изменения карты, запасов, здоровья и игрового времени.
static func close(game: Node) -> void:
	if game.has_meta(META): game.remove_meta(META)
	game.clear_movement_keys(); game.queue_redraw()

## Проверяет посадку до любых боевых изменений и выполняет бесплатный перенос без сюжетных наград.
static func travel(game: Node, target: String) -> bool:
	if not active(game) or game.inventory_item_count(KIND) <= 0 or target not in locations(game): return false
	var previous: String = game.current_location
	game.current_location = target
	var landing := safe_landing(game)
	game.current_location = previous
	if not landing.is_finite(): state(game).notice = Locale.text(game, "failed"); game.queue_redraw(); return false
	game.CombatSystem.reset_transients(game); game.CaveBossSystem.reset(game)
	game.state.fishing.reset_cast(); game.SpellSystem.state(game).effects.clear()
	game.discovery_current.clear(); game.discovery_timer = 0.0
	if game.has_meta(game.HeroActionSystem.META): game.remove_meta(game.HeroActionSystem.META)
	game.player_attack_timer = 0.0; game.player_hurt_timer = 0.0
	game.current_location = target; game.player = landing
	game.location_transition_armed = false; game.location_transition_cooldown = game.LocationTransitionSystem.REENTRY_DELAY
	close(game); game.sync_background_location(); game.update_camera()
	game.message = Locale.text(game, "title") + " · " + game.LocaleSystem.location(target)
	game.play_sfx("travel"); game.queue_redraw()
	return true

## Учитывает движущихся врагов поверх точной проверки пола, перебирая соседние клетки при занятом входе.
static func safe_landing(game: Node) -> Vector2:
	var preferred := Recovery.safe_spawn(game)
	if game.NavigationSystem.walkability_reason(game,preferred,-1,true,false)=="walkable": return preferred
	for radius in range(24,289,24):
		for index in 16:
			var candidate: Vector2=(preferred+Vector2.from_angle(index*TAU/16)*radius).snapped(Vector2(12,12))
			if game.NavigationSystem.walkability_reason(game,candidate,-1,true,false)=="walkable": return candidate
	return Vector2.INF
