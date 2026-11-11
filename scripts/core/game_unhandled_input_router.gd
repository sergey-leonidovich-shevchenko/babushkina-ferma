@warning_ignore_start(
	"untyped_declaration",
	"unsafe_call_argument",
	"unsafe_cast",
	"unsafe_method_access",
	"unsafe_property_access",
	"unsafe_void_return"
)
extends RefCounted

const MenuHubSystem := preload("res://scripts/systems/menu_hub_system.gd")


## Маршрутизирует команды, которые не были перехвачены более приоритетными экранами.
static func route(game: Node, event: InputEvent) -> void:
	if MenuHubSystem.active(game):
		game.InputSystem.handle_modal_input(game, event)
		return
	if game.language_screen:
		game.handle_language_input(event)
		return
	if (
		game.title_screen
		or game.menu_state.pause_open
		or game.menu_state.settings_open
		or game.menu_state.defeat_open
	):
		game.MenuSystem.handle_input(game, event)
		return
	if game.DebugOverlaySystem.handle_input(game, event):
		game.queue_redraw()
		return
	if (
		game.DebugPlaygroundSystem.handle_input(game, event)
		or game.FarmLifeSystem.handle_input(game, event)
	):
		game.queue_redraw()
		return
	if game.AdventurePolishSystem.handle_input(game, event):
		return
	if game.InputSystem.handle_modal_input(game, event):
		return
	if event.is_action_pressed("ui_cancel"):
		game.MenuSystem.open_pause(game)
	if (
		event.is_action_pressed("ui_accept")
		or (event is InputEventKey and event.pressed and event.keycode == KEY_E)
	):
		game.use_active_item()
	if event is InputEventKey and event.pressed and not event.echo:
		_handle_key(game, event.keycode)
		game.queue_redraw()


## Выполняет одиночную немодальную клавиатурную команду игрового фасада.
static func _handle_key(game: Node, keycode: Key) -> void:
	match keycode:
		KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9:
			game.select_hotbar(int(keycode - KEY_1))
		KEY_0:
			game.select_hotbar(9)
		KEY_B:
			game.open_shop()
		KEY_C:
			game.CompanionSystem.cycle_command(game)
		KEY_N:
			game.sleep_until_morning()
		KEY_F:
			game.attack_nearest_enemy()
		KEY_R:
			game.toggle_sword()
		KEY_T:
			game.tutorial_visible = not game.tutorial_visible
		KEY_Y:
			game.reset_tutorial()
		KEY_F9:
			game.grant_tester_kit()
		KEY_F5:
			game.save_game()
		KEY_F6:
			game.AudioSystem.set_enabled(game, not game.audio_enabled)
			game.SettingsSystem.save(game)
			game.message = game.LocaleSystem.ui("sound_on" if game.audio_enabled else "sound_off")
		KEY_F8:
			game.load_game()
		KEY_I, KEY_TAB:
			game.open_inventory()
		KEY_J:
			game.toggle_quest_log()
		KEY_K:
			game.open_skill_menu()
		KEY_M:
			game.WorldMapSystem.toggle(game)
		KEY_H:
			game.DiscoverySystem.dismiss(game)
