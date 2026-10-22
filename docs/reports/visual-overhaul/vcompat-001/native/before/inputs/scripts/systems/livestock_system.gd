extends RefCounted

const Data := preload("res://scripts/systems/livestock_data.gd")
const Visual := preload("res://scripts/systems/farm_life_visual_system.gd")

## Дополняет дневную память старых животных и новых жильцов без сброса дружбы или собранной продукции.
static func initialize(game: Node, value: Dictionary, grant_starter: bool = true) -> void:
	for animal in Data.ANIMALS:
		var memory: Dictionary = value.animals.get(animal.id,{"fed_day":0,"collected_day":0,"bond":0})
		var defaults := {"water_day":int(memory.fed_day),"pet_day":0,"ready":0,"production_day":maxi(int(memory.collected_day),game.day-1),"last_yield_day":int(memory.collected_day)}
		for key in defaults:
			if not memory.has(key): memory[key]=defaults[key]
		memory.bond=clampi(int(memory.bond),0,10); memory.ready=clampi(int(memory.ready),0,Data.STOCK_CAP)
		value.animals[animal.id]=memory
	if grant_starter and not value.get("livestock_started",false):
		value.livestock_started=true
		game.change_inventory_count("animal_feed",4)
	game.set_meta("livestock_clock",0.0)

## Продвигает прогулки только игровым временем и начисляет продукцию за реально обслуженный день ровно один раз.
static func update(game: Node, value: Dictionary, delta: float) -> void:
	game.set_meta("livestock_clock",float(game.get_meta("livestock_clock",0.0))+delta)
	for animal in Data.ANIMALS:
		var memory: Dictionary = value.animals[animal.id]
		var ready_day := int(memory.fed_day)+1
		if int(memory.fed_day)<=0 or ready_day>game.day or ready_day<=int(memory.production_day): continue
		memory.production_day=ready_day
		if int(memory.water_day)!=int(memory.fed_day) or ready_day-int(memory.last_yield_day)<int(animal.interval): continue
		var amount := 2 if int(memory.bond)>=6 or game.state.world.estate.level>=3 else 1
		memory.ready=mini(Data.STOCK_CAP,int(memory.ready)+amount)
		memory.last_yield_day=ready_day

## Возвращает ограниченную позу прогулки; ночь и свежий корм имеют отдельное поведение.
static func pose(game: Node, animal: Dictionary) -> Dictionary:
	var time := float(game.get_meta("livestock_clock",0.0))
	var index := Data.ANIMALS.find(animal)
	var phase := time*0.45+index*1.7
	var rest: bool = game.game_minutes>=1200 or game.game_minutes<360
	var fed: bool = int(game.FarmLifeSystem.state(game).animals[animal.id].fed_day)==game.day
	var frame := 4 if rest else (3 if fed and fmod(time+index,10.0)<2.0 else (1+posmod(floori(time*4.0),2) if fmod(time+index,9.0)<4.0 else 0))
	var position: Vector2 = animal.position
	if frame in [1,2]:
		position += Vector2(sin(phase)*20.0,cos(phase*0.7)*8.0)
	return {"position":position,"frame":frame,"flip":cos(phase)>0.0,"sleeping":rest}

## Находит ближайшую доступную цель ухода вместо постоянного приоритета удалённой кормушки.
static func nearest(game: Node, distance_limit: float) -> String:
	if game.current_location!="overworld": return ""
	var best := distance_limit; var result := ""
	var targets := [{"id":"life:trough","position":Data.TROUGH},{"id":"life:water","position":Data.WATER}]
	for animal in Data.ANIMALS: targets.append({"id":"life:animal:"+animal.id,"position":pose(game,animal).position})
	for target in targets:
		var distance: float = game.player.distance_to(target.position)
		if distance<best: best=distance; result=target.id
	return result

