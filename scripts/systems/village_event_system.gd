extends RefCounted

const POSITIONS := {"market":Vector2(1250,500),"festival":Vector2(1420,520),"traveler":Vector2(1690,500),"raid":Vector2(930,470)}
const RAID_SPAWNS := [Vector2(870,690),Vector2(1050,720),Vector2(1220,690),Vector2(1110,610)]


## Возвращает память текущего события, совместимую со старыми сохранениями.
static func state(game: Node) -> Dictionary:
	var value: Dictionary = game.state.world.estate.get("event_state", {})
	if int(value.get("day", 0)) != game.day: value = {"day":game.day,"used":false,"spawned":false,"rewarded":false}
	game.state.world.estate.event_state = value; return value


## Подготавливает механику события дня и создаёт отряд нападения единственный раз.
static func update(game: Node) -> void:
	if game.current_location != "overworld": return
	var event := String(game.state.world.estate.event); var value := state(game)
	if event != "raid": cleanup_raid(game); return
	if event == "raid" and not bool(value.spawned):
		cleanup_raid(game)
		for index in RAID_SPAWNS.size():
			var level: int = clampi(1 + game.day / 7, 1, 5); var hp: int = int(game.CombatSystem.max_hp("orc", level))
			if index == RAID_SPAWNS.size()-1: level = mini(5,level+1); hp = game.CombatSystem.max_hp("orc",level)*2
			game.enemy_nodes.append({"kind":"orc","location":"overworld","position":RAID_SPAWNS[index],"home":RAID_SPAWNS[index],"level":level,"max_hp":hp,"hp":hp,"alive":true,"direction":Vector2.LEFT,"moving":false,"attack_timer":1.5 + index * 0.2,"visual_state":"idle","visual_time":0.0,"action_kind":game.CombatSystem.enemy_action_kind("orc"),"action_target":game.player,"event_raid":true,"event_raid_boss":index==RAID_SPAWNS.size()-1})
		value.spawned = true; game.state.world.estate.event_state = value; game.notify_tutorial("raid_event")
	if event == "raid" and bool(value.spawned) and not bool(value.rewarded) and raid_alive(game) == 0:
		value.rewarded = true; game.state.world.estate.event_state = value; game.coins += 120; game.award_xp(60,"combat"); var expansion: Dictionary = game.FarmLifeSystem.state(game); expansion.reputation = int(expansion.reputation)+10; game.message = "Капитан налётчиков побеждён • +120 монет • +60 опыта • репутация +10"; game.play_sfx("quest_complete")


## Удаляет завершённый временный отряд, не затрагивая постоянных противников мира.
static func cleanup_raid(game: Node) -> void:
	for index in range(game.enemy_nodes.size()-1,-1,-1):
		if bool(game.enemy_nodes[index].get("event_raid",false)): game.enemy_nodes.remove_at(index)


## Считает живых налётчиков текущего деревенского события.
static func raid_alive(game: Node) -> int:
	var result := 0
	for enemy in game.enemy_nodes:
		if bool(enemy.get("event_raid", false)) and bool(enemy.alive): result += 1
	return result


## Находит доступный объект текущего события с учётом времени ночного торговца.
static func nearest_interaction(game: Node, distance_limit: float) -> String:
	if game.current_location != "overworld": return ""
	var event := String(game.state.world.estate.event)
	if event == "traveler" and (game.game_minutes < 18.0 * 60.0 or game.game_minutes >= 24.0 * 60.0): return ""
	if not POSITIONS.has(event) or game.player.distance_to(POSITIONS[event]) >= distance_limit: return ""
	return "village_event:%s" % event


## Выполняет действие палатки, стола, ночного торговца или баррикады.
static func interact(game: Node, event: String) -> bool:
	var value := state(game)
	match event:
		"market": game.shop_open = true; game.shop_selected = 0; game.clear_movement_keys(); game.message = "Ярмарка: продажа урожая приносит на 15% больше"; game.notify_tutorial("market_event")
		"traveler": game.shop_open = true; game.shop_selected = 0; game.clear_movement_keys(); game.message = "Ночной торговец: покупки сегодня дешевле"; game.notify_tutorial("night_trader")
		"festival":
			if bool(value.used): game.message = "Ты уже отдохнул за праздничным столом сегодня"; return true
			game.player_hp = game.player_max_hp; game.energy = game.SkillSystem.max_stamina(game)
			for npc_id in game.QuestSystem.NPCS: game.state.player.relationships[npc_id] = mini(100,int(game.state.player.relationships.get(npc_id,0))+2)
			value.used = true; game.state.world.estate.event_state = value; game.message = "Праздничный пир восстановил силы • дружба со всеми +2"; game.notify_tutorial("festival_event")
		"raid": game.message = "За баррикадами ещё врагов: %d" % raid_alive(game)
		_: return false
	game.play_sfx("quest_accept"); return true


## Проверяет твёрдую баррикаду нападения, оставляя обход к каждому врагу.
static func blocks_position(game: Node, position: Vector2, radius: float) -> bool:
	if game.current_location != "overworld" or game.state.world.estate.event != "raid": return false
	return game.NavigationSystem.circle_intersects_rect(position, radius, Rect2(POSITIONS.raid - Vector2(70,24),Vector2(140,48)))
