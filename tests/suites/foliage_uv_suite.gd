extends RefCounted

const UV:=preload("res://scripts/presentation/foliage_uv.gd")
const Roots:=preload("res://scripts/presentation/foliage_root_profile.gd")
const Ambient:=preload("res://scripts/systems/village_ambient_renderer.gd")
const RootSuite:=preload("res://tests/suites/foliage_root_suite.gd")
const Points:=preload("res://tools/visual_camera_points.gd")

## Проверяет все регионы, отражения, ограничение выборки, фиксированные ряды и независимость материалов.
static func run(ctx:SceneTree)->void:
	var atlas:=Image.load_from_file(ProjectSettings.globalize_path(RootSuite.ATLAS_PATH));var shared:=ImageTexture.create_from_image(atlas)
	for kind in Roots.PROFILES:
		var profile:=Roots.profile(kind);var source:=RootSuite.source_image(kind,atlas)
		var texture:Texture2D=ImageTexture.create_from_image(source) if kind=="grass_low" else shared
		var size:=Vector2i(texture.get_size());var region:=Rect2i(Vector2i.ZERO,profile.size) if kind=="grass_low" else Rect2i(Ambient.source_rect(kind))
		var mask:=ImageTexture.create_from_image(Roots.build_mask(kind,source));var before:=[]
		for flipped in [false,true]:
			var parameters:=UV.parameters(kind,region,size,flipped)
			ctx.expect(not parameters.is_empty(),"known source region is explicit: "+kind+str(flipped))
			for point in [Vector2(-20,-10),Vector2.ZERO,Vector2.ONE,Vector2(12,18),Vector2(0.5,0.5)]:
				var pixel:Vector2=UV.atlas_uv(parameters,point)*Vector2(size)-Vector2(region.position)
				ctx.expect(pixel.x>=0.4999 and pixel.y>=0.4999 and pixel.x<=region.size.x-0.499 and pixel.y<=region.size.y-0.499,"linear kernel stays within its own texel centers: "+kind)
			var root_uv:=Vector2(parameters.root)/Vector2(profile.size)
			var sampled:Vector2=UV.atlas_uv(parameters,root_uv)*Vector2(size)-Vector2(region.position)
			ctx.expect(sampled.is_equal_approx(Vector2(profile.root)),"horizontal flip samples the original root without inverting the bottom: "+kind)
			var data:=UV.mesh_data(kind,0.2,flipped);var vertices:PackedVector2Array=data.arrays[Mesh.ARRAY_VERTEX];var coords:PackedVector2Array=data.arrays[Mesh.ARRAY_TEX_UV]
			ctx.expect(data.rows.has(float(profile.root.y)/profile.size.y) and data.rows.has(float(profile.lock_y)/profile.size.y),"root and fixed-base rows are present: "+kind)
			var bad:=0
			for i in vertices.size():
				var expected:Vector2=(coords[i]*Vector2(profile.size)-Vector2(data.root))*0.2
				if not vertices[i].is_equal_approx(expected):bad+=1
				if coords[i].y>=float(profile.lock_y)/profile.size.y and vertices[i].y<-1.201:bad+=1
			ctx.expect(bad==0,"mesh uses local UV and keeps the lower rows below its real root: "+kind)
			var mesh:=UV.make_mesh(data);ctx.expect(mesh!=null and mesh.get_surface_count()==1 and mesh.custom_aabb.size.x>profile.size.x*0.2+16,"shader deformation remains inside the declared culling envelope: "+kind)
			var material:=UV.make_material(parameters,texture,mask)
			ctx.expect(material!=null and material.get_shader_parameter("source_rect")==Vector4(region.position.x,region.position.y,region.size.x,region.size.y),"material owns its exact source rectangle: "+kind)
			ctx.expect(material.get_shader_parameter("mirror_x")==flipped and material.get_shader_parameter("bend")==Vector2.ZERO and material.get_shader_parameter("flexible")==profile.flexible,"material begins with no wind and the correct root policy: "+kind)
			ctx.expect(is_equal_approx(material.get_shader_parameter("lock_v"),float(profile.lock_y)/profile.size.y),"fixed lower strip is expressed in local vertical coordinates: "+kind)
			if not flipped:before=[material,data]
			else:
				ctx.expect(before[0]!=material and before[0].get_shader_parameter("mirror_x")==false,"second region/flip does not mutate another material: "+kind)
				var first:PackedVector2Array=before[1].arrays[Mesh.ARRAY_VERTEX];var same_y:=true
				for i in first.size():
					if first[i].y!=vertices[i].y:same_y=false
				ctx.expect(same_y,"flip only changes the horizontal orientation: "+kind)
	ctx.expect(UV.parameters("missing",Rect2i(0,0,362,362),Vector2i(1448,1086)).is_empty(),"unknown type is not a hidden flower region")
	for region in [Rect2i(-1,0,362,362),Rect2i(1300,0,362,362),Rect2i(0,0,361,362),Rect2i(0,0,0,0)]:ctx.expect(UV.parameters("grass",region,Vector2i(1448,1086)).is_empty(),"invalid atlas region is refused")
	for scale in [0.0,-1.0,INF,NAN,5.0]:ctx.expect(UV.mesh_data("grass",scale).is_empty(),"invalid uniform scale is refused")
	ctx.expect(UV.make_mesh({})==null and UV.make_material({},shared,shared)==null and not UV.atlas_uv({},Vector2.ZERO).is_finite(),"empty descriptor cannot produce a drawable object")
	var valid:=UV.parameters("grass",Rect2i(362,0,362,362),Vector2i(1448,1086))
	ctx.expect(not UV.atlas_uv(valid,Vector2(NAN,0)).is_finite() and UV.make_material(valid,shared,shared)==null,"nonfinite UV and wrong mask size are refused")
	_purity(ctx,shared)

