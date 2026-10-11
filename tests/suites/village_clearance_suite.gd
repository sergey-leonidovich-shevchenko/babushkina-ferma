extends "res://tests/suites/suite_base.gd"

const Map := preload("res://scripts/systems/village_map_data.gd")
const Migration := preload("res://scripts/systems/village_map_migration_system.gd")

## Проверяет нарисованные дороги физической прогулкой, запас прохода и перенос сохранённого дерева.
func run() -> void:
	test_marked_roads_and_guild_corridor()
	test_revision_two_save_migration()
	test_custom_tree_and_local_player_repair()

## Сценарий: герой проходит все размеченные дороги, включая новый двор, и три полосы рядом с гильдией.
## Исходное состояние: все штатные деревья, основания, верстак и добыча сохранены, исключены только подвижные враги.
## Ожидаемый результат: реальное движение подшагами не застревает, каждый поперечный зазор не меньше 60 px.
func test_marked_roads_and_guild_corridor() -> void:
	var game := make_game(); game.current_location="overworld"; game.slime_alive=false; game.enemy_nodes.clear(); game.hazard_nodes.clear()
	var index := 0
	for path in Map.routes():
		game.player=path[0]
		var walked := true; var minimum := 1000.0
		for segment in range(path.size()-1):
			var start: Vector2 = path[segment]; var finish: Vector2 = path[segment+1]
			var normal := start.direction_to(finish).orthogonal()
			var samples := maxi(1,ceili(start.distance_to(finish)/12.0))
			for sample in range(samples+1):
				var point := start.lerp(finish,float(sample)/samples)
				minimum=minf(minimum,clearance(game,point,normal)+clearance(game,point,-normal)+game.PLAYER_RADIUS*2)
			if not walk_to(game,finish): walked=false; break
		expect(walked,"marked road walks through actual swept navigation: "+str(index))
		expect(minimum>=60,"marked road has at least 60px physical width: "+str(index))
		index+=1
	var right := 0.0
	for rect in game.BuildingSystem.collision_rects("guild_hall"): right=maxf(right,rect.end.x)
	var tree: Rect2 = game.TreeSystem.collision_rect(game.state.world.tree_nodes[0])
	expect(tree.position.x-right==84,"guild and first grown tree leave 84px")
	var middle := (right+tree.position.x)/2
	for offset in [-12,0,12]:
		game.player=Vector2(middle+offset,288)
		expect(walk_to(game,Vector2(middle+offset,504)),"guild corridor tolerates imprecise aim: "+str(offset))
		expect(walk_to(game,Vector2(middle+offset,288)),"guild corridor returns without corner assistance: "+str(offset))
	game.free()

## Измеряет первый физический край реальным радиусом героя с точностью два пикселя.
func clearance(game: Node, point: Vector2, direction: Vector2) -> float:
	for distance in range(2,122,2):
		if game.NavigationSystem.walkability_reason(game,point+direction*distance,-1,false)!="walkable": return float(distance-2)
	return 120.0

## Проходит сегмент малыми шагами без помощи краю, обнаруживая физическую стену между узлами.
func walk_to(game: Node, target: Vector2) -> bool:
	for step in range(ceili(game.player.distance_to(target)/3.0)+2):
		if game.player.distance_to(target)<0.01: return true
		var motion: Vector2 = (target-game.player).limit_length(3)
		var previous: Vector2 = game.player
		game.NavigationSystem.move(game,motion,false)
		if game.player.distance_to(previous+motion)>0.01: return false
	return game.player.distance_to(target)<0.01

## Сценарий: сохранение карты второй ревизии содержит срубленное дерево и открытый сундук на своей позиции.
## Исходное состояние: здоровье, рост, монеты, урожай и все остальные позиции имеют пользовательский прогресс.
## Ожидаемый результат: меняется лишь координата первого дерева, повторная загрузка не переносит его снова.
func test_revision_two_save_migration() -> void:
	var game := make_game(); game.current_location="overworld"; game.player=Map.START
	game.state.world.estate.map_revision=2
	game.state.world.tree_nodes[0].position=Vector2(2016,336); game.state.world.tree_nodes[0].health=0
	game.state.world.tree_nodes[0].stage=1; game.state.world.tree_nodes[0].regrow_timer=13.75
	game.world_loot_nodes[0].opened=true; game.world_loot_nodes[0].position=Vector2(920,400)
	game.plots[Vector2i(0,0)].tilled=true; game.coins=137
	var snapshot: Dictionary = game.SaveSystem.snapshot(game)
	var restored := make_game()
	expect(restored.SaveSystem.apply(restored,snapshot),"revision two snapshot applies through production save loader")
	var tree: Dictionary = restored.state.world.tree_nodes[0]
	expect(tree.position==Map.TREES[0] and tree.health==0 and tree.stage==1 and tree.regrow_timer==13.75,"moving old tree preserves felling and growth progress")
	expect(restored.world_loot_nodes[0].opened and restored.world_loot_nodes[0].position==Vector2(920,400),"revision three does not remigrate revision two loot")
	expect(restored.coins==137 and restored.plots[Vector2i(0,0)].tilled and restored.player==Map.START,"map update preserves rewards crops and free player position")
	var trees: Array = restored.state.world.tree_nodes.duplicate(true)
	var loot: Array = restored.world_loot_nodes.duplicate(true)
	Migration.apply(restored,Map.REVISION)
	expect(restored.state.world.tree_nodes==trees and restored.world_loot_nodes==loot,"repeat map migration is idempotent")
	expect(restored.state.world.estate.map_revision==Map.REVISION,"successful migration records current map revision")
	game.free(); restored.free()

## Сценарий: редакторная позиция дерева отличается от старого шаблона, а герой сохранён на новом основании.
## Исходное состояние: миграция второй ревизии знает старые координаты только одного штатного дерева.
## Ожидаемый результат: пользовательская позиция не изменяется; застрявший герой выходит рядом, остальные деревья сохраняются.
func test_custom_tree_and_local_player_repair() -> void:
	var game := make_game(); game.current_location="overworld"
	game.state.world.tree_nodes[0].position=Vector2(2112,312)
	var custom: Array = game.state.world.tree_nodes.duplicate(true)
	Migration.apply(game,2)
	expect(game.state.world.tree_nodes==custom,"custom and unrelated tree positions are not overwritten")
	game.state.world.tree_nodes[0].position=Vector2(2016,336)
	game.player=Vector2(2064,360)
	var original: Vector2 = game.player
	Migration.apply(game,2)
	expect(game.NavigationSystem.walkability_reason(game,game.player,-1,false)=="walkable","player under migrated trunk moves to a truly free circle")
	expect(game.player.distance_to(original)>0 and game.player.distance_to(original)<=60,"repair stays near the saved place")
	game.free()
