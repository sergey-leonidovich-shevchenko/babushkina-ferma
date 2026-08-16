extends RefCounted

const DROP_SIZE := Vector2(44, 44)


## Возвращает верхний видимый объект под экранным курсором или пустой словарь над интерфейсом.
static func hovered_object(game: Node, screen_point: Vector2) -> Dictionary:
	if pointer_over_debug_ui(game, screen_point): return {}
	var world_point := screen_point + Vector2(game.camera_offset)
	var best: Dictionary = {}
	for candidate in candidates(game):
		var bounds: Rect2 = candidate.bounds
		if not bounds.has_point(world_point): continue
		if best.is_empty() or int(candidate.priority) > int(best.priority) or (int(candidate.priority) == int(best.priority) and bounds.get_area() < (best.bounds as Rect2).get_area()):
			best = candidate
	return best


## Не позволяет инспектору выбирать мир сквозь основную, миссионную или модальную debug-панель.
static func pointer_over_debug_ui(game: Node, screen_point: Vector2) -> bool:
	if game.DebugOverlaySystem.PANEL.has_point(screen_point): return true
	var state: Dictionary = game.get_meta(game.DebugOverlaySystem.META_KEY, {})
	if not String(state.get("mission_details", "")).is_empty() or bool(state.get("mission_completion", {}).get("open", false)): return true
	if game.DebugMissionSystem.HEADER.has_point(screen_point): return true
	return bool(state.get("missions_expanded", false)) and game.DebugMissionSystem.PANEL.has_point(screen_point)


## Собирает единый каталог текущих runtime-объектов без изменения игрового состояния.
static func candidates(game: Node) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	append_buildings(game, result); append_world_props(game, result); append_trees(game, result); append_forage(game, result)
	append_resources(game, result); append_containers(game, result); append_drops(game, result); append_hazards(game, result)
	append_enemies(game, result); append_wildlife(game, result); append_npcs(game, result); append_companions(game, result); append_farm_life(game,result); append_world_plots(game, result); append_fences(game,result)
	append_player(game, result)
	return result


## Добавляет животных, кормушку, музей, тайники и установленную мебель из общего визуального профиля.
static func append_farm_life(game:Node,result:Array[Dictionary])->void:
	var life:Dictionary=game.FarmLifeSystem.state(game)
	if game.current_location=="overworld" and game.state.world.estate.level>=3:
		for animal in game.FarmLifeSystem.ANIMALS:
			var kind:String=String(animal.id); var position:Vector2=Vector2(animal.position); var memory:Dictionary=life.animals.get(kind,{})
			add(result,"farm_animal:%s"%kind,"ФЕРМА",String(animal.name),position,game.FarmLifeVisualSystem.visual_rect(kind,position),86,rect_description(game.FarmLifeVisualSystem.collision_rect(kind,position)),"накормлено" if int(memory.get("fed_day",0))==game.day else "ждёт кормления",["продукт %s"%animal.product,"привязанность %d"%int(memory.get("bond",0)),"профиль %s"%str(game.FarmLifeVisualSystem.profile(kind).visual)])
		var trough:Vector2=game.FarmLifeSystem.TROUGH_POSITION
		add(result,"farm:trough","ФЕРМА","Кормушка",trough,game.FarmLifeVisualSystem.visual_rect("trough",trough),76,rect_description(game.FarmLifeVisualSystem.collision_rect("trough",trough)),"доступна",["профиль 96×72","кормит всех животных"])
	if game.current_location=="cottage_interior":
		for index in life.furniture.size():
			var furniture:Dictionary=life.furniture[index]; var kind:String=String(furniture.kind); var position:Vector2=Vector2(furniture.position)
			add(result,"furniture:%d:%s"%[index,kind],"МЕБЕЛЬ",game.inventory_item_name(kind),position,game.FarmLifeVisualSystem.visual_rect(kind,position),74,rect_description(game.FarmLifeVisualSystem.collision_rect(kind,position)),"установлена",["item id %s"%kind,"профиль %s"%str(game.FarmLifeVisualSystem.profile(kind).visual)])
	if game.current_location=="guild_interior":
		var museum:Vector2=Vector2(780,270); add(result,"farm:museum","МУЗЕЙ","Витрина музея",museum,game.FarmLifeVisualSystem.visual_rect("museum",museum),73,rect_description(game.FarmLifeVisualSystem.collision_rect("museum",museum)),"доступна",["экспонатов %d/%d"%[life.museum.size(),game.FarmLifeSystem.MUSEUM_ITEMS.size()]])
	if game.FarmLifeSystem.SECRETS.has(game.current_location):
		var secret:Dictionary=game.FarmLifeSystem.SECRETS[game.current_location]; var position:Vector2=Vector2(secret.position)
		add(result,"farm:secret:%s"%game.current_location,"ТАЙНА","Скрытый механизм",position,game.FarmLifeVisualSystem.visual_rect("secret",position),72,rect_description(game.FarmLifeVisualSystem.collision_rect("secret",position)),"разгадан" if bool(life.secrets.get(game.current_location,false)) else "не разгадан",["награда %s"%secret.reward])


