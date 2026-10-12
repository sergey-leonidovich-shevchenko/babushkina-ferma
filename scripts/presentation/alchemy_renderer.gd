extends RefCounted

const Herbs := preload("res://scripts/systems/alchemy_herb_data.gd")
const Products := preload("res://scripts/systems/alchemy_product_data.gd")
const Icons := preload("res://scripts/presentation/alchemy_icon_system.gd")
const Visual := preload("res://scripts/systems/farm_visual_system.gd")

## Рисует небольшой целый травяной куст из существующего атласа и отличает цветы, ягоды, корни и мох.
static func draw_herb(game: Node2D, node: Dictionary) -> void:
	var data:Dictionary=Herbs.HERBS[node.kind]; var rect:Rect2=game.ForageSystem.destination_rect(node)
	var tint:=Color(data.tint).lerp(Color.WHITE,0.5)
	var stage: int=(4 if data.shape=="flower" else (2 if data.shape=="berry" else 1)) if node.active else 0
	if data.shape=="moss": rect.position.y+=18; rect.size.y-=18
	game.draw_texture_rect_region(Visual.HERBS_SEASONS,rect,Visual.crop_source(stage,"herbs",game.WorldEventSystem.season(game.day)),tint)
	if not node.active: return
	var center:Vector2=rect.get_center()+Vector2(0,-8 if data.shape=="flower" else 5)
	if data.shape in ["flower","berry"]:
		var heads:=PackedVector2Array()
		for offset in [Vector2(-7,-3),Vector2(4,-7),Vector2(7,3)]: heads.append(center+offset-Vector2(2,0)); heads.append(center+offset+Vector2(2,0))
		game.draw_multiline(heads,Color(data.tint),5.0 if data.shape=="flower" else 4.0)
	elif data.shape=="moss": game.draw_arc(center+Vector2(0,12),13,PI,TAU,10,Color(data.tint),4)
	elif data.shape=="root": game.draw_line(center+Vector2(0,10),center+Vector2(0,19),Color(data.tint),3)

## Рисует материалы из прежних иконок и простых векторных флаконов, сохраняя отдельный цвет сырья.
static func draw_item(game: Node2D, kind: String, rect: Rect2) -> bool:
	if not Products.handles(kind): return false
	var texture:=Icons.texture(kind)
	if texture==null: return false
	game.draw_texture_rect(texture,rect,false,Icons.tint(kind))
	return true

## Отмечает действующий домашний стол небольшим флаконом и пучком трав поверх его существующего рисунка.
static func draw_station(game: Node2D) -> void:
	if game.current_location!="cottage_interior": return
	draw_item(game,"glass_vial",Rect2(681,392,20,26))
	draw_item(game,"field_mint",Rect2(711,397,22,22))
