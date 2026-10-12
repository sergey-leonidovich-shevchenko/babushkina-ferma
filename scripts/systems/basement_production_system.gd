extends RefCounted

const Basement := preload("res://scripts/systems/basement_system.gd")

## Продвигает каждую готовую личную производственную очередь один раз, независимо от открытого станка и текущей комнаты.
static func update(game: Node, delta: float) -> void:
	if not game.state.world.estate.expansion.has("basement"): return
	for item in Basement.state(game).objects:
		if item.phase!="ready" or item.production.queue.is_empty(): continue
		if item.kind=="furnace": game.FurnaceSystem.advance(game,item.production,delta)
		elif game.WorkshopSystem.handles(item.kind): game.WorkshopSystem.advance(game,item.kind,item.production,maxf(delta,0))