## Выполняет кормление, наполнение воды, сбор накопленной продукции или ежедневную ласку.
static func interact(game: Node, value: Dictionary, interaction: String) -> bool:
	if game.current_location!="overworld": return false
	game.notify_tutorial("farmyard")
	if interaction=="life:trough": return feed(game,value)
	if interaction=="life:water":
		update(game,value,0.0)
		for memory in value.animals.values(): memory.water_day=game.day
		game.message=game.LocaleSystem.text("livestock_watered"); game.notify_tutorial("animal_water"); return true
	var animal := Data.animal(interaction.trim_prefix("life:animal:"))
	if animal.is_empty(): return false
	update(game,value,0.0)
	var memory: Dictionary=value.animals[animal.id]
	if int(memory.ready)>0:
		var amount := int(memory.ready)
		if not game.change_inventory_count(animal.product,amount): return true
		memory.ready=0; memory.collected_day=game.day
		game.message=game.LocaleSystem.text("livestock_collected",[animal.name,game.inventory_item_name(animal.product),amount])
		game.SkillSystem.award_profession_xp(game,"farming",3); game.notify_tutorial("animal_product")
	elif int(memory.pet_day)!=game.day:
		memory.pet_day=game.day; memory.bond=mini(10,int(memory.bond)+1)
		game.message=game.LocaleSystem.text("livestock_petted",[animal.name,memory.bond])+" • "+product_hint(game,animal,memory); game.notify_tutorial("animal_pet")
	else: game.message=game.LocaleSystem.text("livestock_status",[animal.name,status(game,memory)])+" • "+product_hint(game,animal,memory)
	return true

## Объясняет продукт и минимальный интервал без обещания выдачи за день без корма и воды.
static func product_hint(game: Node, animal: Dictionary, memory: Dictionary) -> String:
	var patterns:=["%s ×%d • интервал %d дн.","%s ×%d • interval %d days","%s ×%d • cada %d días","%s ×%d • alle %d Tage","%s ×%d • intervalle %d j","%s ×%d • 间隔%d天"]
	var amount:=2 if int(memory.bond)>=6 or game.state.world.estate.level>=3 else 1
	var index:int=maxi(0,game.LocaleSystem.LOCALES.find(game.LocaleSystem.current))
	return patterns[index]%[game.inventory_item_name(animal.product),amount,animal.interval]

## Кормит двор одной готовой порцией либо тремя пшеницами, не расходуя ничего повторно в этот день.
static func feed(game: Node, value: Dictionary) -> bool:
	if value.animals.values().all(func(memory): return int(memory.fed_day)==game.day):
		game.message=game.LocaleSystem.text("livestock_already_fed"); return true
	var kind := "animal_feed" if game.inventory_item_count("animal_feed")>0 else "wheat"
	var count := 1 if kind=="animal_feed" else 3
	if not game.change_inventory_count(kind,-count): game.message=game.LocaleSystem.text("livestock_need_feed"); return true
	# До перезаписи fed_day сохраняется продукт предыдущего обслуженного дня, даже если утро пропущено.
	update(game,value,0.0)
	for memory in value.animals.values(): memory.fed_day=game.day
	game.message=game.LocaleSystem.text("livestock_fed"); game.notify_tutorial("animal_feed"); return true

## Описывает накопленный продукт, нехватку ухода или ожидание следующего утра.
static func status(game: Node, memory: Dictionary) -> String:
	if int(memory.ready)>0: return game.LocaleSystem.text("livestock_ready",[memory.ready])
	if int(memory.fed_day)!=game.day: return game.LocaleSystem.text("livestock_hungry")
	if int(memory.water_day)!=game.day: return game.LocaleSystem.text("livestock_thirsty")
	return game.LocaleSystem.text("livestock_waiting")

## Проверяет основания животных, построек и оград, сохраняя реальные открытые проходы в загоны.
static func blocks_position(game: Node, position: Vector2, radius: float) -> bool:
	if game.current_location!="overworld" or not Data.YARD_BOUNDS.grow(radius).has_point(position): return false
	for wall in Data.walls():
		if Visual.circle_intersects_rect(position,radius,wall): return true
	for prop in Data.PROPS:
		if Visual.circle_intersects_rect(position,radius,Data.prop_base(prop)): return true
	for animal in Data.ANIMALS:
		var foot: Vector2 = pose(game,animal).position
		if Visual.circle_intersects_rect(position,radius,Data.animal_base(animal,foot)): return true
	return false
