extends "res://tests/suites/suite_base.gd"

const Loot := preload("res://scripts/systems/dropped_loot_system.gd")

## Проверяет движение и контакт добычи, остановку мира и сохранность каждого предмета.
func run() -> void:
	test_radius_contact_and_exact_stack()
	test_many_drops_locations_and_frame_rate()
	test_obstacles_stop_attraction()
	test_manual_drop_waits_until_hero_leaves()
	test_rejected_and_unique_pickups_are_lossless()
	test_pause_and_real_game_loop()
	test_save_roundtrip_and_old_records()
	test_legacy_slime_and_tutorial()

## Готовит настоящую модель в пустой части полигона с известной геометрией стен.
func prepare(game:Node) -> void:
	game.DebugPlaygroundSystem.configure(game); game.player=Vector2(400,600)
	game.FarmLifeSystem.state(game).cutscene=""; game.FirstChapterSystem.state(game).completed=true
	game.tutorial_visible=false; game.dropped_items.clear(); game.clear_movement_keys()

## Создаёт обычную физическую добычу в текущей локации без обхода игровой выдачи.
func drop(game:Node,offset:Vector2,kind:String="stone",count:int=3) -> Dictionary:
	var item:={"kind":kind,"count":count,"position":game.player+offset,"location":game.current_location}
	game.dropped_items.append(item); return item

## Сценарий: герой подходит к стеку снаружи двух клеток и касается его после притягивания.
## Исходное состояние: три камня лежат в97 пикселях, затем герой сокращает дистанцию до96.
## Ожидаемый результат: дальний предмет неподвижен, в радиусе плавно летит без ранней выдачи и целиком подбирается один раз.
func test_radius_contact_and_exact_stack() -> void:
	var game:=make_game(); prepare(game); var before:int=game.inventory_item_count("stone"); var energy:int=game.energy
	var item:=drop(game,Vector2(97,0)); var origin:Vector2=item.position
	Loot.update(game,0.05)
	expect(item.position==origin and game.inventory_item_count("stone")==before,"outside two 48px tiles loot remains on the ground")
	game.player.x+=1; Loot.update(game,0.05)
	expect(item.position.x<origin.x and game.dropped_items.size()==1 and game.inventory_item_count("stone")==before,"magnet moves the icon without granting distant inventory")
	Loot.update(game,1.0); Loot.update(game,1.0)
	expect(game.dropped_items.is_empty() and game.inventory_item_count("stone")==before+3,"contact grants the complete stack exactly once without overshooting")
	expect(game.energy==energy,"pickup does not spend stamina")
	drop(game,Vector2(Loot.PICKUP_RADIUS,0),"stone",2); Loot.update(game,0.001)
	expect(game.dropped_items.is_empty() and game.inventory_item_count("stone")==before+5,"touching the pickup boundary collects without pressing E")
	game.free()

## Сценарий: несколько стеков окружают героя, а один находится в другой комнате.
## Исходное состояние: три близких разных вида, чужая локация и два одинаковых стека для сравнения шага времени.
## Ожидаемый результат: обратный проход не пропускает предметы, чужая комната не меняется,30 и120 кадров дают одинаковое движение.
func test_many_drops_locations_and_frame_rate() -> void:
	var game:=make_game(); prepare(game); var stone:int=game.inventory_item_count("stone"); var wood:int=game.inventory_item_count("wood")
	drop(game,Vector2(10,0),"stone",2); drop(game,Vector2(-10,0),"wood",4); drop(game,Vector2(0,10),"stone",5)
	var foreign:=drop(game,Vector2.ZERO,"stone",9); foreign.location="cave_fungal"; var origin:Vector2=foreign.position
	Loot.update(game,0.1)
	expect(game.dropped_items.size()==1 and foreign.position==origin and int(foreign.count)==9,"foreign room retains its independent loot")
	expect(game.inventory_item_count("stone")==stone+7 and game.inventory_item_count("wood")==wood+4,"one frame receives every touching stack without index skips")
	var positions:Array[Vector2]=[]
	for fps in [30,120]:
		game.dropped_items.clear(); var item:=drop(game,Vector2(96,0))
		for _frame in int(fps*0.1): Loot.update(game,1.0/fps)
		positions.append(item.position)
	expect(positions[0].distance_to(positions[1])<0.01,"magnet speed is independent from render frequency")
	game.free()

