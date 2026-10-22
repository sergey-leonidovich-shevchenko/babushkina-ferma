extends RefCounted

const WORDS := {
	"shop":["Лавка","Shop","Tienda","Laden","Boutique","商店"],
	"workbench":["Верстак","Workbench","Banco de trabajo","Werkbank","Établi","工作台"],
	"alchemy":["Алхимический стол","Alchemy table","Mesa de alquimia","Alchemietisch","Table d’alchimie","炼金桌"],
	"map":["Районы деревни","Village districts","Barrios de la aldea","Dorfviertel","Quartiers du village","村庄区域"],
	"world":["Весь мир","Whole world","Todo el mundo","Gesamte Welt","Monde entier","整个世界"],
	"daytime":["Жители днём","Residents by day","Vecinos de día","Bewohner am Tag","Habitants le jour","白天的居民"],
	"orchard":["Плоды и прогулки","Fruit and walks","Fruta y paseos","Obst und Spaziergänge","Fruits et promenades","水果与散步"],
	"help":["Переходы двусторонние. Указатели ведут к соседним районам. V / R3 переключает карту.","Passages work both ways. Signs lead to adjacent districts. V / R3 switches maps.","Pasos de ida y vuelta. Sigue las señales. V / R3 cambia el mapa.","Wege in beide Richtungen. Folge den Schildern. V / R3 wechselt die Karte.","Passages dans les deux sens. Suis les panneaux. V / R3 change de carte.","通道双向连通，路牌指向相邻区域。V / R3切换地图。"],
}

## Возвращает подпись районного интерфейса на выбранном языке игры.
static func text(game: Node, key: String) -> String:
	return String(WORDS.get(key,[key,key,key,key,key,key])[game.LocaleSystem.index()])
