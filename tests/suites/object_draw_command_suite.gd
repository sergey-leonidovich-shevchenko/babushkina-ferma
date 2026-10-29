extends RefCounted

const Command := preload("res://scripts/presentation/object_draw_command.gd")
const Replay := preload("res://scripts/presentation/object_draw_replay.gd")
const Bench := preload("res://scripts/presentation/world_workbench_visual_system.gd")

## Запускает договорённости о чистом пакете и атомарном возврате к прежнему draw.
static func run(context: SceneTree) -> void:
	test_real_workbench_descriptor(context)
	test_invalid_commands(context)
	test_material_scope_and_fallback(context)
	test_world_and_save_are_unchanged(context)

## Сценарий: настоящий верстак описывается в трёх рабочих ракурсах на дробной мировой опоре.
## Исходное состояние: общий AtlasTexture, прежние размеры рисунка и отдельный коллизионный след.
## Ожидаемый результат: команда замкнута, UV локален, ресурсы не копируются, поля исходника не связаны.
static func test_real_workbench_descriptor(context: SceneTree) -> void:
	for direction in [0,1,3]:
		var ground:=Vector2(720.25,612.5); var packet:=Bench.command(ground,direction)
		context.expect(Command.valid(packet) and packet.is_read_only(),"real bench command is a read-only versioned snapshot: "+str(direction))
		context.expect(packet.anchor==ground and packet.bounds==Bench.destination(ground,direction) and packet.bounds!=Bench.collision_rect(ground),"draw bounds are not mistaken for collision geometry")
		context.expect(packet.texture==Bench.texture(direction) and packet.source==Rect2(Vector2.ZERO,packet.texture.get_size()),"atlas resource and source pixels retain the legacy identity")
		context.expect(packet.local_uv==Rect2(0,0,1,1) and packet.world=="overworld" and packet.layer=="behind_actors","local UV is distinct from atlas pixels and phase is explicit")
	var spec:=Bench.command(Vector2(600,600)).duplicate();var frozen:=Command.create(spec);spec.anchor=Vector2.ZERO
	context.expect(frozen.anchor==Vector2(600,600) and frozen.texture==spec.texture,"caller dictionary cannot mutate a queued descriptor; shared resources retain identity")

## Сценарий: внешний пакет содержит неверные границы, UV, версию, слой либо ресурс.
## Исходное состояние: настоящий корректный верстак и независимые копии его описания.
## Ожидаемый результат: каждый дефект отклоняется до любой частичной команды рисования.
static func test_invalid_commands(context: SceneTree) -> void:
	for change in [["version",2],["id"," "],["world",""],["space","screen"],["layer","hud"],
		["anchor",Vector2(NAN,0)],["bounds",Rect2(0,0,-2,3)],["bounds",Rect2(0,0,INF,2)],
		["source",Rect2(-1,0,2,2)],["source",Rect2(0,0,99999,99999)],["texture",null],
		["material",StandardMaterial3D.new()],["material",ShaderMaterial.new()],["local_uv",Rect2(0.2,0,1,1)],
		["modulate",Color(1,1,1,2)],["modulate",Color(NAN,1,1,1)]]:
		var spec:=Bench.command(Vector2(600,600)).duplicate();spec[change[0]]=change[1]
		context.expect(Command.create(spec).is_empty(),"invalid command rejected: "+str(change[0])+" / "+str(change[1]))
	var spec:=Bench.command(Vector2(600,600)).duplicate();spec.erase("material")
	context.expect(Command.create(spec).is_empty(),"implicit material omission is rejected")
	spec=Bench.command(Vector2(600,600)).duplicate();spec.rotation=0.3
	context.expect(Command.create(spec).is_empty(),"unsupported diagonal transform is not silently ignored")

## Сценарий: пакет попадает в чужой мир, фазу или CanvasItem с другим материалом.
## Исходное состояние: отдельный узел и счётчик прежнего пути без настоящего draw вне callback.
## Ожидаемый результат: отказ атомарен, fallback вызывается один раз, материал и трансформация сохраняются.
static func test_material_scope_and_fallback(context: SceneTree) -> void:
	var canvas:=Node2D.new();var packet:=Bench.command(Vector2(600,600));var calls:=[0]
	var fallback:=func(): calls[0]+=1
	context.expect(Replay.can_draw(canvas,packet,"overworld","behind_actors"),"exact canvas world and phase accept the existing null-material sprite")
	var shader:=Shader.new();shader.code="shader_type canvas_item; void fragment(){ COLOR *= vec4(0.8,0.9,1.0,1.0); }"
	var shader_material:=ShaderMaterial.new();shader_material.shader=shader
	var spec:=packet.duplicate();spec.material=shader_material;spec.modulate=Color(0.8,1,0.9,0.34)
	canvas.material=shader_material
	context.expect(Replay.can_draw(canvas,Command.create(spec),"overworld","behind_actors"),"isolated canvas-item shader and per-object alpha are accepted without mutating the material")
	canvas.material=null
	for scope in [["cottage_interior","behind_actors"],["overworld","foreground"]]:
		context.expect(Replay.draw(canvas,packet,scope[0],scope[1],fallback)=="fallback","foreign world/phase takes legacy fallback")
	canvas.material=CanvasItemMaterial.new();var material:=canvas.material;var transform:=canvas.transform
	context.expect(Replay.draw(canvas,packet,"overworld","behind_actors",fallback)=="fallback" and canvas.material==material and canvas.transform==transform,"material mismatch never mutates a shared root to make a packet fit")
	canvas.material=null;canvas.use_parent_material=true
	context.expect(Replay.draw(canvas,packet,"overworld","behind_actors",fallback)=="fallback","inherited material cannot masquerade as an isolated object material")
	context.expect(calls[0]==4,"each refusal calls the legacy route exactly once")
	context.expect(Replay.draw(canvas,{},"overworld","behind_actors")=="rejected","missing fallback fails closed without draw")
	canvas.free()

## Сценарий: чтение команд происходит рядом с действительным игроком первой карты.
## Исходное состояние: подготовленная навигация, полный save и прежние 1 200 правил/восемь движений.
## Ожидаемый результат: описание рисунка не меняет механику, карту, опору героя или сохраняемые данные.
static func test_world_and_save_are_unchanged(context: SceneTree) -> void:
	var Fixture:=preload("res://tools/qa/ground/ground_seasons_fixture.gd")
	var game:=Fixture.Points.create_game();game._ready();Fixture.Points.configure(game,Fixture.Points.registry().points[0])
	var rules:=Fixture.rules(game);var saved:Dictionary=game.SaveSystem.snapshot(game);var player:Vector2=game.player
	for i in 32:Bench.command(game.workbench_position+Vector2(0,24),[0,1,3][i%3])
	context.expect(saved==game.SaveSystem.snapshot(game) and player==game.player,"descriptor construction preserves complete save and physical hero position")
	context.expect(rules==Fixture.rules(game),"descriptor construction preserves 1200 rules and eight real bridge motions")
	game.free()
