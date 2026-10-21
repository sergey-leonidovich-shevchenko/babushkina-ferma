extends "res://tools/visual_modules_capture.gd".ModuleCanvas

const Bench:=preload("res://scripts/presentation/village_bench_visual.gd")
const Street:=preload("res://scripts/presentation/village_street_visual.gd")
const Lamp:=preload("res://scripts/presentation/village_lamp_visual.gd")
const Board:=preload("res://scripts/presentation/village_board_visual.gd")
const Fence:=preload("res://scripts/presentation/village_fence_visual.gd")
const Trade:=preload("res://scripts/presentation/village_trade_visual.gd")
const Hero:=preload("res://scripts/systems/hero_visual_system.gd")
var game:Node
var style:="legacy"
var observe:=false
var records:=[]
var legacy:={}

## Статичный стенд объединяет принятые модули и наружные предметы, не заменяя штатную карту.
func _draw()->void:
	var before:Dictionary=game.SaveSystem.snapshot(game) if observe else {}
	draw_set_transform(Vector2.ZERO)
	_pilot()
	draw_set_transform(Vector2.ZERO)
	if observe:records.append({"before":before,"after":game.SaveSystem.snapshot(game),"frame":Engine.get_process_frames(),"style":style,"variant":variant,"mode":mode,"scale":1.2,"viewport":[get_viewport().size.x,get_viewport().size.y],"field":[get_viewport().size_2d_override.x,get_viewport().size_2d_override.y],"actual_zoom":[get_viewport().get_stretch_transform().x.x,get_viewport().get_stretch_transform().y.y],"footprint_cells":960,"game_material":game.material==null})

## Сохраняет одну композицию, камеру и материалы для старого и нового набора предметов.
func _pilot()->void:
	_material(Rect2(0,0,960,540),"meadow");_material(Rect2(744,0,120,540),"water")
	_material(Rect2(0,312,744,48),"earth");_material(Rect2(864,312,96,48),"earth");_material(Rect2(216,264,48,72),"earth")
	for x in range(48,961,120):
		if x>720 and x<900:continue
		var join:float=(float(parts["road-h"].join_source)-float(parts["road-h"].pivot[1]))*float(parts["road-h"].scale)
		_sprite("road-h",Vector2(x,312-join));_sprite("road-h",Vector2(x,360+join),Vector2(1,-1))
	for y in range(-15,601,75):_sprite("bank-v",Vector2(724,y));_sprite("bank-v",Vector2(884,y),Vector2(-1,1))
	var house:String=data.variants[variant].facade
	_shadow(house,Vector2(240,288));_shadow("tree",Vector2(576,240));_sprite(house,Vector2(240,288))
	_bridge(Vector2(804,336),mode=="bridge")
	var hero_feet:=Vector2(576,216 if mode=="back" else 264)
	if mode=="back":_hero(hero_feet)
	_sprite("tree",Vector2(576,240))
	if mode not in ["back","bridge"]:_hero(hero_feet)
	_sprite("bush-hazel",Vector2(660,480));_sprite("bush-berry",Vector2(912,480))
	for i in 4:_sprite(["grass-low","clover","daisy","blue-flower"][i],Vector2(48+i*192,504))
	_props()
	if mode=="grid":
		for x in range(0,961,24):draw_line(Vector2(x,0),Vector2(x,540),Color(1,1,1,.15))
		for y in range(0,541,24):draw_line(Vector2(0,y),Vector2(960,y),Color(1,1,1,.15))

## Показывает ровно готовые семейства наружного декора без торговой экономики или новых размещений в игре.
func _props()->void:
	for row in [{"kind":"bench","point":Vector2(456,312),"size":Vector2(96,72)},{"kind":"well","point":Vector2(672,312),"size":Vector2(96,96)},{"kind":"cart","point":Vector2(120,408),"size":Vector2(96,96)},{"kind":"lamp","point":Vector2(360,384),"size":Vector2(72,96)},{"kind":"board","point":Vector2(72,288),"size":Vector2(96,96)},{"kind":"sign","point":Vector2(912,288),"size":Vector2(72,96)}]:
		if style=="legacy":draw_texture_rect(legacy[row.kind],Rect2(row.point-Vector2(row.size.x/2,row.size.y),row.size),false)
		else:
			match row.kind:
				"bench":Bench.draw_shadow(self,row.point);Bench.draw(self,row.point)
				"well","cart":Street.draw_shadow(self,row.kind,row.point);Street.draw(self,row.kind,row.point)
				"lamp":Lamp.draw_shadow(self,row.point);Lamp.draw(self,row.point)
				"board","sign":Board.draw_shadow(self,row.kind,row.point);Board.draw(self,row.kind,row.point)
	if style=="legacy":
		draw_texture_rect(legacy.fence,Rect2(264,456,240,48),false)
		draw_texture_rect(legacy.market,Rect2(408,360,144,144),false)
	else:
		for a in [Vector2(264,480),Vector2(312,480),Vector2(408,480),Vector2(456,480)]:
			Fence.post(self,a);Fence.post(self,a+Vector2(48,0));Fence.rail(self,a,a+Vector2(48,0))
		Fence.draw_gate(self,Vector2(372,480),0,false)
		for row in [{"kind":"stall","point":Vector2(480,432),"scale":1.0},{"kind":"crate","point":Vector2(408,432),"scale":1.0},{"kind":"barrel","point":Vector2(552,432),"scale":1.0},{"kind":"sack","point":Vector2(528,432),"scale":0.5}]:Trade.draw_shadow(self,row.kind,row.point,0,row.scale);Trade.draw(self,row.kind,row.point,0,row.scale)

## Использует настоящую текущую позу вместо исторического снимка героя из макета.
func _hero(feet:Vector2)->void:
	var frame:=Hero.walk_pose(Vector2.DOWN,0,false)
	draw_texture_rect_region(frame.texture,Hero.destination(feet,frame),frame.source)
