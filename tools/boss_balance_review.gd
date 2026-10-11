extends SceneTree

const Game := preload("res://scripts/game.gd")
const Boss := preload("res://scripts/systems/cave_boss_system.gd")
const Arena := preload("res://scripts/systems/cave_boss_arena_system.gd")
const Attacks := preload("res://scripts/systems/cave_boss_attack_system.gd")
const STEP := 1.0/60.0

## Повторяет ограниченные бои без бессмертия, усилений, телепортаций или изменения урона.
func _initialize() -> void:
	var results: Array = []
	for weapon in ["forest_sword","iron_spear","bow"]:
		for world_seed in [7,23,61]: results.append(battle(weapon,world_seed))
	var path := "res://docs/reports/five-priorities-2026-10-11/balance/before.json"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): path=argument.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify({"schema":1,"step":STEP,"note":"Deterministic steering probe, not a human difficulty claim. Level 1, no armor/talents/companions/buffs, 4 apples, no god mode, no dodge. Decisions every 250 ms; real Navigation.move and public attacks/food.","battles":results},"  ")+"\n")
	print("BOSS BALANCE: ",JSON.stringify(results)); quit()

## Ведёт обычного героя с настоящей прочностью и едой; каждые четверть секунды выбирает безопасный ответ.
func battle(weapon: String, world_seed: int) -> Dictionary:
	seed(world_seed)
	var game := Game.new(); game._ready(); Boss.configure_preview(game)
	game.change_inventory_count("apple",4-game.inventory_item_count("apple"))
	var item: String = game.WeaponSystem.item_kind(weapon)
	if game.inventory_item_count(item)==0: game.change_inventory_count(item,1)
	if game.equipped_weapon != weapon: game.InventorySystem.equip(game,item)
	assert(game.equipped_weapon == weapon,"Balance probe must actually equip the requested weapon")
	Arena.activate(game)
	game.AudioSystem.set_enabled(game,false)
	var boss_index := Boss.index(game)
	var target: Vector2 = game.player
	var phases := {}; var attacks := {}; var hits:=0; var healing:=0; var damage:=0; var peak:=0
	var elapsed := 0.0
	var loadout := {"hp":game.player_hp,"maximum":game.player_max_hp,"damage":game.CombatSystem.player_attack_damage(game),"weapon":game.equipped_weapon,"apples":game.inventory_item_count("apple")}
	for tick in 10800:
		elapsed=tick*STEP
		if game.menu_state.defeat_open or not game.enemy_nodes[boss_index].alive: break
		var state: Dictionary = game.state.world.cave_boss
		phases[str(state.phase)] = float(phases.get(str(state.phase),0.0))+STEP
		if not state.attack.is_empty(): attacks[state.attack.id]=true
		peak=maxi(peak,Boss.Minions.living_count(game))
		if tick%15==0:
			target=choose_target(game,game.enemy_nodes[boss_index])
			if game.player_hp<=55 and game.PotionSystem.consume(game,"apple"): healing+=1
		if game.player.distance_to(target)>3:
			var direction: Vector2 = game.player.direction_to(target)
			game.facing=direction
			game.NavigationSystem.move(game,direction*game.speed*STEP)
		if game.attack_nearest_enemy(): hits+=1
		var hp: int = game.player_hp
		Boss.update(game,STEP); game.AnimationSystem.update(game,STEP); game.update_status_effects(STEP)
		damage+=maxi(0,hp-game.player_hp)
	var result := {"weapon":weapon,"seed":world_seed,"seconds":snappedf(elapsed,0.01),"victory":not game.enemy_nodes[boss_index].alive,"defeat":game.menu_state.defeat_open,"boss_hp":game.enemy_nodes[boss_index].hp,"hero_hp":game.player_hp,"hero_max_hp":game.player_max_hp,"damage_received":damage,"apples_used":healing,"accepted_attacks":hits,"peak_minions":peak,"phase_seconds":phases,"attacks_seen":attacks.keys(),"weapon_durability":game.state.inventory.durability.get(item,-1),"player_damage":game.CombatSystem.player_attack_damage(game)}
	result.initial_loadout=loadout
	game.free(); return result

## Предпочитает доступный ответный удар, а во время предупреждения выбирает безопасную физическую точку рядом.
func choose_target(game: Node, boss: Dictionary) -> Vector2:
	var state: Dictionary = game.state.world.cave_boss
	var desired: float = game.WeaponSystem.range_of(game.equipped_weapon)-24.0
	var enemy: Vector2 = boss.position
	var direction: Vector2 = enemy.direction_to(game.player)
	var best: Vector2 = game.player
	var score := INF
	for index in 24:
		var candidate := enemy + direction.rotated((index-12)*TAU/24.0)*desired
		if not game.NavigationSystem.is_walkable(game,candidate): continue
		var danger:=false
		for area in state.zones:
			if float(state.attack.get("elapsed",0))>float(area.trigger)+1.0: continue
			if area.shape=="charge": danger=Geometry2D.get_closest_point_to_segment(candidate,area.position,area.end).distance_to(candidate)<65
			else: danger=Attacks.contains(area,candidate,maxf(0,float(state.attack.get("elapsed",0))-float(area.trigger)))
			if danger: break
		var value: float = candidate.distance_to(game.player)+(1000.0 if danger else 0.0)
		if value<score: score=value; best=candidate
	if score>=1000:
		var away: Vector2 = game.player + enemy.direction_to(game.player)*90
		if game.NavigationSystem.is_walkable(game,away): return away
	return best
