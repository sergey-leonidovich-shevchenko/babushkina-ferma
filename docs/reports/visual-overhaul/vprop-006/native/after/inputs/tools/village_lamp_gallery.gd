extends Node2D

const Lamp := preload("res://scripts/presentation/village_lamp_visual.gd")
const Hero := preload("res://scripts/systems/hero_visual_system.gd")
var game:Node
var lit := false
var background := "light"
var observe := false
var records := []

## Сравнивает три ракурса при 120%, источник света и настоящее тело героя в двух порядках слоёв.
func _draw() -> void:
	var before:Dictionary=game.SaveSystem.snapshot(game) if observe else {}
	var body_material:Material=game.material;var own_material:=material
	draw_rect(Rect2(0,0,1152,648),{"light":Color("f4ecd9"),"dark":Color("252b2a"),"grass":Color("819454"),"evening":Color("4c5d4b")}[background])
	draw_set_transform(Vector2.ZERO,0,Vector2(1.2,1.2))
	var ink:=Color("f4ecd9") if background in ["dark","evening"] else Color("343a2c")
	draw_string(ThemeDB.fallback_font,Vector2(28,32),"VPROP-004 · 120% · "+("вечерний профиль" if lit else "сухой фонарь")+" · отдельное свечение",HORIZONTAL_ALIGNMENT_LEFT,-1,16,ink)
	for i in 3:
		var side:int=[0,1,3][i]
		for row in 2:
			var ground:=Vector2(192+i*288,224+row*252)
			for x in range(-72,73,24):draw_line(ground+Vector2(x,-144),ground+Vector2(x,24),Color(0.5,0.5,0.5,0.18))
			for y in range(-144,49,24):draw_line(ground+Vector2(-72,y),ground+Vector2(72,y),Color(0.5,0.5,0.5,0.18))
			Lamp.draw_shadow(self,ground,side)
			var hero_ground:=ground+Vector2(0,-8 if row==0 else 25)
			if row==0:_hero(hero_ground)
			Lamp.draw(self,ground,side)
			if row==1:_hero(hero_ground)
			if lit:Lamp.draw_glow(self,ground,1.0,0.62,side)
			draw_circle(ground,1.2,Color(0.9,0.35,0.2,0.8))
			var approach:=Lamp.approach(ground,side);draw_circle(approach,2,Color("bce1a4"));draw_line(approach,approach+Vector2(0,4),ink)
			var label:String=Lamp.Facing.NAMES[side]+(" · герой позади" if row==0 else " · герой спереди")
			draw_string(ThemeDB.fallback_font,ground+Vector2(-84,58),label,HORIZONTAL_ALIGNMENT_LEFT,-1,13,ink)
	draw_set_transform(Vector2.ZERO)
	if observe:
		var offsets:=[]
		for side in [0,1,3]:
			var p:=Lamp.emitter(Vector2.ZERO,side);offsets.append([p.x,p.y])
		records.append({"before":before,"after":game.SaveSystem.snapshot(game),"frame":Engine.get_process_frames(),"root_material_equal":game.material==body_material,"own_material_equal":material==own_material,"lit":lit,"emitters":offsets})

## Использует настоящую позу героя с его постоянной опорой вместо силуэта-заглушки.
func _hero(ground:Vector2) -> void:
	var frame:=Hero.walk_pose(Vector2.DOWN,0,false)
	draw_texture_rect_region(frame.texture,Hero.destination(ground,frame),frame.source)
