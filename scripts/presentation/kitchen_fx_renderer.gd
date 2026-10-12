extends RefCounted

const Data := preload("res://scripts/systems/kitchen_data.gd")
const Art := preload("res://scripts/presentation/kitchen_visual_system.gd")

## Разрешает живой огонь только оплаченной горячей партии с запасом жара у готовой кухни.
static func working(item: Dictionary) -> bool:
	if item.get("kind","")!="cauldron" or item.get("phase","")!="ready" or not item.has("production"): return false
	var value:Dictionary=item.production
	if value.queue.is_empty() or float(value.heat)<=0: return false
	return Data.recipe(value.queue[0].id).output not in Data.COLD

## Привязывает анимацию к сохранённому прогрессу партии, поэтому пауза замораживает и огонь, и пар.
static func draw(game: Node2D, item: Dictionary, destination: Rect2) -> void:
	if not working(item): return
	var job:Dictionary=item.production.queue[0]
	var phase:float=float(job.duration)-float(job.remaining); var tier:=int(item.level); var direction:=int(item.direction)
	if direction==0 or tier==1:
		var point:=Vector2(0.5,0.79) if tier==1 else (Vector2(0.38,0.82) if tier==2 else Vector2(0.62,0.87))
		var size:=Vector2(18,20) if tier>1 else Vector2(22,25)
		game.draw_texture_rect(Art.FIRE[posmod(floori(phase*8),4)],Rect2(destination.position+point*destination.size-size/2,size),false)
	if direction==2: return
	var pot:=Vector2(0.5,0.44) if tier==1 else (Vector2(0.25,0.16) if tier==2 else Vector2(0.15,0.52))
	if direction in [1,3] and tier>1: pot=Vector2(0.62 if direction==1 else 0.28,0.5 if tier==3 else 0.14)
	for index in 3:
		var rise:=fposmod(phase*0.45+index/3.0,1)
		game.draw_circle(destination.position+pot*destination.size+Vector2(sin(phase*2+index)*3,-rise*18),1+rise*2,Color(0.96,0.93,0.82,(1-rise)*0.2))
