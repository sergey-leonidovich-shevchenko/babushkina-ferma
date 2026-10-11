extends RefCounted

const Layout:=preload("res://scripts/systems/village_layout_system.gd")
const Props:={
	"well":preload("res://assets/game/locations/overworld/modular/prop_well_v1.png"),
	"bench":preload("res://assets/game/locations/overworld/modular/prop_bench_v1.png"),
	"lamp":preload("res://assets/game/locations/overworld/modular/prop_lamp_v1.png"),
	"board":preload("res://assets/game/locations/overworld/modular/prop_board_v1.png"),
	"cart":preload("res://assets/game/locations/overworld/modular/prop_cart_v1.png"),
}
const TreeTexture:=preload("res://assets/game/environment/forest_tree_growth_atlas_v1.png")
const TreeSystem:=preload("res://scripts/systems/tree_system.gd")
const BuildingSystem:=preload("res://scripts/systems/building_system.gd")
const BuildingVisualSystem:=preload("res://scripts/systems/building_visual_system.gd")
const TreeOcclusion := preload("res://scripts/systems/tree_occlusion_system.gd")
const WorldVisibility := preload("res://scripts/systems/world_visibility_system.gd")

## Рисует самостоятельные деревенские объекты на заднем либо переднем плане без замены рисунка при приближении.
static func draw(game:Node2D,foreground:bool)->void:
	if game.current_location!="overworld": return
	var visible := WorldVisibility.visible_rect(game)
	for prop in Layout.PROP_PLACEMENTS:
		if _in_front(Vector2(prop.position),game.player)!=foreground: continue
		var rect: Rect2 = Layout.prop_rect(prop)
		if visible.intersects(rect, true): game.draw_texture_rect(Props[prop.kind],rect,false)
	if not foreground:
		for position in Layout.BORDER_TREES:
			var tree:={"position":position,"stage":3}
			var rect: Rect2 = TreeSystem.destination_rect(tree)
			if visible.intersects(rect, true):
				TreeOcclusion.submit(game, TreeOcclusion.key_for("border",position), TreeTexture, rect, TreeSystem.source_rect(3), TreeSystem.ground_anchor(position).y, Color("d9e6c5"))

## Сравнивает линию земли, а не центр квадратного PNG: так герой естественно скрывается за высоким объектом.
static func _in_front(position:Vector2,player:Vector2)->bool:
	return player.y<position.y+16.0

## Дорисовывает поверх героя те же фасады, когда персонаж действительно проходит за зданием.
static func draw_building_foreground(game:Node2D)->void:
	if game.current_location!="overworld": return
	for id in BuildingSystem.buildings_at("overworld"):
		var door:Vector2=BuildingSystem.BUILDINGS[id].door
		if game.player.y<door.y-24:
			BuildingVisualSystem.draw_building(game,id,door)
