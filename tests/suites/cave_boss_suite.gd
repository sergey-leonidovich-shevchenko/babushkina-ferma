extends "res://tests/suites/suite_base.gd"

const Boss := preload("res://scripts/systems/cave_boss_system.gd")
const Data := preload("res://scripts/systems/cave_boss_data.gd")
const Attacks := preload("res://scripts/systems/cave_boss_attack_system.gd")

## Запускает проверки стадий, предупреждений, геометрии атак, паузы и постоянного результата боя.
func run() -> void:
	test_three_phases_have_twelve_distinct_mechanics()
	test_guardian_uses_custom_ai_and_phase_transition_grace()
	test_all_attacks_warn_before_damage_and_offer_recovery()
	test_geometry_projectiles_and_multi_step_attacks()
	test_pause_exit_victory_and_save_cleanup()
	test_tutorial_and_localized_attack_labels()
	test_legacy_guardian_progress_and_playable_preview()
	test_defeat_returns_to_safe_cave_entry()

## Создаёт изолированный бой на сухой части действующего святилища.
func battle() -> Node:
	var game := make_game()
	game.current_location = Data.LOCATION; game.player = Vector2(1584,648)
	game.enemy_nodes[Boss.index(game)].position = Vector2(1728,648)
	Boss.start(game)
	return game

## Сценарий: три стадии открывают собственные наборы из четырёх различных атак.
## Исходное состояние: хранитель имеет 120 HP и каталог из двенадцати механик.
## Ожидаемый результат: точные пороги 80 и 40 включают новые стадии, предупреждения не короче 0,9 секунды.
func test_three_phases_have_twelve_distinct_mechanics() -> void:
	for sample in [[120,1],[81,1],[80,2],[41,2],[40,3],[1,3]]:
		expect(Data.phase(sample[0]) == sample[1], "guardian phase uses exact health threshold: " + str(sample))
	var ids: Array = []
	for phase in Data.PHASES:
		expect(phase.size() == 4,"each guardian phase has four mechanics")
		for id in phase:
			expect(not ids.has(id) and Data.ATTACKS.has(id),"guardian attack is unique and implemented: " + id)
			expect(float(Data.ATTACKS[id].windup) >= 0.9 and float(Data.ATTACKS[id].recovery) >= 1.0,"attack has a fair windup and recovery: " + id)
			ids.append(id)
	expect(ids.size() == 12,"guardian exposes twelve independent attack mechanics")

## Сценарий: обычный AI не наносит второй скрытый удар, а переход стадии отменяет старую угрозу.
## Исходное состояние: герой стоит у хранителя, затем атакует во время замаха и пересекает оба порога здоровья.
## Ожидаемый результат: стандартный AI пропускает босса, замахи и снаряды отменяются, начинается передышка.
func test_guardian_uses_custom_ai_and_phase_transition_grace() -> void:
	var game := battle(); var index := Boss.index(game)
	var hp: int = game.player_hp
	game.CombatSystem.update(game,2.0)
	expect(game.player_hp == hp and not game.enemy_nodes[index].attack_pending,"custom guardian cannot receive an extra generic AI attack")
	Attacks.begin(game,"fan",game.enemy_nodes[index])
	Boss.Shots.launch(game,Vector2(1680,648),Vector2.LEFT,12)
	game.CombatSystem.apply_damage(game,index,40)
	var state: Dictionary = game.state.world.cave_boss
	expect(state.phase == 2 and state.attack.is_empty() and state.projectiles.is_empty(),"health loss immediately starts second phase and removes old hazards")
	expect(float(state.recovery) >= 2.0,"phase transition grants a two-second response window")
	game.CombatSystem.apply_damage(game,index,45)
	expect(state.phase == 3 and game.CombatSystem.boss_phase(game.enemy_nodes[index]) == 3,"third phase is reflected in the common combat API")
	expect(game.enemy_nodes[index].position == Vector2(1728,648),"guardian takes damage without weapon knockback changing the telegraph origin")
	game.free()

## Сценарий: все двенадцать атак показывают опасность до первого контактного кадра.
## Исходное состояние: герой находится рядом с боссом, каждая атака начинается с нулевым временем.
## Ожидаемый результат: во время половины замаха HP сохраняется, после атаки есть окно восстановления.
func test_all_attacks_warn_before_damage_and_offer_recovery() -> void:
	var game := battle(); var index := Boss.index(game)
	for id in Data.ATTACKS:
		Boss.reset(game); Boss.start(game); game.player = Vector2(1808,648); game.enemy_nodes[index].position = Vector2(1728,648)
		var hp: int = game.player_hp
		Attacks.begin(game,id,game.enemy_nodes[index])
		expect(not game.state.world.cave_boss.zones.is_empty(),"attack has a visible geometry before contact: " + id)
		Attacks.update(game,index,float(Data.ATTACKS[id].windup)*0.5)
		expect(game.player_hp == hp,"attack windup cannot apply hidden early damage: " + id)
		for _step in 90: Attacks.update(game,index,0.05)
		expect(game.state.world.cave_boss.attack.is_empty() and float(game.state.world.cave_boss.recovery) >= 1.0,"attack finishes with a usable recovery window: " + id)
	game.free()

