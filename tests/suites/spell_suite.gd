extends "res://tests/suites/suite_base.gd"

## Запускает сценарии выбора, лечения, дальнего и массового заклинания, устройств ввода и сохранения.
func run() -> void:
	test_spell_selection_localization_and_input_actions()
	test_healing_obeys_mana_health_and_cooldown()
	test_arcane_bolt_and_frost_nova_use_real_combat_targets()
	test_magic_profile_survives_save_roundtrip()

## Сценарий: три заклинания циклически выбираются и имеют локализацию вместе с переназначаемыми действиями.
## Исходное состояние: новый герой с магической стрелой в первом слоте магии.
## Ожидаемый результат: цикл охватывает все варианты, тексты шести языков непустые, InputMap содержит команды магии.
func test_spell_selection_localization_and_input_actions() -> void:
	var game:=make_game(); var magic:Variant=game.SpellSystem
	expect(String(magic.selected(game).id)=="arcane_bolt","magic starts with the ranged arcane bolt")
	expect(magic.cycle(game)=="healing_light" and magic.cycle(game)=="frost_nova" and magic.cycle(game)=="arcane_bolt","spell cycling wraps through all three roles")
	expect(InputMap.has_action("cast_spell") and InputMap.has_action("cycle_spell"),"magic uses rebindable InputMap actions")
	for locale in game.LocaleSystem.LOCALES:
		game.LocaleSystem.current=locale; expect(not magic.word(game,"frost_nova").is_empty(),"spell names are localized for %s"%locale)
	game.LocaleSystem.current="ru"; game.free()

## Сценарий: лечение не тратит ману при полном HP, затем восстанавливает здоровье и уходит на перезарядку.
## Исходное состояние: выбран целительный свет, запас маны полный, здоровье сначала полное, затем повреждённое.
## Ожидаемый результат: невалидный каст бесплатен, успешный ограничен максимумом, повтор запрещён до окончания таймера.
func test_healing_obeys_mana_health_and_cooldown() -> void:
	var game:=make_game(); var magic:Variant=game.SpellSystem; magic.state(game).selected=1; var mana:int=game.player_mana
	expect(not magic.cast(game) and game.player_mana==mana,"healing at full health does not waste mana")
	game.player_hp=40; expect(magic.cast(game) and game.player_hp==75 and game.player_mana==mana-12,"healing light restores exact base health and spends mana")
	expect(not magic.cast(game) and game.player_mana==mana-12 and magic.selected_cooldown(game)>0.0,"spell cooldown prevents duplicate mana spending")
	magic.update(game,5.1); expect(magic.selected_cooldown(game)==0.0,"cooldown advances by simulation delta")
	game.free()

## Сценарий: стрела выбирает врага на дистанции, а ледяная волна поражает и замедляет несколько близких целей.
## Исходное состояние: два живых слизня стоят на разных дистанциях от героя с полным запасом маны.
## Ожидаемый результат: дальний каст бьёт ближайшего, волна затрагивает обе цели в радиусе и создаёт мировой эффект.
func test_arcane_bolt_and_frost_nova_use_real_combat_targets() -> void:
	var game:=make_game(); var magic:Variant=game.SpellSystem; game.current_location="overworld"; game.player=Vector2(500,500)
	game.enemy_nodes=game.CombatSystem.default_enemies().slice(0,2)
	for index in game.enemy_nodes.size(): game.enemy_nodes[index].location="overworld"; game.enemy_nodes[index].position=game.player+Vector2(120+index*30,0); game.enemy_nodes[index].hp=20; game.enemy_nodes[index].alive=true
	var first_hp:int=game.enemy_nodes[0].hp; expect(magic.cast(game) and game.enemy_nodes[0].hp<first_hp,"arcane bolt reaches the nearest target beyond melee range")
	magic.state(game).selected=2; var hp_values:=[int(game.enemy_nodes[0].hp),int(game.enemy_nodes[1].hp)]; expect(magic.cast(game),"frost nova casts when enemies occupy its radius")
	expect(game.enemy_nodes[0].hp<hp_values[0] and game.enemy_nodes[1].hp<hp_values[1],"frost nova damages every nearby enemy")
	expect(game.enemy_nodes.all(func(enemy): return float(enemy.attack_timer)>=1.8) and not magic.state(game).effects.is_empty(),"frost nova delays attacks and records visible feedback")
	game.free()

## Сценарий: выбранная школа и перезарядки проходят через стандартный профиль сохранения.
## Исходное состояние: выбрана ледяная волна и записана незавершённая перезарядка.
## Ожидаемый результат: после save/load выбранный индекс и таймер полностью восстановлены.
func test_magic_profile_survives_save_roundtrip() -> void:
	var game:=make_game(); var magic:Variant=game.SpellSystem; var value:Dictionary=magic.state(game); value.selected=2; value.cooldowns.frost_nova=2.5
	var snapshot:Dictionary=game.SaveSystem.snapshot(game); var restored:=make_game(); expect(game.SaveSystem.apply(restored,snapshot),"save accepts persistent magic profile")
	var loaded:Dictionary=magic.state(restored); expect(loaded.selected==2 and is_equal_approx(float(loaded.cooldowns.frost_nova),2.5),"selected spell and cooldown survive save roundtrip")
	game.free(); restored.free()
