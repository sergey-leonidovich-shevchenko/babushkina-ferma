extends SceneTree

const Game := preload("res://scripts/game.gd")
const Yard := preload("res://scripts/systems/livestock_data.gd")
const Rooms := preload("res://scripts/systems/cave_room_data.gd")
const Arena := preload("res://scripts/systems/cave_boss_arena_data.gd")
const DT := 1.0/60.0
var game: Node
var ticks := 0
var failed := false
var observations: Array[Dictionary]=[]
var held := {}
var visited: Array[String]=[]
var meals_used := 0
var phases := {}
var original_saves := {}
var prepared_snapshot := {}

## Запускает реальную модель новой игры в отдельном пользовательском каталоге без тестовых ресурсов.
func _initialize() -> void:
	for filename in ["farm-save.json","farm-save-2.json","farm-save-3.json"]:
		var path:=OS.get_user_data_dir().path_join(filename)
		original_saves[path]=FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "absent"
	ProjectSettings.set_setting("application/config/use_custom_user_dir",true)
	ProjectSettings.set_setting("application/config/custom_user_dir_name","Codex-MoonValley-E2E-%d"%Time.get_unix_time_from_system())
	if DirAccess.make_dir_recursive_absolute(OS.get_user_data_dir())!=OK:
		push_error("Не удалось создать отдельный каталог QA-сохранений"); quit(2); return
	seed(20260908)
	game=Game.new(); game.audio_enabled=false; game.world_loot_seed=20260908; game._ready()
	game.language_screen=false; game.LocaleSystem.current="ru"
	game.MenuSystem.start_new_game(game)
	game.AdventurePolishSystem.handle_creation_key(game,KEY_ENTER)
	game.InventorySystem.equip(game,"axe")
	note("new_game",{"profile_created":game.state.player.profile.created,"starter_feed":game.inventory_item_count("animal_feed")})
	for column in [1,2,3]:
		var center: Vector2=Vector2(game.FARM_ORIGIN)+Vector2(column*48+24,2*48+24)
		walk_to(center-Vector2(0,42),8); game.facing=Vector2.DOWN
		for tool in [game.Tool.HOE,game.Tool.SEEDS,game.Tool.WATER]: game.selected_tool=tool; game.use_selected_tool(); wait_ticks(40)
	wait_ticks(700)
	for column in [1,2,3]:
		var center: Vector2=Vector2(game.FARM_ORIGIN)+Vector2(column*48+24,2*48+24)
		walk_to(center-Vector2(0,42),8); game.facing=Vector2.DOWN; game.selected_tool=game.Tool.WATER; game.use_selected_tool()
	wait_ticks(700)
	for column in [1,2,3]:
		var center: Vector2=Vector2(game.FARM_ORIGIN)+Vector2(column*48+24,2*48+24)
		walk_to(center-Vector2(0,42),8); game.facing=Vector2.DOWN; game.selected_tool=game.Tool.HAND; game.use_selected_tool()
	check(game.inventory_item_count("carrot")>=3,"first crop harvested after both waterings")
	note("farm_harvest",{"carrots":game.inventory_item_count("carrot"),"energy":game.energy})
	for _day in 4:
		if failed: finish(); return
		walk_to(Yard.TROUGH,78); game.FarmLifeSystem.interact(game,"life:trough")
		walk_to(Yard.WATER,78); game.FarmLifeSystem.interact(game,"life:water")
		enter_house(); game.sleep_until_morning(); wait_ticks(180); leave_house()
		for animal in Yard.ANIMALS:
			if animal.product not in ["egg","milk"]: continue
			walk_to(animal.position,78); game.FarmLifeSystem.interact(game,"life:animal:"+animal.id)
		enter_house(); walk_to(Vector2(930,390),75); game.CraftingSystem.open(game,"cauldron"); craft("omelet"); game.crafting_open=false; leave_house()
	note("kitchen",{"day":game.day,"omelets":game.inventory_item_count("omelet"),"eggs":game.inventory_item_count("egg"),"milk":game.inventory_item_count("milk")})
	check(game.inventory_item_count("omelet")==4,"four meals cooked from four genuinely cared mornings")
	var tree: Dictionary=game.state.world.tree_nodes[0]
	walk_to(game.TreeSystem.collision_rect(tree).get_center(),70); game.select_hotbar(6)
	note("tree_approach",{"tree":str(tree),"energy":game.energy,"tool":game.selected_tool,"axe":game.inventory_item_count("axe"),"durability":game.state.inventory.durability.axe})
	for _hit in 3:
		var chopped:bool=game.TreeSystem.chop_nearby(game)
		note("tree_hit",{"success":chopped,"message":game.message}); wait_ticks(60)
	check(game.inventory_item_count("log")>0,"log obtained by chopping a real tree")
	enter_cave()
	mine_all("metal")
	passage("deep"); passage("top"); mine_all("metal")
	check(game.inventory_item_count("metal")>=5,"ore gathered from accessible cave veins")
	passage("bottom"); passage("left"); exit_cave()
	walk_to(game.workbench_position,75); game.CraftingSystem.open(game,"workbench")
	craft("plank"); craft("nails"); craft("iron_spear"); game.crafting_open=false
	check(game.InventorySystem.equip(game,"iron_spear"),"spear crafted and equipped without grants")
	restock_food()
	prepared_snapshot=game.SaveSystem.snapshot(game)
	note("preparation",{"hp":game.player_hp,"level":game.player_level,"ore":game.inventory_item_count("metal"),"spear":game.inventory_item_count("iron_spear"),"omelets":game.inventory_item_count("omelet")})
	if failed: finish(); return
	enter_cave(); passage("deep"); passage("right"); passage("bottom"); passage("left"); passage("right"); passage("right")
	for room in Rooms.IDS: check(room in visited,"visited room "+room)
	walk_to(Arena.ALTAR,78); check(preload("res://scripts/systems/cave_boss_arena_system.gd").activate(game),"altar awakened boss")
	boss_fight()
	check(game.CaveBossSystem.index(game)>=0 and not game.enemy_nodes[game.CaveBossSystem.index(game)].alive,"boss defeated through contact attacks")
	check(phases.size()==3,"fight reached all three phases")
	if failed: finish(); return
	for index in range(game.dropped_items.size()-1,-1,-1):
		if game.dropped_items[index].kind=="moon_relic": walk_to(game.dropped_items[index].position,75); game.collect_dropped_item(index)
	walk_to(Arena.CHEST,75)
	for index in game.world_loot_nodes.size():
		if game.world_loot_nodes[index].location==Arena.LOCATION: game.LootContainerSystem.open(game,index)
	check(game.inventory_item_count("moon_relic")==1,"one real relic collected")
	check(game.world_loot_nodes.any(func(container): return container.location==Arena.LOCATION and container.opened),"boss reward chest opened")
	var saved:Dictionary=game.SaveSystem.snapshot(game)
	check(game.FarmLifeSystem.save_active(game),"end-to-end progress saved to isolated slot")
	var restored:=Game.new(); restored.audio_enabled=false; restored._ready()
	check(restored.SaveSystem.load_at(restored,game.FarmLifeSystem.slot_path(1)),"isolated slot loaded")
	check(restored.inventory_item_count("moon_relic")==1 and preload("res://scripts/systems/cave_boss_arena_system.gd").defeated(restored),"victory and relic persist after load")
	check(restored.export_inventory_counts()==saved.counts,"inventory survives disk round trip")
	check(not restored.state.world.cave_boss.active and restored.state.world.cave_boss.projectiles.is_empty(),"no transient attacks restored")
	restored.free(); finish()

