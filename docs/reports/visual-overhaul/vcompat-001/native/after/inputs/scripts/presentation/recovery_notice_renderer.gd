extends RefCounted

const Style := preload("res://scripts/presentation/moon_theme.gd")
const PANEL := Rect2(818,144,316,102)

## Показывает уведомление под часами только в игровом мире, оставляя модальные меню без лишних слоёв.
static func visible(game:Node) -> bool:
	return game.menu_state.recovery_notice>0 and not game.language_screen and not game.GameLoop.modal_active(game) and not game.GameLoop.gameplay_window_open(game) and not game.LevelEditorSystem.active(game)

## Рисует компактное светлое сообщение без кнопок, затемнения мира и перехвата ввода.
static func draw(game:Node2D) -> void:
	if not visible(game): return
	Style.panel(game,PANEL)
	Style.text(game,Rect2(PANEL.position+Vector2(12,8),Vector2(292,20)),Style.sentence_case(game.LocaleSystem.ui("defeat_title")),13)
	var text:String=game.LocaleSystem.ui("defeat_saved",[game.menu_state.defeat_source])
	game.draw_ui_multiline_string(game.UI_FONT,PANEL.position+Vector2(12,45),text,HORIZONTAL_ALIGNMENT_LEFT,292,32,11,2,Style.MUTED)
	Style.text(game,Rect2(PANEL.position+Vector2(12,73),Vector2(292,20)),game.LocaleSystem.ui("defeat_loss",[game.menu_state.defeat_lost_coins]),11,Style.DANGER)
