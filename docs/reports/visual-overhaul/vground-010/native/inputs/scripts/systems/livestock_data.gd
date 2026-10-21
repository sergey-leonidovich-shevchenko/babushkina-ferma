extends RefCounted

const ANIMALS := [
	{"id":"hen","kind":"hen","name":"Ряба","product":"egg","position":Vector2(852,996),"pen":"coop","interval":1},
	{"id":"hen_2","kind":"hen","name":"Искра","product":"egg","position":Vector2(792,1056),"pen":"coop","interval":1},
	{"id":"hen_3","kind":"hen","name":"Кнопка","product":"egg","position":Vector2(852,1056),"pen":"coop","interval":1},
	{"id":"cow","kind":"cow","name":"Зорька","product":"milk","position":Vector2(792,1224),"pen":"pasture","interval":1},
	{"id":"sheep","kind":"sheep","name":"Облачко","product":"wool","position":Vector2(852,1160),"pen":"pasture","interval":3},
	{"id":"pig","kind":"pig","name":"Пятачок","product":"truffle","position":Vector2(1104,1200),"pen":"pigsty","interval":2},
]
const PENS := {
	"coop":{"rect":Rect2(720,936,192,144),"gate":Rect2(908,1008,8,48)},
	"pasture":{"rect":Rect2(624,1104,288,144),"gate":Rect2(908,1176,8,48)},
	"pigsty":{"rect":Rect2(984,1128,288,120),"gate":Rect2(980,1176,8,48)},
}
const PROPS := [
	{"kind":"coop","position":Vector2(780,1008),"size":Vector2(72,80),"base":Vector2(48,24)},
	{"kind":"barn","position":Vector2(708,1176),"size":Vector2(112,104),"base":Vector2(72,24)},
	{"kind":"barn","position":Vector2(1200,1176),"size":Vector2(112,104),"base":Vector2(72,24)},
	{"kind":"trough","position":Vector2(888,1128),"size":Vector2(60,40),"base":Vector2(48,18)},
	{"kind":"water_tub","position":Vector2(1032,1224),"size":Vector2(48,40),"base":Vector2(36,18)},
	{"kind":"hay","position":Vector2(672,1224),"size":Vector2(40,40),"base":Vector2(24,12)},
	{"kind":"compost","position":Vector2(576,1200),"size":Vector2(48,48),"base":Vector2(36,18)},
]
const TROUGH := Vector2(888,1128)
const WATER := Vector2(1032,1224)
const WALKWAY := Rect2(912,936,72,312)
const YARD_BOUNDS := Rect2(548,900,736,364)
const STOCK_CAP := 3
static var _walls: Array[Rect2] = []

## Возвращает животное по устойчивому идентификатору, не обращаясь к пустому результату поиска.
static func animal(id: String) -> Dictionary:
	for entry in ANIMALS:
		if entry.id == id: return entry
	return {}

## Возвращает физические секции ограды с настоящими разрывами для открытых калиток.
static func walls() -> Array[Rect2]:
	if not _walls.is_empty(): return _walls
	var result: Array[Rect2] = []
	for pen in PENS.values():
		var r: Rect2 = pen.rect; var gate: Rect2 = pen.gate
		result.append(Rect2(r.position-Vector2(4,4),Vector2(r.size.x+8,8)))
		result.append(Rect2(Vector2(r.position.x-4,r.end.y-4),Vector2(r.size.x+8,8)))
		for x in [r.position.x-4,r.end.x-4]:
			if is_equal_approx(x,gate.position.x):
				if gate.position.y>r.position.y+4: result.append(Rect2(x,r.position.y+4,8,gate.position.y-r.position.y-4))
				if gate.end.y<r.end.y-4: result.append(Rect2(x,gate.end.y,8,r.end.y-4-gate.end.y))
			else: result.append(Rect2(x,r.position.y+4,8,r.size.y-8))
	_walls=result
	return result

## Строит основание отдельной хозяйственной постройки по её точке опоры.
static func prop_base(prop: Dictionary) -> Rect2:
	var size: Vector2 = prop.base
	return Rect2(Vector2(prop.position)-Vector2(size.x*0.5,size.y),size)

## Возвращает физическую опору животного, одинаковую для навигации и инспектора F10.
static func animal_base(animal: Dictionary, position: Vector2) -> Rect2:
	var size := Vector2(14,8) if animal.kind=="hen" else Vector2(28,14)
	return Rect2(position-Vector2(size.x*0.5,size.y),size)