## Добавляет построенные игроком секции и калитки с материалом, клетками и фактической коллизией.
static func append_fences(game: Node, result: Array[Dictionary]) -> void:
	if game.current_location=="overworld":
		var static_rects:Array[Rect2]=game.BuildingSystem.farm_fence_rects()
		for index in static_rects.size():
			var rect:=static_rects[index]; add(result,"farm_fence:%d"%index,"ОГРАДА","Фермерский забор",rect.get_center(),rect,57,"сетка 24×24 · твёрдая","постоянная",["span %s"%str(game.BuildingSystem.FARM_FENCE_SPANS[index]),"профиль старой усадьбы"])
		var gates:Array[Rect2]=game.BuildingSystem.farm_gate_rects()
		for index in gates.size():
			var rect:=gates[index]; add(result,"farm_gate:%d"%index,"ОГРАДА","Открытая калитка фермы",rect.get_center(),rect,56,"нет · проход","открыта",["span %s"%str(game.BuildingSystem.FARM_GATE_SPANS[index]),"верхняя" if index==0 else "рядом с бабушкой"])
	var values: Array=game.FenceSystem.structures(game)
	for index in values.size():
		var structure: Dictionary=values[index]
		if String(structure.get("location",""))!=game.current_location: continue
		var center: Vector2=game.FenceSystem.structure_center(structure); var size:Vector2=game.WorldVisualProfileSystem.visual_size("fence_gate" if structure.kind=="gate" else "fence_section"); var cells: Array[Vector2i]=game.FenceSystem.occupied_cells(structure)
		add(result,"player_fence:%d"%index,"ОГРАДА","Калитка" if structure.kind=="gate" else "Секция забора",center,centered_bounds(center,size),58,"нет · открыта" if structure.kind=="gate" and structure.open else "клетки 24×24 · твёрдая","открыта" if structure.get("open",false) else "закрыта",[
			"материал %s · style %d"%[game.FenceSystem.style_name(game,int(structure.style)),int(structure.style)],
			"клетки %s · ориентация %d"%[str(cells),int(structure.orientation)],
			"соединение mask %d"%game.FenceSystem.connection_mask(game,structure),
		])


## Добавляет свободные мировые грядки с координатами, культурой, влагой и стадией роста.
static func append_world_plots(game: Node, result: Array[Dictionary]) -> void:
	for key in game.state.world.world_plots:
		var plot: Dictionary = game.state.world.world_plots[key]
		if String(plot.location) != game.current_location: continue
		var rect: Rect2 = game.WorldFarmingSystem.cell_rect(plot.cell)
		add(result, "world_plot:%s" % key, "ГРЯДКА", "Свободный участок", rect.get_center(), rect, 12, "тайл 48×48 · проходимый", "посажено" if plot.planted else "вспахано", [
			"локация %s · клетка %d/%d" % [plot.location,plot.cell.x,plot.cell.y],
			"культура %s · стадия %d/4" % [plot.crop_kind,plot.stage],
			"рост %.1f/%.1f · полив %s" % [plot.growth,game.GROWTH_DURATION,str(plot.watered)],
		])


