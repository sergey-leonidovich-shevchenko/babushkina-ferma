extends "res://scripts/game.gd"

const MoonStyle := preload("res://scripts/presentation/moon_theme.gd")
const WINDOW := Rect2(160,444,832,176)

## Сравнивает исходное окно с двумя предложенными стилями на неизменном игровом кадре.
func _draw() -> void:
	var variant:String=String(get_meta("dialogue_review_variant","before"))
	if variant in ["before","runtime"]: super._draw(); return
	var opened:bool=bool(state.player.adventure_ui.dialogue_open)
	state.player.adventure_ui.dialogue_open=false; super._draw(); state.player.adventure_ui.dialogue_open=opened
	var parchment:=variant=="b"
	var fill:=Color("eee1bf") if parchment else MoonStyle.PANEL
	var ink:=Color("463c2b") if parchment else MoonStyle.TEXT
	var muted:=Color("776c50") if parchment else MoonStyle.MUTED
	var border:=Color("b3a077") if parchment else MoonStyle.EDGE
	draw_rect(Rect2(0,0,1152,648),Color(0.01,0.02,0.015,0.12))
	MoonStyle.panel(self,WINDOW,fill,border,7)
	var portrait:=Rect2(176,461,64,100)
	MoonStyle.panel(self,portrait,Color("dfd0a7") if parchment else MoonStyle.INSET,border)
	StoryUiRenderer.draw_npc_portrait(self,portrait.grow(-6),"varvara")
	MoonStyle.text(self,Rect2(256,455,520,24),QuestSystem.npc_name("varvara"),16,ink)
	MoonStyle.text(self,Rect2(842,455,86,24),"♥ 0 / 100",12,Color("b57974") if not parchment else Color("9c5a51"),HORIZONTAL_ALIGNMENT_RIGHT)
	MoonStyle.text(self,Rect2(944,450,44,44),"×",21,muted,HORIZONTAL_ALIGNMENT_CENTER)
	MoonStyle.text(self,Rect2(256,482,672,18),"Уха для переправы",12,muted)
	draw_ui_multiline_string(UI_FONT,Vector2(256,521),"Поймай пять рыб для рабочих, ремонтирующих мост.",HORIZONTAL_ALIGNMENT_LEFT,716,40,15,2,ink)
	for entry in [[Rect2(256,559,156,44),"Принять",true],[Rect2(424,559,156,44),"Отказаться",false],[Rect2(820,559,154,44),"G · Подарить",false]]:
		var selected:bool=entry[2]
		MoonStyle.panel(self,entry[0],Color("657653") if parchment and selected else (Color("dfd0a7") if parchment else (Color("46613d") if selected else MoonStyle.INSET)),Color("657653") if parchment and selected else (MoonStyle.ACCENT if selected else border))
		MoonStyle.text(self,(entry[0] as Rect2).grow(-6),entry[1],13,Color("fbf4df") if parchment and selected else ink,HORIZONTAL_ALIGNMENT_CENTER)
	MoonStyle.text(self,Rect2(256,604,718,14),"← → выбор   ·   Enter / A подтвердить   ·   Esc / B закрыть",9,muted)

## Сохраняет режим диалога для нижнего HUD, не рисуя старое окно поверх предложенного макета.
func draw_ui() -> void:
	var variant:String=String(get_meta("dialogue_review_variant","before"))
	if variant in ["before","runtime"]: super.draw_ui(); return
	var opened:bool=bool(state.player.adventure_ui.dialogue_open)
	state.player.adventure_ui.dialogue_open=true; super.draw_ui(); state.player.adventure_ui.dialogue_open=opened
