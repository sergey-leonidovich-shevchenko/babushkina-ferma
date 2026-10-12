extends RefCounted

const Data := preload("res://scripts/systems/apiary_data.gd")

## Создаёт пустые места пасеки без бесплатных построек, пчёл и готовой продукции.
static func state(game: Node) -> Dictionary:
	var expansion:Dictionary=game.state.world.estate.expansion
	if not expansion.has("apiary"):
		var hives:Array=[]
		for index in Data.SITES.size(): hives.append({"level":0,"colonized":false,"last_day":game.day,"cycles":0,"stock":{}})
		expansion.apiary={"hives":hives,"wild_days":{}}
	return expansion.apiary

## Сбрасывает временное окно после загрузки, сохраняя целые запасы и оплаченные уровни.
static func restore(game: Node) -> void:
	var value:=state(game)
	for item in value.hives:
		for key in ["level","last_day","cycles"]: item[key]=int(item[key])
		for kind in item.stock: item.stock[kind]=int(item.stock[kind])
	if game.has_meta("apiary_ui"): game.remove_meta("apiary_ui")

## Отвергает неизвестные, дробные и превышающие ёмкость запасы до изменения живой игры.
static func valid(value: Dictionary) -> bool:
	if value.hives.size()!=Data.SITES.size(): return false
	for item in value.hives:
		if float(item.level)!=int(item.level) or int(item.level) not in range(4): return false
		if float(item.last_day)!=int(item.last_day) or item.last_day<1 or float(item.cycles)!=int(item.cycles) or int(item.cycles) not in range(3): return false
		if item.level==0 and (item.colonized or not item.stock.is_empty()): return false
		if not item.colonized and not item.stock.is_empty(): return false
		for kind in item.stock:
			if kind not in ["honeycomb","bees","pollen","propolis"] or float(item.stock[kind])!=int(item.stock[kind]) or item.stock[kind]<0: return false
			if item.stock[kind]>((int(item.level)+1) if kind=="bees" else int(item.level)*6): return false
			if (kind=="pollen" and item.level<2) or (kind=="propolis" and item.level<3): return false
	for id in value.wild_days:
		if id not in ["meadow","forest"] or float(value.wild_days[id])!=int(value.wild_days[id]) or value.wild_days[id]<1: return false
	return true

## Начисляет только новые игровые дни с ограниченным складом без повторного урожая после паузы и загрузки.
static func update(game: Node) -> void:
	if not game.state.world.estate.expansion.has("apiary"): return
	for item in state(game).hives:
		var elapsed:=maxi(0,game.day-int(item.last_day)); item.last_day=maxi(game.day,int(item.last_day))
		if not item.colonized or elapsed==0: continue
		var level:=int(item.level); var limit:=level*6
		item.stock.honeycomb=mini(limit,int(item.stock.get("honeycomb",0))+elapsed*level)
		if level>=2: item.stock.pollen=mini(limit,int(item.stock.get("pollen",0))+elapsed)
		if level>=3: item.stock.propolis=mini(limit,int(item.stock.get("propolis",0))+elapsed)
		var cycles:=int(item.cycles)+elapsed
		item.stock.bees=mini(level+1,int(item.stock.get("bees",0))+cycles/3); item.cycles=posmod(cycles,3)

## Возвращает близкую рабочую сторону пасеки или дикого гнезда без глобального открытия из любой точки.
static func nearest(game: Node, radius: float) -> String:
	var best:=radius; var result:=""
	if game.current_location=="overworld":
		for index in Data.SITES.size():
			var distance:float=game.player.distance_to(Data.SITES[index]+Vector2(0,48))
			if distance<best: best=distance; result="life:apiary:"+str(index)
	for entry in Data.WILD:
		if game.current_location==entry.location:
			var distance:float=game.player.distance_to(entry.position+Vector2(0,48))
			if distance<best: best=distance; result="life:wild_hive:"+entry.id
	return result

## Возвращает тот же физический подход, которым пользуются навигация, подсветка и взаимодействие.
static func position(interaction: String) -> Vector2:
	if interaction.begins_with("life:apiary:"): return Data.SITES[clampi(int(interaction.get_slice(":",2)),0,2)]+Vector2(0,48)
	for entry in Data.WILD:
		if interaction.get_slice(":",2)==entry.id: return entry.position+Vector2(0,48)
	return Vector2.ZERO

## Открывает конкретный улей либо собирает дикое гнездо с трёхдневным восстановлением.
static func interact(game: Node, interaction: String) -> bool:
	if nearest(game,64)!=interaction: return false
	if interaction.begins_with("life:wild_hive:"):
		var id:=interaction.get_slice(":",2); var value:=state(game)
		if game.day<int(value.wild_days.get(id,-3))+3: game.message=game.LocaleSystem.ui("apiary_wild_wait"); return true
		if game.energy<2: game.message=game.LocaleSystem.ui("study_need_energy",[2]); return true
		game.energy-=2; value.wild_days[id]=game.day; game.change_inventory_count("bees",1); game.change_inventory_count("honeycomb",1)
		game.notify_tutorial("apiary_wild"); game.message=game.LocaleSystem.ui("apiary_wild_done"); return true
	game.set_meta("apiary_ui",{"open":true,"selected":int(interaction.get_slice(":",2))}); game.clear_movement_keys(); game.action_held=false; game.attack_held=false; game.CombatSystem.set_blocking(game,false); game.message=""; return true