## Добавляет один нормализованный объект с общей геометрией, состоянием и техническими строками.
static func add(result: Array[Dictionary], id: String, category: String, name: String, position: Vector2, bounds: Rect2, priority: int, collision: String, state: String, details: Array[String] = []) -> void:
	result.append({"id":id,"category":category,"name":name,"position":position,"bounds":bounds,"priority":priority,"collision":collision,"state":state,"details":details})


## Добавляет героя с текущими RPG-ресурсами, направлением, движением и радиусом физики.
static func append_player(game: Node, result: Array[Dictionary]) -> void:
	var size: Vector2 = game.DirectionalCharacterSystem.HERO_DRAW_SIZE
	var bounds:Rect2=game.DirectionalCharacterSystem.actor_rect(game.player,size)
	var moving: bool = game.get_movement_direction() != Vector2.ZERO
	add(result, "player", "ГЕРОЙ", String(game.state.player.profile.get("name", "Герой")), game.player, bounds, 120, "круг r%.0f · твёрдый" % game.PLAYER_RADIUS, "жив · %s" % ("идёт" if moving else "стоит"), [
		"HP %d/%d · MP %d/%d · EN %d/%d" % [game.player_hp,game.player_max_hp,game.player_mana,game.player_max_mana,game.energy,game.SkillSystem.max_stamina(game)],
		"ур. %d · XP %d · очков %d" % [game.player_level,game.player_xp,game.skill_points],
		"направление %.2f / %.2f" % [game.facing.x,game.facing.y],
		"оружие %s · инструмент %s" % [game.equipped_weapon,str(game.selected_tool)],
	])


## Добавляет внешние здания по полному рисунку и показывает отдельный прямоугольник коллизии.
static func append_buildings(game: Node, result: Array[Dictionary]) -> void:
	for building_id in game.BuildingSystem.buildings_at(game.current_location):
		var data: Dictionary = game.BuildingSystem.BUILDINGS[building_id]
		var collision: Rect2=game.BuildingSystem.collision_rect(building_id); var profile:Dictionary=game.BuildingVisualSystem.profile(building_id)
		var names := {"cottage":"Дом бабушки","shop_house":"Сельская лавка","guild_hall":"Гильдия","forge":"Кузница","chapel":"Часовня","prison":"Тюрьма","wizard_tower":"Башня волшебника","moon_castle":"Лунный замок"}
		var unlocked: bool = game.BuildingSystem.can_enter(game, building_id)
		add(result, "building:%s" % building_id, "ЗДАНИЕ", names.get(building_id, building_id), data.door, game.BuildingSystem.destination_rect(building_id), 20, rect_description(collision), "открыто" if unlocked else "закрыто", [
			"дверь %.0f / %.0f · проём %.0f×%.0f" % [data.door.x,data.door.y,Vector2(profile.door_size).x,Vector2(profile.door_size).y],
			"фасад %.0f×%.0f · фундамент %.0f×%.0f" % [Vector2(profile.visual_size).x,Vector2(profile.visual_size).y,Vector2(profile.foundation_size).x,Vector2(profile.foundation_size).y],
			"интерьер %s" % data.interior,
			"условие %s" % ("нет" if String(data.unlock).is_empty() else String(data.unlock)),
		])
	if not game.BuildingSystem.is_interior(game.current_location): return
	for index in game.InteriorVisualSystem.props(game.current_location).size():
		var prop: Dictionary = game.InteriorVisualSystem.props(game.current_location)[index]; var kind := String(prop.kind); var position := Vector2(prop.position); var rect: Rect2 = game.InteriorVisualSystem.collision_rect(kind,position); var visual: Rect2 = game.InteriorVisualSystem.destination_rect(kind,position)
		add(result, "interior_prop:%d:%s" % [index,kind], "ИНТЕРЬЕР", game.LocaleSystem.entity(kind), position, visual, 16, rect_description(rect), "непроходимо", ["комната %s" % game.current_location,"рисунок %.0f×%.0f" % [visual.size.x,visual.size.y]])


