extends RefCounted

## Разрешает дым лишь готовой коптильне с оплаченной очередью и запасом жара.
static func working(item: Dictionary) -> bool:
	return item.get("kind","")=="smoker" and item.get("phase","")=="ready" and not item.production.queue.is_empty() and float(item.production.heat)>0

## Рисует дым и мягкий жар по сохранённому прогрессу партии, поэтому остановка мира останавливает анимацию.
static func draw(game: Node2D, item: Dictionary, destination: Rect2) -> void:
	if not working(item): return
	var job:Dictionary=item.production.queue[0]
	var phase:float=float(job.duration)-float(job.remaining)
	var chimney:=destination.position+Vector2(0.68,0.025)*destination.size
	for index in 4:
		var rise:=fposmod(phase*0.32+index*0.25,1)
		var point:=chimney+Vector2(sin(phase+index)*3+rise*5,-rise*26)
		game.draw_circle(point,2+rise*4,Color(0.77,0.75,0.68,(1-rise)*0.19))
	if int(item.direction)==2: return
	var grate:=destination.position+Vector2(0.5 if int(item.direction)==0 else 0.42,0.88)*destination.size
	game.draw_circle(grate,8,Color(0.94,0.54,0.18,0.1+sin(phase*6)*0.025))
