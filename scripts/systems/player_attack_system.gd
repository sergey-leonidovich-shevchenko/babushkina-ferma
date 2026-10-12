extends RefCounted

const KEY := &"player_attack_pending"
const Targets := preload("res://scripts/systems/player_attack_targets.gd")
const Projectiles := preload("res://scripts/systems/player_projectile_system.gd")

## Запускает подготовку проверенной цели, фиксируя оружие, направление, урон и один расход прочности.
static func begin(game: Node, category: String, index: int = 0) -> bool:
	if game.GameLoop.gameplay_window_open(game) or game.GameLoop.modal_active(game): return false
	if not game.WeaponSystem.can_start_attack(game): return false
	var target := Targets.find(game,category,index)
	if target.is_empty() or game.player.distance_to(target.position)>game.WeaponSystem.range_of(game.equipped_weapon): return false
	var aim: Vector2 = game.player.direction_to(target.position)
	if aim.is_zero_approx(): aim=game.facing.normalized()
	game.facing=game.HeroActionSystem.cardinal(aim)
	if not game.WeaponSystem.begin_attack(game): return false
	game.remove_meta(game.HeroActionSystem.META)
	var power_strike: bool = game.TalentSystem.has(game,"combat_power_strike")
	var amount: int = game.CombatSystem.player_attack_damage(game)
	if power_strike and posmod(game.state.player.combat_hits+1,4)==0: amount-=2
	var weapon: String = game.player_attack_weapon
	var ranged: bool = game.WeaponSystem.weapon_class(weapon) in ["bow","staff"]
	game.set_meta(KEY,{"category":category,"index":int(target.index),"uid":int(target.uid),"weapon":weapon,"aim":aim,"damage":amount,"power_strike":power_strike,"location":game.current_location,"elapsed":0.0,"contact":game.WeaponSystem.attack_duration(game)*(0.62 if ranged else 0.43)})
	game.PotionSystem.break_invisibility(game)
	game.AdventurePolishSystem.consume_durability(game,game.WeaponSystem.durability_kind(weapon))
	game.play_sfx("attack"); game.notify_tutorial("combat_animation"); game.notify_tutorial("player_contact")
	return true

## Продвигает существующие снаряды и единственную фазу контакта, учитывая остаток большого кадра после выпуска.
static func update(game: Node, delta: float) -> void:
	if game.GameLoop.gameplay_window_open(game) or game.GameLoop.modal_active(game): return
	Projectiles.update(game,maxf(delta,0.0))
	var attack: Dictionary = game.get_meta(KEY,{})
	if attack.is_empty(): return
	if attack.location!=game.current_location or game.player_attack_timer<=0.0: cancel(game); return
	attack.elapsed=float(attack.elapsed)+maxf(delta,0.0)
	if float(attack.elapsed)<float(attack.contact): game.set_meta(KEY,attack); return
	game.remove_meta(KEY)
	var kind: String = game.WeaponSystem.weapon_class(attack.weapon)
	if kind in ["bow","staff"]:
		Projectiles.launch(game,attack,float(attack.elapsed)-float(attack.contact)); return
	var target := Targets.find(game,String(attack.category),int(attack.index),int(attack.uid))
	if target.is_empty(): return
	var origin: Vector2 = game.player
	var tip: Vector2 = origin+Vector2(attack.aim)*game.WeaponSystem.range_of(attack.weapon)
	var width: float = {"blade":20.0,"spear":9.0,"heavy":25.0,"unarmed":12.0}.get(kind,20.0)
	if origin.direction_to(target.position).dot(attack.aim)<0.0: return
	if Geometry2D.get_closest_point_to_segment(target.position,origin,tip).distance_to(target.position)>float(target.radius)+width: return
	if not clear_line(game,origin,target.position): return
	contact(game,attack,target)

## Не позволяет ближнему оружию бить сквозь скалу, постройку или другое сплошное препятствие.
static func clear_line(game: Node, origin: Vector2, target: Vector2) -> bool:
	var steps := maxi(1,ceili(origin.distance_to(target)/6.0))
	for step in range(1,steps+1):
		if game.NavigationSystem.walkability_reason(game,origin.lerp(target,float(step)/steps),-1,false) not in ["walkable","guardian"]: return false
	return true

## Применяет снимок урона при реальном попадании; промахи не повышают серию критических ударов.
static func contact(game: Node, attack: Dictionary, target: Dictionary) -> bool:
	var critical: bool = posmod(game.state.player.combat_hits+1,4)==0
	var base := int(attack.damage)+(2 if critical and bool(attack.power_strike) else 0)
	var amount: int = roundi(base*game.FarmLifeSystem.vulnerability(target.kind,attack.weapon))*(2 if critical else 1)
	if not Targets.damage(game,target,amount): return false
	game.state.player.combat_hits+=1
	if critical: game.notify_tutorial("critical_hit")
	game.FarmLifeSystem.register_player_attack(game,target.position,critical)
	return true

## Отменяет не выпущенный замах при входящем уроне, сохраняя уже летящие стрелы и перезарядку.
static func cancel(game: Node) -> void:
	game.remove_meta(KEY)

## Убирает временные атаки и снаряды при загрузке, поражении или смене игрового цикла.
static func reset(game: Node) -> void:
	cancel(game); Projectiles.reset(game)
	game.player_attack_timer=0.0; game.player_attack_cooldown=0.0; game.player_hurt_timer=0.0
	game.remove_meta(game.HeroActionSystem.META)