## Добавляет деревья всех стадий по фактической кроне, включая здоровье и таймер отрастания.
static func append_trees(game: Node, result: Array[Dictionary]) -> void:
	if game.current_location != "overworld": return
	for index in game.state.world.tree_nodes.size():
		var tree: Dictionary = game.state.world.tree_nodes[index]; var stage := int(tree.stage)
		var bounds:Rect2=game.TreeSystem.destination_rect(tree); var collision:Rect2=game.TreeSystem.collision_rect(tree)
		add(result, String(tree.get("id", "tree_%d" % index)), "ДЕРЕВО", "Лесное дерево", tree.position, bounds, 34, rect_description(collision) if game.TreeSystem.is_solid(tree) else "нет", "стадия %d/3" % stage, [
			"здоровье %d/%d" % [tree.health,game.TreeSystem.MAX_HEALTH],
			"отрастание %.1f/%.1f сек" % [tree.regrow_timer,game.TreeSystem.REGROW_DURATION],
			"прогресс %d%%" % roundi(game.TreeSystem.regrow_progress(tree) * 100.0),
		])


## Добавляет собираемые растения и показывает готовность, урожай и время повторного роста.
static func append_forage(game: Node, result: Array[Dictionary]) -> void:
	for index in game.food_nodes.size():
		var node: Dictionary = game.food_nodes[index]
		if String(node.get("location", "overworld")) != game.current_location: continue
		var data: Dictionary = game.ForageSystem.TYPES[node.kind]; var bounds := forage_bounds(game, node)
		var orchard_stage: int = game.OrchardSystem.stage(node) if game.OrchardSystem.handles(node.kind) else -1
		var collision:Rect2=game.OrchardSystem.collision_rect(node.position,orchard_stage) if orchard_stage>=0 else game.ForageSystem.collision_rect(node)
		add(result, "forage:%d:%s" % [index,node.kind], "СБОР", game.LocaleSystem.entity(node.kind), node.position, bounds, 55, rect_description(collision), "готово" if game.ForageSystem.is_collectable(game,node) else ("зимний покой" if node.active else "растёт"), [
			"урожай %d · продажа %d" % [data.yield,data.sell],
			"цикл %s · осталось %s" % [game.ForageSystem.duration_text(data.growth_minutes),game.ForageSystem.remaining_text(game,node)],
			"стадия %s" % ("%d/3 · %d%%" % [orchard_stage,roundi(game.OrchardSystem.growth_progress(game,node,data)*100.0)] if orchard_stage >= 0 else "нет"),
			"плодоношение %s" % ("%d%%" % roundi(game.OrchardSystem.fruit_progress(game,node,data)*100.0) if orchard_stage == 3 else "после взросления"),
			"ready_at %.1f · active %s" % [node.ready_at,str(node.active)],
		])


## Добавляет жилы и камни с оставшимися ударами и выдаваемым предметом.
static func append_resources(game: Node, result: Array[Dictionary]) -> void:
	for index in game.resource_nodes.size():
		var node: Dictionary = game.resource_nodes[index]
		if node.location != game.current_location or int(node.hits) <= 0: continue
		var name: String = game.ResourceSystem.RESOURCE_NAMES.get(node.kind, node.kind)
		var bounds:Rect2=game.ResourceSystem.destination_rect(node); var collision:Rect2=game.ResourceSystem.collision_rect(node)
		add(result, "resource:%d:%s" % [index,node.kind], "РЕСУРС", name, node.position, bounds, 70, rect_description(collision), "доступен", ["ударов осталось %d" % node.hits,"добыча %s" % game.inventory_item_name(node.kind)])


## Добавляет закрытые и уже опустошённые мировые контейнеры с точным содержимым.
static func append_containers(game: Node, result: Array[Dictionary]) -> void:
	for index in game.world_loot_nodes.size():
		var node: Dictionary = game.world_loot_nodes[index]
		if node.location != game.current_location: continue
		var bounds:Rect2=game.WorldLootRenderer.visual_rect(node.kind,node.position); var collision:Rect2=game.WorldLootRenderer.collision_rect(node.kind,node.position)
		add(result, "container:%s" % node.get("id",index), "КОНТЕЙНЕР", game.LocaleSystem.entity(node.kind), node.position, bounds, 75, rect_description(collision), "открыт и пуст" if node.opened else "закрыт", [
			"runtime index %d" % index,
			"содержимое %s" % dictionary_text(node.contents),
			"seed мира %d" % game.world_loot_seed,
		])


