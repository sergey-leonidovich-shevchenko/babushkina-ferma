extends Node2D

const Bench := preload("res://scripts/presentation/village_bench_visual.gd")
const Hero := preload("res://scripts/systems/hero_visual_system.gd")
var game:Node
var background := "light"
var observe := false
var records := []

## Сравнивает три ракурса при 120%, четыре контакта и настоящее тело героя в двух порядках слоёв.
func _draw() -> void:
	var before:Dictionary=game.SaveSystem.snapshot(game) if observe else {}
	var body_material:Material=game.material;var own_material:=material
	draw_rect(Rect2(0,0,1152,648),{"light":Color("f4ecd9"),"dark":Color("252b2a"),"grass":Color("819454")}[background])
	draw_set_transform(Vector2.ZERO,0,Vector2(1.2,1.2))
	var ink:=Color("f4ecd9") if background=="dark" else Color("343a2c")
	draw_string(ThemeDB.fallback_font,Vector2(28,32),"VPROP-002 · 120% · четыре ножки · тень отдельно от PNG",HORIZONTAL_ALIGNMENT_LEFT,-1,16,ink)
	for i in 3:
		var side:int=[0,1,3][i]
		for row in 2:
			var ground:=Vector2(192+i*288,216+row*252)
			for x in range(-72,73,24):draw_line(ground+Vector2(x,-96),ground+Vector2(x,24),Color(0.5,0.5,0.5,0.18))
			for y in range(-96,25,24):draw_line(ground+Vector2(-72,y),ground+Vector2(72,y),Color(0.5,0.5,0.5,0.18))
			Bench.draw_shadow(self,ground,side)
			var hero_ground:=ground+Vector2(0,-8 if row==0 else 25)
			if row==0:_hero(hero_ground)
			Bench.draw(self,ground,side)
			if row==1:_hero(hero_ground)
			for foot in Bench.contacts(ground,side):draw_circle(foot,1.2,Color(0.9,0.35,0.2,0.8))
			var approach:=Bench.approach(ground,side);draw_circle(approach,2,Color("bce1a4"));draw_line(approach,approach+Vector2(0,4),ink)
			var label:String=Bench.Facing.NAMES[side]+(" · герой позади" if row==0 else " · герой спереди")
			draw_string(ThemeDB.fallback_font,ground+Vector2(-84,58),label,HORIZONTAL_ALIGNMENT_LEFT,-1,13,ink)
	draw_set_transform(Vector2.ZERO)
	if observe:records.append({"before":before,"after":game.SaveSystem.snapshot(game),"frame":Engine.get_process_frames(),"root_material_equal":game.material==body_material,"own_material_equal":material==own_material,"contact_counts":[Bench.contacts(Vector2.ZERO,0).size(),Bench.contacts(Vector2.ZERO,1).size(),Bench.contacts(Vector2.ZERO,3).size()]})

## Использует настоящую позу героя с его постоянной опорой вместо силуэта-заглушки.
func _hero(ground:Vector2) -> void:
	var frame:=Hero.walk_pose(Vector2.DOWN,0,false)
	draw_texture_rect_region(frame.texture,Hero.destination(ground,frame),frame.source)
