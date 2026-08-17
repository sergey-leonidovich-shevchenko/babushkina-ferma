extends "res://tests/suites/suite_base.gd"

## Запускает сценарии зданий, интерьеров, условий доступа и группы напарников.
func run() -> void:
	test_building_catalog_entry_exit_and_collision()
	test_automatic_building_transition_and_reentry_guard()
	test_automatic_cave_gate_and_portal_routes()
	test_progress_gated_buildings()
	test_castle_has_multiple_connected_locations()
	test_prison_recruitment_switching_and_capacity()
	test_companion_follow_combat_defense_and_healing()
	test_buildings_and_companions_are_saved_and_taught()


## Сценарий: восемь зданий отображаются, блокируют стены и имеют отдельные входы и выходы.
## Исходное состояние: новая игра в деревне, герой последовательно помещается у дома и его стен.
## Ожидаемый результат: каталог и атлас полны, дверь ведёт в малый интерьер, стены непроходимы, а выход возвращает наружу.
func test_building_catalog_entry_exit_and_collision() -> void:
	var game := make_game()
	expect(game.BuildingSystem.BUILDINGS.size() == 8, "eight distinct exterior buildings are configured")
	expect(game.BuildingSystem.INTERIORS.size() == 10, "buildings expose ten separate interior locations")
	expect(game.BuildingVisualSystem.TEXTURES.size()==8 and game.BuildingVisualSystem.PROFILES.size()==8, "eight independent building sprites own eight modular geometry profiles")
	for building_id in game.BuildingSystem.BUILDINGS:
		var profile:Dictionary=game.BuildingVisualSystem.profile(building_id); var texture:Texture2D=game.BuildingVisualSystem.texture(building_id); var image:Image=texture.get_image(); var destination:Rect2=game.BuildingSystem.destination_rect(building_id); var door_rect:Rect2=game.BuildingSystem.door_rect(building_id); var solids:Array[Rect2]=game.BuildingSystem.collision_rects(building_id)
		expect(game.BuildingVisualSystem.profile_is_valid(building_id) and destination.size==texture.get_size(), "%s facade uses a native crop-safe canvas on the 24 px grid"%building_id)
		expect(image.get_pixel(0,0).a==0.0 and image.get_pixel(image.get_width()-1,image.get_height()-1).a==0.0, "%s independent PNG has transparent corners without neighbour bleed"%building_id)
		expect(door_rect.size==Vector2(48,24) and solids.size()==2 and not solids[0].intersects(door_rect) and not solids[1].intersects(door_rect), "%s exposes a real two-cell doorway between split foundation collisions"%building_id)
	for preview_name in ["rocky","cursed","forest","ruins","collision"]:
		var preview:Image=Image.load_from_file(ProjectSettings.globalize_path("res://assets/generated/level_drafts/building_%s_ingame_preview.png"%preview_name))
		expect(preview!=null and preview.get_size()==Vector2i(1152,648), "%s keeps a current native gameplay preview for facade and collision review"%preview_name)
	var renderer_source:=FileAccess.get_file_as_string("res://scripts/game_renderer.gd"); var context_source:=FileAccess.get_file_as_string("res://scripts/game_context.gd"); var catalog_source:=FileAccess.get_file_as_string("res://scripts/systems/level_editor_asset_catalog_system.gd")
	expect(renderer_source.contains("BuildingVisualSystem.draw_building") and not renderer_source.contains("BUILDING_ATLAS") and not context_source.contains("building_atlas.png"), "runtime renders separate facades without fractional atlas source rectangles")
	expect(catalog_source.contains("SAFE_ATLAS_SLICES") and catalog_source.contains("and not SAFE_ATLAS_SLICES.has"), "level editor hides irregular source atlases while exposing only verified modular sheets")
	expect(game.DirectionalCharacterSystem.COMPANION_TEXTURES.size()==3 and game.DirectionalCharacterSystem.profiles_are_valid(), "three companions use the current directional sprite catalog")
	var cottage: Dictionary = game.BuildingSystem.BUILDINGS.cottage
	game.player = cottage.door
	expect(game.nearest_interaction() == "building:cottage", "cottage door receives the contextual interaction")
	expect(game.perform_context_action(), "unlocked cottage can be entered immediately")
	expect(game.current_location == "cottage_interior", "cottage uses a separate interior location")
	game.player = game.BuildingSystem.INTERIORS.cottage_interior.service_position
	expect(game.nearest_interaction() == "interior_service:bed", "cottage contains an interactive bed")
	var day_before_sleep: int = game.day
	expect(game.perform_context_action() and game.day == day_before_sleep + 1, "cottage bed completes the day")
	var room: Rect2 = game.BuildingSystem.INTERIORS.cottage_interior.room
	expect(game.NavigationSystem.is_walkable(game, room.get_center()), "cottage floor is walkable")
	expect(not game.NavigationSystem.is_walkable(game, room.position), "cottage walls block movement")
	game.player = game.BuildingSystem.INTERIORS.cottage_interior.exit
	expect(game.nearest_interaction() == "interior_exit" and game.perform_context_action(), "interior exit returns through the same building")
	expect(game.current_location == "overworld" and game.player.y > cottage.door.y, "hero appears outside below the cottage door")
	var cottage_wall:Vector2=game.BuildingSystem.collision_rects("cottage")[0].get_center()
	expect(not game.NavigationSystem.is_walkable(game,cottage_wall) and game.NavigationSystem.is_walkable(game,cottage.door), "exterior walls block movement while the unlocked 48 px doorway remains physically open")
	game.player = game.BuildingSystem.BUILDINGS.shop_house.door
	expect(game.BuildingSystem.enter(game, "shop_house"), "village shop has its own accessible interior")
	game.player = game.BuildingSystem.INTERIORS.shop_interior.service_position
	expect(game.perform_context_action() and game.shop_open, "shop counter opens the existing trade table")
	game.free()


