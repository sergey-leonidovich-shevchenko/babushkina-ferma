extends RefCounted

const Depth:=preload("res://scripts/systems/tree_occlusion_system.gd")
const Herbs:=preload("res://scripts/systems/alchemy_herb_data.gd")

## Сохраняет прежние рисунки и подписи; низкие растения получают единственный выбранный проход первой карты.
static func draw(game:Node2D)->void:
	var visible:=preload("res://scripts/systems/world_visibility_system.gd").visible_rect(game)
	for food in game.food_nodes:
		if food.get("location","overworld")!=game.current_location:continue
		var position:Vector2=food.position
		var orchard:bool=game.OrchardSystem.handles(food.kind)
		var bounds:Rect2=game.OrchardSystem.destination_rect(position,game.OrchardSystem.stage(food)) if orchard else game.ForageSystem.destination_rect(food)
		if not visible.intersects(bounds.grow(64)):continue
		if orchard:
			game.OrchardSystem.draw_tree(game,food);_remaining(game,food);continue
		if food.kind=="nut":
			Depth.submit(game,Depth.key_for("nut",position),game.FOREST_TREE_GROWTH_ATLAS,bounds,game.TreeSystem.source_rect(3),game.ForageSystem.ground_anchor(position).y,Color("e3dfb3"))
			_remaining(game,food);continue
		var ground_y:float=bounds.end.y if Herbs.is_herb(food.kind) else game.ForageSystem.ground_anchor(position).y
		Depth.submit_body(game,Depth.key_for("forage_"+String(food.kind),position),bounds.grow(64),ground_y,_low.bind(game,food))

## Рисует прежний состав одного куста, травы, гриба или бахчи вместе с его подписью.
static func _low(game:Node2D,food:Dictionary)->void:
	var position:Vector2=food.position
	if Herbs.is_herb(food.kind):
		preload("res://scripts/presentation/alchemy_renderer.gd").draw_herb(game,food)
		if not game.ForageSystem.is_collectable(game,food):game.draw_ui_string(game.UI_FONT,position+Vector2(-55,20),game.ForageSystem.remaining_text(game,food),HORIZONTAL_ALIGNMENT_CENTER,110,11,Color("e7d6a3"))
		return
	var alpha:=1.0 if food.active else 0.36
	match food.kind:
		"mushroom":game.draw_texture_rect(game.RED_MUSHROOMS,game.ForageSystem.destination_rect(food),false,Color(1,1,1,alpha))
		"watermelon":game.draw_texture_rect_region(game.FarmVisualSystem.crop_texture("melon"),game.ForageSystem.destination_rect(food),game.FarmVisualSystem.crop_source(4 if food.active else 2,"melon"),Color(0.84,1.0,0.76,1.0))
		"berries":
			var layout:Dictionary=game.forage_sprite_layout(food.kind,position)
			game.draw_texture_rect_region(game.PLANT_SHEET,layout.destination,layout.source,Color(1,1,1,alpha))
	_remaining(game,food)

## Сохраняет прежнее положение и текст времени восстановления без записи в растение.
static func _remaining(game:Node2D,food:Dictionary)->void:
	if not food.active:game.draw_string(game.UI_FONT,Vector2(food.position)+Vector2(-55,42),game.ForageSystem.remaining_text(game,food),HORIZONTAL_ALIGNMENT_CENTER,110,12,Color("e7d6a3"))
