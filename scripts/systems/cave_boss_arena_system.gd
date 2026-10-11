extends RefCounted

const Data := preload("res://scripts/systems/cave_boss_arena_data.gd")

## Проверяет сохранённую победу по единственному сюжетному хранителю, не по рядовым стражам.
static func defeated(game: Node) -> bool:
	var index: int = game.CaveBossSystem.index(game)
	return index >= 0 and not game.enemy_nodes[index].alive

## Разрешает дальнейший переход только после победы; остальные области сохраняют свои правила.
static func can_exit(game: Node) -> bool:
	return game.current_location != Data.LOCATION or defeated(game)

## Предлагает алтарь рядом с героем, пока хранитель жив и ещё спит.
static func altar_available(game: Node) -> bool:
	return game.current_location == Data.LOCATION and not defeated(game) and not game.state.world.cave_boss.active

## Пробуждает хранителя осознанным взаимодействием; близость и пауза проверяются перед запуском.
static func activate(game: Node) -> bool:
	if not altar_available(game) or game.player.distance_to(Data.ALTAR) > 92.0: return false
	if game.menu_state.pause_open or game.menu_state.settings_open or game.menu_state.defeat_open or preload("res://scripts/systems/menu_hub_system.gd").active(game): return false
	if not game.CaveBossSystem.start(game): return false
	game.notify_tutorial("cave_boss_altar"); game.play_sfx("travel")
	game.message = game.LocaleSystem.tutorial("cave_boss_altar")
	return true

## Не даёт обойти видимую лунную печать по краям северного туннеля.
static func blocks_seal(game: Node, position: Vector2, radius: float) -> bool:
	return not can_exit(game) and position.distance_squared_to(position.clamp(Data.SEAL.position,Data.SEAL.end)) < radius*radius

## Скрывает наградной сундук до победы, включая его невидимую коллизию и подсказки.
static func container_visible(game: Node, container: Dictionary) -> bool:
	return container.location != Data.LOCATION or defeated(game)

## Выдаёт одну сюжетную реликвию за победу, учитывая старую добычу и уже завершённую миссию.
static func award_relic(game: Node) -> void:
	if not defeated(game) or _relic_received(game): return
	game.state.world.cave_arena.relic_awarded = true
	game.dropped_items.append({"kind":"moon_relic","count":1,"position":Data.BOSS,"location":Data.LOCATION})

## Восстанавливает совместимый прогресс и переносит прежний сундук, сохраняя его содержимое и открытие.
static func restore(game: Node, saved: Dictionary) -> void:
	game.state.world.cave_arena = {"relic_awarded":bool(saved.get("relic_awarded",false))}
	if _relic_received(game): game.state.world.cave_arena.relic_awarded = true
	for container in game.world_loot_nodes:
		if container.location == Data.LOCATION: container.position = Data.CHEST
	var index: int = game.CaveBossSystem.index(game)
	if index >= 0: game.enemy_nodes[index].position = Data.BOSS

## Находит следы старой сюжетной награды, чтобы обновление не создавало вторую реликвию.
static func _relic_received(game: Node) -> bool:
	if game.state.world.cave_arena.relic_awarded or game.inventory_item_count("moon_relic") > 0 or game.home_chest_counts.get("moon_relic",0) > 0: return true
	if game.mission_states.get("story_relic","") == game.QuestSystem.COMPLETED: return true
	return game.dropped_items.any(func(item): return item.kind == "moon_relic" and int(item.count) > 0)
