extends RefCounted

const Graph := preload("res://scripts/systems/production_graph_system.gd")
const Plan := preload("res://scripts/systems/production_plan_system.gd")
const Text := preload("res://scripts/systems/production_guide_locale.gd")
const Style := preload("res://scripts/presentation/moon_theme.gd")
const BUTTONS := [Rect2(568,250,28,28),Rect2(664,250,28,28),Rect2(704,250,140,28),Rect2(854,250,198,28),Rect2(568,290,150,28),Rect2(730,290,150,28),Rect2(892,290,160,28),Rect2(1040,332,20,24),Rect2(1040,490,20,24)]
const ROWS := Rect2(568,332,462,162)

## Хранит только временный выбор панели и один результат, не расширяя игровые сохранения.
static func state(game: Node) -> Dictionary:
	if not game.has_meta("production_guide"): game.set_meta("production_guide",{"batches":1,"stock":true,"tab":0,"row":0,"choices":{},"navigation":false,"focus":0})
	return game.get_meta("production_guide")

## Перестраивает план только при смене рецепта, запасов или навыков; готовый кадр использует ограниченный кеш.
static func data(game: Node) -> Dictionary:
	var ui:=state(game); var stock:={}
	for kind in game.InventorySystem.ITEM_DATA: stock[kind]=game.inventory_item_count(kind)
	var signature:=hash([game.world_guide_selected,ui.batches,ui.stock,ui.choices,stock,game.talent_levels,game.skill_xp,game.state.player.profile.get("workbench_crafts",game.state.player.craft_count),game.state.world.estate.expansion.get("alchemy",{}).get("xp",0),game.LocaleSystem.current])
	var cache:Dictionary=game.get_meta("production_guide_cache",{})
	if cache.get("signature",-1)==signature: return cache
	var graph:Dictionary=game.get_meta("production_guide_graph",{})
	if graph.get("locale","")!=game.LocaleSystem.current:
		graph=Graph.catalog(game); graph.locale=game.LocaleSystem.current; game.set_meta("production_guide_graph",graph)
	var plan:=Plan.plan(graph.recipes,game.world_guide_selected,stock if ui.stock else {},ui.batches,ui.choices,Graph.options(game))
	cache={"signature":signature,"graph":graph,"plan":plan,"rowsets":{}}; game.set_meta("production_guide_cache",cache); return cache

## Даёт варианты и основного результата, и побочного продукта из того же графа.
static func variants(recipes: Array, kind: String, primary_only: bool=false) -> Array[int]:
	var result:Array[int]=[]
	for index in recipes.size():
		if recipes[index].output==kind or (not primary_only and recipes[index].get("byproducts",{}).has(kind)): result.append(index)
	return result

## Формирует строки выбранного раздела, оставляя подробные источники доступными прокрутке.
static func rows(game: Node, cached: Dictionary={}) -> Array:
	var value:Dictionary=data(game) if cached.is_empty() else cached
	var ui:=state(game); var result:Array=[]; var key:=str(ui.tab)
	if value.rowsets.has(key): return value.rowsets[key]
	if ui.tab==1:
		for step in value.plan.steps:
			var recipe:Dictionary=value.graph.recipes[step.index]
			var text:String=game.inventory_item_name(recipe.output)+" ×"+str(step.count)
			var detail:String=game.CraftingSystem.station_name(game,recipe.station)+" • "+Text.word(game,"level",[recipe.level])
			if recipe.public_kitchen: detail=Text.word(game,"kitchen_route",[recipe.level])
			result.append({"title":text,"detail":detail,"step":step})
			for kind in recipe.inputs:
				var amount:int=game.CraftingSystem.material_cost(game,game.CraftingSystem.RECIPES[step.index],kind)
				result.append({"title":"← "+game.inventory_item_name(kind)+" ×"+str(amount),"detail":"","step":step})
			for requirement in requirements(game,recipe): result.append({"title":requirement,"detail":"","step":step})
	else:
		for kind in value.plan.missing:
			var title:String=game.inventory_item_name(kind)+" ×"+str(value.plan.missing[kind])
			if ui.tab==0: result.append({"title":title,"detail":""}); continue
			var sources:Array=value.graph.sources.get(kind,[])
			if sources.is_empty(): result.append({"title":title,"detail":Text.word(game,"unknown")})
			for source in sources: result.append({"title":title,"detail":Text.source_text(game,source)})
	value.rowsets[key]=result; return result

