extends RefCounted

const Fixture := preload("res://tools/qa/ground/ground_seasons_fixture.gd")
const Terrain := preload("res://scripts/systems/village_terrain_renderer.gd")

## Принимает цвета на неизменной геометрии и сохраняет настоящие правила календаря и полива.
static func run(context: SceneTree) -> void:
	test_calendar_and_geometry(context)
	test_visual_climate_is_pure(context)
	test_existing_rain_and_winter_rules(context)

## Сценарий: первая карта проходит четыре сезона и естественный дождливый день.
## Исходное состояние: один мир, одинаковые дороги, вода, мосты и прежние тридцать клеток.
## Ожидаемый результат: 41 меш и физические правила сохраняются; цвета различаются, весенний возврат точен.
static func test_calendar_and_geometry(context: SceneTree) -> void:
	var game:=Fixture.Points.create_game(); game._ready(); Fixture.Points.configure(game,Fixture.Points.registry().points[0]); game.get_node("WorldBackground")._ready()
	var geometry:=Fixture.geometry(); var baseline:=Fixture.rules(game); var colors:=[]
	context.expect(geometry.mesh_count==41 and geometry.world==[2400.0,1368.0],"all forty-one retained ground meshes cover the canonical first map")
	for profile in Fixture.CASES:
		Fixture.configure(game,profile)
		context.expect(game.WorldEventSystem.season(game.day)==profile.season and game.WorldEventSystem.location_weather(game.day,"overworld")==profile.weather,"profile uses the real calendar and its natural weather: "+profile.id)
		context.expect(geometry==Fixture.geometry(),"season changes no mesh, UV, alpha, bridge or path geometry: "+profile.id)
		context.expect(baseline==Fixture.rules(game),"1200 navigation/tilling rules and eight bridge motions stay identical: "+profile.id)
		colors.append(Terrain.ground_tint(profile.season,profile.weather))
	context.expect(colors.size()==5 and colors[0]!=colors[1] and colors[0]!=colors[2] and colors[0]!=colors[3] and colors[0]!=colors[4],"all four seasonal tones and wet spring are distinct")
	var wet:Color=colors[4]; var dry:Color=colors[0]
	context.expect(wet.r<dry.r and wet.g<dry.g and wet.b<dry.b,"rain darkens every meadow channel without moving coverage")
	game.day=29; game.state.world.weather_day=29; game.state.world.weather="clear"; game.sync_background_environment()
	context.expect(game.WorldEventSystem.season(29)=="spring" and Fixture.geometry()==geometry and Fixture.rules(game)==baseline,"complete calendar cycle returns to the same first-map geometry")
	game.free()

## Сценарий: только фон переключается между климатическими профилями, затем режим сравнения отключается.
## Исходное состояние: штатный календарь и полный save после ленивой подготовки навигации.
## Ожидаемый результат: графический климат и эталонный режим не пишут в игровой мир и не растят геометрию.
static func test_visual_climate_is_pure(context: SceneTree) -> void:
	var game:=Fixture.Points.create_game(); game._ready(); Fixture.Points.configure(game,Fixture.Points.registry().points[0]); var bg:Node=game.get_node("WorldBackground"); bg._ready()
	Fixture.rules(game); var saved:Dictionary=game.SaveSystem.snapshot(game); var geometry:=Fixture.geometry()
	for profile in Fixture.CASES:
		bg.set_environment(profile.season,profile.weather)
		context.expect(saved==game.SaveSystem.snapshot(game),"render-only environment preserves the complete save: "+profile.id)
		context.expect(bg.cover_layer.season==profile.season and bg.water_layer.season==profile.season and bg.terrain_viewport==null,"headless checks synchronize only actual retained layer data: "+profile.id)
	preload("res://scripts/presentation/visual_reference_mode.gd").enable(game,true)
	context.expect(saved==game.SaveSystem.snapshot(game) and not preload("res://scripts/presentation/visual_reference_mode.gd").effects_enabled(game),"reference disables moving effects transiently without changing save")
	preload("res://scripts/presentation/visual_reference_mode.gd").disable(game)
	context.expect(saved==game.SaveSystem.snapshot(game) and geometry==Fixture.geometry(),"ordinary effects return with the same geometry and save")
	game.free()

## Сценарий: настоящий дождливый день поливает обработанную землю, а зимой рост останавливается.
## Исходное состояние: две старые домашние клетки обработаны; сезонная механика не заменена цветовым профилем.
## Ожидаемый результат: дождь не создаёт грядки снаружи, инвентарь и силы сохраняются, зимняя пауза остаётся прежней.
static func test_existing_rain_and_winter_rules(context: SceneTree) -> void:
	var game:=Fixture.Points.create_game(); game._ready(); Fixture.Points.configure(game,Fixture.Points.registry().points[0])
	game.plots[Vector2i(0,0)].tilled=true; game.plots[Vector2i(1,0)].tilled=true
	var energy:int=game.energy; var coins:int=game.coins; var count:int=game.plots.size()
	game.day=3; game.state.world.weather_day=2; game.WorldEventSystem.update(game)
	context.expect(game.WorldEventSystem.weather(game)=="rain" and game.plots[Vector2i(0,0)].watered and game.plots[Vector2i(1,0)].watered,"real rainy day retains automatic watering of worked cells")
	context.expect(game.plots.size()==count and count==30 and game.state.world.world_plots.is_empty() and game.energy==energy and game.coins==coins,"rain creates no extra farm cells or stamina/inventory operation")
	game.day=22; game.state.world.weather_day=0; game.state.world.weather=""
	context.expect(game.WorldEventSystem.crop_growth_multiplier(game)==0.0 and game.WorldEventSystem.weather(game)=="clear","winter still pauses crops under the original natural-weather rules")
	game.free()
