extends RefCounted
const Pass:=preload("res://scripts/presentation/pilot_object_pass.gd")
const Points:=preload("res://tools/qa/camera/visual_camera_points.gd")
const Rules:=preload("res://tools/qa/ground/ground_seasons_fixture.gd")

## Проверяет ограничение флага, чистую команду, атомарный отказ и отсутствие изменений механики.
static func run(ctx:SceneTree)->void:
	var game:=Points.create_game();game._ready();Points.configure(game,Points.registry().points[0]);var rules:=Rules.rules(game);var saved:Dictionary=game.SaveSystem.snapshot(game)
	var plan:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://docs/reports/visual-overhaul/vrelease-001/plan.json"))
	var rect:Array=plan.scope.world_rect
	ctx.expect(Pass.SCOPE==Rect2(rect[0],rect[1],rect[2],rect[3]),"pilot scope exactly matches canonical first-location plan")
	var prop:={"kind":"board","position":Pass.POSITION}
	ctx.expect(Pass.enabled(game) and Pass.selected(game,prop,false),"pilot defaults on only for selected first-map body")
	for value in [false,1,"on"]:
		game.set_meta(Pass.FLAG,value);ctx.expect(not Pass.enabled(game),"pilot rejects unknown or disabled flag: "+str(value))
	game.remove_meta(Pass.FLAG)
	ctx.expect(not Pass.selected(game,prop,true),"pilot leaves original foreground pass untouched")
	ctx.expect(not Pass.selected(game,{"kind":"board","position":Vector2(1656,528)},false),"pilot excludes second board outside reference patch")
	ctx.expect(not Pass.selected(game,{"kind":"board","position":Vector2(672,576)},false),"pilot excludes unselected body even inside reference patch")
	ctx.expect(not Pass.selected(game,{"kind":"bench","position":Pass.POSITION},false),"pilot excludes other prop families")
	game.current_location="forest";ctx.expect(not Pass.selected(game,prop,false),"pilot excludes other maps");game.current_location="overworld"
	game.set_meta(game.LevelEditorSystem.META_KEY,{"active":true});ctx.expect(not Pass.selected(game,prop,false),"pilot editor retains legacy route");game.remove_meta(game.LevelEditorSystem.META_KEY)
	Pass._packets.clear();Pass._builds=0
	for side in [0,1,3]:
		var packet:=Pass.packet(side)
		ctx.expect(Pass.Command.valid(packet) and packet.is_read_only(),"pilot real immutable packet: "+str(side))
		ctx.expect(packet.anchor==Pass.GROUND and packet.bounds==Pass.Board.destination("board",Pass.GROUND,side),"pilot exact measured board geometry: "+str(side))
		ctx.expect(packet.texture==Pass.Board.Resources.sampled_texture("prop.village_board",Pass.Board.Facing.NAMES[side]) and packet.material==null,"pilot shares original texture/material identity")
		ctx.expect(packet.layer=="behind_actors" and packet.world=="overworld" and packet.local_uv==Rect2(0,0,1,1),"pilot explicit world pass and UV")
	for i in 256:Pass.packet(i%4)
	ctx.expect(Pass._packets.size()==3 and Pass._builds==3,"pilot bounded three entries without per-frame reconstruction")
	ctx.expect(Pass.Replay.can_draw(game,Pass.packet(),"overworld",Pass.LAYER),"pilot actual null-material canvas accepts command")
	var calls:=[0];var legacy:=func():calls[0]+=1
	game.set_meta(Pass.FLAG,false);ctx.expect(Pass.draw(game,prop,false,legacy)=="legacy" and calls[0]==1,"pilot disabled flag calls original route once")
	game.set_meta(Pass.FLAG,true);ctx.expect(Pass.draw(game,prop,true,legacy)=="legacy" and calls[0]==2,"pilot foreground calls original route once")
	game.material=CanvasItemMaterial.new();var material:Material=game.material
	ctx.expect(Pass.draw(game,prop,false,legacy)=="fallback" and calls[0]==3 and game.material==material,"pilot material mismatch is atomic and preserves material")
	game.material=null;game.use_parent_material=true
	ctx.expect(Pass.draw(game,prop,false,legacy)=="fallback" and calls[0]==4 and game.use_parent_material,"pilot inherited material is refused without mutation")
	game.use_parent_material=false
	var good:=Pass.packet();var bad:=good.duplicate();bad.texture=null;bad.make_read_only();Pass._packets[0]=bad
	ctx.expect(Pass.draw(game,prop,false,legacy)=="fallback" and calls[0]==5,"pilot invalid cached resource uses one legacy call")
	Pass._packets[0]=good
	ctx.expect(not game.has_meta(Pass.TRACE),"pilot normal route creates no tracing metadata")
	game.set_meta(Pass.TRACE,[]);game.set_meta(Pass.FLAG,false)
	for i in 24:Pass.draw(game,prop,false,legacy)
	ctx.expect(game.get_meta(Pass.TRACE).size()==8,"pilot optional QA trace is capped even without consumer")
	ctx.expect(saved==game.SaveSystem.snapshot(game) and rules==Rules.rules(game),"pilot flags/cache/fallback preserve full save and 1200 movement rules")
	game.free()
