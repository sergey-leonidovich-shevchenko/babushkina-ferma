class_name SpellSystem
extends RefCounted

const SPELLS := [
	{"id":"arcane_bolt","icon":"✦","cost":8,"cooldown":1.2,"range":420.0},
	{"id":"healing_light","icon":"❤","cost":12,"cooldown":5.0,"range":0.0},
	{"id":"frost_nova","icon":"❄","cost":16,"cooldown":4.0,"range":175.0},
]
const WORDS := {
	"arcane_bolt":["Магическая стрела","Arcane bolt","Proyectil arcano","Arkanes Geschoss","Projectile arcanique","奥术飞弹"],
	"healing_light":["Целительный свет","Healing light","Luz sanadora","Heilendes Licht","Lumière curative","治疗之光"],
	"frost_nova":["Ледяная волна","Frost nova","Nova de hielo","Frostnova","Nova de givre","冰霜新星"],
	"no_mana":["Недостаточно маны: нужно %d","Not enough mana: %d required","Maná insuficiente: se necesitan %d","Nicht genug Mana: %d benötigt","Mana insuffisant : %d requis","法力不足：需要%d"],
	"cooldown":["Заклинание восстановится через %.1f с","Spell ready in %.1f s","Hechizo listo en %.1f s","Zauber bereit in %.1f s","Sort prêt dans %.1f s","法术将在%.1f秒后就绪"],
	"no_target":["В пределах заклинания нет цели","No target within spell range","No hay objetivo al alcance","Kein Ziel in Reichweite","Aucune cible à portée","施法范围内没有目标"],
	"full_health":["Здоровье уже полностью восстановлено","Health is already full","La salud ya está completa","Gesundheit ist bereits voll","La santé est déjà pleine","生命值已经全满"],
	"selected":["Выбрано заклинание: %s","Selected spell: %s","Hechizo elegido: %s","Zauber gewählt: %s","Sort choisi : %s","已选择法术：%s"],
}

## Возвращает сохранённое магическое состояние и дополняет старый профиль выбранным заклинанием и таймерами.
static func state(game: Node) -> Dictionary:
	var value: Dictionary = game.state.player.profile.get("magic",{})
	var defaults := {"selected":0,"cooldowns":{},"effects":[]}
	for key in defaults:
		if not value.has(key): value[key]=defaults[key]
	game.state.player.profile.magic=value; return value

## Возвращает локализованное название или служебное сообщение магии.
static func word(game: Node, key: String, values: Array = []) -> String:
	var variants: Array=WORDS.get(key,[key,key,key,key,key,key]); var locale_index:=maxi(game.LocaleSystem.LOCALES.find(game.LocaleSystem.current),0); var result:=String(variants[locale_index])
	return result % values if not values.is_empty() else result

## Возвращает выбранное заклинание по безопасно ограниченному индексу.
static func selected(game: Node) -> Dictionary:
	return SPELLS[clampi(int(state(game).selected),0,SPELLS.size()-1)]

## Переключает активное заклинание по кругу без расхода маны.
static func cycle(game: Node, direction: int = 1) -> String:
	var value:=state(game); value.selected=posmod(int(value.selected)+direction,SPELLS.size()); var spell:Dictionary=selected(game); game.message=word(game,"selected",[word(game,String(spell.id))]); game.notify_tutorial("magic_cycle"); return String(spell.id)

## Обновляет независимые перезарядки и короткие мировые эффекты без привязки к FPS.
static func update(game: Node, delta: float) -> void:
	var value:=state(game)
	for spell_id in value.cooldowns: value.cooldowns[spell_id]=maxf(0.0,float(value.cooldowns[spell_id])-delta)
	for effect in value.effects: effect.timer=maxf(0.0,float(effect.timer)-delta)
	value.effects=value.effects.filter(func(effect): return float(effect.timer)>0.0)

## Проверяет ману и перезарядку, затем применяет одно из трёх боевых или лечебных заклинаний.
static func cast(game: Node) -> bool:
	var value:=state(game); var spell:Dictionary=selected(game); var spell_id:=String(spell.id); var remaining:=float(value.cooldowns.get(spell_id,0.0))
	if remaining>0.0: game.message=word(game,"cooldown",[remaining]); return false
	if game.player_mana<int(spell.cost): game.message=word(game,"no_mana",[spell.cost]); return false
	var success:=false
	if spell_id=="healing_light":
		if game.player_hp>=game.player_max_hp: game.message=word(game,"full_health"); return false
		game.player_hp=mini(game.player_max_hp,game.player_hp+35+game.SkillSystem.skill(game,"mana")*3); success=true
	elif spell_id=="arcane_bolt":
		var index:=nearest_enemy(game,float(spell.range))
		if index>=0: success=game.CombatSystem.apply_damage(game,index,4+game.SkillSystem.skill(game,"mana")/2,"Магия")
	else:
		for index in game.enemy_nodes.size():
			var enemy:Dictionary=game.enemy_nodes[index]
			if enemy.alive and enemy.location==game.current_location and game.player.distance_to(enemy.position)<=float(spell.range):
				if game.CombatSystem.apply_damage(game,index,2+game.SkillSystem.skill(game,"mana")/3,"Мороз"): game.enemy_nodes[index].attack_timer=float(game.enemy_nodes[index].attack_timer)+1.8; success=true
	if not success: game.message=word(game,"no_target"); return false
	game.player_mana-=int(spell.cost); value.cooldowns[spell_id]=float(spell.cooldown); value.effects.append({"kind":spell_id,"position":game.player,"timer":0.45}); game.play_sfx("attack"); game.notify_tutorial("magic_cast"); return true

## Находит ближайшего живого врага в радиусе заклинания независимо от экипированного оружия.
static func nearest_enemy(game: Node, maximum_distance: float) -> int:
	var result:=-1; var best:=maximum_distance
	for index in game.enemy_nodes.size():
		var enemy:Dictionary=game.enemy_nodes[index]
		if enemy.alive and enemy.location==game.current_location:
			var distance:float=game.player.distance_to(enemy.position)
			if distance<best: best=distance; result=index
	return result

## Возвращает оставшееся время перезарядки выбранного заклинания.
static func selected_cooldown(game: Node) -> float:
	var spell:Dictionary=selected(game); return float(state(game).cooldowns.get(String(spell.id),0.0))
