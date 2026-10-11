extends RefCounted

const MoonStyle := preload("res://scripts/presentation/moon_theme.gd")
const Assets := preload("res://scripts/systems/celestial_dial_assets_system.gd")
const CYCLE_DAYS := 28
const DIAMETER := 96.0
const ORBIT_RADIUS := 27.0

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
	return Rect2(rect.position+Vector2(0,98),Vector2(rect.size.x,18))

## Возвращает непрерывный угол суток, включая переход через полночь без скачка на полный оборот.
static func rotation_angle(day: int, minutes: float) -> float:
	return TAU*((day-1)*1440.0+minutes-720.0)/1440.0

## Центрирует круг в выделенной области, оставляя календарю собственную строку.
static func dial_rect(rect: Rect2) -> Rect2:
	return Rect2(rect.position+Vector2((rect.size.x-DIAMETER)/2,0),Vector2.ONE*DIAMETER)

## Размещает светила на противоположных сторонах одной орбиты: восход слева и закат справа.
static func body_center(rect: Rect2, angle: float, sun: bool) -> Vector2:
	return dial_rect(rect).get_center()+Vector2(0,-ORBIT_RADIUS if sun else ORBIT_RADIUS).rotated(fposmod(angle,TAU))

## Вращает только небо; неподвижная долина закрывает заходящие светила, рамка и подпись остаются ровными.
static func draw(game: Node, rect: Rect2) -> void:
	var angle := fposmod(rotation_angle(game.day,game.game_minutes),TAU)
	var circle := dial_rect(rect)
	var local := Rect2(-circle.size/2,circle.size)
	game.draw_set_transform(circle.get_center(),angle)
	game.draw_texture_rect(Assets.texture("sky"),local,false)
	game.draw_set_transform(Vector2.ZERO)
	draw_sun(game,body_center(rect,angle,true),1.0,fposmod(game.game_minutes,1440.0)/1440.0)
	draw_moon(game,body_center(rect,angle,false),moon_phase(game.day))
	var light := Color("65759c").lerp(Color.WHITE,(cos(angle)+1)/2.0)
	game.draw_texture_rect(Assets.texture("landscape"),circle,false,light)
	game.draw_texture_rect(Assets.texture("frame"),circle,false)
	var calendar: String = MoonStyle.sentence_case(game.LocaleSystem.ui("day_short",[game.day]))+" · "+game.LocaleSystem.ui("season_"+game.WorldEventSystem.season(game.day))
	MoonStyle.panel(game,calendar_rect(rect),Color(0.025,0.055,0.045,0.82))
	MoonStyle.text(game,calendar_rect(rect),calendar,MoonStyle.LABEL_SIZE,MoonStyle.MUTED,HORIZONTAL_ALIGNMENT_CENTER)

## Привязывает лучи к игровому времени: при паузе останавливаются и круг, и мелкие движения.
static func draw_sun(game: Node, center: Vector2, opacity: float = 1.0, progress: float = 0.5) -> void:
	var rotation := 0.0 if game.settings_state.reduced_motion else sin(progress*TAU)*0.12
	var color := Color("f0df9a").lerp(Color("dba16c"),absf(progress-0.5)*2)
	color.a=opacity
	game.draw_circle(center,5,color)
	game.draw_circle(center-Vector2(1,1),2,Color(0.97,0.91,0.67,opacity))
	for index in 8:
		var direction := Vector2.from_angle(index*TAU/8.0+rotation)
		game.draw_line(center+direction*7,center+direction*9,Color(0.91,0.79,0.46,opacity),1.0,true)

## Рисует освещённую часть сферы геометрически, без переключения готовых одинаковых лунных пиктограмм.
static func draw_moon(game: Node, center: Vector2, phase: float, opacity: float = 1.0) -> void:
	var radius := 6.5
	game.draw_circle(center,radius+0.5,Color(0.48,0.61,0.70,opacity))
	game.draw_circle(center,radius,Color(0.17,0.24,0.32,opacity))
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
