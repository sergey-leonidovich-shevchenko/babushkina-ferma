extends RefCounted

const Data := preload("res://scripts/systems/research_data.gd")
const STUDY_POINT := Vector2(340,470)
const BENCH_POINT := Vector2(315,480)

## Возвращает сохраняемую память исследованных видов, общую для всех экземпляров предмета.
static func state(game: Node) -> Dictionary:
	var expansion:Dictionary=game.state.world.estate.expansion
	if not expansion.has("research"): expansion.research={"level":1,"known":[],"dismantled":0}
	return expansion.research

## Восстанавливает только канонические знания и допустимый уровень без повторных наград.
static func restore(game: Node) -> void:
	var value:=state(game); value.level=clampi(int(value.get("level",1)),1,3); value.dismantled=maxi(0,int(value.get("dismantled",0)))
	var known:Array=[]
	for kind in value.get("known",[]):
		if not Data.entry(String(kind)).is_empty() and kind not in known: known.append(kind)
	value.known=known

## Определяет два предметных окна механики без подмены обычных рецептов операциями изучения.
static func handles(station: String) -> bool:
	return station in ["study","recycling"]

## Проверяет постоянное знание состава для разборки и дополнительных рецептов.
static func learned(game: Node, kind: String) -> bool:
	return kind in state(game).known

## Проверяет настоящую точку подхода к столу гильдии либо левому верстаку кузницы.
static func at_station(game: Node, station: String) -> bool:
	return (station=="study" and game.current_location=="guild_interior" and game.player.distance_to(STUDY_POINT)<=80) or (station=="recycling" and game.current_location=="forge_interior" and game.player.distance_to(BENCH_POINT)<=80)

## Даёт устойчивые индексы исследуемых предметов для выбора, колеса и клавиатуры.
static func indices(_game: Node) -> Array[int]:
	var result:Array[int]=[]
	for index in Data.ENTRIES.size(): result.append(index)
	return result

## Открывает отдельный каталог, сохраняя обычную паузу предметного окна.
static func open(game: Node, station: String) -> void:
	game.crafting_open=true; game.crafting_station=station; game.crafting_selected=0; game.clear_movement_keys()
	for index in Data.ENTRIES.size():
		if reason(game,Data.ENTRIES[index],station).is_empty(): game.crafting_selected=index; break
	game.notify_tutorial("study_table" if station=="study" else "study_dismantle")

## Запрещает уничтожать надетый предмет или активный инструмент до его снятия.
static func in_use(game: Node, kind: String) -> bool:
	if kind in game.equipment.values(): return true
	var item:Dictionary=game.InventorySystem.data(kind)
	if item.get("equip","")=="hands" and game.equipped_weapon==game.WeaponSystem.weapon_for_item(kind): return true
	return item.has("tool") and game.hotbar_slots[game.selected_hotbar]==kind

## Рассчитывает весь видимый возврат с потерями от износа, не добавляя награды за заточку.
static func parts(game: Node, entry: Dictionary) -> Dictionary:
	var result:Dictionary=entry.parts.duplicate(); var durability:int=game.state.inventory.durability.get(entry.kind,100)
	var factor:=0.5+0.5*clampf(float(durability)/100.0,0,1)
	for kind in result: result[kind]=maxi(1,floori(int(result[kind])*factor))
	return result

## Формирует одинаковые для интерфейса и проверок списки точного расхода или выхода.
static func material_text(game: Node, counts: Dictionary, show_stock: bool=false) -> String:
	var labels:Array[String]=[]
	for kind in counts: labels.append(game.inventory_item_name(kind)+(" %d/%d"%[game.inventory_item_count(kind),counts[kind]] if show_stock else " ×"+str(counts[kind])))
	return ", ".join(labels)

## Объясняет первое недоступное требование до любой мутации денег, энергии или вещей.
static func reason(game: Node, entry: Dictionary, station: String) -> String:
	if not at_station(game,station): return game.LocaleSystem.ui("study_station_need")
	if station=="study":
		if learned(game,entry.kind): return game.LocaleSystem.ui("study_known")
		if int(state(game).level)<int(entry.tier): return game.LocaleSystem.ui("study_level_need",[entry.tier])
		if game.inventory_item_count(entry.kind)<1: return game.LocaleSystem.ui("study_sample_need")
		var cost:Dictionary=Data.COSTS[int(entry.tier)-1]
		if game.coins<int(cost.coins): return game.LocaleSystem.ui("study_need_money",[cost.coins])
		if game.energy<float(cost.energy): return game.LocaleSystem.ui("study_need_energy",[cost.energy])
		for kind in cost.inputs:
			if game.inventory_item_count(kind)<int(cost.inputs[kind]): return game.LocaleSystem.text("needs",[material_text(game,cost.inputs,true)])
	else:
		if not learned(game,entry.kind): return game.LocaleSystem.ui("study_hidden")
		if in_use(game,entry.kind): return game.LocaleSystem.ui("study_unequip")
		if game.inventory_item_count(entry.kind)<int(entry.batch): return game.LocaleSystem.ui("study_batch_need",[entry.batch])
		if game.energy<float(int(entry.tier)*2): return game.LocaleSystem.ui("study_need_energy",[int(entry.tier)*2])
	return ""

