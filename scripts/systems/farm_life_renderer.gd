extends RefCounted

const FarmLifeVisualSystem:=preload("res://scripts/systems/farm_life_visual_system.gd")
const UiKitSystem:=preload("res://scripts/systems/ui_kit_system.gd")
const ATLAS:=FarmLifeVisualSystem.ATLAS

## Отрисовывает животных фермы, музей, секреты, мебель и боевые снаряды.
static func draw_world(game: Node) -> void:
	var value: Dictionary = game.FarmLifeSystem.state(game)
	if game.current_location == "overworld" and game.state.world.estate.level >= 3:
		for animal in game.FarmLifeSystem.ANIMALS:
			game.FarmLifeVisualSystem.draw(game,animal.id,animal.position); var visual:Rect2=game.FarmLifeVisualSystem.visual_rect(animal.id,animal.position)
			game.draw_ui_string(game.UI_FONT,Vector2(visual.position.x-8,visual.position.y-18),"%s ♥%d" % [animal.name,value.animals[animal.id].bond],HORIZONTAL_ALIGNMENT_CENTER,visual.size.x+16,13,Color("fff0bd"))
		game.FarmLifeVisualSystem.draw(game,"trough",game.FarmLifeSystem.TROUGH_POSITION)
	if game.current_location == "cottage_interior":
		for furniture in value.furniture: game.FarmLifeVisualSystem.draw(game,String(furniture.kind),Vector2(furniture.position))
	if game.current_location == "guild_interior": game.FarmLifeVisualSystem.draw(game,"museum",Vector2(780,270))
	if game.FarmLifeSystem.SECRETS.has(game.current_location):
		var secret: Dictionary = game.FarmLifeSystem.SECRETS[game.current_location]; game.FarmLifeVisualSystem.draw(game,"secret",secret.position)
	for projectile in value.projectiles:
		draw_combat_effect(game, projectile)
	for enemy in game.enemy_nodes:
		if enemy.location==game.current_location and enemy.alive and bool(enemy.get("event_raid_boss",false)): game.FarmLifeVisualSystem.draw(game,"raid_banner",enemy.position+Vector2(0,-76)); game.draw_ui_string(game.UI_FONT,enemy.position+Vector2(-75,-184),"КАПИТАН НАЛЁТЧИКОВ",HORIZONTAL_ALIGNMENT_CENTER,150,13,Color("ffcf75"))


## Рисует различимую траекторию клинка, стрелы, копья, тяжёлого удара или магии.
static func draw_combat_effect(game: Node2D, projectile: Dictionary) -> void:
	var origin: Vector2 = Vector2(projectile.from)
	var target: Vector2 = Vector2(projectile.to)
	var progress: float = float(projectile.progress)
	var direction: Vector2 = origin.direction_to(target)
	var position: Vector2 = origin.lerp(target, progress)
	match String(projectile.kind):
		"bow":
			game.draw_line(position - direction * 18.0, position + direction * 8.0, Color("fff1c2"), 3.0)
			game.draw_circle(position + direction * 8.0, 3.0, Color("e1a653"))
		"staff":
			game.draw_circle(position, 10.0, Color(0.25, 0.86, 1.0, 0.36))
			game.draw_circle(position, 5.0, Color("b9f8ff"))
		"spear":
			game.draw_line(origin + direction * 18.0, origin + direction * (28.0 + sin(progress * PI) * 46.0), Color("dce7e9"), 4.0)
		"heavy":
			game.draw_arc(target, 10.0 + progress * 22.0, 0.0, TAU, 18, Color(1.0, 0.67, 0.28, 1.0 - progress), 4.0)
		_:
			game.draw_arc(origin, 26.0 + progress * 18.0, direction.angle() - 0.8, direction.angle() + 0.8, 14, Color(1.0, 0.88, 0.52, 1.0 - progress * 0.65), 4.0)