## Подготовка ресурсов остаётся вне игрового состояния при четырёх направлениях, остановке и паузе.
static func _purity(ctx:SceneTree,texture:Texture2D)->void:
	var a:=Points.create_game();a._ready();Points.configure(a,Points.registry().points[0])
	var b:=Points.create_game();b._ready();Points.configure(b,Points.registry().points[0])
	var initial:Dictionary=a.SaveSystem.snapshot(a);a.SaveSystem.apply(a,initial);b.SaveSystem.apply(b,initial)
	for direction in [Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN,Vector2.ZERO]:
		for game in [a,b]:
			seed(9321);game.clear_movement_keys();game.move_left_held=direction.x<0;game.move_right_held=direction.x>0;game.move_up_held=direction.y<0;game.move_down_held=direction.y>0
			for step in 3:game._physics_process(1.0/30)
		var before:Dictionary=a.SaveSystem.snapshot(a);var count:=a.get_child_count();var metadata:=a.get_meta_list()
		for flipped in [false,true]:
			var data:=UV.parameters("grass",Rect2i(362,0,362,362),Vector2i(texture.get_size()),flipped)
			var mesh:=UV.make_mesh(UV.mesh_data("grass",0.2,flipped))
			ctx.expect(not data.is_empty() and mesh!=null,"resource preparation works during an existing gameplay route")
		ctx.expect(a.SaveSystem.snapshot(a)==before and a.get_child_count()==count and a.get_meta_list()==metadata,"local UV preparation creates no game nodes, active tufts, metadata or save fields")
		ctx.expect(a.SaveSystem.snapshot(a)==b.SaveSystem.snapshot(b),"equal input/seed preserves whole gameplay with UV preparation")
	for mode in ["pause","wall","teleport","offscreen","low"]:
		a.menu_state.pause_open=false;a.clear_movement_keys()
		if mode=="pause":a.menu_state.pause_open=true
		elif mode=="wall":
			a.player=a.workbench_position+Vector2(0,48);a.move_up_held=true
			for step in 12:a._physics_process(1.0/30)
		elif mode=="teleport":
			a.change_inventory_count(Points.Teleport.KIND,1)
			ctx.expect(Points.Teleport.open(a) and Points.Teleport.travel(a,"overworld"),"actual QA transfer precedes UV preparation")
		elif mode=="low":a.settings_state.reduced_motion=true
		var before:Dictionary=a.SaveSystem.snapshot(a);var count:=a.get_child_count();var metadata:=a.get_meta_list()
		for flip in [false,true]:
			var item:=UV.mesh_data("grass",0.2,flip);var mesh:=UV.make_mesh(item)
			var origin:Vector2=Vector2(-8000,4000) if mode=="offscreen" else a.player
			ctx.expect(mesh!=null and Roots.world_anchor("grass",Rect2(origin,Vector2(72,72))).is_finite(),"resource preparation remains bounded for "+mode)
		ctx.expect(a.SaveSystem.snapshot(a)==before and a.get_child_count()==count and a.get_meta_list()==metadata,"no hidden active tuft/node/state survives "+mode)
	a.free();b.free()
