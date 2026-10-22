extends RefCounted

## Даёт временной сущности устойчивую идентичность, чтобы удаление другого миньона не подменяло цель.
static func identity(game: Node, actor: Dictionary) -> int:
	if not actor.has("attack_uid"):
		var serial := int(game.get_meta("attack_target_serial",0))+1
		game.set_meta("attack_target_serial",serial); actor.attack_uid=serial
	return int(actor.attack_uid)

## Собирает живые тела текущей комнаты с физическими радиусами, исключая ещё появляющихся миньонов.
static func all(game: Node) -> Array:
	var result := []
	for index in game.enemy_nodes.size():
		var enemy: Dictionary = game.enemy_nodes[index]
		if not enemy.alive or enemy.location!=game.current_location: continue
		if enemy.get("cave_boss",false) and not game.state.world.cave_boss.active: continue
		result.append({"category":"enemy","index":index,"uid":identity(game,enemy),"position":enemy.position,"radius":48.0 if enemy.get("cave_boss",false) else 30.0,"kind":enemy.kind})
	for index in game.wildlife_nodes.size():
		var animal: Dictionary = game.wildlife_nodes[index]
		if animal.alive and animal.location==game.current_location:
			result.append({"category":"wildlife","index":index,"uid":identity(game,animal),"position":animal.position,"radius":22.0,"kind":animal.kind})
	if game.current_location==game.CaveBossSystem.Data.LOCATION and game.state.world.cave_boss.active:
		for index in game.state.world.cave_boss.minions.size():
			var minion: Dictionary = game.state.world.cave_boss.minions[index]
			if minion.alive and float(minion.emerge)<=0.0:
				result.append({"category":"minion","index":index,"uid":identity(game,minion),"position":minion.position,"radius":22.0,"kind":minion.kind})
	if game.current_location=="overworld" and game.slime_alive:
		result.append({"category":"slime","index":0,"uid":0,"position":game.slime_position,"radius":28.0,"kind":"slime"})
	if game.current_location=="moon_glade" and game.state.world.moon_glade.guardian_alive:
		result.append({"category":"moon","index":0,"uid":0,"position":game.MoonGladeSystem.GUARDIAN_POSITION,"radius":34.0,"kind":"eclipse_guardian"})
	if game.current_location=="castle_dungeon" and game.state.world.castle_campaign.boss_alive:
		result.append({"category":"castle","index":0,"uid":0,"position":game.CastleCampaignSystem.BOSS_POSITION,"radius":34.0,"kind":"shadow_regent"})
	return result

## Находит ту же живую цель после перемещения или уплотнения массива призванных существ.
static func find(game: Node, category: String, index: int, uid: int = 0) -> Dictionary:
	for target in all(game):
		if target.category==category and (int(target.uid)==uid if uid>0 else int(target.index)==index): return target
	return {}

## Передаёт подтверждённый контакт в соответствующий конвейер здоровья и наград ровно один раз.
static func damage(game: Node, target: Dictionary, amount: int) -> bool:
	match String(target.category):
		"enemy": return game.CombatSystem.apply_damage(game,int(target.index),amount)
		"wildlife": return game.WildlifeSystem.apply_damage(game,int(target.index),amount)
		"minion": return game.CaveBossSystem.Minions.damage(game,int(target.index),amount)
		"slime": return game.apply_slime_damage(amount)
		"moon": return game.MoonGladeSystem.apply_guardian_damage(game,amount)
		"castle": return game.CastleCampaignSystem.apply_boss_damage(game,amount)
	return false
