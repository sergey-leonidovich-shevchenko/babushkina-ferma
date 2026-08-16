extends "res://tests/suites/suite_base.gd"


## Запускает сценарии первого дня, фермерской жизни, коллекций, боя и интерфейса расширения.
func run() -> void:
	test_first_day_is_coherent_route()
	test_animals_feed_then_produce()
	test_museum_secrets_and_reputation()
	test_furniture_crafting_and_collision()
	test_birthdays_hearts_and_discount()
	test_combat_vulnerability_and_projectile()
	test_save_slots_compendium_and_photo_mode()
	test_expansion_atlas_and_tutorials()


## Сценарий: новый герой проходит последовательность от знакомства до первого поручения.
## Исходное состояние: чистая игра находится на первом шаге прибытия, нужные события ещё не отмечены.
## Ожидаемый результат: реальные события продвигают цель строго до шага сна и не перескакивают его.
func test_first_day_is_coherent_route() -> void:
	var game := make_game(); var life = game.FarmLifeSystem; var value: Dictionary = life.state(game)
	expect(value.first_day == 1 and life.first_day_objective(game).contains("бабуш"),"first day begins with arrival and grandmother objective")
	for event_name in ["talk","plant","shop"]: game.tutorial_events_completed[event_name]=true; life.update_first_day(game)
	game.quest_active=true; life.update_first_day(game)
	expect(value.first_day==5 and life.first_day_objective(game).contains("спать"),"first-day actions form an ordered route ending at sleep")
	game.free()


## Сценарий: построенный хлев связывает кормление сегодня с продуктом завтра.
## Исходное состояние: у героя есть пшеница, хлев третьего уровня и пустая дневная память Рябы.
## Ожидаемый результат: кормушка списывает одно зерно, а яйцо выдаётся один раз следующим утром.
func test_animals_feed_then_produce() -> void:
	var game := make_game(); game.state.world.estate.level=3; game.current_location="overworld"; game.day=3; game.change_inventory_count("wheat",1); var life=game.FarmLifeSystem
	expect(life.interact(game,"life:trough") and game.inventory_item_count("wheat")==0,"trough consumes exactly one wheat and feeds all animals")
	game.day=4; expect(life.interact(game,"life:animal:hen") and game.inventory_item_count("egg")==1,"fed hen produces one egg on the next morning")
	expect(life.interact(game,"life:animal:hen") and game.inventory_item_count("egg")==1,"animal product cannot be collected twice in one day")
	game.free()


## Сценарий: редкая находка становится экспонатом, а руна открывает физический клад.
## Исходное состояние: у героя один алмаз, музей и лесной механизм ещё не использованы.
## Ожидаемый результат: предмет удаляется в коллекцию, репутация растёт, секрет создаёт подбираемый лут один раз.
func test_museum_secrets_and_reputation() -> void:
	var game := make_game(); var life=game.FarmLifeSystem; var value: Dictionary=life.state(game); game.change_inventory_count("blue_gem",1)
	expect(life.donate_museum_item(game) and "blue_gem" in value.museum and game.inventory_item_count("blue_gem")==0 and value.reputation==5,"museum donation persists and raises village reputation")
	for kind in ["red_crystal","green_crystal"]: game.change_inventory_count(kind,1); life.donate_museum_item(game)
	expect(value.museum.size()==3 and game.inventory_item_count("museum_token")==1,"third museum exhibit grants unique curator token once")
	expect(life.activate_secret(game,"forest") and game.dropped_items.back().kind=="rare_seeds" and value.reputation==18,"secret mechanism reveals physical thematic loot")
	var drops: int=game.dropped_items.size(); life.activate_secret(game,"forest"); expect(game.dropped_items.size()==drops,"opened secret cannot duplicate its treasure")
	game.free()


## Сценарий: созданный стол устанавливается на сетку собственного дома.
## Исходное состояние: герой в коттедже, в инвентаре один стол, выбран первый рецепт мебели.
## Ожидаемый результат: предмет расходуется, сохраняется в усадьбе и его основание блокирует проход.
func test_furniture_crafting_and_collision() -> void:
	var game:=make_game(); var life=game.FarmLifeSystem; game.current_location="cottage_interior"; game.player=Vector2(420,330); game.change_inventory_count("rustic_table",1)
	expect(life.toggle_build_mode(game) and life.place_furniture(game),"home build mode places owned furniture")
	expect(game.inventory_item_count("rustic_table")==0 and life.state(game).furniture.size()==1 and life.blocks_position(game,game.player,game.PLAYER_RADIUS),"placed furniture persists and owns collision")
	game.free()


## Сценарий: календарь влияет на подарки, сердца отражают дружбу, репутация снижает цену.
## Исходное состояние: четвёртый день сезона — день рождения Мирона, дружба равна 21, репутация равна 50.
## Ожидаемый результат: любимый подарок удваивается, сердца округляются вверх, покупка дешевеет на десять процентов.
func test_birthdays_hearts_and_discount() -> void:
	var game:=make_game(); game.day=4; game.state.player.relationships.miron=21; game.change_inventory_count("carrot",1); game.FarmLifeSystem.state(game).reputation=50
	expect(game.FarmLifeSystem.birthday_npc(game)=="miron" and game.VillageLifeSystem.gift_value(game,"miron","carrot")==24,"birthday doubles the NPC-specific gift value")
	expect(game.FarmLifeSystem.hearts(game,"miron")==3 and is_equal_approx(game.EstateSystem.purchase_multiplier(game),0.9),"friendship hearts and reputation discount use persistent values")
	game.FarmLifeSystem.state(game).cutscene=""; game.state.player.relationships.miron=25; game.FarmLifeSystem.update_relationship_scenes(game); expect("miron:25" in game.FarmLifeSystem.state(game).relationship_scenes,"friendship threshold opens its relationship cutscene exactly once")
	game.free()