## Добавляет лежащие предметы, их количество и читаемое имя инвентарного каталога.
static func append_drops(game: Node, result: Array[Dictionary]) -> void:
	for index in game.dropped_items.size():
		var item: Dictionary = game.dropped_items[index]
		add(result, "drop:%d:%s" % [index,item.kind], "ДОБЫЧА", game.inventory_item_name(item.kind), item.position, centered_bounds(item.position,DROP_SIZE), 95, "нет · можно подобрать", "лежит в мире", ["количество %d" % item.count,"item id %s" % item.kind])


## Добавляет статичные опасные растения с уровнем, уроном, режимом и cooldown.
static func append_hazards(game: Node, result: Array[Dictionary]) -> void:
	for index in game.hazard_nodes.size():
		var node: Dictionary = game.hazard_nodes[index]
		if node.location != game.current_location: continue
		var data: Dictionary = game.EnvironmentHazardSystem.TYPES[node.kind]
		var size:Vector2=game.CreatureVisualProfileSystem.hazard_size(node.kind)
		add(result, "hazard:%d:%s" % [index,node.kind], "ОПАСНОСТЬ", game.LocaleSystem.entity(node.kind), node.position, game.CreatureVisualProfileSystem.actor_rect(node.position,size), 82, "круг r30 · твёрдый", "активна", [
			"ур. %d · урон %d" % [node.level,game.EnvironmentHazardSystem.damage(node.kind,node.level)],
			"режим %s · радиус %.0f" % [data.mode,data.range],
			"cooldown %.2f · interval %.2f" % [node.cooldown,data.interval],
		])


## Добавляет обычного слизня и всех data-driven противников с полным состоянием боя и AI.
static func append_enemies(game: Node, result: Array[Dictionary]) -> void:
	if game.current_location == "overworld" and (game.slime_alive or game.AnimationSystem.slime_is_visible(game)):
		add(result, "enemy:legacy_slime", "ВРАГ", game.LocaleSystem.entity("slime"), game.slime_position, game.WorldVisualProfileSystem.visual_rect("story_slime",game.slime_position), 90, "круг r28 · твёрдый", game.slime_visual_state, ["HP %d/3" % game.slime_hp,"loot ready %s" % str(game.loot_available)])
	for index in game.enemy_nodes.size():
		var enemy: Dictionary = game.enemy_nodes[index]
		if enemy.location != game.current_location or not game.AnimationSystem.enemy_is_visible(enemy): continue
		var size_value:Vector2=game.CreatureVisualProfileSystem.enemy_size(int(enemy.level))
		var data: Dictionary = game.CombatSystem.TYPES.get(enemy.kind,{})
		add(result, "enemy:%d:%s" % [index,enemy.kind], "ВРАГ", game.LocaleSystem.entity(enemy.kind), enemy.position, game.CreatureVisualProfileSystem.actor_rect(enemy.position,size_value), 92, "круг r30 · твёрдый" if enemy.alive else "нет", String(enemy.get("visual_state","idle")), [
			"HP %d/%d · ур. %d" % [enemy.hp,enemy.max_hp,enemy.level],
			"урон %d · XP %d" % [game.CombatSystem.attack_damage(enemy.kind,enemy.level),game.CombatSystem.xp_reward(enemy.kind,enemy.level)],
			"AI %s · mobile %s" % [enemy.get("action_kind",""),str(data.get("mobile",false))],
			"dir %.2f / %.2f · moving %s" % [enemy.direction.x,enemy.direction.y,str(enemy.get("moving",false))],
			"home %.0f / %.0f" % [enemy.home.x,enemy.home.y],
		])