## Сценарий: конус, крест, последовательный разлом, неполная клетка и кольцо требуют разных уклонений.
## Исходное состояние: атаки построены вокруг неподвижного хранителя на безопасной части пола.
## Ожидаемый результат: направления фиксируются, залпы имеют правильное число снарядов, центр кольца безопасен.
func test_geometry_projectiles_and_multi_step_attacks() -> void:
	var game := battle(); var index := Boss.index(game)
	game.player = Vector2(1728,508)
	Attacks.begin(game,"sweep",game.enemy_nodes[index]); var cone: Dictionary = game.state.world.cave_boss.zones[0]
	expect(Attacks.contains(cone,Vector2(1728,548)) and not Attacks.contains(cone,Vector2(1728,748)),"wide sweep has a front sector and a safe rear")
	game.player = Vector2(1860,648)
	expect(Vector2(game.state.world.cave_boss.attack.target) == Vector2(1728,508),"moving hero cannot redirect a committed windup")
	for sample in [["fan",5],["burst",8],["spiral",24]]:
		Boss.reset(game); Boss.start(game); Attacks.begin(game,sample[0],game.enemy_nodes[index])
		Attacks.update(game,index,2.4)
		expect(game.state.world.cave_boss.projectiles.size() == sample[1],"projectile mechanic emits its distinct pattern: " + sample[0])
	Attacks.begin(game,"cross",game.enemy_nodes[index])
	expect(game.state.world.cave_boss.zones.size() == 2,"cross quake creates two perpendicular corridors")
	Attacks.begin(game,"fissure",game.enemy_nodes[index])
	expect(game.state.world.cave_boss.zones.size() == 4 and game.state.world.cave_boss.zones[3].trigger > game.state.world.cave_boss.zones[0].trigger,"fissure advances as four delayed explosions")
	game.player = Vector2(1440,816)
	Attacks.begin(game,"rockfall",game.enemy_nodes[index])
	expect(game.state.world.cave_boss.zones.size() == 3,"rockfall locks three successive landing spots")
	Attacks.begin(game,"triple_charge",game.enemy_nodes[index])
	expect(game.state.world.cave_boss.zones.size() == 3 and game.state.world.cave_boss.zones[2].trigger > 3.0,"triple charge warns about all three separate dashes")
	Attacks.begin(game,"prison",game.enemy_nodes[index])
	expect(game.state.world.cave_boss.zones.size() <= 6 and game.state.world.cave_boss.zones.size() >= 3,"crystal cage preserves an intentional escape gap")
	Attacks.begin(game,"pulse",game.enemy_nodes[index]); var ring: Dictionary = game.state.world.cave_boss.zones[0]
	expect(not Attacks.contains(ring,ring.position,0.5) and Attacks.contains(ring,Vector2(ring.position)+Vector2(235,0),0.5),"moon pulse expands as an annulus with a safe center")
	expect(not Attacks.contains(ring,Vector2(ring.position)+Vector2(65,0),0.0),"safe center is wide enough to stand beside the physical boss body")
	game.free()

## Сценарий: пауза останавливает угрозы, выход и загрузка очищают их, победа сохраняется без повторной награды.
## Исходное состояние: активный бой со снарядом и мухой, затем сохранение и смертельный удар по боссу.
## Ожидаемый результат: HP и часы не меняются в рюкзаке, сохранённый HP восстанавливается, победа выдаёт добычу один раз.
func test_pause_exit_victory_and_save_cleanup() -> void:
	var game := battle(); var index := Boss.index(game)
	Boss.Shots.attach_fly(game,3.5); Boss.Shots.launch(game,Vector2(1640,648),Vector2.LEFT,12)
	var state: Dictionary = game.state.world.cave_boss; var hp: int = game.player_hp; var clock := float(state.clock)
	game.inventory_open = true; Boss.update(game,4.0)
	expect(game.player_hp == hp and state.clock == clock and state.fly_timer == 3.5,"backpack pause freezes boss projectiles and bite timers")
	game.inventory_open = false; game.current_location = "cave_lake"; Boss.update(game,0.1)
	expect(not game.state.world.cave_boss.active and game.state.world.cave_boss.projectiles.is_empty() and game.state.world.cave_boss.fly_timer == 0.0,"leaving the sanctuary clears all temporary threats")
	game.current_location = Data.LOCATION; Boss.start(game); game.CombatSystem.apply_damage(game,index,52)
	var saved: Dictionary = game.SaveSystem.snapshot(game)
	Boss.Minions.summon(game,["zombie"]); Boss.Shots.attach_fly(game,5.0)
	expect(game.SaveSystem.apply(game,saved),"mid-battle progress remains a compatible save")
	expect(game.enemy_nodes[index].hp == 68 and game.enemy_nodes[index].max_hp == 120,"loading preserves guardian HP and its custom maximum")
	expect(game.state.world.cave_boss.minions.is_empty() and game.state.world.cave_boss.fly_timer == 0.0,"loading grants a fresh warning instead of resuming an unseen hit")
	Boss.start(game); game.CombatSystem.apply_damage(game,index,200)
	var drops: int = game.dropped_items.size()
	expect(not game.enemy_nodes[index].alive and not game.state.world.cave_boss.active,"guardian victory stops all encounter AI")
	expect(not game.CombatSystem.apply_damage(game,index,200) and game.dropped_items.size() == drops,"dead guardian cannot award duplicate loot")
	var restored := make_game()
	expect(restored.SaveSystem.apply(restored,game.SaveSystem.snapshot(game)) and not restored.enemy_nodes[index].alive,"guardian victory persists after loading another instance")
	game.free(); restored.free()