## Показывает реальные ограничения таланта, изучения, ранга и лаборатории без открытия знаний при чтении.
static func requirements(game: Node, recipe: Dictionary) -> Array[String]:
	var result:Array[String]=[]; var talents:Array=recipe.get("talents",[]).duplicate()
	if recipe.has("talent"): talents.append(recipe.talent)
	for talent in talents: result.append(game.TalentSystem.word(game,talent))
	if recipe.has("study_kind"): result.append(game.LocaleSystem.ui("study_blueprint_need",[game.inventory_item_name(recipe.study_kind)]))
	if recipe.has("alchemy_rank"):
		var xp:int=int(game.state.world.estate.expansion.get("alchemy",{}).get("xp",0)); var rank:=1
		for index in game.CraftingSystem.Alchemy.RANK_XP.size():
			if xp>=game.CraftingSystem.Alchemy.RANK_XP[index]: rank=index+1
		result.append(game.LocaleSystem.ui("alchemy_rank_need",[recipe.alchemy_rank,rank]))
	if recipe.get("laboratory",false): result.append(game.LocaleSystem.ui("alchemy_lab_need"))
	return result

## Рисует подробности в прежней правой колонке без крупных декоративных изображений.
static func draw(game: Node) -> void:
	var value:=data(game); var ui:=state(game); var recipe:Dictionary=value.graph.recipes[game.world_guide_selected]
	Style.panel(game,Rect2(548,174,522,392),Style.INSET)
	game.draw_item_icon(recipe.output,Rect2(568,188,52,52))
	Style.text(game,Rect2(628,190,424,28),game.inventory_item_name(recipe.output),16,Style.TEXT)
	var station:String=game.CraftingSystem.station_name(game,recipe.station)+" • "+Text.word(game,"level",[recipe.level])
	if recipe.public_kitchen: station=Text.word(game,"kitchen_route",[recipe.level])
	station+=" • "+game.LocaleSystem.ui("guide_recipe_open" if game.TalentSystem.recipe_unlocked(game,recipe) else "guide_recipe_locked")
	if recipe.station=="alchemy": station+=" • "+preload("res://scripts/systems/alchemy_learning_system.gd").status(game,recipe)
	Style.text(game,Rect2(628,222,424,20),station,11,Style.MUTED)
	var options:=variants(value.graph.recipes,recipe.output,true)
	var records:=rows(game,value); ui.row=clampi(ui.row,0,maxi(0,records.size()-6))
	var labels:=["−","+",Text.word(game,"stock"),Text.word(game,"variant",[options.find(game.world_guide_selected)+1,options.size()]),Text.word(game,"raw"),Text.word(game,"steps"),Text.word(game,"sources"),"↑","↓"]
	for index in BUTTONS.size():
		var selected:bool=(index==2 and ui.stock) or (index>=4 and index<=6 and ui.tab==index-4) or (ui.navigation and ui.focus==index)
		var enabled:bool=(index!=0 or ui.batches>1) and (index!=1 or ui.batches<99) and (index!=3 or options.size()>1) and (index!=7 or ui.row>0) and (index!=8 or ui.row<maxi(0,records.size()-6))
		Style.button(game,BUTTONS[index],labels[index],selected,enabled)
	Style.text(game,Rect2(597,250,66,28),str(ui.batches),12,Style.TEXT,HORIZONTAL_ALIGNMENT_CENTER)
	for offset in 6:
		var index:int=int(ui.row)+offset
		if index>=records.size(): break
		var row:Dictionary=records[index]; var rect:=Rect2(ROWS.position+Vector2(0,offset*27),Vector2(462,25))
		Style.text(game,Rect2(rect.position,Vector2(462,13)),row.title,11,Style.TEXT)
		if not row.detail.is_empty(): Style.text(game,Rect2(rect.position+Vector2(0,13),Vector2(462,12)),row.detail,9,Style.MUTED)
	if records.is_empty(): Style.text(game,Rect2(568,352,462,40),Text.word(game,"empty"),13,Style.ACCENT)
	var footer:String=Text.word(game,"limit") if value.plan.truncated else (Text.word(game,"partial") if not value.plan.warnings.is_empty() else Text.word(game,"batch",[ui.batches])+" • ×"+str(value.plan.output_count))
	Style.text(game,Rect2(568,516,484,18),footer,10,Style.MUTED)
	Style.text(game,Rect2(568,542,484,18),Text.word(game,"note"),10,Style.MUTED)

