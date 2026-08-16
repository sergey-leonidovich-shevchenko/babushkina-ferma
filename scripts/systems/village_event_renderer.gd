extends RefCounted


## Рисует объект активного события площади и его короткое состояние.
static func draw(game: Node2D) -> void:
	if game.current_location != "overworld": return
	var event := String(game.state.world.estate.event)
	if not game.VillageEventSystem.POSITIONS.has(event): return
	if event == "traveler" and game.game_minutes < 18.0 * 60.0: return
	var position: Vector2 = game.VillageEventSystem.POSITIONS[event]
	var column: int = int({"market":0,"festival":1,"traveler":2,"raid":3}[event])
	game.WorldPolishRenderer.draw_cell(game,column,1,Rect2(position-Vector2(78,70),Vector2(156,140)))
	var label: String = String({"market":"ЯРМАРКА","festival":"ПРАЗДНИК УРОЖАЯ","traveler":"НОЧНОЙ ТОРГОВЕЦ","raid":"БАРРИКАДА"}[event])
	game.draw_ui_string(game.UI_FONT,position+Vector2(-105,80),label,HORIZONTAL_ALIGNMENT_CENTER,210,14,Color("fff0bd"))