## Сценарий: добыча за углом стены попадает в радиус притяжения.
## Исходное состояние: герой и предмет стоят на двух проходимых сторонах настоящего препятствия полигона.
## Ожидаемый результат: движение не прорезает угол стены и предмет остаётся на земле.
func test_obstacles_stop_attraction() -> void:
	var game:=make_game(); prepare(game); game.player=Vector2(670,440); var item:=drop(game,Vector2(40,50)); var origin:Vector2=item.position
	expect(game.NavigationSystem.is_walkable(game,game.player) and game.NavigationSystem.is_walkable(game,item.position),"wall fixture has valid positions on both sides of its corner")
	Loot.update(game,1.0)
	expect(game.dropped_items.size()==1 and item.position==origin,"magnet cannot pull loot through a solid corner")
	game.free()

## Сценарий: игрок выбрасывает предмет, отходит и позже возвращается.
## Исходное состояние: обычное действие выбрасывания создаёт защищённый от немедленного возврата стек.
## Ожидаемый результат: ожидание рядом не отменяет выбрасывание, а новый подход включает обычный автоподбор; E доступна сразу.
func test_manual_drop_waits_until_hero_leaves() -> void:
	var game:=make_game(); prepare(game); game.change_inventory_count("apple",2); var before:int=game.inventory_item_count("apple")
	game.inventory_selected=game.inventory_slots.find("apple"); game.facing=Vector2.RIGHT
	expect(game.drop_selected_item(),"regular inventory action creates a physical manual drop")
	var item:Dictionary=game.dropped_items[0]; var origin:Vector2=item.position
	Loot.update(game,2.0)
	expect(item.position==origin and game.inventory_item_count("apple")==before-1,"standing beside a manual drop does not immediately undo it")
	game.player=origin-Vector2(97,0); Loot.update(game,0.1)
	expect(not item.pickup_blocked,"leaving two cells arms the manually dropped item")
	game.player=origin-Vector2(80,0); Loot.update(game,1.0)
	expect(game.dropped_items.is_empty() and game.inventory_item_count("apple")==before,"returning collects the manually dropped item")
	game.drop_selected_item(); game.player=game.dropped_items[0].position
	expect(game.collect_dropped_item(0),"explicit E can recover a manual drop immediately")
	game.free()

## Сценарий: инвентарь отвергает вид, а на земле лежит несколько уникальных инструментов.
## Исходное состояние: неизвестный старый вид, отсутствующий счётчик досок, три кирки и одна уже имеющаяся кирка.
## Ожидаемый результат: отказ ничего не удаляет, новая кирка выдаётся по одной, повтор сохраняет весь остаток.
func test_rejected_and_unique_pickups_are_lossless() -> void:
	var game:=make_game(); prepare(game); var unknown:=drop(game,Vector2.ZERO,"unknown_old_item",4)
	var plank:=drop(game,Vector2(4,0),"plank",6); game.state.inventory.counts.erase("plank")
	game.has_pickaxe=false; var pickaxe:=drop(game,Vector2(0,4),"pickaxe",3)
	Loot.update(game,0.1); Loot.update(game,0.1)
	expect(game.has_pickaxe and int(pickaxe.count)==2 and game.dropped_items.has(pickaxe),"unique transfer grants one and retains the other two copies")
	expect(int(unknown.count)==4 and int(plank.count)==6 and game.dropped_items.size()==3,"rejected additions preserve every source item")
	expect(not game.collect_dropped_item(0) and not game.collect_dropped_item(1) and not game.collect_dropped_item(2),"manual pickup uses the same lossless transfer rules")
	game.free()