## Проверяет привязку полноэкранного окна к месту пасеки перед любой расходной операцией.
static func selected(game: Node) -> Dictionary:
	var ui:Dictionary=game.get_meta("apiary_ui",{})
	if not bool(ui.get("open",false)) or game.current_location!="overworld" or game.player.distance_to(Data.SITES[int(ui.selected)]+Vector2(0,48))>64: return {}
	return state(game).hives[int(ui.selected)]

## Списывает полную строительную стоимость атомарно, сохраняя продукцию и население при улучшении.
static func construct(game: Node) -> bool:
	var item:=selected(game)
	if item.is_empty(): return false
	if int(item.level)>=3: game.message=game.LocaleSystem.ui("furnace_max"); return false
	var cost:Dictionary=Data.COSTS[int(item.level)]
	if game.energy<int(cost.energy): game.message=game.LocaleSystem.ui("study_need_energy",[cost.energy]); return false
	if game.coins<int(cost.coins): game.message=game.LocaleSystem.ui("basement_money"); return false
	for kind in cost.inputs:
		if game.inventory_item_count(kind)<int(cost.inputs[kind]): game.message=game.LocaleSystem.ui("basement_materials"); return false
	for kind in cost.inputs: game.change_inventory_count(kind,-int(cost.inputs[kind]))
	game.coins-=int(cost.coins); game.energy-=int(cost.energy); item.level=int(item.level)+1; item.last_day=game.day
	game.notify_tutorial("apiary_build"); game.message=game.LocaleSystem.ui("basement_level",[game.LocaleSystem.ui("apiary_context"),item.level]); game.queue_redraw(); return true

## Заселяет пустой построенный улей одной единицей пчёл, оставляя будущую семью внутри навсегда.
static func populate(game: Node) -> bool:
	var item:=selected(game)
	if item.is_empty() or item.level==0 or item.colonized: return false
	if game.inventory_item_count("bees")<1 or game.energy<1: game.message=game.LocaleSystem.ui("apiary_need_bees"); return false
	game.change_inventory_count("bees",-1); game.energy-=1; item.colonized=true; item.last_day=game.day; item.cycles=0
	game.notify_tutorial("apiary_populate"); game.message=game.LocaleSystem.ui("apiary_population",[game.LocaleSystem.ui("apiary_present"),item.level]); game.queue_redraw(); return true

## Выдаёт все накопленные соты и сырьё один раз, сохраняя рабочую пчелиную семью.
static func harvest(game: Node) -> bool:
	var item:=selected(game)
	if item.is_empty() or item.stock.values().all(func(count): return int(count)==0): return false
	if game.energy<2: game.message=game.LocaleSystem.ui("study_need_energy",[2]); return false
	game.energy-=2
	var labels:Array[String]=[]
	for kind in item.stock:
		game.change_inventory_count(kind,int(item.stock[kind]))
		if int(item.stock[kind])>0: labels.append(game.inventory_item_name(kind)+" ×"+str(item.stock[kind]))
	item.stock.clear(); game.SkillSystem.award_profession_xp(game,"farming",4); game.notify_tutorial("apiary_harvest"); game.message=game.LocaleSystem.ui("apiary_collected",[", ".join(labels)]); game.queue_redraw(); return true

## Делит оплаченные компоненты пополам и возвращает население с накопленным сырьём без дублирования.
static func dismantle(game: Node) -> bool:
	var item:=selected(game)
	if item.is_empty() or item.level==0: return false
	for kind in Data.paid(int(item.level)):
		var amount:int=Data.paid(int(item.level))[kind]; game.change_inventory_count(kind,amount/2)
		game.change_inventory_count(preload("res://scripts/systems/basement_data.gd").debris(kind),amount-amount/2)
	for kind in item.stock: game.change_inventory_count(kind,int(item.stock[kind]))
	if item.colonized: game.change_inventory_count("bees",1)
	item.level=0; item.colonized=false; item.stock={}; item.cycles=0; item.last_day=game.day; game.message=game.LocaleSystem.ui("apiary_empty"); game.queue_redraw(); return true

## Блокирует героя только реальными основаниями построенных ульев и диких гнёзд.
static func blocks(game: Node, point: Vector2, radius: float) -> bool:
	if game.current_location=="overworld":
		for index in Data.SITES.size():
			if state(game).hives[index].level>0 and game.FarmLifeVisualSystem.circle_intersects_rect(point,radius,Data.base(Data.SITES[index])): return true
	for entry in Data.WILD:
		if game.current_location==entry.location and game.FarmLifeVisualSystem.circle_intersects_rect(point,radius,Data.base(entry.position)): return true
	return false
