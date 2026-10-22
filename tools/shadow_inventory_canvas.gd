extends Node2D

const Bench:=preload("res://scripts/presentation/village_bench_visual.gd")
const Street:=preload("res://scripts/presentation/village_street_visual.gd")
const Lamp:=preload("res://scripts/presentation/village_lamp_visual.gd")
const Board:=preload("res://scripts/presentation/village_board_visual.gd")
const Trade:=preload("res://scripts/presentation/village_trade_visual.gd")
const Events:=preload("res://scripts/systems/world_event_system.gd")
const GROUPS:={"single":["bench"],"street":["well","cart","lamp"],"boards":["board","sign"],"trade":["stall","crate","barrel","sack"]}
var group:="single"
var mode:="plain"
var minutes:=720.0
var observe:=false
var records:=[]

## Показывает прежние production-рисунки с прежним отдельным контактом и без него; солнечной тени не добавляет.
func _draw()->void:
	if mode!="body":draw_rect(Rect2(0,0,768,256),Color("9ba570"))
	draw_set_transform(Vector2.ZERO,0,Vector2(1.2,1.2))
	var rows:=[];var kinds:Array=GROUPS[group]
	for i in kinds.size():
		var kind:String=kinds[i];var ground:=Vector2((i+0.5)*768.0/kinds.size(),200)/1.2
		var direction:=0;var rect:=Rect2();var contacts:=0
		if kind=="bench":
			rect=Bench.destination(ground,direction);contacts=Bench.contacts(ground,direction).size()
			if mode=="shadow":Bench.draw_shadow(self,ground,direction)
			Bench.draw(self,ground,direction)
		elif kind in ["well","cart"]:
			rect=Street.destination(kind,ground,direction);contacts=Street.contacts(kind,ground,direction).size()
			if mode=="shadow":Street.draw_shadow(self,kind,ground,direction)
			Street.draw(self,kind,ground,direction)
		elif kind=="lamp":
			rect=Lamp.destination(ground,direction);contacts=1
			if mode=="shadow":Lamp.draw_shadow(self,ground,direction)
			Lamp.draw(self,ground,direction)
		elif kind in ["board","sign"]:
			rect=Board.destination(kind,ground,direction);contacts=Board.contacts(kind,ground,direction).size()
			if mode=="shadow":Board.draw_shadow(self,kind,ground,direction)
			Board.draw(self,kind,ground,direction)
		else:
			rect=Trade.destination(kind,ground,direction);contacts=Trade.contacts(kind,ground,direction).size()
			if mode=="shadow":Trade.draw_shadow(self,kind,ground,direction)
			Trade.draw(self,kind,ground,direction)
		rows.append({"kind":kind,"ground":[ground.x,ground.y],"destination":[rect.position.x,rect.position.y,rect.size.x,rect.size.y],"contact_points":contacts,"shadow_calls":1 if mode=="shadow" else 0,"body_calls":1})
	draw_set_transform(Vector2.ZERO)
	if mode!="body":draw_rect(Rect2(0,0,768,256),Color(0.055,0.08,0.20,Events.darkness(minutes)))
	if observe:records.append({"process_frame":Engine.get_process_frames(),"group":group,"mode":mode,"minutes":minutes,"rows":rows})