## Отрисовывает цель первого дня, кат-сцену, энциклопедию и фоторежим без дублирования календаря HUD.
static func draw_ui(game: Node) -> void:
	# Полноэкранные игровые окна получают весь фокус и не смешиваются с календарём или событиями мира.
	if game.inventory_open or game.shop_open or game.quest_log_open or game.world_map_open or game.skill_menu_open or game.crafting_open or game.storage_open or game.forge_open or game.contract_open: return
	var value: Dictionary = game.FarmLifeSystem.state(game)
	if not String(value.cutscene).is_empty():
		game.draw_rect(Rect2(0,0,1152,648),Color(0,0,0,0.38)); UiKitSystem.draw_modal_panel(game,Rect2(170,245,812,150),false); game.draw_ui_string(game.UI_FONT,Vector2(220,305),"БАБУШКИНА ФЕРМА",HORIZONTAL_ALIGNMENT_CENTER,712,30,Color("4b3020")); game.draw_ui_string(game.UI_FONT,Vector2(220,350),"Новый день — новая история",HORIZONTAL_ALIGNMENT_CENTER,712,20,Color("745033"))
	if bool(value.compendium): draw_compendium(game,value)
	if bool(value.photo_mode): draw_photo_mode(game,value)

## Отрисовывает пять страниц календаря, отношений, музея, энциклопедии и достижений.
static func draw_compendium(game: Node, value: Dictionary) -> void:
	UiKitSystem.draw_modal_panel(game,Rect2(90,55,972,535)); var titles := ["КАЛЕНДАРЬ","ОТНОШЕНИЯ","МУЗЕЙ","ЭНЦИКЛОПЕДИЯ","ДОСТИЖЕНИЯ"]
	var title:=Rect2(326,67,500,58); UiKitSystem.draw_nine_patch(game,"quest_ribbon",title); game.draw_ui_string(game.UI_FONT,title.position+Vector2(28,39),"‹  %s  ›"%titles[int(value.page)],HORIZONTAL_ALIGNMENT_CENTER,title.size.x-56,20,UiKitSystem.COLORS.text_light); var lines: Array[String] = []
	match int(value.page):
		0:
			for day in range(1,29): lines.append("%02d%s" % [day," 🎂" if game.FarmLifeSystem.BIRTHDAYS.has(day) else ""])
		1:
			for npc_id in game.QuestSystem.NPCS: lines.append("%s   %s %d/10" % [game.QuestSystem.npc_name(npc_id),"♥".repeat(game.FarmLifeSystem.hearts(game,npc_id)),game.FarmLifeSystem.hearts(game,npc_id)])
		2:
			for kind in game.FarmLifeSystem.MUSEUM_ITEMS: lines.append(("✓ " if kind in value.museum else "□ ")+game.inventory_item_name(kind))
		3:
			for kind in value.encyclopedia: lines.append("• "+game.inventory_item_name(kind))
		4:
			for achievement in ["first_week","collector","curator","beloved","rancher"]: lines.append(("✓ " if achievement in value.achievements else "□ ")+achievement.capitalize())
	for index in mini(lines.size(),24): game.draw_ui_string(game.UI_FONT,Vector2(155+(index/8)*285,160+(index%8)*45),lines[index],HORIZONTAL_ALIGNMENT_LEFT,265,17,Color("513724"))
	game.draw_ui_string(game.UI_FONT,Vector2(145,535),"V — закрыть • ← → — разделы",HORIZONTAL_ALIGNMENT_CENTER,862,12,Color("765437"))

## Отрисовывает чистый визир фотокамеры с опциональной сеткой третей.
static func draw_photo_mode(game: Node, value: Dictionary) -> void:
	game.draw_rect(Rect2(18,18,1116,612),Color.WHITE,false,3); game.draw_ui_string(game.UI_FONT,Vector2(30,48),"ФОТОРЕЖИМ • P закрыть • G сетка",HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color.WHITE)
	if bool(value.photo_grid):
		for x in [384.0,768.0]: game.draw_line(Vector2(x,18),Vector2(x,630),Color(1,1,1,0.45),1)
		for y in [216.0,432.0]: game.draw_line(Vector2(18,y),Vector2(1134,y),Color(1,1,1,0.45),1)
