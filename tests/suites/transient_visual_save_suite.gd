extends RefCounted

const Store:=preload("res://scripts/systems/atomic_json_store.gd")
const Save:=preload("res://scripts/systems/save_system.gd")
const Points:=preload("res://tools/visual_camera_points.gd")
const Clock:=preload("res://scripts/presentation/village_ground_clock.gd")
const Depth:=preload("res://scripts/systems/tree_occlusion_system.gd")
const Pose:=preload("res://scripts/systems/presentation_pose_system.gd")
const PATH:="user://vcompat-001-boundary-test.json"

## Проверяет типовые ссылки, реальный transient-контейнер, старые слоты и одинаковый ввод с эффектами/без.
static func run(ctx:SceneTree)->void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PATH).get_base_dir())
	_references(ctx);_metadata(ctx);_legacy(ctx);_replay(ctx);_cleanup()

## Отказывает до записи и ротации; строки, похожие на ссылки, остаются обычным пользовательским текстом.
static func _references(ctx:SceneTree)->void:
	_cleanup()
	ctx.expect(Store.write(PATH,{"value":11},Callable(),true) and Store.write(PATH,{"value":22},Callable(),true),"reference guard accepts healthy JSON and backup")
	var original:=FileAccess.get_sha256(PATH);var backup:=FileAccess.get_sha256(PATH+".bak")
	var node:=Node2D.new();var material:=ShaderMaterial.new()
	var texture:=ImageTexture.create_from_image(Image.create(2,2,false,Image.FORMAT_RGBA8))
	var cases:={"node":node,"texture":texture,"material":material,"rid":node.get_canvas_item(),"callable":Callable(node,"queue_redraw"),"signal":node.tree_entered,"invalid_rid":RID(),"invalid_callable":Callable()}
	for label in cases:
		var payload:={"level":[{"visual":{"nested":[cases[label]]}}]}
		ctx.expect(not Store.write(PATH,payload,Callable(),true),"writer refuses nested runtime value: "+label)
		ctx.expect(FileAccess.get_sha256(PATH)==original and FileAccess.get_sha256(PATH+".bak")==backup and not FileAccess.file_exists(PATH+".tmp"),"runtime refusal preserves primary/backup/temp: "+label)
	var key_payload:={};key_payload[node]="not a stable JSON key"
	ctx.expect(not Store.write(PATH,key_payload),"object dictionary key is not implicitly stringified")
	var cycle:=[];cycle.append(cycle)
	ctx.expect(not Store.write(PATH,{"cache":cycle}),"cyclic visual cache is bounded and refused")
	cycle.clear()
	ctx.expect(FileAccess.get_sha256(PATH)==original and FileAccess.get_sha256(PATH+".bak")==backup,"key/cycle refusal preserves both files")
	var text:={"note":"<ShaderMaterial#123> RID(456) Callable()","nil":null,"rows":[1,2.5,true,"text"],"legacy_position":Vector2(4,5)}
	ctx.expect(Store.write(PATH,text),"literal resource-looking strings and legacy coordinates remain accepted")
	ctx.expect(Store.read(PATH).note==text.note and Store.read(PATH).rows==JSON.parse_string(JSON.stringify(text.rows)),"ordinary JSON semantics remain unchanged")
	node.free()

## Сохраняет настоящую очередь с Texture2D и временные часы за пределами документа, даже до flush.
static func _metadata(ctx:SceneTree)->void:
	var game:=_game();game.player=Vector2(1000,800);game.update_camera();Pose.reset(game)
	var before:=Save.snapshot(game)
	game.set_meta(Clock.META,123.25)
	game.set_meta(&"qa_visual_cache",{"shader":ShaderMaterial.new(),"canvas":game.get_canvas_item(),"bend":[Vector2(2,3)],"callback":Callable(game,"queue_redraw")})
	Depth.begin_frame(game)
	Depth.submit(game,"qa_pending_texture",game.PLANT_SHEET,Rect2(game.player-Vector2(16,16),Vector2(32,32)),Rect2(),game.player.y+24)
	ctx.expect(game.get_meta(Depth.META_KEY).queue.size()==1,"real foreground queue contains one pending texture packet")
	ctx.expect(Save.snapshot(game)==before,"GPU queue, bend, caches and shader clock never enter snapshot")
	ctx.expect(Save.save_at(game,PATH),"live transient references do not prevent a valid game save")
	var stored:=Store.read(PATH)
	ctx.expect(stored==JSON.parse_string(JSON.stringify(before)),"actual file contains only the normal gameplay document")
	var clone:=_game();ctx.expect(Save.load_at(clone,PATH),"saved gameplay document reloads normally")
	ctx.expect(not clone.has_meta(&"qa_visual_cache") and not clone.has_meta(Clock.META) and not clone.has_meta(Depth.META_KEY),"load cannot recreate handles, bends, queues or shader clock from JSON")
	Depth.begin_frame(game);ctx.expect(game.get_meta(Depth.META_KEY).queue.is_empty(),"next frame releases pending transient packet")
	clone.free();game.free()

