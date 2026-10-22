extends RefCounted

const BASE_CELL:=24
const ENEMY_RANK_SIZES:=[Vector2(96,96),Vector2(120,120),Vector2(144,144)]
const WILDLIFE_SIZE:=Vector2(96,96)
const HAZARD_SIZES:={"poison_ivy":Vector2(96,96),"thorn_bloom":Vector2(120,120),"cactus":Vector2(96,96)}
const GROUND_RATIO:=0.72


## Возвращает модульную рамку врага по одному из трёх визуальных рангов уровней 1–5.
static func enemy_size(level:int)->Vector2:
	return ENEMY_RANK_SIZES[mini(floori(float(clampi(level,1,5)-1)/2.0),2)]


## Возвращает единую рамку любого декоративного или охотничьего животного.
static func wildlife_size()->Vector2:
	return WILDLIFE_SIZE


## Возвращает малый либо крупный модуль укоренённой опасности.
static func hazard_size(kind:String)->Vector2:
	return HAZARD_SIZES.get(kind,Vector2(96,96))


## Строит видимый прямоугольник существа относительно общей точки земли.
static func actor_rect(position:Vector2,size:Vector2)->Rect2:
	return Rect2(position-size*Vector2(0.5,GROUND_RATIO),size)


## Проверяет кратность всех ранговых, звериных и растительных рамок базовой клетке.
static func profiles_are_valid()->bool:
	for size in ENEMY_RANK_SIZES+[WILDLIFE_SIZE]+HAZARD_SIZES.values():
		if int(Vector2(size).x)%BASE_CELL!=0 or int(Vector2(size).y)%BASE_CELL!=0: return false
	return true


## Добавляет зверей в подготовленную ранговую витрину и включает чистый автоматический кадр.
static func configure_preview(game:Node)->void:
	game.current_location="cave"; game.player=Vector2(1150,620)
	var enemy_index:=0
	for enemy in game.enemy_nodes:
		if enemy.location=="overworld": enemy.location="cave"; enemy.position=Vector2(790+enemy_index*180,430); enemy.home=enemy.position; enemy_index+=1
	for index in mini(3,game.hazard_nodes.size()): game.hazard_nodes[index].location="cave"; game.hazard_nodes[index].position=Vector2(880+index*260,680)
	for index in game.wildlife_nodes.size(): game.wildlife_nodes[index].location="cave"; game.wildlife_nodes[index].position=Vector2(790+(index%5)*180,890)
	game.set_meta("capture_creature_frames",8); game.set_meta("capture_first_level_clean",true)


## Сохраняет контрольный кадр рангов врагов, опасных растений и зверей в единой мировой сцене.
static func update_preview_capture(game:Node)->bool:
	if not game.has_meta("capture_creature_frames"): return false
	var frames_left:=int(game.get_meta("capture_creature_frames"))-1; game.set_meta("capture_creature_frames",frames_left)
	if frames_left>0: return false
	game.remove_meta("capture_creature_frames"); var image:=game.get_viewport().get_texture().get_image()
	if image==null: game.get_tree().quit(); return true
	if image.get_size()!=Vector2i(1152,648): image.resize(1152,648,Image.INTERPOLATE_NEAREST)
	var output:=ProjectSettings.globalize_path("res://assets/generated/level_drafts/creatures_ingame_preview.png"); var error:=image.save_png(output)
	if error!=OK: push_error("Не удалось сохранить предпросмотр существ: %s"%error)
	game.get_tree().quit(); return true
