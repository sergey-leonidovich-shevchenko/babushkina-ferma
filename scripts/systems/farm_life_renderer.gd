extends RefCounted

const ATLAS := preload("res://assets/game/expansion_pack/expansion_atlas.png")
const CELL := Vector2(128,128)

## Отрисовывает одну ячейку нового прозрачного атласа в мировом прямоугольнике.
static func draw_cell(game: Node, cell: Vector2i, center: Vector2, size: Vector2 = Vector2(82,82)) -> void:
	game.draw_texture_rect_region(ATLAS,Rect2(center-size*0.5,size),Rect2(Vector2(cell)*CELL,CELL))

## Отрисовывает животных фермы, музей, секреты, мебель и боевые снаряды.
static func draw_world(game: Node) -> void:
	var value: Dictionary = game.FarmLifeSystem.state(game)
	if game.current_location == "overworld" and game.state.world.estate.level >= 3:
		for animal in game.FarmLifeSystem.ANIMALS:
			draw_cell(game,animal.cell,animal.position,Vector2(76,76)); game.draw_string(game.UI_FONT,animal.position+Vector2(-45,-47),"%s ♥%d" % [animal.name,value.animals[animal.id].bond],HORIZONTAL_ALIGNMENT_CENTER,90,13,Color("fff0bd"))
		draw_cell(game,Vector2i(3,0),Vector2(445,790),Vector2(88,72))
	if game.current_location == "cottage_interior":
		for furniture in value.furniture: draw_cell(game,game.FarmLifeSystem.FURNITURE.get(furniture.kind,Vector2i.ZERO),Vector2(furniture.position),Vector2(80,80))
	if game.current_location == "guild_interior": draw_cell(game,Vector2i(0,1),Vector2(780,270),Vector2(92,92))
	if game.FarmLifeSystem.SECRETS.has(game.current_location):
		var secret: Dictionary = game.FarmLifeSystem.SECRETS[game.current_location]; draw_cell(game,Vector2i(0,3),secret.position,Vector2(78,78))
	for projectile in value.projectiles:
		var position: Vector2 = Vector2(projectile.from).lerp(Vector2(projectile.to),float(projectile.progress)); game.draw_circle(position,7.0,Color("ffe36e")); game.draw_line(position-Vector2(14,0),position,Color.WHITE,3)
	for enemy in game.enemy_nodes:
		if enemy.location==game.current_location and enemy.alive and bool(enemy.get("event_raid_boss",false)): draw_cell(game,Vector2i(4,3),enemy.position+Vector2(0,-92),Vector2(70,70)); game.draw_string(game.UI_FONT,enemy.position+Vector2(-75,-122),"КАПИТАН НАЛЁТЧИКОВ",HORIZONTAL_ALIGNMENT_CENTER,150,13,Color("ffcf75"))

## Отрисовывает цель первого дня, календарь, репутацию, кат-сцену, энциклопедию и фоторежим.
static func draw_ui(game: Node) -> void:
	var value: Dictionary = game.FarmLifeSystem.state(game)
	if int(value.first_day) < 6:
		game.draw_rect(Rect2(798,104,330,54),Color(0.08,0.12,0.10,0.90)); game.draw_string(game.UI_FONT,Vector2(814,128),"ПЕРВЫЙ ДЕНЬ",HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color("e8bd62")); game.draw_string(game.UI_FONT,Vector2(814,150),game.FarmLifeSystem.first_day_objective(game),HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("fff4cf"))
	var birthday: String = game.FarmLifeSystem.birthday_npc(game); var calendar: String = "День %d • репутация %d" % [game.day,value.reputation]
	if not birthday.is_empty(): calendar += " • 🎂 %s" % game.QuestSystem.npc_name(birthday)
	game.draw_rect(Rect2(14,610,330,26),Color(0.07,0.10,0.08,0.78)); game.draw_string(game.UI_FONT,Vector2(25,629),calendar,HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("fff0bd"))
	if not String(value.cutscene).is_empty():
		game.draw_rect(Rect2(0,0,1152,648),Color(0,0,0,0.38)); game.draw_rect(Rect2(170,245,812,150),Color("39251b")); game.draw_rect(Rect2(178,253,796,134),Color("efdca8")); game.draw_string(game.UI_FONT,Vector2(220,305),"БАБУШКИНА ФЕРМА",HORIZONTAL_ALIGNMENT_CENTER,712,30,Color("4b3020")); game.draw_string(game.UI_FONT,Vector2(220,350),"Новый день — новая история",HORIZONTAL_ALIGNMENT_CENTER,712,20,Color("745033"))
	if bool(value.compendium): draw_compendium(game,value)
	if bool(value.photo_mode): draw_photo_mode(game,value)

## Отрисовывает пять страниц календаря, отношений, музея, энциклопедии и достижений.
static func draw_compendium(game: Node, value: Dictionary) -> void:
	game.draw_rect(Rect2(90,55,972,535),Color("382318")); game.draw_rect(Rect2(105,70,942,505),Color("ead7a3")); var titles := ["КАЛЕНДАРЬ","ОТНОШЕНИЯ","МУЗЕЙ","ЭНЦИКЛОПЕДИЯ","ДОСТИЖЕНИЯ"]
	game.draw_string(game.UI_FONT,Vector2(145,115),"‹  %s  ›" % titles[int(value.page)],HORIZONTAL_ALIGNMENT_CENTER,862,30,Color("4c3020")); var lines: Array[String] = []
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
	for index in mini(lines.size(),24): game.draw_string(game.UI_FONT,Vector2(155+(index/8)*285,160+(index%8)*45),lines[index],HORIZONTAL_ALIGNMENT_LEFT,265,17,Color("513724"))
	game.draw_string(game.UI_FONT,Vector2(145,550),"V — закрыть • ← → — разделы",HORIZONTAL_ALIGNMENT_CENTER,862,15,Color("765437"))

## Отрисовывает чистый визир фотокамеры с опциональной сеткой третей.
static func draw_photo_mode(game: Node, value: Dictionary) -> void:
	game.draw_rect(Rect2(18,18,1116,612),Color.WHITE,false,3); game.draw_string(game.UI_FONT,Vector2(30,48),"ФОТОРЕЖИМ • P закрыть • G сетка",HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color.WHITE)
	if bool(value.photo_grid):
		for x in [384.0,768.0]: game.draw_line(Vector2(x,18),Vector2(x,630),Color(1,1,1,0.45),1)
		for y in [216.0,432.0]: game.draw_line(Vector2(18,y),Vector2(1134,y),Color(1,1,1,0.45),1)