## Сценарий: новая механика объясняется обучением и переводится на все шесть языков.
## Исходное состояние: события боя и каталог локализованных названий зарегистрированы в игре.
## Ожидаемый результат: подсказки не показывают технических идентификаторов ни в одном языке.
func test_tutorial_and_localized_attack_labels() -> void:
	var game := battle()
	for locale in game.LocaleSystem.LOCALES:
		game.LocaleSystem.set_locale(locale,false)
		for id in Data.ATTACKS: expect(Data.word(game,id) != id,"boss attack is localized: %s/%s" % [locale,id])
		for event in ["cave_boss_phases","cave_boss_attacks","cave_boss_summons","cave_boss_flies","cave_boss_victory"]:
			expect(event in game.TutorialSystem.STEP_IDS and game.LocaleSystem.tutorial(event) != event,"boss mechanic has a localized tutorial: %s/%s" % [locale,event])
	game.LocaleSystem.set_locale("ru",false); game.free()

## Сценарий: старый страж переносит долю здоровья, а отдельный режим позволяет вручную проверить новый бой.
## Исходное состояние: прежние сохранения не содержат максимальный HP, новый босс имеет 120 HP.
## Ожидаемый результат: нет потери стадий из-за прежнего максимума, проверочный запуск даёт оружие без сохранения.
func test_legacy_guardian_progress_and_playable_preview() -> void:
	expect(Data.restored_hp({"hp":34},34)==120,"untouched legacy guardian starts the new encounter at full health")
	expect(Data.restored_hp({"hp":17},34)==60,"damaged legacy guardian retains the same health fraction")
	expect(Data.restored_hp({"hp":7,"max_hp":120},34)==7,"new boss saves preserve exact HP instead of scaling twice")
	var game := make_game(); Boss.configure_preview(game)
	expect(game.current_location==Data.LOCATION and game.equipped_weapon=="iron_spear","playable boss preview starts in the actual arena with a spear")
	expect(game.FirstChapterSystem.state(game).completed and game.state.player.profile.created,"preview avoids onboarding dialogs that would pause the battle")
	Boss.update(game,0.05)
	expect(not game.state.world.cave_boss.active and game.GameInteractionRouter.perform(game),"preview waits for the real altar interaction")
	expect(game.state.world.cave_boss.active and game.enemy_nodes[Boss.index(game)].hp==120,"preview starts a live three-stage encounter with the real scheduler")
	game.free()

## Сценарий: поражение во время боя возвращает героя на доступный пол, а не за пределы пещеры.
## Исходное состояние: у героя один HP и прикреплённая муха, возле него действуют призванные существа.
## Ожидаемый результат: открывается экран спасения, угрозы исчезают, из точки возрождения можно двигаться.
func test_defeat_returns_to_safe_cave_entry() -> void:
	var game := battle(); game.player_hp=1
	Boss.Minions.summon(game,["zombie"]); Boss.Shots.attach_fly(game,2.5)
	Boss.Shots.update_bites(game,1.05)
	expect(game.menu_state.defeat_open and game.player_hp==game.player_max_hp,"lethal fly bite uses the normal rescue screen")
	expect(not game.state.world.cave_boss.active and game.state.world.cave_boss.minions.is_empty(),"rescue immediately clears boss threats")
	expect(game.NavigationSystem.walkability_reason(game,game.player,-1,false)=="walkable","rescued hero starts on accessible cave ground")
	var before: Vector2 = game.player; game.NavigationSystem.move(game,Vector2(48,0))
	expect(game.player.x>before.x,"rescued hero can leave the cave entry instead of remaining trapped")
	game.free()