## Сценарий: открытая дверь и выход срабатывают от подхода без кнопки, а точка появления не отправляет героя обратно.
## Исходное состояние: герой стоит непосредственно у двери доступного дома, система перехода взведена.
## Ожидаемый результат: вход и выход автоматические, звук мелодии проигрывается, повторный переход возможен только после выхода из зоны.
func test_automatic_building_transition_and_reentry_guard() -> void:
	var game := make_game()
	var cottage: Dictionary = game.BuildingSystem.BUILDINGS.cottage
	game.player = cottage.door
	expect(game.LocationTransitionSystem.update(game, 0.01), "approaching an unlocked building enters without pressing the action button")
	expect(game.current_location == "cottage_interior" and game.audio_last_sfx == "travel", "automatic building entry keeps location audio feedback")
	expect(game.tutorial_events_completed.has("building_enter"), "automatic doorway still completes the building tutorial")
	game.LocationTransitionSystem.update(game, 1.0)
	expect(game.current_location == "cottage_interior" and game.location_transition_armed, "interior spawn stays outside the exit trigger and safely rearms")
	game.player = game.BuildingSystem.INTERIORS.cottage_interior.exit
	expect(game.LocationTransitionSystem.update(game, 0.01) and game.current_location == "overworld", "approaching the interior exit returns outdoors without a button")
	expect(game.player.distance_to(cottage.door) > game.LocationTransitionSystem.TRIGGER_RADIUS, "outdoor spawn cannot immediately bounce back through the door")
	var outdoor_spawn: Vector2 = game.player
	expect(game.NavigationSystem.walkability_reason(game,outdoor_spawn)=="walkable", "cottage exit places the hero on a genuinely walkable road instead of the farm fence")
	for motion in [Vector2.LEFT*24.0,Vector2.RIGHT*24.0,Vector2.DOWN*24.0]:
		game.player=outdoor_spawn; game.NavigationSystem.move(game,motion)
		expect(game.player.distance_to(outdoor_spawn)>0.1, "hero can move immediately after leaving the cottage: %s"%motion)
	game.current_location = "rocky"; game.player = game.BuildingSystem.BUILDINGS.forge.door
	game.location_transition_armed = true; game.location_transition_cooldown = 0.0
	var sounds_before: int = game.audio_sfx_count
	expect(not game.LocationTransitionSystem.update(game, 0.01) and game.current_location == "rocky", "automatic transition respects a locked building")
	var sounds_after_lock: int = game.audio_sfx_count
	game.LocationTransitionSystem.update(game, 1.0)
	expect(sounds_after_lock == sounds_before + 1 and game.audio_sfx_count == sounds_after_lock, "locked door feedback does not repeat while the hero remains in its trigger")
	game.player += Vector2(100, 0); game.LocationTransitionSystem.update(game, 0.01)
	game.skill_levels.mining = 1; game.player = game.BuildingSystem.BUILDINGS.forge.door
	expect(game.LocationTransitionSystem.update(game, 0.01) and game.current_location == "forge_interior", "leaving and returning rearms an unlocked doorway")
	game.free()