## Сценарий: настоящий физический цикл работает с добычей при игре и при открытых окнах.
## Исходное состояние: предмет лежит в двух клетках; последовательно открываются меню, разговор, пауза, экран поражения и редактор.
## Ожидаемый результат: остановленный мир не двигает добычу, а после закрытия обычный игровой цикл притягивает её.
func test_pause_and_real_game_loop() -> void:
	var game:=make_game(); prepare(game); var item:=drop(game,Vector2(80,0)); var origin:Vector2=item.position
	for flag in ["inventory_open","storage_open","crafting_open","shop_open","forge_open","quest_log_open","world_map_open","skill_menu_open","contract_open"]:
		game.set(flag,true); Loot.update(game,0.5); game._physics_process(0.5)
		expect(item.position==origin and game.dropped_items.size()==1,"loot stays paused under "+flag); game.set(flag,false)
	game.state.player.adventure_ui.dialogue_open=true; Loot.update(game,0.5)
	expect(item.position==origin,"dialogue pauses loot attraction"); game.state.player.adventure_ui.dialogue_open=false
	for flag in ["pause_open","settings_open","defeat_open"]:
		game.menu_state.set(flag,true); Loot.update(game,0.5)
		expect(item.position==origin,"system menu pauses loot: "+flag); game.menu_state.set(flag,false)
	game.player_hp=0; Loot.update(game,0.5)
	expect(item.position==origin,"a defeated hero does not receive automatic loot"); game.player_hp=game.player_max_hp
	game.language_screen=true; Loot.update(game,0.5)
	expect(item.position==origin,"language selection pauses loot"); game.language_screen=false
	var editor:Dictionary=game.get_meta(game.LevelEditorSystem.META_KEY,{})
	game.set_meta(game.LevelEditorSystem.META_KEY,{"active":true}); Loot.update(game,0.5)
	expect(item.position==origin,"level editing does not consume nearby physical loot"); game.set_meta(game.LevelEditorSystem.META_KEY,editor)
	game._physics_process(0.05)
	expect(item.position.distance_to(game.player)<80 and game.dropped_items.size()==1,"regular physics loop advances the magnet after player motion")
	game._physics_process(0.3)
	expect(game.dropped_items.is_empty(),"normal physics completes automatic contact collection")
	game.free()

## Сценарий: сохранение записывается посреди притягивания и после ручного выбрасывания.
## Исходное состояние: два стека с актуальными позициями, необязательной защитой и старой записью без этого поля.
## Ожидаемый результат: загрузка сохраняет позиции и количества, защита не теряется, старый лут притягивается, неверный тип отклоняется.
func test_save_roundtrip_and_old_records() -> void:
	var game:=make_game(); prepare(game); var item:=drop(game,Vector2(80,0)); Loot.update(game,0.05)
	var manual:=drop(game,Vector2(0,70),"wood",2); manual.pickup_blocked=true
	var snapshot:Dictionary=game.SaveSystem.snapshot(game)
	expect(game.SaveSystem.ValidationSystem.valid(snapshot),"new optional pickup field remains compatible with save validation")
	var restored:=make_game(); restored.set_meta(Loot.SLIME_POSITION,Vector2.ZERO); restored.SaveSystem.apply(restored,snapshot)
	expect(restored.dropped_items[0].position==item.position and restored.dropped_items[0].count==3 and restored.dropped_items[1].pickup_blocked,"save preserves moving stack and manual-drop protection")
	expect(not restored.dropped_items[0].has("pickup_blocked"),"old records without optional metadata keep normal automatic pickup")
	expect(not restored.has_meta(Loot.SLIME_POSITION),"loading discards a stale temporary slime-loot position")
	snapshot.drops[1].pickup_blocked="yes"
	expect(not game.SaveSystem.ValidationSystem.valid(snapshot),"malformed pickup protection is rejected before loading")
	game.free(); restored.free()

## Сценарий: герой касается добычи стартового сюжетного слизня.
## Исходное состояние: слизень побеждён, три единицы добычи ещё доступны, событие обучения не отмечено.
## Ожидаемый результат: слизь подбирается один раз без E, событие завершается, тело врага остаётся на месте.
func test_legacy_slime_and_tutorial() -> void:
	var game:=make_game(); prepare(game); game.current_location="overworld"; game.slime_alive=false; game.loot_available=true; game.player=game.slime_position
	var before:int=game.slime_gel; var corpse:Vector2=game.slime_position
	Loot.update(game,0.01); Loot.update(game,0.01)
	expect(game.slime_gel==before+3 and not game.loot_available and game.slime_position==corpse,"story slime shares automatic contact without duplicate reward or corpse movement")
	expect(game.tutorial_events_completed.has("loot"),"automatic pickup completes the existing loot tutorial")
	for locale in game.LocaleSystem.LOCALES:
		game.LocaleSystem.set_locale(locale); expect(not game.LocaleSystem.tutorial("loot").contains("[E]"),"loot hint teaches automatic pickup in "+locale)
	game.free()