## Добавляет декоративных и охотничьих животных, включая поведение, здоровье и добычу.
static func append_wildlife(game: Node, result: Array[Dictionary]) -> void:
	for index in game.wildlife_nodes.size():
		var animal: Dictionary = game.wildlife_nodes[index]
		if animal.location != game.current_location: continue
		var data:Dictionary=game.WildlifeSystem.TYPES[animal.kind]; var size:Vector2=game.CreatureVisualProfileSystem.wildlife_size()
		add(result, "wildlife:%d:%s" % [index,animal.kind], "ЖИВОТНОЕ", game.LocaleSystem.entity(animal.kind), animal.position, game.CreatureVisualProfileSystem.actor_rect(animal.position,size), 85, "нет" if data.get("flying",false) else "круг r24", String(animal.get("visual_state","idle")), [
			"HP %d/%d · alive %s" % [animal.hp,data.hp,str(animal.alive)],
			"speed %.0f · panic %.2f" % [data.speed,animal.panic],
			"home %.0f / %.0f · moving %s" % [animal.home.x,animal.home.y,str(animal.get("moving",false))],
			"loot %s" % dictionary_text(data.loot),
		])


## Добавляет бабушку и всех квестовых NPC в их фактических местах дневного расписания.
static func append_npcs(game: Node, result: Array[Dictionary]) -> void:
	for actor_id in game.npc_movement:
		var actor: Dictionary = game.npc_movement[actor_id]
		if String(actor.get("location","")) != game.current_location: continue
		var name: String = game.LocaleSystem.entity("grandmother") if actor_id == "grandmother" else game.QuestSystem.npc_name(actor_id)
		var missions: Array = [] if actor_id == "grandmother" else game.QuestSystem.NPCS.get(actor_id,{}).get("missions",[])
		add(result, "npc:%s" % actor_id, "NPC", name, actor.position, game.DirectionalCharacterSystem.actor_rect(actor.position,game.DirectionalCharacterSystem.NPC_DRAW_SIZE), 100, "нет · диалог", String(actor.get("schedule","без расписания")), [
			"home %.0f / %.0f · %s" % [actor.home.x,actor.home.y,actor.home_location],
			"dir %.2f / %.2f · moving %s" % [actor.direction.x,actor.direction.y,str(actor.moving)],
			"миссии %s" % (", ".join(missions) if not missions.is_empty() else "обучение"),
		])


## Добавляет кандидатов тюрьмы или активных напарников с боевыми параметрами и приказом группы.
static func append_companions(game: Node, result: Array[Dictionary]) -> void:
	for companion_id in game.CompanionSystem.COMPANIONS:
		var visible: bool = game.current_location == "prison_interior" or companion_id in game.active_companions
		if not visible: continue
		var data: Dictionary = game.CompanionSystem.COMPANIONS[companion_id]
		var position: Vector2 = data.position if game.current_location == "prison_interior" else game.companion_positions.get(companion_id,game.player)
		add(result, "companion:%s" % companion_id, "НАПАРНИК", game.CompanionSystem.name(game,companion_id), position, game.DirectionalCharacterSystem.actor_rect(position,game.DirectionalCharacterSystem.COMPANION_DRAW_SIZE), 105, "нет · союзник", "активен" if companion_id in game.active_companions else ("нанят" if companion_id in game.recruited_companions else "заключён"), [
			"урон %d · защита %d · лечение %d" % [data.damage,data.defense,data.heal],
			"лидерство %d · цена %d" % [data.leadership,data.price],
			"приказ %s" % game.state.player.companion_command,
		])


