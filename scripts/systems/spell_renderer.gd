class_name SpellRenderer
extends RefCounted

const CYCLE_BUTTON:=Rect2(1018,444,54,54)
const CAST_BUTTON:=Rect2(1078,444,54,54)

## Отрисовывает короткие световые круги лечения, снаряда и ледяной волны в координатах мира.
static func draw_world(game: Node) -> void:
	for effect in game.SpellSystem.state(game).effects:
		var progress:=1.0-clampf(float(effect.timer)/0.45,0.0,1.0); var color:=Color("75b8ff") if effect.kind=="arcane_bolt" else (Color("8cff9a") if effect.kind=="healing_light" else Color("b8efff")); color.a=1.0-progress; game.draw_circle(Vector2(effect.position),24.0+progress*95.0,color,false,4.0)

## Отрисовывает выбранное заклинание, стоимость, перезарядку и две сенсорные кнопки.
static func draw_ui(game: Node) -> void:
	if game.inventory_open or game.shop_open or game.quest_log_open or game.skill_menu_open or game.crafting_open or game.storage_open or game.forge_open or game.AdventurePolishSystem.has_modal(game) or game.FirstChapterSystem.modal_active(game): return
	var spell:Dictionary=game.SpellSystem.selected(game); var cooldown:float=game.SpellSystem.selected_cooldown(game); var rect:=Rect2(930,500,198,42); game.draw_rect(rect,Color(0.08,0.10,0.18,0.88)); game.draw_rect(rect,Color("7aa9d8"),false,2.0)
	game.draw_string(game.UI_FONT,rect.position+Vector2(8,18),"%s %s"%[spell.icon,game.SpellSystem.word(game,String(spell.id))],HORIZONTAL_ALIGNMENT_LEFT,146,11,Color("d9edff")); game.draw_string(game.UI_FONT,rect.position+Vector2(8,35),"C • %d MP%s"%[spell.cost," • %.1f"%cooldown if cooldown>0.0 else ""],HORIZONTAL_ALIGNMENT_LEFT,180,10,Color("9fc8ef"))
	if game.touch_controls_visible:
		for data in [[CYCLE_BUTTON,"↻"],[CAST_BUTTON,String(spell.icon)]]: game.draw_rect(data[0],Color(0.08,0.10,0.18,0.88)); game.draw_rect(data[0],Color("7aa9d8"),false,2.0); game.draw_string(game.UI_FONT,data[0].position+Vector2(5,35),data[1],HORIZONTAL_ALIGNMENT_CENTER,44,23,Color("d9edff"))