## Отмечает проверенное событие вместе с фактическими ресурсами и положением героя.
func note(label: String, detail: Dictionary={}) -> void:
	observations.append({"event":label,"ticks":ticks,"day":game.day,"location":game.current_location,"position":[game.player.x,game.player.y],"hp":game.player_hp,"detail":detail})
	print("E2E: "+label+" "+JSON.stringify(detail))

## Регистрирует нарушение без скрытого исправления состояния или выдачи предметов.
func check(condition: bool, label: String) -> void:
	if not condition: failed=true; note("FAIL",{"reason":label}); push_error(label)

## Продвигает единственный обычный игровой цикл; еда расходуется штатным действием рюкзака.
func step() -> void:
	if failed: return
	game._physics_process(DT); ticks+=1
	if game.current_location not in visited: visited.append(game.current_location)
	if game.player_hp<55 and game.inventory_item_count("omelet")>0:
		if game.consume_item("omelet"): meals_used+=1
	if game.menu_state.defeat_open: check(false,"hero defeated during legitimate route")

## Даёт анимациям, росту и утреннему производству пройти обычные физические тики.
func wait_ticks(count: int) -> void:
	for _tick in count: step()

## Передаёт изменение физической клавиши через настоящий игровой обработчик.
func key(code: Key, pressed: bool) -> void:
	if held.get(code,false)==pressed: return
	held[code]=pressed
	var event:=InputEventKey.new(); event.physical_keycode=code; event.keycode=code; event.pressed=pressed
	game._input(event)

