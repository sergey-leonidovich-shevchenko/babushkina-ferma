extends Node2D

var Street
const Hero := preload("res://scripts/systems/hero_visual_system.gd")
var game:Node
var kind := "stall"
var background := "light"
var observe := false
var records := []

## Сравнивает три ракурса при 120%, контакты основания и настоящее тело героя в двух порядках слоёв.
func _draw() -> void:
	Street=load("res://scripts/presentation/village_trade_visual.gd")
	var before:Dictionary=game.SaveSystem.snapshot(game) if observe else {}
	var body_material:Material=game.material;var own_material:=material
	draw_rect(Rect2(0,0,1152,648),{"light":Color("f4ecd9"),"dark":Color("252b2a"),"grass":Color("819454"),"evening":Color("4c5d4b")}[background])
	draw_set_transform(Vector2.ZERO,0,Vector2(1.2,1.2))
	var ink:=Color("f4ecd9") if background in ["dark","evening"] else Color("343a2c")
	draw_string(ThemeDB.fallback_font,Vector2(28,32),"VPROP-007 · 120% · "+kind+" · три стороны · отдельная тень",HORIZONTAL_ALIGNMENT_LEFT,-1,16,ink)
	for i in 3:
		var side:int=[0,1,3][i]
		for row in 2:
			var ground:=Vector2(192+i*288,224+row*252)
			for x in range(-96,97,24):draw_line(ground+Vector2(x,-144),ground+Vector2(x,24),Color(0.5,0.5,0.5,0.18))
			for y in range(-144,49,24):draw_line(ground+Vector2(-96,y),ground+Vector2(96,y),Color(0.5,0.5,0.5,0.18))
			Street.draw_shadow(self,kind,ground,side)
			var hero_ground:=ground+Vector2(0,-8 if row==0 else 25)
			if row==0:_hero(hero_ground)
			Street.draw(self,kind,ground,side)
			if row==1:_hero(hero_ground)
			for foot in Street.contacts(kind,ground,side):draw_circle(foot,1.2,Color(0.9,0.35,0.2,0.8))
			var approach:Vector2=Street.approach(kind,ground,side);draw_circle(approach,2,Color("bce1a4"));draw_line(approach,approach+Vector2(0,4),ink)
			var label:String=Street.Facing.NAMES[side]+(" · герой позади" if row==0 else " · герой спереди")
			draw_string(ThemeDB.fallback_font,ground+Vector2(-84,58),label,HORIZONTAL_ALIGNMENT_LEFT,-1,13,ink)
	draw_set_transform(Vector2.ZERO)
	if observe:records.append({"before":before,"after":game.SaveSystem.snapshot(game),"frame":Engine.get_process_frames(),"root_material_equal":game.material==body_material,"own_material_equal":material==own_material,"kind":kind,"contact_counts":[Street.contacts(kind,Vector2.ZERO,0).size(),Street.contacts(kind,Vector2.ZERO,1).size(),Street.contacts(kind,Vector2.ZERO,3).size()]})

## Использует настоящую позу героя с его постоянной опорой вместо силуэта-заглушки.
func _hero(ground:Vector2) -> void:
	var frame:=Hero.walk_pose(Vector2.DOWN,0,false)
	draw_texture_rect_region(frame.texture,Hero.destination(ground,frame),frame.source)
