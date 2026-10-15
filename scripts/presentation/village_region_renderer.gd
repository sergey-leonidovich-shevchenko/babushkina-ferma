extends RefCounted

const Data := preload("res://scripts/systems/village_region_data.gd")
const Buildings := preload("res://scripts/systems/building_visual_system.gd")
const Props := preload("res://scripts/systems/village_prop_renderer.gd")
const Terrain := preload("res://scripts/presentation/village_region_terrain.gd")
const Occlusion := preload("res://scripts/systems/tree_occlusion_system.gd")
const Visible := preload("res://scripts/systems/world_visibility_system.gd")
const Trees := preload("res://scripts/systems/tree_system.gd")
const Workbench := preload("res://scripts/presentation/world_workbench_visual_system.gd")
const Wayfinding := preload("res://scripts/systems/village_wayfinding_system.gd")

## Рисует дополнительные дороги старой фермы и указатели реальных соседних районов.
static func draw_ground(game: Node2D) -> void:
	if not Data.contains(game.current_location): return
	for link in Data.passages(game.current_location):
		var point:Vector2=link.position; var sign:=point+Vector2(0,-44)
		game.draw_texture_rect(Props.Props.board,game.VillageLayoutSystem.prop_rect({"kind":"board","position":sign}),false)
		if game.player.distance_to(point)<240:
			draw_sign(game,link)

## Размещает обе строки в общей светлой карточке, чтобы нижний край камеры не накладывал их друг на друга.
static func draw_sign(game: Node2D, link: Dictionary) -> void:
	var label: String = Wayfinding.title(game,link); var tags: String = Wayfinding.tags(game,link.port)
	var rect := preload("res://scripts/presentation/world_label_renderer.gd").bounds(game,link.position+Vector2(0,24),label)
	if not tags.is_empty(): rect.size.y += 22
	var safe: Rect2 = preload("res://scripts/systems/camera_system.gd").playfield_rect(game).grow(-8)
	rect.position.y = minf(rect.position.y,safe.end.y+game.camera_offset.y-rect.size.y)
	var style := preload("res://scripts/presentation/moon_theme.gd")
	style.panel(game,rect)
	style.text(game,Rect2(rect.position+Vector2(4,2),Vector2(rect.size.x-8,20)),label,11,style.TEXT,HORIZONTAL_ALIGNMENT_CENTER)
	if not tags.is_empty(): style.text(game,Rect2(rect.position+Vector2(4,24),Vector2(rect.size.x-8,20)),tags,10,style.MUTED,HORIZONTAL_ALIGNMENT_CENTER)

## Рисует существующие фасады, лавочки, мастерские и деревья с отсечением вне камеры.
static func draw_objects(game: Node2D, foreground: bool=false) -> void:
	var location:String=game.current_location
	if not Data.added(location): return
	var visible:=Visible.visible_rect(game)
	for house in Data.HOUSES.get(location,[]):
		if foreground and game.player.y>=house.position.y-24: continue
		Buildings.draw_building(game,house.kind,house.position)
	for prop in Data.PROPS.get(location,[]):
		if (game.player.y<prop.position.y+16)!=foreground: continue
		if prop.kind=="workbench":
			if visible.intersects(Workbench.destination(prop.position,int(prop.get("direction",0))),true): Workbench.draw(game,prop.position,int(prop.get("direction",0)))
			continue
		if prop.kind=="table": game.FarmLifeVisualSystem.draw(game,"rustic_table",prop.position); continue
		var rect:Rect2=game.VillageLayoutSystem.prop_rect(prop)
		if visible.intersects(rect,true): game.draw_texture_rect(Props.Props[prop.kind],rect,false)
	if foreground: return
	for tree in Data.trees(location):
		var rect:Rect2=Trees.destination_rect(tree)
		if visible.intersects(rect,true): Occlusion.submit(game,Occlusion.key_for(location,tree.position),Props.TreeTexture,rect,Trees.source_rect(tree.stage),Trees.ground_anchor(tree.position).y)