## Переключает вариант корневого изделия по полному списку реальных рецептов.
static func cycle_root(game: Node) -> void:
	var recipes:Array=data(game).graph.recipes; var current:int=game.world_guide_selected
	var options:=variants(recipes,recipes[current].output,true)
	game.world_guide_selected=options[posmod(options.find(current)+1,options.size())]; state(game).row=0

## Меняет способ получения выбранного вложенного ингредиента вместо копирования цепочки в интерфейс.
static func cycle_route(game: Node, index: int=-1) -> void:
	var ui:=state(game); var records:=rows(game)
	if ui.tab!=1 or records.is_empty(): cycle_root(game); return
	var row:Dictionary=records[clampi(int(ui.row) if index<0 else index,0,records.size()-1)]; var step:Dictionary=row.step
	if step.target==data(game).graph.recipes[game.world_guide_selected].output: cycle_root(game); return
	var options:=variants(data(game).graph.recipes,step.target)
	ui.choices[step.target]=options[posmod(options.find(int(step.index))+1,options.size())]

## Выполняет одно действие общей кнопки и сбрасывает прокрутку при смене раздела.
static func activate(game: Node, index: int) -> void:
	var ui:=state(game)
	if index in [0,1]: ui.batches=clampi(int(ui.batches)+(-1 if index==0 else 1),1,99)
	elif index==2: ui.stock=not ui.stock
	elif index==3: cycle_root(game)
	elif index in [4,5,6]: ui.tab=index-4; ui.row=0
	elif index in [7,8]: ui.row=maxi(0,int(ui.row)+(-1 if index==7 else 1))
	game.queue_redraw()

## Обрабатывает кнопки и строки шагов одинаково мышью и касанием.
static func handle_pointer(game: Node, point: Vector2) -> bool:
	for index in BUTTONS.size():
		if BUTTONS[index].has_point(point): activate(game,index); return true
	if ROWS.has_point(point) and state(game).tab==1:
		cycle_route(game,int(state(game).row)+int((point.y-ROWS.position.y)/27)); game.queue_redraw(); return true
	return false

## Прокручивает правую часть построчно, сохраняя левый выбор рецепта.
static func scroll(game: Node, amount: int) -> void:
	state(game).row=maxi(0,int(state(game).row)+amount); game.queue_redraw()

## Разделяет построчное колесо правого плана и левого каталога, оставляя остальные окна прежнему маршрутизатору.
static func handle_wheel(game: Node, event: InputEventMouseButton) -> bool:
	if not game.world_map_open or game.world_guide_page!=4: return false
	var direction:= -1 if event.button_index==MOUSE_BUTTON_WHEEL_UP else 1
	if event.position.x>=548: scroll(game,direction)
	else: game.WorldMapSystem.move_selection(game,direction)
	return true

## Даёт клавиатуре и геймпаду доступ к партиям, разделам, вариантам и прокрутке плана.
static func handle_input(game: Node, event: InputEvent) -> bool:
	if game.world_guide_page!=4: return false
	var ui:=state(game)
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode==KEY_G: activate(game,4+posmod(int(ui.tab)+1,3))
		elif event.keycode in [KEY_EQUAL,KEY_KP_ADD]: activate(game,1)
		elif event.keycode in [KEY_MINUS,KEY_KP_SUBTRACT]: activate(game,0)
		elif event.keycode==KEY_R: activate(game,2)
		elif event.keycode in [KEY_COMMA,KEY_PERIOD]: scroll(game,-1 if event.keycode==KEY_COMMA else 1)
		elif event.keycode==KEY_ENTER: cycle_route(game)
		else: return false
		return true
	if event is InputEventJoypadButton and event.pressed:
		if event.button_index==JOY_BUTTON_Y: ui.navigation=not ui.navigation; return true
		if not ui.navigation: return false
		if event.button_index in [JOY_BUTTON_DPAD_LEFT,JOY_BUTTON_DPAD_RIGHT]: ui.focus=posmod(int(ui.focus)+(-1 if event.button_index==JOY_BUTTON_DPAD_LEFT else 1),9)
		elif event.button_index in [JOY_BUTTON_DPAD_UP,JOY_BUTTON_DPAD_DOWN]: scroll(game,-1 if event.button_index==JOY_BUTTON_DPAD_UP else 1)
		elif event.button_index==JOY_BUTTON_A: activate(game,int(ui.focus))
		elif event.button_index==JOY_BUTTON_X: cycle_route(game)
		else: return false
		game.queue_redraw(); return true
	return false
