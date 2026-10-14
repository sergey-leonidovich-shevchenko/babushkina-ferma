extends "res://tests/suites/suite_base.gd"

const Routes := preload("res://scripts/systems/cardinal_path_system.gd")
const Map := preload("res://scripts/systems/village_map_data.gd")
const Regions := preload("res://scripts/systems/village_region_data.gd")
const Labels := preload("res://scripts/presentation/world_label_renderer.gd")
const Marker := preload("res://scripts/presentation/world_marker_renderer.gd")

## Проверяет прямые дороги, рабочие ракурсы и доступность компактных мировых подписей.
func run() -> void:
	test_cardinal_paths_keep_endpoints_and_grid()
	test_home_routes_use_bridges_instead_of_water()
	test_station_tiers_share_approved_front_art()
	test_labels_stay_in_camera_at_all_font_scales()
	test_reduced_motion_freezes_attention_marker()
	test_recipe_badges_show_exact_material_costs()

## Сценарий: дороги всех районов строятся из прямых ветвей вместо диагональных полос.
## Исходное состояние: прежние начало и конец маршрутов, повторные точки и разная длина сегментов.
## Ожидаемый результат: все повороты ортогональны и лежат на сетке, концы сохранены, пустые маршруты безопасны.
func test_cardinal_paths_keep_endpoints_and_grid() -> void:
	var catalogs:=[Map.routes()]
	for area in Regions.IDS: catalogs.append(Regions.routes(area))
	for paths in catalogs:
		for path in paths:
			for index in path.size():
				var point:=Vector2(path[index])
				expect(is_zero_approx(fmod(point.x,24)) and is_zero_approx(fmod(point.y,24)),"road vertex shares the world grid: "+str(point))
				if index==0: continue
				var delta:Vector2=point-Vector2(path[index-1])
				expect((is_zero_approx(delta.x) or is_zero_approx(delta.y)) and delta.length()>0,"every visible road segment is cardinal and nonzero")
	var original:=[[],[Vector2(48,72)],[Vector2(24,48),Vector2(96,120),Vector2(96,120),Vector2(192,24)]]
	var paths:=Routes.routes(original)
	expect(paths.size()==2 and paths[0]==[Vector2(48,72)],"empty and single-point routes are safe")
	expect(paths[1][0]==original[2][0] and paths[1][-1]==original[2][-1] and original[2].size()==4,"orthogonal conversion preserves endpoints without mutating source")

## Сценарий: дороги фермы пересекают реку только по двум настоящим настилам.
## Исходное состояние: новая прямоугольная сеть и прежние границы воды и мостов.
## Ожидаемый результат: каждый участок центральной линии лежит на суше либо на мосту.
func test_home_routes_use_bridges_instead_of_water() -> void:
	for path in Map.routes()+Regions.routes("overworld"):
		for index in range(1,path.size()):
			var from:=Vector2(path[index-1]); var to:=Vector2(path[index]); var clear:=true
			for step in range(ceili(from.distance_to(to)/12)+1):
				var point:=from.move_toward(to,step*12)
				if preload("res://scripts/systems/village_layout_system.gd").is_water(point,0): clear=false; break
			expect(clear,"visible road does not cross open water: %s to %s"%[from,to])

## Сценарий: станки в гильдии и кузнице имеют видимую рабочую сторону на всех уровнях.
## Исходное состояние: четыре семейства с тремя уровнями и согласованный ремесленный набор.
## Ожидаемый результат: старые диагональные ресурсы не выбираются, пропорции, нижняя опора и основания сохранены.
func test_station_tiers_share_approved_front_art() -> void:
	var art:=preload("res://scripts/presentation/workshop_visual_system.gd")
	var approved:=preload("res://scripts/presentation/basement_visual_system.gd")
	for kind in art.SPRITES:
		for tier in range(1,4):
			var texture:AtlasTexture=art.texture(kind,tier)
			var rect:Rect2=art.destination(kind,Vector2(336,432),tier)
			expect(texture==approved.texture("study" if kind=="study_table" else kind,tier,0),"station uses approved front at every tier: %s %d"%[kind,tier])
			expect(is_equal_approx(rect.size.x/texture.get_width(),rect.size.y/texture.get_height()) and rect.end.y==432,"station preserves aspect and ground at every tier")