## Ведёт героя по рассчитанной навигации без присваивания положения и без обхода коллизий.
func steer(target: Vector2) -> void:
	var direction: Vector2=target-game.player
	key(KEY_A,direction.x<-2); key(KEY_D,direction.x>2); key(KEY_W,direction.y<-2); key(KEY_S,direction.y>2)

## Отпускает движение перед действием или после смены комнаты.
func stop() -> void:
	for code in [KEY_A,KEY_D,KEY_W,KEY_S]: key(code,false)

## Находит ближайший достижимый подход к предмету по реальным неподвижным препятствиям.
func walk_to(target: Vector2, radius: float) -> void:
	if failed or game.player.distance_to(target)<=radius: return
	var location: String=game.current_location
	var cell_size:=12 if game.BuildingSystem.is_interior(location) else 24
	var grid:=AStarGrid2D.new(); var bounds:Vector2=game.WorldBoundsSystem.size(location)
	grid.region=Rect2i(0,0,ceili(bounds.x/cell_size),ceili(bounds.y/cell_size)); grid.cell_size=Vector2.ONE*cell_size; grid.offset=Vector2.ONE*cell_size*0.5
	grid.diagonal_mode=AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES; grid.update()
	for y in grid.region.size.y:
		for x in grid.region.size.x:
			grid.set_point_solid(Vector2i(x,y),game.NavigationSystem.walkability_reason(game,Vector2(x,y)*cell_size+grid.offset,-1,false)!="walkable")
	var triggers:Array[Vector2]=[]
	for building in game.BuildingSystem.buildings_at(location): triggers.append(game.BuildingSystem.BUILDINGS[building].door)
	if location=="overworld": triggers.append(game.cave_entrance_position)
	if location=="cave": triggers.append(game.cave_exit_position)
	if game.BuildingSystem.is_interior(location): triggers.append(game.BuildingSystem.INTERIORS[location].exit)
	for link in Rooms.passages(location): triggers.append(link.position)
	for trigger in triggers:
		if trigger.distance_to(target)<radius+40: continue
		for y in range(maxi(0,floori((trigger.y-48)/cell_size)),mini(grid.region.size.y,ceili((trigger.y+48)/cell_size)+1)):
			for x in range(maxi(0,floori((trigger.x-48)/cell_size)),mini(grid.region.size.x,ceili((trigger.x+48)/cell_size)+1)):
				if (Vector2(x,y)*cell_size+grid.offset).distance_to(trigger)<48: grid.set_point_solid(Vector2i(x,y),true)
	var start:=Vector2i(game.player/cell_size); grid.set_point_solid(start,false)
	var path:=PackedVector2Array(); var best:=INF
	for y in range(maxi(0,floori((target.y-radius)/cell_size)),mini(grid.region.size.y,ceili((target.y+radius)/cell_size)+1)):
		for x in range(maxi(0,floori((target.x-radius)/cell_size)),mini(grid.region.size.x,ceili((target.x+radius)/cell_size)+1)):
			var id:=Vector2i(x,y); var point:=Vector2(x,y)*cell_size+grid.offset
			if grid.is_point_solid(id) or point.distance_to(target)>maxf(radius,18): continue
			var candidate:=grid.get_point_path(start,id)
			if not candidate.is_empty() and candidate.size()<best: path=candidate; best=candidate.size()
	check(not path.is_empty(),"reachable approach: %s %s"%[location,target])
	var point_index:=0; var replans:=0
	while point_index<path.size() and not failed:
		var point:=path[point_index]
		var count:=0; var fought:=false
		while not failed and game.current_location==location and game.player.distance_to(point)>4 and count<300:
			if defend(): fought=true; break
			steer(point); step(); count+=1
		if game.current_location!=location: break
		if fought:
			var current:=Vector2i(game.player/cell_size); grid.set_point_solid(current,false)
			path=grid.get_point_path(current,Vector2i(path[-1]/cell_size)); point_index=0
			check(not path.is_empty(),"route continues after ordinary combat"); continue
		if count>=300:
			replans+=1; grid.set_point_solid(Vector2i(point/cell_size),true)
			var current:=Vector2i(game.player/cell_size); grid.set_point_solid(current,false)
			path=grid.get_point_path(current,Vector2i(path[-1]/cell_size)); point_index=0
			check(not path.is_empty() and replans<20,"physical route has alternate approach at "+str(game.player))
			continue
		point_index+=1
	stop()

