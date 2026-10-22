extends RefCounted

const Layout := preload("res://scripts/presentation/compact_dialogue_layout.gd")
const Text := preload("res://scripts/systems/dialogue_text_layout_system.gd")
const Style := preload("res://scripts/presentation/moon_theme.gd")
const Paper := preload("res://scripts/presentation/paper_theme_palette.gd")

## Рисует выбранный светлый диалог Б с компактным портретом и читаемыми страницами текста.
static func draw(game: Node2D) -> void:
	var ui:Dictionary=game.state.player.adventure_ui; var dialogue:Dictionary=ui.get("dialogue",{})
	var npc:=String(dialogue.get("npc_id","")); var packet:=Text.layout(game)
	game.draw_rect(Rect2(0,0,1152,648),Color(0.01,0.02,0.015,0.12))
	Style.panel(game,Layout.WINDOW,Paper.PANEL,Paper.EDGE,7)
	Style.panel(game,Layout.PORTRAIT,Paper.INSET,Paper.EDGE)
	game.StoryUiRenderer.draw_npc_portrait(game,Layout.PORTRAIT.grow(-6),npc)
	Style.text(game,Layout.NAME,game.QuestSystem.npc_name(npc),16,Paper.TEXT)
	Style.text(game,Layout.FRIENDSHIP,"♥ %d / 100"%int(game.state.player.relationships.get(npc,0)),12,Paper.DANGER,HORIZONTAL_ALIGNMENT_RIGHT)
	Style.text(game,Layout.CLOSE,"×",21,Paper.MUTED,HORIZONTAL_ALIGNMENT_CENTER)
	Style.text(game,Layout.TITLE,String(dialogue.get("title",game.AdventurePolishSystem.word(game,"continue"))),12,Paper.MUTED)
	game.draw_multiline_string(game.UI_FONT,Layout.BODY.position+Vector2(0,game.UI_FONT.get_ascent(int(packet.size))),Text.visible_text(game),HORIZONTAL_ALIGNMENT_LEFT,Layout.BODY.size.x,int(packet.size),-1,Paper.TEXT)
	var more:=Text.has_next(game); var choices:Array=["next"] if more else dialogue.get("choices",["leave"])
	for index in choices.size(): button(game,Layout.choice_rect(index,choices.size()),word(game,"next") if more else game.AdventurePolishSystem.word(game,String(choices[index])),index==int(ui.choice))
	button(game,Layout.GIFT,"G · "+word(game,"gift"))
	var help:=word(game,"help")
	if packet.pages.size()>1: help+="   ·   %d / %d"%[Text.page_index(game)+1,packet.pages.size()]
	Style.text(game,Layout.HELP,help,9,Paper.MUTED)

## Рисует компактное действие в выбранном пергаментном стиле с контрастной подписью.
static func button(game: Node2D, rect: Rect2, label: String, selected: bool=false) -> void:
	Style.panel(game,rect,Paper.ACCENT if selected else Paper.INSET,Paper.ACCENT if selected else Paper.EDGE)
	Style.text(game,rect.grow(-6),label,13,Paper.ON_ACCENT if selected else Paper.TEXT,HORIZONTAL_ALIGNMENT_CENTER)

## Возвращает служебные подписи разговора для всех шести локалей игры.
static func word(game: Node, key: String) -> String:
	var words:={
		"next":["Далее","Next","Siguiente","Weiter","Suite","下一页"],
		"gift":["Подарить","Give gift","Regalar","Schenken","Offrir","赠送"],
		"help":["← → выбор · Enter / A подтвердить · Esc / B закрыть","← → select · Enter / A confirm · Esc / B close","← → elegir · Enter / A aceptar · Esc / B cerrar","← → wählen · Enter / A bestätigen · Esc / B schließen","← → choisir · Entrée / A confirmer · Esc / B fermer","← →选择 · 回车 / A确认 · Esc / B关闭"],
	}
	return String(words[key][game.LocaleSystem.index()])