## Сценарий: пещера, золотые врата и редкий портал используют тот же автоматический маршрут.
## Исходное состояние: герой последовательно ставится в активные зоны переходов, кнопка действия не вызывается.
## Ожидаемый результат: каждый маршрут меняет локацию один раз и лунный портал получает общий мелодичный эффект.
func test_automatic_cave_gate_and_portal_routes() -> void:
	var game := make_game()
	game.player = game.cave_entrance_position
	expect(game.LocationTransitionSystem.update(game, 0.01) and game.current_location == "cave", "cave entrance activates automatically")
	game.LocationTransitionSystem.update(game, 1.0); game.player = game.cave_exit_position
	expect(game.LocationTransitionSystem.update(game, 0.01) and game.current_location == "overworld", "cave exit activates automatically")
	game.current_location = "forest"; game.player = game.world_gate_position
	game.location_transition_armed = true; game.location_transition_cooldown = 0.0
	expect(game.LocationTransitionSystem.update(game, 0.01) and game.current_location == "rocky", "golden world gate advances the route without an action button")
	game.current_location = "overworld"; game.day = 5; game.game_minutes = 21.0 * 60.0
	game.player = game.WorldEventSystem.PORTAL_POSITION
	game.location_transition_armed = true; game.location_transition_cooldown = 0.0
	expect(game.LocationTransitionSystem.update(game, 0.01) and game.current_location == "moon_glade", "eclipse portal activates automatically when available")
	expect(game.audio_last_sfx == "travel", "moon portal uses the same melodic travel feedback")
	game.free()


## Сценарий: кузница, часовня, башня и замок открываются разными видами прогресса.
## Исходное состояние: новая игра без ремесленных рангов, ключа, завершённого сюжета и требуемого уровня.
## Ожидаемый результат: каждая дверь сначала отказывает, а затем открывается только после собственного условия.
func test_progress_gated_buildings() -> void:
	var game := make_game()
	game.current_location = "rocky"
	expect(not game.BuildingSystem.can_enter(game, "forge"), "forge starts locked without mining training")
	game.skill_levels.mining = 1
	expect(game.BuildingSystem.can_enter(game, "forge"), "mining rank one unlocks the forge")
	game.current_location = "cursed"
	expect(not game.BuildingSystem.can_enter(game, "chapel"), "moon chapel starts locked without an ancient key")
	game.change_inventory_count("ancient_key", 1)
	expect(game.BuildingSystem.can_enter(game, "chapel"), "ancient key unlocks the moon chapel")
	game.current_location = "forest"
	expect(not game.BuildingSystem.can_enter(game, "wizard_tower"), "wizard tower starts locked without mana mastery")
	game.skill_levels.mana = 2
	expect(game.BuildingSystem.can_enter(game, "wizard_tower"), "mana rank two unlocks the wizard tower")
	game.current_location = "ruins"
	game.player_level = 3
	expect(not game.BuildingSystem.can_enter(game, "moon_castle"), "level alone does not unlock the castle")
	game.mission_states.story_relic = game.QuestSystem.COMPLETED
	expect(game.BuildingSystem.can_enter(game, "moon_castle"), "completed relic story and level three unlock the castle")
	game.free()


## Сценарий: замок состоит из большого зала, верхнего этажа и отдельного подземелья.
## Исходное состояние: сюжет завершён, герой третьего уровня стоит у открытой двери замка.
## Ожидаемый результат: вход и оба перехода меняют локации, а обратные выходы возвращают в большой зал.
func test_castle_has_multiple_connected_locations() -> void:
	var game := make_game()
	game.current_location = "ruins"
	game.player_level = 3
	game.mission_states.story_relic = game.QuestSystem.COMPLETED
	game.player = game.BuildingSystem.BUILDINGS.moon_castle.door
	expect(game.BuildingSystem.enter(game, "moon_castle") and game.current_location == "castle_hall", "castle opens into a large great hall")
	expect(game.BuildingSystem.INTERIORS.castle_hall.room.size.x > 1500, "castle hall is larger than house interiors")
	expect(game.BuildingSystem.travel_inside(game, "castle_upper"), "great hall connects to the upper floor")
	expect(game.BuildingSystem.leave(game) and game.current_location == "castle_hall", "upper floor exit returns to the hall")
	expect(game.BuildingSystem.travel_inside(game, "castle_dungeon"), "great hall connects to the dungeon")
	expect(game.BuildingSystem.leave(game) and game.current_location == "castle_hall", "dungeon exit returns to the hall")
	game.player = game.BuildingSystem.INTERIORS.castle_hall.exit
	expect(game.BuildingSystem.leave(game) and game.current_location == "ruins", "castle front exit returns to the ruins")
	game.free()


