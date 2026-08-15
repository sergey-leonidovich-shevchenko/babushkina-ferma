extends RefCounted

const WorldVisualProfileSystem := preload("res://scripts/systems/world_visual_profile_system.gd")
const POSITIONS := [Vector2(480,250),Vector2(720,600),Vector2(1040,300),Vector2(1380,720),Vector2(1720,280),Vector2(2050,620)]


## Возвращает полный модульный прямоугольник валунно-кристального скопления.
static func cluster_bounds(position: Vector2) -> Rect2:
	return WorldVisualProfileSystem.visual_rect("cave_cluster",position+Vector2(0,4))


## Возвращает основание скопления, которое одновременно использует навигация и F10.
static func collision_rect(position: Vector2) -> Rect2:
	return WorldVisualProfileSystem.collision_rect("cave_cluster",position+Vector2(0,4))


## Рассчитывает один из шести камней 48×48 вокруг центра без случайных промежуточных размеров.
static func rock_rect(position: Vector2, ring: int) -> Rect2:
	var angle:=float(ring)*TAU/6.0
	var ground:=position+Vector2(cos(angle)*34.0,sin(angle)*18.0+28.0)
	return WorldVisualProfileSystem.visual_rect("cave_rock",ground)


## Возвращает кристалл 72×72 с общей нижней опорой и только визуальным вертикальным пульсом.
static func crystal_rect(position: Vector2, pulse: float=0.0) -> Rect2:
	return WorldVisualProfileSystem.visual_rect("cave_crystal",position+Vector2(0,36+pulse))


## Строит камень портала 48×48 на модульной сетке вокруг заданного смещения.
static func entrance_rock_rect(entrance: Vector2, offset: Vector2) -> Rect2:
	return WorldVisualProfileSystem.visual_rect("cave_rock",entrance+offset+Vector2(0,24))


## Готовит чистый игровой обзор центра пещеры без стартовых экранов и обучающих карточек.
static func configure_preview(game: Node) -> void:
	game.language_screen=false; game.title_screen=false; game.current_location="cave"; game.player=Vector2(720,820); game.tutorial_visible=false; game.set_meta("capture_first_level_clean",true)


## Сохраняет контрольный кадр пещеры после нескольких полноценно отрисованных кадров.
static func update_preview_capture(game: Node) -> bool:
	if not game.has_meta("capture_cave_frames"): return false
	var frames_left:=int(game.get_meta("capture_cave_frames"))-1; game.set_meta("capture_cave_frames",frames_left)
	if frames_left>0: return false
	game.remove_meta("capture_cave_frames"); var image:=game.get_viewport().get_texture().get_image()
	if image==null: game.push_error("Renderer не предоставил кадр пещеры"); game.get_tree().quit(); return true
	var output:=ProjectSettings.globalize_path("res://assets/generated/level_drafts/cave_ingame_preview.png"); var error:=image.save_png(output)
	if error!=OK: game.push_error("Не удалось сохранить предпросмотр пещеры: %s"%error)
	game.get_tree().quit(); return true