## Читает неизменные синтетические v1/v2 и повторяет полную запись/загрузку их нормализованных состояний.
static func _legacy(ctx:SceneTree)->void:
	for name in ["v1-core","v2-production","v2-orchard-alchemy"]:
		var path:String="res://tests/fixtures/saves/"+String(name)+".json";var hash_before:=FileAccess.get_sha256(path)
		var raw:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path));var game:=_game()
		ctx.expect(Save.apply(game,raw),"historical fixture loads: "+name)
		var before:=Save.snapshot(game);game.set_meta(&"qa_visual_cache",{"material":ShaderMaterial.new()})
		ctx.expect(Save.save_at(game,PATH),"historical fixture saves with transient GPU metadata: "+name)
		var loaded:=_game();ctx.expect(Save.load_at(loaded,PATH),"historical fixture normal JSON reloads: "+name)
		var expected:Dictionary=JSON.parse_string(JSON.stringify(before))
		var actual:Dictionary=JSON.parse_string(JSON.stringify(Save.snapshot(loaded)))
		if actual!=expected:
			for key in expected:
				if actual.get(key)!=expected[key]:print("LEGACY DIFFERENCE ",name," ",key)
		ctx.expect(actual==expected,"complete normalized gameplay survives JSON: "+name)
		ctx.expect(FileAccess.get_sha256(path)==hash_before,"historical source bytes stay unchanged: "+name)
		loaded.free();game.free()

## Сравнивает весь мир после одинаковых тактов/seed; графические флаги и metadata не меняют игровой результат.
static func _replay(ctx:SceneTree)->void:
	var a:=_game();var b:=_game();var initial:=Save.snapshot(a)
	ctx.expect(Save.apply(a,initial) and Save.apply(b,initial),"visual replay begins from the same normalized gameplay state")
	a.set_meta(&"pilot_object_pass_enabled",true);a.set_meta(Depth.DEPTH_FLAG,true)
	b.set_meta(&"pilot_object_pass_enabled",false);b.set_meta(Depth.DEPTH_FLAG,false)
	a.settings_state.reduced_motion=false;b.settings_state.reduced_motion=true
	a.set_meta(&"qa_visual_cache",{"material":ShaderMaterial.new(),"bend":[Vector2(9,4)]});a.set_meta(Clock.META,82.5)
	var directions:=[Vector2.RIGHT,Vector2.DOWN,Vector2.LEFT,Vector2.UP,Vector2.ZERO]
	for i in directions.size():
		var outputs:=[]
		for game in [a,b]:
			seed(7200+i);game.clear_movement_keys();game.benchmark_autoplay=false
			game.move_left_held=directions[i].x<0;game.move_right_held=directions[i].x>0
			game.move_up_held=directions[i].y<0;game.move_down_held=directions[i].y>0
			ctx.expect(game.PlayerSystem.movement_direction(game)==directions[i],"replay feeds actual held input step "+str(i))
			for step in 4:game._physics_process(1.0/30.0)
			outputs.append(Save.snapshot(game))
		ctx.expect(outputs[0]==outputs[1],"full gameplay/RNG equal for visual-on/off input step "+str(i))
	ctx.expect(a.player!=Vector2(initial.player[0],initial.player[1]) or a.game_minutes!=float(initial.minutes),"comparison advances real simulation instead of static fixtures")
	a.free();b.free()

## Подготавливает только существующую игру с одинаковым seed и отключёнными стартовыми окнами.
static func _game()->Node:
	var game:=Points.create_game();game._ready();Points.configure(game,Points.registry().points[0]);game.WorkshopSystem.state(game,"pottery")
	game.set_meta(&"camera_reference_zoom",1.2);return game

## Удаляет только временные файлы этого набора, включая резервную копию и незавершённую запись.
static func _cleanup()->void:
	for suffix in ["",".bak",".tmp"]:
		if FileAccess.file_exists(PATH+suffix):DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH+suffix))