## Отбивается имеющимся оружием от ближайшего противника во время настоящего перемещения.
func defend() -> bool:
	var nearest:=-1; var distance:=300.0
	for index in game.enemy_nodes.size():
		var enemy:Dictionary=game.enemy_nodes[index]
		if enemy.location!=game.current_location or not enemy.alive or enemy.get("cave_boss",false): continue
		var candidate:float=game.player.distance_to(enemy.position)
		if candidate<distance: distance=candidate; nearest=index
	if nearest<0: return false
	var count:=0
	while not failed and game.enemy_nodes[nearest].alive and count<3600:
		var enemy:Dictionary=game.enemy_nodes[nearest]
		var direction:Vector2=enemy.position.direction_to(game.player)
		var reach:=85.0 if game.equipped_weapon=="axe" else 135.0
		var desired:Vector2=enemy.position+direction*reach
		if enemy.get("attack_pending",false):
			if enemy.action_kind in ["shoot","cast"]: desired=enemy.position+direction.rotated(0.2)*reach
			else: desired=enemy.position+direction*170
		steer(desired); game.CombatSystem.attack(game,nearest); step(); count+=1
	stop(); check(not game.enemy_nodes[nearest].alive,"ordinary enemy defeated with actual contacts")
	note("ordinary_combat",{"kind":game.enemy_nodes[nearest].kind,"ticks":count,"meals_used":meals_used})
	return true

## Входит в дом автоматическим триггером настоящей двери.
func enter_house() -> void:
	walk_to(game.BuildingSystem.BUILDINGS.cottage.door,10); check(game.current_location=="cottage_interior","entered home through door")

## Покидает дом через обычный выход с задержкой повторного входа.
func leave_house() -> void:
	walk_to(Vector2(576,545),8); check(game.current_location=="overworld","left home through door")

## Проходит настоящий вход пещеры из деревни.
func enter_cave() -> void:
	walk_to(game.cave_entrance_position,8); check(game.current_location=="cave","entered cave through entrance")

## Возвращается в деревню по реальному выходу входной комнаты.
func exit_cave() -> void:
	walk_to(game.cave_exit_position,8); check(game.current_location=="overworld","left cave through entrance")

## Проходит связанный туннель и проверяет фактическую комнату назначения.
func passage(port: String) -> void:
	if failed: return
	wait_ticks(35)
	var target: String=Rooms.LINKS[game.current_location][port][0]
	walk_to(Rooms.PORTS[port],8); check(game.current_location==target,"passage reached "+target)
	note("room",{"port":port})

## Вырабатывает жилы штатной киркой с расходом прочности и реальными наградами добычи.
func mine_all(kind: String) -> void:
	for index in game.resource_nodes.size():
		var resource:Dictionary=game.resource_nodes[index]
		if resource.location!=game.current_location or resource.kind!=kind: continue
		walk_to(resource.position,78); game.select_hotbar(4)
		while not failed and resource.hits>0: check(game.ResourceSystem.mine(game,index),"legitimate vein mined"); wait_ticks(45)
		note("vein",{"kind":kind,"count":game.inventory_item_count(kind)})

## Изготавливает один рецепт в реально посещённой станции из собранных ингредиентов.
func craft(output: String) -> void:
	for index in game.CraftingSystem.RECIPES.size():
		if game.CraftingSystem.RECIPES[index].output==output:
			check(game.CraftingSystem.craft(game,index),"crafted "+output); return
	check(false,"missing recipe "+output)