## Сценарий: лук попадает в уязвимое растение и создаёт отдельный видимый полёт.
## Исходное состояние: растение первого уровня стоит рядом, герой вооружён луком, серия ударов не критическая.
## Ожидаемый результат: урон умножается до двух, снаряд записан, а hit-stop активирован.
func test_combat_vulnerability_and_projectile() -> void:
	var game:=make_game(); game.current_location="forest"; game.player=Vector2(400,400); game.equipped_weapon="bow"; game.enemy_nodes=game.CombatSystem.default_enemies().slice(0,1); game.enemy_nodes[0].location="forest"; game.enemy_nodes[0].position=Vector2(450,400); var hp:int=game.enemy_nodes[0].hp
	var expected_damage:=roundi(game.CombatSystem.player_attack_damage(game)*game.FarmLifeSystem.vulnerability("plant","bow")); expect(game.CombatSystem.attack(game,0) and game.enemy_nodes[0].hp==hp-expected_damage,"weapon vulnerability multiplies combat damage")
	var value: Dictionary=game.FarmLifeSystem.state(game); expect(value.projectiles.size()==1 and value.projectiles[0].kind=="arrow" and value.hit_stop>0.0,"combat hit registers visible projectile and short hit stop")
	game.free()


## Сценарий: три сохранения и два новых интерфейсных режима управляются независимо.
## Исходное состояние: выбран первый слот, энциклопедия и фоторежим закрыты.
## Ожидаемый результат: пути различны, F2 меняет слот, V и P открывают соответствующие модальные режимы.
func test_save_slots_compendium_and_photo_mode() -> void:
	var game:=make_game(); var life=game.FarmLifeSystem
	expect(life.slot_path(1)!=life.slot_path(2) and life.slot_path(2)!=life.slot_path(3) and life.cycle_slot(game)==2,"three save slots have independent paths and cyclic selection")
	expect(life.handle_input(game,key_event(KEY_V,KEY_V,true)) and life.state(game).compendium,"V opens persistent collection compendium")
	life.handle_input(game,key_event(KEY_V,KEY_V,true)); expect(life.handle_input(game,key_event(KEY_P,KEY_P,true)) and life.state(game).photo_mode and life.modal_active(game),"P opens modal photo mode")
	game.free()


## Сценарий: фермерский атлас, мировые профили и подсказки соблюдают производственный контракт проекта.
## Исходное состояние: Godot импортировал строгий RGBA-атлас пять на четыре, локализация содержит шесть языков.
## Ожидаемый результат: все размеры кратны сетке, коллизии совпадают с профилями, а механики имеют обучение.
func test_expansion_atlas_and_tutorials() -> void:
	var game:=make_game(); var texture:Texture2D=game.FarmLifeRenderer.ATLAS; var image:=texture.get_image()
	expect(texture.get_size()==Vector2(640,512) and image.get_pixel(0,0).a<0.05,"farm-life atlas is transparent exact 5x4 production grid")
	expect(game.FarmLifeVisualSystem.profiles_are_valid() and game.FarmLifeVisualSystem.profile("cow").visual==Vector2(96,96) and game.FarmLifeVisualSystem.profile("trough").visual==Vector2(96,72),"farm-life world profiles use shared 72/96 px modules")
	var wardrobe_base:Rect2=game.FarmLifeVisualSystem.collision_rect("wooden_wardrobe",Vector2(320,320)); expect(wardrobe_base==Rect2(284,272,72,48),"furniture visual and collision share one bottom-center profile")
	game.state.world.estate.level=3; game.FarmLifeSystem.initialize(game); var farm_targets:Array=game.DebugObjectInspectorSystem.candidates(game).filter(func(candidate): return String(candidate.category)=="ФЕРМА"); expect(farm_targets.size()==4 and farm_targets.all(func(candidate): return is_equal_approx(float((candidate.bounds as Rect2).end.y),float(candidate.position.y))),"F10 inspector receives all three farm animals and trough from shared bottom anchors")
	expect(game.FarmLifeSystem.blocks_position(game,game.FarmLifeSystem.ANIMALS[0].position,game.PLAYER_RADIUS) and not game.FarmLifeSystem.blocks_position(game,Vector2(900,900),game.PLAYER_RADIUS),"farm-life navigation blocks visible bases without creating a broad invisible wall")
	var preview:=Image.load_from_file(ProjectSettings.globalize_path("res://assets/generated/level_drafts/farm_life_ingame_preview.png")); expect(preview!=null and preview.get_size()==Vector2i(1152,648),"farm-life migration keeps a current native gameplay preview for scale and anchor review")
	for event_name in ["animal_feed","animal_product","museum","secret_puzzle","furniture_place","photo_mode"]: expect(event_name in game.TutorialSystem.STEP_IDS and game.LocaleSystem.TUTORIAL[event_name].size()==6,"new feature has six-language tutorial: %s" % event_name)
	game.free()
