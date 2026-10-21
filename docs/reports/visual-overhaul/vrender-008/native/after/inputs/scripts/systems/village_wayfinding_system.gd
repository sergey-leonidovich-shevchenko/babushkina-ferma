extends RefCounted

const Data := preload("res://scripts/systems/village_region_data.gd")
const ARROWS := {"left":"←","right":"→","top":"↑","bottom":"↓"}
const PLACES := {"home":"overworld","shop":"village_market","herbs":"village_garden","river":"village_river"}
const WORDS := {
	"blocked":["Вход занят. Освободи место с другой стороны.","The entrance is blocked. Clear space on the other side.","La entrada está bloqueada. Despeja el otro lado.","Der Eingang ist belegt. Räume die andere Seite frei.","L’entrée est bloquée. Libère l’autre côté.","入口被挡住了，请清理另一侧的空间。"],
	"home":["Дом","Home","Casa","Zuhause","Maison","家"],
	"shop":["Лавка","Shop","Tienda","Laden","Boutique","商店"],
	"herbs":["Агафья","Agafya","Agafya","Agafya","Agafya","阿加菲娅"],
	"river":["Река","River","Río","Fluss","Rivière","河流"],
	"farm":["Дом и ферма","Home and farm","Casa y granja","Haus und Hof","Maison et ferme","家与农场"],
}

## Находит первый физический порт кратчайшего маршрута по существующим обратимым дорогам.
static func next_port(source: String, target: String) -> String:
	if source == target or not Data.contains(source) or not Data.contains(target): return ""
	var queue: Array = [{"area":source,"first":""}]; var visited := {source:true}; var cursor := 0
	while cursor < queue.size():
		var current: Dictionary = queue[cursor]; cursor += 1
		for link in Data.passages(current.area):
			if visited.has(link.target): continue
			var first: String = link.port if current.first.is_empty() else current.first
			if link.target == target: return first
			visited[link.target] = true; queue.append({"area":link.target,"first":first})
	return ""

## Локализует короткий ориентир, сохраняя названия районов в общем каталоге.
static func word(game: Node, key: String) -> String:
	return String(WORDS[key][game.LocaleSystem.index()])

## Подписывает существующий указатель осевой стрелкой и понятным названием домашней области.
static func title(game: Node, link: Dictionary) -> String:
	var destination: String = word(game,"farm") if link.target == "overworld" else game.LocaleSystem.location(link.target)
	return String(ARROWS[link.port]) + " " + destination

## Возвращает не более двух ближайших полезных ориентиров по этой дороге без постоянной миникарты.
static func tags(game: Node, port: String) -> String:
	var result: PackedStringArray = []
	for place in PLACES:
		if next_port(game.current_location,PLACES[place]) == port:
			result.append(word(game,place))
			if result.size() == 2: break
	return " · ".join(result)
