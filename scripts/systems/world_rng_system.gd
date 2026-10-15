extends RefCounted

const VERSION := 1
const MODULUS := 2147483647
const MULTIPLIER := 48271
const STREAMS := ["world","loot","combat"]

## Создаёт независимые целочисленные потоки; формат не зависит от внутреннего генератора движка или отрисовки.
static func fresh(seed_value: int) -> Dictionary:
	var seed_key:=posmod(seed_value,MODULUS-1)+1
	var states: Dictionary={}
	for index in STREAMS.size():
		var mixed: int=(seed_key*MULTIPLIER+(index+1)*104729)%(MODULUS-1)+1
		states[STREAMS[index]]=mixed
	return {"version":VERSION,"seed":seed_key,"streams":states}

## Возвращает снимок без изменения мира, в том числе после явной замены тестового seed.
static func snapshot(game: Node) -> Dictionary:
	var current: Dictionary=game.state.world.rng_state
	return current.duplicate(true) if valid(current,game.world_loot_seed) else fresh(game.world_loot_seed)

## Загружает уже проверенное состояние; старый слот начинает новые потоки, не меняя прежнюю добычу.
static func restore(game: Node, value: Dictionary={}) -> void:
	game.state.world.rng_state=value.duplicate(true) if valid(value,game.world_loot_seed) else fresh(game.world_loot_seed)

## Проверяет точные безопасные для JSON целые состояния и согласованность с seed мира.
static func valid(value: Variant, seed_value: int) -> bool:
	if not value is Dictionary: return false
	for key in ["version","seed"]:
		var field: Variant=value.get(key,null)
		if not (field is int or field is float) or not is_finite(float(field)) or float(field)!=floorf(float(field)): return false
	if value.version!=VERSION or value.seed!=posmod(seed_value,MODULUS-1)+1: return false
	var states: Variant=value.get("streams",null)
	if not states is Dictionary or states.size()!=STREAMS.size(): return false
	for stream in STREAMS:
		var number: Variant=states.get(stream,null)
		if not (number is int or number is float) or not is_finite(float(number)) or float(number)!=floorf(float(number)) or number<1 or number>=MODULUS: return false
	return true

## Продвигает только указанный поток; все промежуточные произведения помещаются в int64.
static func next(game: Node, stream: String) -> int:
	assert(stream in STREAMS,"Неизвестный поток случайности")
	if not valid(game.state.world.rng_state,game.world_loot_seed): restore(game)
	var states: Dictionary=game.state.world.rng_state.streams
	var value: int=int(states[stream])*MULTIPLIER%MODULUS
	states[stream]=value
	return value

## Выбирает равновероятное целое без модульного смещения на ограниченном игровом диапазоне.
static func integer(game: Node, stream: String, low: int, high: int) -> int:
	assert(high>=low and high-low<1000000,"Слишком большой игровой диапазон")
	var width:=high-low+1
	var limit: int=((MODULUS-1)/width)*width
	var value:=next(game,stream)-1
	while value>=limit: value=next(game,stream)-1
	return low+value%width

## Выбирает вещественное значение из воспроизводимого потока, исключая системные часы.
static func real(game: Node, stream: String, low: float, high: float) -> float:
	return lerpf(low,high,float(next(game,stream)-1)/float(MODULUS-2))
