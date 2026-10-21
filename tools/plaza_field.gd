extends RefCounted

const Map := preload("res://scripts/systems/village_map_data.gd")
const Shared := preload("res://tools/ground_edge_field.gd")
const STEP := 2
const CELL := 192.0

## Оценивает расстояние до эллипса площади; центр стабилен, рисунок края не управляет физикой.
static func distance(point: Vector2) -> float:
	var delta := point-Map.SQUARE.get_center(); var radius := Map.SQUARE.size*0.5
	var k0 := (delta/radius).length(); var k1 := (delta/(radius*radius)).length()
	var base := -minf(radius.x,radius.y) if k1<0.00001 else k0*(k0-1.0)/k1
	var angle := delta.angle()
	return base+sin(angle*13.0)*2.0+sin(angle*29.0+.5)*1.5+Shared.roughness(point)

## Возвращает воспроизводимые маленькие сколы вокруг кромки без случайного генератора или новых предметов.
static func chips() -> Array:
	var result := []
	for i in 22:
		var angle := TAU*(i+.23)/22.0
		var axis := Vector2(cos(angle),sin(angle))
		var centre := Map.SQUARE.get_center()+axis*(Map.SQUARE.size*.5+Vector2.ONE*(8.0+float(i%3)*3.0))
		result.append(Rect2(centre-Vector2(3.0+i%3,2.0+i%2),Vector2(6.0+(i%3)*2.0,4.0+(i%2)*2.0)))
	return result

## Считает независимые альфа-слои земляного контакта, мягкой тени и камня с мелкими обломками.
static func coverage(point: Vector2, kind: String, fragments: Array) -> float:
	var edge := distance(point)
	if kind=="apron": return 1.0-smoothstep(4.0,18.0,edge)
	var chip := INF; var shadow := INF
	for rect: Rect2 in fragments:
		var radius := rect.size*.5; var delta := point-rect.get_center()
		chip=minf(chip,((delta/radius).length()-1.0)*minf(radius.x,radius.y))
		shadow=minf(shadow,(((delta-Vector2(1.0,2.0))/(radius+Vector2.ONE)).length()-1.0)*minf(radius.x,radius.y))
	if kind=="stone": return maxf(1.0-smoothstep(-3.0,3.0,edge),1.0-smoothstep(-.6,1.0,chip))
	return maxf((1.0-smoothstep(0.0,5.0,absf(edge-1.5)))*.08,(1.0-smoothstep(-1.0,2.0,shadow))*.12)
