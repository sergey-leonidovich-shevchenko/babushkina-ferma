extends RefCounted

const META := "runtime_maintenance"
const INTERVAL_USEC := 30_000_000
const FRAME_BUDGET_USEC := 300
const MAX_CHECKS_PER_FRAME := 16
const PROVIDERS := [
	preload("res://scripts/systems/sprite_matte_system.gd"),
	preload("res://scripts/systems/wildlife_visual_system.gd"),
	preload("res://scripts/systems/resident_visual_system.gd"),
	preload("res://scripts/systems/level_editor_atlas_picker_renderer.gd"),
]

## Возвращает четыре ограниченных производных кеша без обхода дерева сцены и игровых сущностей.
static func caches() -> Array:
	return [PROVIDERS[0]._textures,PROVIDERS[1]._bounds,PROVIDERS[2]._bounds,PROVIDERS[3]._visible_source_cache]

## Хранит только небольшой рабочий курсор и числовые счётчики, которые не попадают в сохранения.
static func state(game: Node, now_usec: int) -> Dictionary:
	if not game.has_meta(META):
		game.set_meta(META,{"next_usec":now_usec+INTERVAL_USEC,"active":false,"remaining":[],"index":0,"cycles":0,"scanned":0,"removed":0,"last_checks":0,"last_usec":0,"max_usec":0,"overruns":0})
	return game.get_meta(META)

## Запрашивает один постепенный проход для стенда, не накапливая повторные задачи поверх выполняющейся.
static func request(game: Node, now_usec: int = -1) -> void:
	var now: int = Time.get_ticks_usec() if now_usec<0 else now_usec
	var value := state(game,now)
	if value.active: return
	value.remaining=[]
	for cache in caches(): value.remaining.append(cache.scan_size())
	value.index=0; value.active=true

## Проверяет наличие работы без создания временных массивов или изменения расписания.
static func busy(game: Node) -> bool:
	return bool(game.get_meta(META,{}).get("active",false))

## Раз в тридцать реальных секунд обходит исчезнувших владельцев малыми порциями даже при остановленном игровом мире.
static func update(game: Node, now_usec: int = -1) -> void:
	var now: int = Time.get_ticks_usec() if now_usec<0 else now_usec
	var value := state(game,now)
	if not value.active and now < int(value.next_usec): return
	if not value.active: request(game,now)
	var started := Time.get_ticks_usec(); var deadline := started+FRAME_BUDGET_USEC
	var processed := 0; var providers := caches()
	while processed<MAX_CHECKS_PER_FRAME and Time.get_ticks_usec()<deadline:
		if value.index>=providers.size():
			value.active=false; value.next_usec=now+INTERVAL_USEC; value.cycles+=1; value.remaining=[]
			break
		if value.remaining[value.index]<=0: value.index+=1; continue
		value.removed+=providers[value.index].prune_one()
		value.remaining[value.index]-=1; processed+=1
	value.scanned+=processed; value.last_checks=processed
	value.last_usec=Time.get_ticks_usec()-started; value.max_usec=maxi(value.max_usec,value.last_usec)
	if value.last_usec>FRAME_BUDGET_USEC: value.overruns+=1

## Даёт диагностике копию счётчиков; итоговое освобождение общей памяти зависит от остальных владельцев ресурса.
static func statistics(game: Node) -> Dictionary:
	var result: Dictionary=game.get_meta(META,{}).duplicate(true)
	result.caches=[]
	for cache in caches(): result.caches.append(cache.statistics())
	return result