## Сценарий: длинные имена и переходы показываются у краёв камеры на шести языках.
## Исходное состояние: масштаб от восьмидесяти до ста двадцати процентов и камера вдали от начала мира.
## Ожидаемый результат: плашка находится внутри игрового поля и строка помещается с внутренними отступами.
func test_labels_stay_in_camera_at_all_font_scales() -> void:
	var game:=make_game(); game.camera_offset=Vector2(768,360)
	var safe:Rect2=preload("res://scripts/systems/camera_system.gd").playfield_rect(game).grow(-8); safe.position+=game.camera_offset
	for locale in game.LocaleSystem.LOCALES:
		game.LocaleSystem.set_locale(locale)
		for scale in [0.8,1.0,1.2]:
			game.settings_state.text_scale=scale
			var text:String=game.LocaleSystem.location("village_workyard")
			for anchor in [safe.position,safe.end]:
				var rect:=Labels.bounds(game,anchor,text)
				var size:int=game.UiScaleSystem.fitted_singleline_font_size(game,game.UI_FONT,text,rect.size.x-8,rect.size.y-8,11)
				expect(safe.encloses(rect),"world label stays clear of HUD and hotbar in "+locale)
				expect(game.UI_FONT.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x<=rect.size.x-8+0.1 and game.UI_FONT.get_height(size)<=rect.size.y-8+0.1,"world label fits at chosen text scale in "+locale)
	game.free()

## Сценарий: пользователь отключает движение интерфейса и мировых подсказок.
## Исходное состояние: один маркер проверяется в разные моменты времени.
## Ожидаемый результат: уменьшение движения даёт неподвижную опору, обычный цикл непрерывен через шов.
func test_reduced_motion_freezes_attention_marker() -> void:
	var game:=make_game(); var anchor:=Vector2(240,300)
	game.settings_state.reduced_motion=true
	expect(Marker.center(game,anchor,0)==anchor and Marker.center(game,anchor,1)==anchor,"reduced motion freezes all shared attention marks")
	var first:=Marker.water_pose(game,anchor,0); var second:=Marker.water_pose(game,anchor,1)
	expect(first==second and is_equal_approx(float(first.scale)*19,12),"watering mark is twelve pixels and completely static with reduced motion")
	game.settings_state.reduced_motion=false
	expect(Marker.center(game,anchor,2.2-0.0001).distance_to(Marker.center(game,anchor,2.2+0.0001))<0.01,"attention motion has a continuous loop seam")
	for time in [0.0,0.55,1.1,1.65,2.2]:
		var pose:=Marker.water_pose(game,anchor,time)
		expect(float(pose.scale)*19<12.31 and Vector2(pose.center).distance_to(anchor)<=0.45,"watering animation stays compact and below the growth track")
	game.free()

## Сценарий: список рецептов показывает материалы и количество вместо обрезанных похожих названий.
## Исходное состояние: весь реестр рецептов, запас больше тысячи и действующий ремесленный талант.
## Ожидаемый результат: до трёх колонок, точные значения расхода, явный остаток длинного состава и ограниченная длина счётчика.
func test_recipe_badges_show_exact_material_costs() -> void:
	var game:=make_game(); var badges:=preload("res://scripts/presentation/recipe_input_renderer.gd")
	game.change_inventory_count("plank",1200)
	for recipe in game.CraftingSystem.RECIPES:
		var entries:=badges.entries(game,recipe)
		expect(entries.size()<=3,"all recipe rows fit at most three ingredient columns")
		for entry in entries:
			if entry.kind.is_empty():
				expect(entry.label=="+"+str(recipe.inputs.size()-2),"long recipe states the number of ingredients shown in details")
			else:
				expect(entry.need==game.CraftingSystem.material_cost(game,recipe,entry.kind) and entry.have==game.inventory_item_count(entry.kind),"ingredient badge uses actual inventory and discounted crafting cost")
	var parts:=badges.entries(game,{"inputs":{"plank":1},"station":"cauldron"})
	expect(parts[0].have==1200 and parts[0].label=="999+/1","compact number does not truncate or change actual stock")
	game.talent_levels["craft_efficient"]=1
	parts=badges.entries(game,{"inputs":{"plank":3},"station":"workbench"})
	expect(parts[0].need==2 and parts[0].label=="999+/2","ingredient badge shows the actual thrift discount")
	game.free()