## Изучает или разбирает только канонический предмет после полной проверки условий.
static func execute(game: Node, index: int) -> bool:
	if not handles(game.crafting_station) or index<0 or index>=Data.ENTRIES.size(): return false
	var entry:Dictionary=Data.ENTRIES[index]; var why:=reason(game,entry,game.crafting_station)
	if not why.is_empty(): game.message=why; return false
	if game.crafting_station=="study":
		var cost:Dictionary=Data.COSTS[int(entry.tier)-1]; game.coins-=int(cost.coins); game.energy-=float(cost.energy)
		for kind in cost.inputs: game.change_inventory_count(kind,-int(cost.inputs[kind]))
		state(game).known.append(entry.kind); game.award_xp(4*int(entry.tier)); game.notify_tutorial("study_learn")
		game.message=game.LocaleSystem.ui("study_learned",[game.inventory_item_name(entry.kind)])
	else:
		var output:=parts(game,entry); game.change_inventory_count(entry.kind,-int(entry.batch)); game.energy-=float(int(entry.tier)*2)
		for kind in output: game.change_inventory_count(kind,int(output[kind]))
		if game.inventory_item_count(entry.kind)==0:
			if game.state.forge.level(entry.kind)>0: game.state.forge.set_level(entry.kind,0)
			if game.state.inventory.durability.has(entry.kind): game.state.inventory.durability[entry.kind]=100
		state(game).dismantled+=1; game.SkillSystem.award_profession_xp(game,"smithing",2); game.notify_tutorial("study_dismantle")
		game.message=game.LocaleSystem.ui("study_dismantled",[1])
	game.play_sfx("craft"); game.queue_redraw(); return true

## Выполняет ограниченное пакетное действие, не повторяя стоимость уже известного исследования.
static func bulk(game: Node, index: int, requested: int) -> int:
	if game.crafting_station=="study": return 1 if requested>0 and execute(game,index) else 0
	var completed:=0
	for _batch in mini(maxi(requested,0),99):
		if not execute(game,index): break
		completed+=1
	if game.crafting_station=="recycling" and completed>0: game.message=game.LocaleSystem.ui("study_dismantled",[completed])
	return completed

## Возвращает полную цену следующего улучшения из того же источника, что выполняет списание.
static func upgrade_text(game: Node) -> String:
	var value:=state(game)
	if int(value.level)>=3: return game.LocaleSystem.ui("furnace_max")
	var cost:Dictionary=Data.UPGRADES[int(value.level)-1]
	return game.LocaleSystem.ui("furnace_upgrade_cost",[cost.coins,material_text(game,cost.inputs)])

## Атомарно улучшает исследовательский стол до третьего уровня в его настоящей точке.
static func upgrade(game: Node) -> bool:
	var value:=state(game)
	if not at_station(game,"study") or int(value.level)>=3: return false
	var cost:Dictionary=Data.UPGRADES[int(value.level)-1]
	if game.coins<int(cost.coins): game.message=upgrade_text(game); return false
	for kind in cost.inputs:
		if game.inventory_item_count(kind)<int(cost.inputs[kind]): game.message=upgrade_text(game); return false
	game.coins-=int(cost.coins)
	for kind in cost.inputs: game.change_inventory_count(kind,-int(cost.inputs[kind]))
	value.level+=1; game.message=game.LocaleSystem.ui("study_upgraded",[value.level]); game.notify_tutorial("study_upgrade"); game.queue_redraw(); return true

## Обрабатывает выбор, разовое действие, пакетную разборку и улучшение без общей фабрики рецептов.
static func handle_input(game: Node, event: InputEvent) -> void:
	var offset:=0; var accept:=false; var many:=false
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_ESCAPE,KEY_C: game.crafting_open=false
			KEY_UP: offset=-1
			KEY_DOWN: offset=1
			KEY_ENTER,KEY_E: accept=true; many=event.shift_pressed
			KEY_U: if game.crafting_station=="study": upgrade(game)
	elif event is InputEventJoypadButton and event.pressed:
		match event.button_index:
			JOY_BUTTON_B,JOY_BUTTON_Y: game.crafting_open=false
			JOY_BUTTON_DPAD_UP: offset=-1
			JOY_BUTTON_DPAD_DOWN: offset=1
			JOY_BUTTON_A: accept=true
			JOY_BUTTON_X: accept=true; many=true
			JOY_BUTTON_LEFT_STICK: if game.crafting_station=="study": upgrade(game)
	if offset!=0: game.crafting_selected=posmod(game.crafting_selected+offset,Data.ENTRIES.size())
	if accept:
		if many: bulk(game,game.crafting_selected,99)
		else: execute(game,game.crafting_selected)
	game.queue_redraw()

## Проверяет весь каталог знаний и компонентов в момент запуска игры.
static func validation_errors(items: Dictionary) -> Array[String]:
	var errors:Array[String]=[]; var kinds:Array=[]
	for entry in Data.ENTRIES:
		if entry.kind in kinds or not items.has(entry.kind): errors.append("research item: "+entry.kind)
		kinds.append(entry.kind)
		for kind in entry.parts:
			if not items.has(kind) or int(entry.parts[kind])<=0: errors.append("research component: "+kind)
	for recipe in Data.RECIPES:
		if recipe.has("study_kind") and Data.entry(recipe.study_kind).is_empty(): errors.append("research blueprint: "+recipe.id)
	return errors