## Добавляет верстак, торговые точки, переход мира и домашний сундук как технические объекты.
static func append_world_props(game: Node, result: Array[Dictionary]) -> void:
	if game.current_location in ["cave","cursed"]:
		for index in game.CAVE_DECORATIONS.size():
			var position:Vector2=game.CAVE_DECORATIONS[index]; var bounds:Rect2=game.CaveVisualSystem.cluster_bounds(position); var collision:Rect2=game.CaveVisualSystem.collision_rect(position)
			add(result,"cave_decor:%d"%index,"ПЕЩЕРА","Валунная кристальная группа",position,bounds,32,rect_description(collision),"декорация",["профиль 120×96","камни 48×48 · кристалл 72×72"])
	if game.current_location == "overworld":
		var village_props:Array=game.VillageLayoutSystem.PROP_PLACEMENTS+game.VillageLayoutSystem.SCENIC_PLACEMENTS
		for index in village_props.size():
			var prop:Dictionary=village_props[index]; var bounds:Rect2=game.VillageLayoutSystem.prop_rect(prop); var collision:Rect2=game.VillageLayoutSystem.prop_collision_rect(prop)
			add(result,"village_prop:%d:%s"%[index,prop.kind],"ДЕКОР","Деревенский объект: %s"%prop.kind,prop.position,bounds,31,rect_description(collision) if collision.has_area() else "нет · декор", "твёрдый" if collision.has_area() else "проходимый",["профиль %s"%game.VillageLayoutSystem.PROP_PROFILES[prop.kind],"ячейка %s"%str(game.VillageLayoutSystem.PROP_CELLS[prop.kind])])
		add(result,"prop:workbench","ОБЪЕКТ","Верстак",game.workbench_position,centered_bounds(game.workbench_position,Vector2(64,44)),45,"прямоугольник 64×44 · твёрдый","доступен")
		add(result,"prop:shop_stall","ТОРГОВЛЯ","Лавка",game.BuildingSystem.SHOP_STALL_POSITION,centered_bounds(game.BuildingSystem.SHOP_STALL_POSITION,Vector2(76,64)),42,"нет · взаимодействие","доступна")
		add(result,"prop:sell_crate","ТОРГОВЛЯ","Ящик продажи",game.BuildingSystem.SELL_CRATE_POSITION,game.BuildingSystem.SELL_CRATE_RECT,48,rect_description(game.BuildingSystem.SELL_CRATE_RECT),"доступен")
	add(result,"prop:world_gate","ПЕРЕХОД","Переход: %s" % game.WorldSystem.name(game.WorldSystem.next_location(game.current_location)),game.world_gate_position,centered_bounds(game.world_gate_position,Vector2(108,108)),38,"триггер","доступен")
	if game.current_location == "cottage_interior" and game.home_chest_owned:
		var stored_total := 0
		for count in game.home_chest_counts.values(): stored_total += int(count)
		var bounds: Rect2 = game.InteriorVisualSystem.destination_rect("home_chest",game.StorageSystem.CHEST_POSITION); var collision: Rect2 = game.InteriorVisualSystem.collision_rect("home_chest",game.StorageSystem.CHEST_POSITION)
		add(result,"prop:home_chest","ХРАНИЛИЩЕ",game.LocaleSystem.entity("home_chest"),game.StorageSystem.CHEST_POSITION,bounds,80,rect_description(collision),"установлен",["предметов %d" % stored_total])


## Возвращает визуальный прямоугольник персонажа с общей точкой опоры у ног.
static func actor_bounds(position: Vector2, size: Vector2) -> Rect2:
	return Rect2(position - Vector2(size.x * 0.5,size.y * 0.68),size)


## Возвращает визуальный прямоугольник объекта, центрированного по мировой позиции.
static func centered_bounds(position: Vector2, size: Vector2) -> Rect2:
	return Rect2(position - size * 0.5,size)


## Возвращает фактическую область дерева или куста из атласа с безопасным размером для отдельных иконок.
static func forage_bounds(game: Node, node: Dictionary) -> Rect2:
	if game.OrchardSystem.handles(node.kind):
		var data:Dictionary=game.ForageSystem.TYPES[node.kind]
		return game.OrchardSystem.destination_rect(node.position,game.OrchardSystem.visual_stage(game,node,data))
	if node.kind in game.FORAGE_SPRITES:
		var layout: Dictionary = game.forage_sprite_layout(node.kind,node.position)
		return layout.destination
	return game.ForageSystem.destination_rect(node)


## Форматирует прямоугольную коллизию без потери координат и размеров.
static func rect_description(rect: Rect2) -> String:
	return "rect %.0f/%.0f %.0f×%.0f" % [rect.position.x,rect.position.y,rect.size.x,rect.size.y]


## Форматирует небольшой словарь добычи или содержимого в одну техническую строку.
static func dictionary_text(value: Dictionary) -> String:
	if value.is_empty(): return "пусто"
	var parts: Array[String] = []
	for key in value: parts.append("%s×%s" % [key,value[key]])
	return ", ".join(parts)
