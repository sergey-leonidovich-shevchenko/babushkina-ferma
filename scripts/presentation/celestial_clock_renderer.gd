extends RefCounted

const MoonStyle := preload("res://scripts/presentation/moon_theme.gd")
const CYCLE_DAYS := 28

## Возвращает фазу двадцативосьмидневного цикла: новолуние, рост, полнолуние и убывание.
static func moon_phase(day: int) -> float:
	return float(posmod(day-1,CYCLE_DAYS))/CYCLE_DAYS

## Разделяет день и ночь по игровому времени, а не по часам компьютера.
static func is_day(minutes: float) -> bool:
	var hour := fposmod(minutes/60.0,24.0)
	return hour>=6.0 and hour<18.0

## Возвращает путь светила от левого горизонта через зенит к правому, включая ночь после полуночи.
static func orbit_progress(minutes: float, daytime: bool) -> float:
	var minute := fposmod(minutes,1440.0)
	if daytime: return clampf((minute-360.0)/720.0,0.0,1.0)
	if minute<720.0: minute+=1440.0
	return clampf((minute-1080.0)/720.0,0.0,1.0)

## Размещает знак над горизонтом так, чтобы его положение заменяло цифровое время.
static func orbit_center(rect: Rect2, progress: float) -> Vector2:
	return rect.position+Vector2(24+(rect.size.x-48)*progress,31-sin(progress*PI)*11)

## Возвращает общую область календарной подписи для рендера и проверки локализованных шрифтов.
static func calendar_rect(rect: Rect2) -> Rect2:
	return Rect2(rect.position+Vector2(8,50),Vector2(rect.size.x-16,18))

## Рисует небесную дугу, плавную смену солнца и фазовой луны; точное время не выводится.
static func draw(game: Node, rect: Rect2) -> void:
	MoonStyle.panel(game,rect,MoonStyle.INSET)
	var orbit := PackedVector2Array()
	for index in 25: orbit.append(orbit_center(rect,float(index)/24.0))
	game.draw_polyline(orbit,Color("405442"),1.0,true)
	var minute := fposmod(game.game_minutes,1440.0)
	var daylight := smoothstep(354.0,366.0,minute)-smoothstep(1074.0,1086.0,minute)
	var sun_progress := orbit_progress(game.game_minutes,true)
	if daylight>0: draw_sun(game,orbit_center(rect,sun_progress),daylight,sun_progress)
	if daylight<1: draw_moon(game,orbit_center(rect,orbit_progress(game.game_minutes,false)),moon_phase(game.day),1-daylight)
	var calendar: String = MoonStyle.sentence_case(game.LocaleSystem.ui("day_short",[game.day]))+" · "+game.LocaleSystem.ui("season_"+game.WorldEventSystem.season(game.day))
	MoonStyle.text(game,calendar_rect(rect),calendar,MoonStyle.LABEL_SIZE,MoonStyle.MUTED,HORIZONTAL_ALIGNMENT_CENTER)

## Анимирует короткие солнечные лучи; режим уменьшенной анимации сохраняет неподвижный символ.
static func draw_sun(game: Node, center: Vector2, opacity: float = 1.0, progress: float = 0.5) -> void:
	var rotation := 0.0 if game.settings_state.reduced_motion else sin(Time.get_ticks_msec()/2800.0)*0.12
	var color := Color("f0df9a").lerp(Color("dba16c"),absf(progress-0.5)*2)
	color.a=opacity
	game.draw_circle(center,8,color)
	game.draw_circle(center-Vector2(2,2),3,Color(0.97,0.91,0.67,opacity))
	for index in 8:
		var direction := Vector2.from_angle(index*TAU/8.0+rotation)
		game.draw_line(center+direction*11,center+direction*15,Color(0.8,0.73,0.46,opacity),1.5)

## Рисует освещённую часть сферы геометрически, без переключения готовых одинаковых лунных пиктограмм.
static func draw_moon(game: Node, center: Vector2, phase: float, opacity: float = 1.0) -> void:
	var radius := 11.0
	game.draw_circle(center,radius,Color(0.20,0.30,0.26,opacity))
	var polygon := PackedVector2Array()
	for index in 25:
		var y := -radius+2*radius*index/24.0
		var edge := sqrt(maxf(0,radius*radius-y*y))
		polygon.append(center+Vector2(edge if phase<=0.5 else -edge,y))
	for index in range(24,-1,-1):
		var y := -radius+2*radius*index/24.0
		var edge := sqrt(maxf(0,radius*radius-y*y))
		polygon.append(center+Vector2(cos(phase*TAU)*edge*(1 if phase<=0.5 else -1),y))
	if phase>0.001 and phase<0.999: game.draw_colored_polygon(polygon,Color(0.86,0.91,0.78,opacity))
	game.draw_circle(center+Vector2(15,-11),1,Color(0.73,0.82,0.71,opacity))
	game.draw_circle(center+Vector2(-16,6),1,Color(0.56,0.68,0.60,opacity))
