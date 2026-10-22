extends RefCounted

const Roots:=preload("res://scripts/presentation/foliage_root_profile.gd")
const Ambient:=preload("res://scripts/systems/village_ambient_renderer.gd")
const Points:=preload("res://tools/visual_camera_points.gd")
const ATLAS_PATH:="res://assets/game/environment/village_ambient_atlas_v1.png"
const PILOT_PATH:="res://docs/reports/visual-overhaul/vart-008/native/sprites/grass-low.png"

## Запускает паспорт всех областей, проверки масок и чистое чтение опор на настоящем игровом состоянии.
static func run(ctx:SceneTree)->void:
	var atlas:=Image.load_from_file(ProjectSettings.globalize_path(ATLAS_PATH))
	ctx.expect(atlas.get_size()==Vector2i(1448,1086),"root catalog uses the actual four by three atlas")
	ctx.expect(Roots.PROFILES.size()==Ambient.CELLS.size()+1,"all twelve regions plus accepted painterly pilot have explicit profiles")
	for kind in Roots.PROFILES:
		var source:=source_image(kind,atlas);var data:=Roots.profile(kind)
		ctx.expect(source.get_size()==data.size and Rect2i(Vector2i.ZERO,data.size).has_point(data.root),"root is inside its own source: "+kind)
		ctx.expect(roundi(source.get_pixelv(data.root).a*255)>=Roots.ALPHA_THRESHOLD,"root touches actual opaque artwork: "+kind)
		var digest:=hash(source.get_data());var mask:=Roots.build_mask(kind,source)
		ctx.expect(mask!=null and mask.get_size()==source.get_size() and mask.get_format()==Image.FORMAT_L8,"mask keeps the isolated pixel domain and one data channel: "+kind)
		var bad:=0;var nonzero:=0
		for y in data.size.y:
			for x in data.size.x:
				var value:=mask.get_pixel(x,y).r
				if value>0:
					nonzero+=1
					if not data.flexible or y>=data.lock_y or roundi(source.get_pixel(x,y).a*255)<Roots.ALPHA_THRESHOLD:bad+=1
		ctx.expect(bad==0,"transparent padding, fixed base and rigid/floating details cannot bend: "+kind)
		ctx.expect((nonzero>0)==data.flexible,"only classified terrestrial plants have a nonempty mask: "+kind)
		ctx.expect(mask.get_pixelv(data.root).r==0 and Roots.flexibility(kind,data.root,255)==0,"the real root is fixed in both representations: "+kind)
		ctx.expect(hash(source.get_data())==digest,"mask compilation preserves source RGBA: "+kind)
		var rect:=Rect2(Vector2(118.25,360.5),Vector2(data.size)*0.2)
		var anchor:=Roots.world_anchor(kind,rect)
		ctx.expect(anchor.is_equal_approx(rect.position+Vector2(data.root)*0.2),"world root follows the actual draw rectangle: "+kind)
		for side in [Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN]:
			var moved:=Rect2(rect.position+side*24,rect.size)
			ctx.expect(Roots.world_anchor(kind,moved).is_equal_approx(anchor+side*24),"four approaches keep source root coordinates: "+kind)
		ctx.expect(Roots.flexibility(kind,Vector2i(-1,0),255)==0 and Roots.flexibility(kind,data.size,255)==0 and Roots.flexibility(kind,Vector2i.ZERO,0)==0,"outside and transparent texels have zero influence: "+kind)
	var grass:=source_image("grass_low",atlas)
	ctx.expect(grass.get_pixel(219,490).a<0.02 and grass.get_pixel(219,480).a>0.95,"new grass root avoids the old nearly transparent prototype pivot")
	ctx.expect(atlas.get_pixel(155,722).a>0.8 and Roots.profile("mossy_stone").root.y<294,"neighbor lantern fragment cannot become the stone anchor")
	ctx.expect(Roots.profile("missing").is_empty() and Roots.build_mask("missing",grass)==null,"unknown profile does not silently select flowers")
	ctx.expect(Roots.build_mask("grass",grass)==null and Roots.build_mask("grass",null)==null,"wrong region size and missing source are refused")
	ctx.expect(not Roots.world_anchor("grass",Rect2()).is_finite() and not Roots.world_anchor("missing",Rect2(0,0,72,72)).is_finite(),"invalid projection is explicit")
	var copy:=Roots.profile("grass");copy.root=Vector2i.ZERO
	ctx.expect(Roots.profile("grass").root==Vector2i(178,325),"callers cannot mutate the root passport")
	_gameplay(ctx)

## Выделяет ровно исходную область; принятый живописный пример не подменяет production-атлас.
static func source_image(kind:String,atlas:Image)->Image:
	if kind=="grass_low":return Image.load_from_file(ProjectSettings.globalize_path(PILOT_PATH))
	return atlas.get_region(Rect2i(Ambient.source_rect(kind)))

## Проверяет опоры при реальном вводе, остановке, стене, паузе, телепорте и за экраном без создания живых групп.
static func _gameplay(ctx:SceneTree)->void:
	var a:=Points.create_game();a._ready();Points.configure(a,Points.registry().points[0])
	var b:=Points.create_game();b._ready();Points.configure(b,Points.registry().points[0])
	var initial:Dictionary=a.SaveSystem.snapshot(a);ctx.expect(a.SaveSystem.apply(a,initial) and b.SaveSystem.apply(b,initial),"root reads begin from the same complete gameplay state")
	var positions:=[Vector2(1944,648),Vector2(2160,888),Vector2(-8000,4000)]
	for direction in [Vector2.RIGHT,Vector2.DOWN,Vector2.LEFT,Vector2.UP,Vector2.ZERO]:
		for game in [a,b]:
			seed(8401);game.clear_movement_keys();game.benchmark_autoplay=false
			game.move_left_held=direction.x<0;game.move_right_held=direction.x>0;game.move_up_held=direction.y<0;game.move_down_held=direction.y>0
			for step in 3:game._physics_process(1.0/30)
		var before:Dictionary=a.SaveSystem.snapshot(a);var children:=a.get_child_count();var metadata:=a.get_meta_list()
		for position in positions:
			for kind in Ambient.CELLS:
				var root:Vector2=Ambient.root_anchor(kind,position)
				ctx.expect(root.is_finite() and Ambient.destination_rect(position).has_point(root),"visible/offscreen root lookup is local: "+kind)
		ctx.expect(a.SaveSystem.snapshot(a)==before and a.get_child_count()==children and a.get_meta_list()==metadata,"root queries create no nodes, active bend state, metadata or gameplay mutations")
		var other:Dictionary=b.SaveSystem.snapshot(b)
		if a.SaveSystem.snapshot(a)!=other:
			for key in other:
				if a.SaveSystem.snapshot(a).get(key)!=other[key]:print("ROOT REPLAY DIFFERENCE: ",key)
		ctx.expect(a.SaveSystem.snapshot(a)==other,"same actual input and seed preserve complete gameplay with root reads")
	for mode in ["pause","low","wall","teleport"]:
		if mode=="pause":a.menu_state.pause_open=true
		elif mode=="low":a.settings_state.reduced_motion=true
		elif mode=="wall":a.player=Vector2(0,0)
		else:a.player=Vector2(2160,888)
		var before:Dictionary=a.SaveSystem.snapshot(a)
		for i in 20:
			for kind in Ambient.CELLS:Ambient.root_anchor(kind,a.player)
		ctx.expect(a.SaveSystem.snapshot(a)==before,"pause/low/wall/teleport cannot accumulate root state: "+mode)
	a.free();b.free()