## Покупает четыре порции корма за продажу обычной добычи и готовит новый конечный запас еды перед боссом.
func restock_food() -> void:
	if failed: return
	walk_to(game.BuildingSystem.SHOP_STALL_POSITION,75); game.open_shop()
	var feed:=-1; var bones:=-1; var metal:=-1
	for index in game.shop_products.size():
		match game.shop_products[index].kind:
			"animal_feed": feed=index
			"bones": bones=index
			"metal": metal=index
	while game.coins<52 and not failed:
		var product:int=bones if game.inventory_item_count("bones")>0 else metal
		check(game.ShopSystem.sell(game,product),"loot funds real animal feed")
	for _portion in 4: check(game.ShopSystem.buy(game,feed),"four finite feed portions purchased")
	game.shop_open=false
	for _day in 4:
		walk_to(Yard.TROUGH,78); game.FarmLifeSystem.interact(game,"life:trough")
		walk_to(Yard.WATER,78); game.FarmLifeSystem.interact(game,"life:water")
		enter_house(); game.sleep_until_morning(); wait_ticks(180); leave_house()
		for animal in Yard.ANIMALS:
			if animal.product not in ["egg","milk"]: continue
			walk_to(animal.position,78); game.FarmLifeSystem.interact(game,"life:animal:"+animal.id)
		enter_house(); walk_to(Vector2(930,390),75); game.CraftingSystem.open(game,"cauldron"); craft("omelet"); game.crafting_open=false; leave_house()
	note("restocked_food",{"coins":game.coins,"omelets":game.inventory_item_count("omelet"),"day":game.day})

## Сражается копьём, выбирая безопасную позицию относительно текущего замаха босса.
func boss_fight() -> void:
	var index:int=game.CaveBossSystem.index(game)
	var count:=0
	while not failed and game.enemy_nodes[index].alive and count<18000:
		var boss:Dictionary=game.enemy_nodes[index]; var state:Dictionary=game.state.world.cave_boss
		phases[int(state.phase)]=true
		var offset:Vector2=game.player-boss.position
		var direction:=offset.normalized() if offset.length()>0 else Vector2.LEFT
		var desired:Vector2=boss.position+direction*140
		if not state.attack.is_empty():
			var id:String=state.attack.id
			if id=="slam": desired=boss.position+direction*185
			elif id=="pulse": desired=boss.position+direction*70
			else: desired=boss.position+direction.rotated(0.12)*140
		steer(desired)
		var minion:int=game.CaveBossSystem.Minions.nearest(game,game.player,154)
		if minion>=0: game.CaveBossSystem.Minions.attack(game,minion)
		elif game.player.distance_to(boss.position)<=154: game.CombatSystem.attack(game,index)
		step(); count+=1
	stop(); note("boss_fight",{"phases":phases.keys(),"ticks":count,"meals_used":meals_used,"durability":game.state.inventory.durability.iron_spear})

## Сохраняет проверяемый журнал и завершает стенд явным кодом результата.
func finish() -> void:
	var user_saves_unchanged:=true
	for path in original_saves:
		var current:=FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "absent"
		user_saves_unchanged=user_saves_unchanged and current==original_saves[path]
	check(user_saves_unchanged,"original user saves remain unchanged")
	var path:="res://docs/reports/end-to-end-2026-10-12.json"
	var output:=FileAccess.open(path,FileAccess.WRITE)
	output.store_string(JSON.stringify({"passed":not failed,"ticks":ticks,"simulation_seconds":ticks*DT,"visited":visited,"observations":observations,"user_directory":OS.get_user_data_dir(),"user_saves_unchanged":user_saves_unchanged,"inventory":game.export_inventory_counts(),"hp":game.player_hp,"phases":phases.keys(),"meals_used":meals_used},"  ")+"\n")
	if not failed:
		game.SaveSystem.save_at(game,"res://docs/reports/end-to-end-final-save-2026-10-12.json")
		var prep:=FileAccess.open("res://docs/reports/end-to-end-preparation-2026-10-12.json",FileAccess.WRITE)
		prep.store_string(JSON.stringify(prepared_snapshot,"  ")+"\n")
	game.free(); print("END TO END REVIEW: "+("PASS" if not failed else "FAIL")); quit(1 if failed else 0)