## Сценарий: в тюрьме можно выкупать разных спутников, менять активного и расширить группу лидерством.
## Исходное состояние: герой в тюрьме с 500 монетами и нулевым рангом лидерства.
## Ожидаемый результат: Мила доступна сразу, сильные кандидаты требуют ранг, замена работает, а второй слот открывается на ранге 2.
func test_prison_recruitment_switching_and_capacity() -> void:
	var game := make_game()
	game.current_location = "prison_interior"
	game.coins = 500
	game.player = game.CompanionSystem.COMPANIONS.mila.position
	expect(game.nearest_interaction() == "prisoner:mila", "nearest prison cell highlights Mila")
	expect(game.perform_context_action(), "Mila can be released without leadership training")
	expect(game.recruited_companions == ["mila"] and game.active_companions == ["mila"], "first released companion joins the active party")
	var coins_after_mila: int = game.coins
	expect(coins_after_mila == 420, "releasing Mila charges her configured price")
	expect(not game.CompanionSystem.interact(game, "borislav"), "Borislav refuses a leader without rank one")
	game.skill_levels.leadership = 1
	expect(game.CompanionSystem.interact(game, "borislav"), "leadership rank one allows Borislav to be released")
	expect(game.active_companions == ["borislav"], "new companion replaces the active one while capacity is one")
	game.skill_levels.leadership = 2
	expect(game.CompanionSystem.capacity(game) == 2, "leadership rank two expands party capacity to two")
	expect(game.CompanionSystem.interact(game, "luna"), "leadership rank two allows healer Luna to be released")
	expect(game.active_companions == ["borislav", "luna"], "two different companions can be active together")
	expect(game.CompanionSystem.interact(game, "mila"), "an already recruited companion can be selected again")
	expect(game.active_companions == ["luna", "mila"], "selecting at full capacity replaces the oldest active companion")
	game.free()


## Сценарий: активные напарники следуют, атакуют, защищают и лечат согласно разным характеристикам.
## Исходное состояние: Мила и Луна активны в лесу рядом с раненым героем и хищным растением.
## Ожидаемый результат: позиции приближаются к герою, защита складывается, Луна лечит, а ближайший враг получает урон.
func test_companion_follow_combat_defense_and_healing() -> void:
	var game := make_game()
	game.skill_levels.leadership = 2
	game.recruited_companions.assign(["mila", "luna"])
	game.active_companions.assign(["mila", "luna"])
	game.current_location = "forest"
	game.player = game.enemy_nodes[0].position - Vector2(70, 0)
	game.player_hp = 50
	game.companion_positions = {"mila":game.player - Vector2(300, 0),"luna":game.player - Vector2(280, 0)}
	game.companion_heal_timer = 10.0
	var before_distance: float = game.companion_positions.mila.distance_to(game.player)
	game.CompanionSystem.update(game, 0.5)
	expect(game.companion_positions.mila.distance_to(game.player) < before_distance, "active companion follows the moving hero")
	expect(game.companion_moving.mila, "following companion switches from idle breathing to walking motion")
	expect(game.companion_directions.mila.x > 0.0, "following companion remembers its travel direction for sprite mirroring")
	expect(game.CompanionSystem.defense_bonus(game) == 4, "Mila and Luna combine their defense values")
	game.companion_heal_timer = 0.0
	game.CompanionSystem.update(game, 0.01)
	expect(game.player_hp == 54, "Luna periodically restores her configured four health")
	game.companion_positions.mila = game.enemy_nodes[0].position
	var enemy_hp: int = game.enemy_nodes[0].hp
	game.companion_attack_timer = 0.0
	game.CompanionSystem.update(game, 0.01)
	expect(game.enemy_nodes[0].hp == enemy_hp - 2, "Mila automatically deals her configured damage to a nearby enemy")
	game.free()


## Сценарий: состав группы, интерьер и новые этапы обучения переживают сохранение.
## Исходное состояние: герой находится на верхнем этаже замка с двумя нанятыми напарниками и лидерством 2.
## Ожидаемый результат: snapshot восстанавливает локацию и группу, а туториал содержит все новые пользовательские сценарии.
func test_buildings_and_companions_are_saved_and_taught() -> void:
	var game := make_game()
	game.skill_levels.leadership = 2
	game.recruited_companions.assign(["mila", "borislav", "luna"])
	game.active_companions.assign(["borislav", "luna"])
	game.current_location = "castle_upper"
	game.player = Vector2(620, 410)
	var snapshot: Dictionary = game.SaveSystem.snapshot(game)
	game.recruited_companions.clear()
	game.active_companions.clear()
	game.current_location = "overworld"
	expect(game.SaveSystem.apply(game, snapshot), "save applies building and companion state")
	expect(game.current_location == "castle_upper" and game.player == Vector2(620, 410), "save restores exact interior and position")
	expect(game.recruited_companions.size() == 3 and game.active_companions == ["borislav", "luna"], "save restores recruited and active companions")
	for event_name in ["building_enter", "locked_building", "castle_floor", "companion_recruit", "companion_change"]:
		expect(game.tutorial_steps.any(func(step): return step.event == event_name), "tutorial covers building feature: %s" % event_name)
	game.free()
