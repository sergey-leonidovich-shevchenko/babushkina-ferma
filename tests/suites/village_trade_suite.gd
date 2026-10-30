extends RefCounted
const Trade:=preload("res://scripts/presentation/village_trade_visual.gd")
const Points:=preload("res://tools/qa/camera/visual_camera_points.gd")
const Rules:=preload("res://tools/qa/ground/ground_seasons_fixture.gd")
const Map:=preload("res://scripts/systems/village_map_data.gd")

## Проверяет масштаб, нейтральные виды, сухое размещение, реальные услуги и сохранность мира.
static func run(ctx:SceneTree)->void:
	var ground:=Vector2(720.25,612.5)
	for kind in ["stall","crate","barrel","sack"]:
		var paths:=[]
		for side in [0,1,3]:
			var view:=Trade.view(kind,side);var rect:=Trade.destination(kind,ground,side);paths.append(view.path)
			ctx.expect(rect.size.is_equal_approx(view.source.size*0.25),"trade uniform density "+kind+str(side))
			ctx.expect((rect.position+rect.size*view.pivot).is_equal_approx(ground),"trade exact fractional anchor "+kind+str(side))
			ctx.expect(Trade.shadow(kind,side)==Trade.shadow(kind,side) and Trade.shadow(kind,side).get_surface_count()==1,"trade bounded cached shadow "+kind+str(side))
			ctx.expect(Trade.contacts(kind,ground,side).size()==(2 if kind=="stall" else 1),"trade real measured bases "+kind+str(side))
		ctx.expect((paths[0]==paths[1] and paths[1]==paths[2])==(kind in ["barrel","sack"]),"trade neutral aliases explicit "+kind)
		ctx.expect(Trade.destination(kind,ground,2)==Trade.destination(kind,ground,0),"trade no rear view "+kind)
		var half:=Trade.destination(kind,ground,0,0.5);ctx.expect(half.size==Trade.destination(kind,ground).size*0.5,"trade uniform small instance "+kind)
	ctx.expect(Trade._shadows.size()==8,"trade eight shared shadows maximum")
	var river:=Map.river_polygon();var pond:=Map.pond_polygon()
	for part in Trade.PARTS:
		var rect:=Trade.destination(part.kind,part.ground,0,part.scale).grow(4)
		for p in [rect.position,rect.end,Vector2(rect.position.x,rect.end.y),Vector2(rect.end.x,rect.position.y),part.ground]:
			ctx.expect(not Geometry2D.is_point_in_polygon(p,river) and not Geometry2D.is_point_in_polygon(p,pond),"trade full visible silhouette remains on dry ground: "+part.kind)
		ctx.expect(is_zero_approx(fposmod(part.ground.x,24)) and is_zero_approx(fposmod(part.ground.y,24)),"trade parts stay on grid "+part.kind)
	var game:=Points.create_game();game._ready();Points.configure(game,Points.registry().points[0]);game.state.world.estate.event="market"
	var rules:=Rules.rules(game);var before:Dictionary=game.SaveSystem.snapshot(game)
	for i in 24:Trade.destination("stall",Vector2(i*24,720),i%4);Trade.shadow("sack",i%4)
	ctx.expect(game.SaveSystem.snapshot(game)==before and Rules.rules(game)==rules,"trade lookup preserves full save and 1200 movement rules")
	ctx.expect(game.VillageEventSystem.POSITIONS.market==Vector2(1128,720),"trade original interaction point unchanged")
	game.player=Vector2(1128,768)
	ctx.expect(game.NavigationSystem.walkability_reason(game,game.player,-1,true,false)=="walkable","trade original front approach remains walkable")
	ctx.expect(game.VillageEventSystem.nearest_interaction(game,92)=="village_event:market","trade front approach resolves actual market")
	ctx.expect(game.VillageEventSystem.interact(game,"market") and game.shop_open,"trade actual market opens shop")
	game.shop_open=false
	ctx.expect(game.BuildingSystem.SHOP_STALL_POSITION==Vector2(1416,576) and game.BuildingSystem.SELL_CRATE_POSITION==Vector2(1512,576),"trade existing shop and sale services retain points")
	for p in [Vector2(1416,624),Vector2(1512,624)]:ctx.expect(game.NavigationSystem.walkability_reason(game,p,-1,true,false)=="walkable","trade service approach not blocked: "+str(p))
	containers(ctx,game)
	game.free()

## Открывает настоящий мешок ровно один раз и проверяет все прежние места появления без смены генератора.
static func containers(ctx:SceneTree,game:Node)->void:
	var original:Array=game.LootContainerSystem.generate(Points.SEED)
	ctx.expect(original==game.LootContainerSystem.generate(Points.SEED),"trade deterministic production loot retained")
	for point in game.LootContainerSystem.SPAWNS[0].positions:
		var container:={"kind":"sack","location":"overworld","position":point,"opened":false,"contents":{"seeds":2,"coins":3},"id":900}
		ctx.expect(Trade.painted_sack(container),"trade first-map sack selected")
		ctx.expect(game.WorldLootRenderer.container_collision(container)==Rect2(point-Vector2(24,12),Vector2(48,24)),"trade original sack collision retained")
		var rect:=Trade.destination("sack",point+Vector2(0,12))
		for p in [rect.position,rect.end,Vector2(rect.position.x,rect.end.y),Vector2(rect.end.x,rect.position.y)]:ctx.expect(not Geometry2D.is_point_in_polygon(p,Map.river_polygon()) and not Geometry2D.is_point_in_polygon(p,Map.pond_polygon()),"trade all five sack slots stay dry")
		game.world_loot_nodes=[container];game.player=point+Vector2(0,48);var seeds:int=game.inventory_item_count("seeds");var coins:int=game.coins
		ctx.expect(game.LootContainerSystem.open(game,0) and game.world_loot_nodes[0].opened,"trade actual loot opening")
		ctx.expect(game.inventory_item_count("seeds")==seeds+2 and game.coins==coins+3,"trade exact inventory grants preserved")
		ctx.expect(not game.LootContainerSystem.open(game,0),"trade repeat opening grants nothing")
		container.location="forest";ctx.expect(not Trade.painted_sack(container),"trade other maps retain legacy art")
		container.location="overworld";container.kind="trash";ctx.expect(not Trade.painted_sack(container),"trade other loot kinds unchanged")
