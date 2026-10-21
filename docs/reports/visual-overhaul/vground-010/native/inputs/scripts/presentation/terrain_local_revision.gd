extends RefCounted

const WORLD := Vector2(2400,1368)
const MAX_PENDING := 32
const SECTION := 256.0
var revision := 0
var base_revision := 0
var sections: Dictionary = {}
var pending: Array[Rect2] = []
var active := Rect2()
var full_pending := false
var local_paints := 0
var full_paints := 0
var last_completed := Rect2()

## Округляет только границы записываемых пикселей и отсекает некорректный или внешний запрос.
static func clipped(rect: Rect2) -> Rect2:
	if not rect.position.is_finite() or not rect.size.is_finite() or not rect.has_area(): return Rect2()
	var start:=rect.position.floor().max(Vector2.ZERO)
	var finish:=rect.end.ceil().min(WORLD)
	return Rect2(start,finish-start) if finish.x>start.x and finish.y>start.y else Rect2()

## Заменяет локальную очередь полной ревизией при смене карты, сезона или общего профиля.
func begin_full() -> void:
	revision+=1; base_revision=revision; sections.clear(); pending.clear(); active=Rect2(); full_pending=true

## Сохраняет независимые участки раздельно; переполнение явно требует полного fallback у владельца.
func request(rect: Rect2) -> bool:
	var region:=clipped(rect)
	if not region.has_area(): return false
	var next:=pending.duplicate()
	var merged:=true
	while merged:
		merged=false
		for index in range(next.size()-1,-1,-1):
			if region.intersects(next[index],true):
				region=region.merge(next[index]); next.remove_at(index); merged=true
	if not full_pending and next.size()>=MAX_PENDING: return false
	revision+=1
	for y in range(floori(region.position.y/SECTION),ceili(region.end.y/SECTION)):
		for x in range(floori(region.position.x/SECTION),ceili(region.end.x/SECTION)): sections[Vector2i(x,y)]=revision
	if not full_pending: next.append(region); pending.assign(next)
	return true

## Начинает ровно один локальный проход; запрос в уже активную область остаётся в очереди на следующий кадр.
func take() -> Rect2:
	if full_pending or active.has_area() or pending.is_empty(): return Rect2()
	active=pending.pop_front()
	return active

## Принимает только завершённый реальный проход и не хранит историю кадров или старые текстуры.
func complete() -> void:
	if full_pending:
		full_pending=false; full_paints+=1; last_completed=Rect2(Vector2.ZERO,WORLD)
	elif active.has_area():
		local_paints+=1; last_completed=active; active=Rect2()

## Возвращает ограниченную ревизию секции, не создавая новую запись при чтении.
func at(point: Vector2) -> int:
	if not point.is_finite() or not Rect2(Vector2.ZERO,WORLD).has_point(point): return -1
	return int(sections.get(Vector2i((point/SECTION).floor()),base_revision))

## Показывает копии диагностики; счётчики описывают запросы и проходы, а не GPU-время или FPS.
func snapshot() -> Dictionary:
	return {"revision":revision,"base_revision":base_revision,"sections":sections.duplicate(),"pending":pending.duplicate(),
		"active":active,"full_pending":full_pending,"local_paints":local_paints,"full_paints":full_paints,"last_completed":last_completed}
