extends RefCounted

## Дерево талантов расходует очки общего уровня, не смешивая их с профессиями,
## которые продолжают автоматически расти от практики соответствующих действий.

const GROUPS := [
	{"id":"combat", "icon":"⚔"}, {"id":"farming", "icon":"♣"}, {"id":"fishing", "icon":"≈"}, {"id":"crafting", "icon":"◆"},
]

const TALENTS := [
	{"id":"combat_strength", "group":"combat", "name":"Сила", "icon":"⚔", "description":"Постоянно увеличивает урон героя на 1.", "requires":[], "max_rank":3},
	{"id":"combat_agility", "group":"combat", "name":"Ловкость", "icon":"➶", "description":"Ускоряет движение на 4% за ранг.", "requires":[], "max_rank":3},
	{"id":"combat_vitality", "group":"combat", "name":"Закалка", "icon":"♥", "description":"Добавляет 10 к максимальному здоровью за ранг.", "requires":["combat_strength"], "max_rank":3},
	{"id":"combat_power_strike", "group":"combat", "name":"Мощный удар", "icon":"✦", "description":"Каждый четвёртый удар наносит ещё 2 урона.", "requires":["combat_strength"]},
	{"id":"combat_master", "group":"combat", "name":"Мастер боя", "icon":"★", "description":"Даёт ещё 10% скорости и 1 урон после освоения двух ветвей.", "requires":["combat_agility", "combat_power_strike"]},

	{"id":"farm_orchard", "group":"farming", "name":"Садовод", "icon":"♠", "description":"Открывает фруктовые саженцы и выращивание деревьев.", "requires":[]},
	{"id":"farm_wide_till", "group":"farming", "name":"Широкая борозда", "icon":"▰", "description":"Мотыга вскапывает линию из трёх клеток.", "requires":[]},
	{"id":"farm_field_master", "group":"farming", "name":"Поле 3×3", "icon":"▦", "description":"Мотыга обрабатывает сразу девять клеток.", "requires":["farm_wide_till"]},
	{"id":"farm_exotic_crops", "group":"farming", "name":"Редкие культуры", "icon":"✿", "description":"Открывает тыкву, дыню, хлопок и подсолнух.", "requires":["farm_orchard"]},
	{"id":"farm_cooking", "group":"farming", "name":"Домашняя кухня", "icon":"♨", "description":"Позволяет готовить еду в установленном котелке.", "requires":[]},

	{"id":"fish_fine_rod", "group":"fishing", "name":"Точная снасть", "icon":"⌁", "description":"Открывает улучшенную удочку и ловкую рыбу.", "requires":[]},
	{"id":"fish_deep_water", "group":"fishing", "name":"Глубокая вода", "icon":"▼", "description":"Улучшенная удочка достаёт глубоководную рыбу.", "requires":["fish_fine_rod"]},
	{"id":"fish_big_game", "group":"fishing", "name":"Большой улов", "icon":"◉", "description":"Повышает размер улова и открывает крупную рыбу.", "requires":["fish_fine_rod"], "max_rank":3},
	{"id":"fish_crab_traps", "group":"fishing", "name":"Крабовые ловушки", "icon":"⌑", "description":"Открывает крафт и установку ловушек у воды.", "requires":[]},
	{"id":"fish_master", "group":"fishing", "name":"Речной знаток", "icon":"★", "description":"Расширяет зелёную зону и повышает качество улова.", "requires":["fish_deep_water", "fish_big_game"]},

	{"id":"craft_apprentice", "group":"crafting", "name":"Ученик мастера", "icon":"◇", "description":"Открывает сложные инструменты и устройства.", "requires":[]},
	{"id":"craft_efficient", "group":"crafting", "name":"Бережливость", "icon":"⅔", "description":"Снижает расход материалов сложных рецептов.", "requires":["craft_apprentice"], "max_rank":2},
	{"id":"craft_alchemy", "group":"crafting", "name":"Алхимия", "icon":"⚗", "description":"Открывает приготовление продвинутых зелий.", "requires":["craft_apprentice"]},
	{"id":"craft_engineering", "group":"crafting", "name":"Механизмы", "icon":"⚙", "description":"Открывает ловушки и улучшенное снаряжение.", "requires":["craft_apprentice"]},
	{"id":"craft_master", "group":"crafting", "name":"Мастерская", "icon":"★", "description":"Даёт дополнительный предмет при каждом пятом крафте.", "requires":["craft_efficient", "craft_engineering"]},
]

const RESPEC_COST := 500
const TEXT := {
	"group_combat":["СРАЖЕНИЯ","COMBAT","COMBATE","KAMPF","COMBAT","战斗"], "group_farming":["ФЕРМЕРСТВО","FARMING","AGRICULTURA","LANDWIRTSCHAFT","AGRICULTURE","耕作"], "group_fishing":["РЫБАЛКА","FISHING","PESCA","ANGELN","PÊCHE","钓鱼"], "group_crafting":["РЕМЕСЛО","CRAFTING","ARTESANÍA","HANDWERK","ARTISANAT","工艺"],
	"combat_strength":["Сила|Каждый ранг добавляет 1 к урону.","Strength|Each rank adds 1 damage.","Fuerza|Cada rango añade 1 de daño.","Stärke|Jeder Rang gibt 1 Schaden.","Force|Chaque rang ajoute 1 dégât.","力量|每级增加1点伤害。"],
	"combat_agility":["Ловкость|Каждый ранг ускоряет движение на 4%.","Agility|Each rank increases speed by 4%.","Agilidad|Cada rango aumenta la velocidad un 4%.","Beweglichkeit|Jeder Rang erhöht das Tempo um 4%.","Agilité|Chaque rang augmente la vitesse de 4%.","敏捷|每级提高4%移动速度。"],
	"combat_vitality":["Закалка|Каждый ранг добавляет 10 к здоровью.","Vitality|Each rank adds 10 maximum health.","Vitalidad|Cada rango añade 10 de salud máxima.","Zähigkeit|Jeder Rang gibt 10 maximales Leben.","Endurance|Chaque rang ajoute 10 points de vie.","强韧|每级增加10点生命上限。"],
	"combat_power_strike":["Мощный удар|Каждый четвёртый удар наносит ещё 2 урона.","Power Strike|Every fourth hit deals 2 extra damage.","Golpe poderoso|Cada cuarto golpe causa 2 de daño extra.","Kraftschlag|Jeder vierte Treffer verursacht 2 Extraschaden.","Frappe puissante|Chaque quatrième coup inflige 2 dégâts de plus.","强力一击|每第四次攻击额外造成2点伤害。"],
	"combat_master":["Мастер боя|Даёт 1 урон и 10% скорости после освоения ветвей.","Combat Master|Adds 1 damage and 10% speed after both paths.","Maestro de combate|Añade 1 de daño y 10% de velocidad.","Kampfmeister|Gewährt 1 Schaden und 10% Tempo.","Maître du combat|Ajoute 1 dégât et 10% de vitesse.","战斗大师|增加1点伤害和10%速度。"],
	"farm_orchard":["Садовод|Открывает посадку фруктовых деревьев.","Orchard Keeper|Unlocks fruit-tree planting.","Horticultor|Desbloquea árboles frutales.","Obstgärtner|Schaltet Obstbäume frei.","Arboriculteur|Débloque les arbres fruitiers.","果园主|解锁果树种植。"],
	"farm_wide_till":["Широкая борозда|Мотыга обрабатывает линию из трёх клеток.","Wide Furrow|The hoe tills a line of three tiles.","Surco ancho|La azada labra tres casillas.","Breite Furche|Die Hacke bearbeitet drei Felder.","Large sillon|La houe travaille trois cases.","宽垄|锄头一次耕作三格。"],
	"farm_field_master":["Поле 3×3|Мотыга обрабатывает квадрат из девяти клеток.","3×3 Field|The hoe tills nine tiles at once.","Campo 3×3|La azada labra nueve casillas.","3×3-Feld|Die Hacke bearbeitet neun Felder.","Champ 3×3|La houe travaille neuf cases.","3×3农田|锄头一次耕作九格。"],
	"farm_exotic_crops":["Редкие культуры|Открывает тыкву, дыню, хлопок и подсолнух.","Rare Crops|Unlocks pumpkin, melon, cotton and sunflower.","Cultivos raros|Desbloquea calabaza, melón, algodón y girasol.","Seltene Saat|Schaltet Kürbis, Melone, Baumwolle und Sonnenblume frei.","Cultures rares|Débloque citrouille, melon, coton et tournesol.","稀有作物|解锁南瓜、甜瓜、棉花和向日葵。"],
	"farm_cooking":["Домашняя кухня|Позволяет готовить еду в котелке.","Home Cooking|Allows cooking meals in a cauldron.","Cocina casera|Permite cocinar en un caldero.","Hausküche|Erlaubt Kochen im Kessel.","Cuisine maison|Permet de cuisiner au chaudron.","家庭烹饪|可用锅烹制食物。"],
	"fish_fine_rod":["Точная снасть|Открывает улучшенную удочку и ловкую рыбу.","Fine Tackle|Unlocks the advanced rod and agile fish.","Aparejo fino|Desbloquea la caña avanzada y peces ágiles.","Feines Gerät|Schaltet die bessere Rute und flinke Fische frei.","Ligne précise|Débloque la canne avancée et les poissons agiles.","精密钓具|解锁高级鱼竿和敏捷鱼类。"],
	"fish_deep_water":["Глубокая вода|Позволяет ловить глубоководную рыбу.","Deep Water|Allows catching deep-water fish.","Aguas profundas|Permite capturar peces de profundidad.","Tiefwasser|Erlaubt den Fang von Tiefseefischen.","Eaux profondes|Permet de pêcher les poissons des profondeurs.","深水|可以捕捉深水鱼。"],
	"fish_big_game":["Большой улов|Каждый ранг увеличивает размер рыбы на 8%.","Big Catch|Each rank increases fish size by 8%.","Gran captura|Cada rango aumenta el tamaño un 8%.","Großer Fang|Jeder Rang erhöht die Größe um 8%.","Grosse prise|Chaque rang augmente la taille de 8%.","大丰收|每级使鱼的尺寸提高8%。"],
	"fish_crab_traps":["Крабовые ловушки|Открывает создание и установку ловушек у воды.","Crab Traps|Unlocks traps placed beside water.","Trampas de cangrejo|Desbloquea trampas junto al agua.","Krabbenfallen|Schaltet Fallen am Wasser frei.","Casiers à crabes|Débloque les casiers au bord de l’eau.","蟹笼|解锁水边蟹笼。"],
	"fish_master":["Речной знаток|Расширяет зелёную зону и улучшает качество улова.","River Expert|Expands the catch bar and improves quality.","Experto fluvial|Amplía la barra y mejora la calidad.","Flusskenner|Vergrößert die Fangzone und verbessert die Qualität.","Expert des rivières|Élargit la zone et améliore la qualité.","河流专家|扩大捕捉区域并提高品质。"],
	"craft_apprentice":["Ученик мастера|Открывает сложные инструменты и устройства.","Apprentice|Unlocks advanced tools and devices.","Aprendiz|Desbloquea herramientas y dispositivos avanzados.","Lehrling|Schaltet komplexe Werkzeuge und Geräte frei.","Apprenti|Débloque les outils et appareils avancés.","工匠学徒|解锁高级工具和装置。"],
	"craft_efficient":["Бережливость|Каждый ранг снижает цену сложных рецептов.","Efficiency|Each rank reduces advanced recipe costs.","Eficiencia|Cada rango reduce el coste de recetas avanzadas.","Sparsamkeit|Jeder Rang senkt die Kosten komplexer Rezepte.","Économie|Chaque rang réduit le coût des recettes avancées.","节俭|每级降低高级配方消耗。"],
	"craft_alchemy":["Алхимия|Открывает приготовление продвинутых зелий.","Alchemy|Unlocks advanced potion brewing.","Alquimia|Desbloquea pociones avanzadas.","Alchemie|Schaltet fortgeschrittene Tränke frei.","Alchimie|Débloque les potions avancées.","炼金术|解锁高级药水。"],
	"craft_engineering":["Механизмы|Открывает ловушки и улучшенное снаряжение.","Engineering|Unlocks traps and advanced gear.","Ingeniería|Desbloquea trampas y equipo avanzado.","Mechanik|Schaltet Fallen und bessere Ausrüstung frei.","Mécanismes|Débloque les pièges et l’équipement avancé.","机械学|解锁陷阱和高级装备。"],
	"craft_master":["Мастерская|Каждый пятый крафт создаёт дополнительный предмет.","Workshop Master|Every fifth craft creates an extra item.","Maestro artesano|Cada quinta creación produce un objeto extra.","Werkmeister|Jede fünfte Herstellung erzeugt einen Zusatzgegenstand.","Maître artisan|Chaque cinquième fabrication donne un objet de plus.","工坊大师|每第五次制作额外获得一件物品。"],
	"title":["ДЕРЕВО СПОСОБНОСТЕЙ","ABILITY TREE","ÁRBOL DE HABILIDADES","FÄHIGKEITSBAUM","ARBRE DES TALENTS","能力树"], "learned":["ИЗУЧЕНО","LEARNED","APRENDIDO","GELERNT","APPRIS","已掌握"], "available":["ДОСТУПНО","AVAILABLE","DISPONIBLE","VERFÜGBAR","DISPONIBLE","可学习"], "locked":["ЗАКРЫТО","LOCKED","BLOQUEADO","GESPERRT","VERROUILLÉ","未解锁"],
	"rank":["РАНГ %d/%d","RANK %d/%d","RANGO %d/%d","RANG %d/%d","RANG %d/%d","等级 %d/%d"], "learn_hint":["Enter / E / A — изучить","Enter / E / A — learn","Enter / E / A — aprender","Enter / E / A — lernen","Entrée / E / A — apprendre","Enter / E / A — 学习"], "need":["Нужно: %s","Requires: %s","Requiere: %s","Benötigt: %s","Requiert : %s","需要：%s"], "close":["K / Esc / B — закрыть","K / Esc / B — close","K / Esc / B — cerrar","K / Esc / B — schließen","K / Esc / B — fermer","K / Esc / B — 关闭"],
	"respec":["R / X — сброс за %d монет","R / X — reset for %d coins","R / X — reiniciar por %d monedas","R / X — für %d Münzen zurücksetzen","R / X — réinitialiser pour %d pièces","R / X — 花费%d金币重置"], "choose":["Выбери развитие. Свободных очков: %d","Choose a talent. Free points: %d","Elige una habilidad. Puntos: %d","Wähle ein Talent. Punkte: %d","Choisis un talent. Points : %d","选择能力。可用点数：%d"], "already":["Способность уже полностью изучена","Ability is already mastered","La habilidad ya está dominada","Fähigkeit ist bereits gemeistert","Talent déjà maîtrisé","该能力已满级"], "unlocked":["Изучено: %s (%d/%d)","Learned: %s (%d/%d)","Aprendido: %s (%d/%d)","Gelernt: %s (%d/%d)","Appris : %s (%d/%d)","已学习：%s（%d/%d）"], "respec_done":["Таланты сброшены • возвращено очков: %d","Talents reset • %d points refunded","Habilidades reiniciadas • %d puntos devueltos","Talente zurückgesetzt • %d Punkte erstattet","Talents réinitialisés • %d points rendus","能力已重置 • 返还%d点"], "respec_empty":["Сбрасывать пока нечего","No talents to reset","No hay habilidades que reiniciar","Keine Talente zum Zurücksetzen","Aucun talent à réinitialiser","没有可重置的能力"], "respec_money":["Для сброса нужно %d монет","Reset requires %d coins","Se necesitan %d monedas","Zurücksetzen kostet %d Münzen","La réinitialisation coûte %d pièces","重置需要%d金币"],
}


## Возвращает локализованный текст дерева либо часть после разделителя для описания таланта.
static func word(game: Node, key: String, description: bool = false, values: Array = []) -> String:
	var variants: Array = TEXT.get(key, [key, key, key, key, key, key])
	var value := String(variants[game.LocaleSystem.index()])
	var parts := value.split("|", true, 1)
	var result := parts[1] if description and parts.size() > 1 else parts[0]
	return result % values if not values.is_empty() else result


## Создаёт полный словарь неоткрытых талантов для новой игры и миграции сохранений.
static func default_levels() -> Dictionary:
	var result := {}
	for talent in TALENTS:
		result[String(talent.id)] = 0
	return result


## Дополняет загруженный словарь новыми талантами и нормализует известные значения.
static func merge_levels(saved: Dictionary) -> Dictionary:
	var result := default_levels()
	for talent_id in result:
		result[talent_id] = clampi(int(saved.get(talent_id, 0)), 0, max_rank(talent_id))
	return result


## Возвращает метаданные таланта по идентификатору или пустой словарь.
static func data(talent_id: String) -> Dictionary:
	for talent in TALENTS:
		if String(talent.id) == talent_id:
			return talent
	return {}


## Возвращает талант по безопасно зацикленному индексу интерфейса.
static func at(index: int) -> Dictionary:
	return TALENTS[posmod(index, TALENTS.size())]


## Возвращает разрешённое число рангов способности, равное одному для обычных узлов.
static func max_rank(talent_id: String) -> int:
	return maxi(1, int(data(talent_id).get("max_rank", 1)))


## Возвращает текущий безопасно ограниченный ранг способности героя.
static func rank(game: Node, talent_id: String) -> int:
	return clampi(int(game.talent_levels.get(talent_id, 0)), 0, max_rank(talent_id))


## Проверяет, открыт ли талант в текущем сохранении.
static func has(game: Node, talent_id: String) -> bool:
	return rank(game, talent_id) > 0


## Возвращает список ещё не выполненных зависимостей выбранного таланта.
static func missing_requirements(game: Node, talent_id: String) -> Array[String]:
	var result: Array[String] = []
	var talent := data(talent_id)
	for required_id in talent.get("requires", []):
		if not has(game, String(required_id)):
			result.append(String(required_id))
	return result


## Проверяет возможность вложить одно свободное очко без изменения состояния героя.
static func can_unlock(game: Node, talent_id: String) -> bool:
	return game.skill_points > 0 and rank(game, talent_id) < max_rank(talent_id) and not data(talent_id).is_empty() and missing_requirements(game, talent_id).is_empty()


## Тратит очко общего уровня, применяет постоянные характеристики и запускает обучение.
static func unlock(game: Node, talent_id: String) -> bool:
	var talent := data(talent_id)
	if talent.is_empty():
		return false
	if rank(game, talent_id) >= max_rank(talent_id):
		game.message = word(game, "already")
		return false
	var missing := missing_requirements(game, talent_id)
	if not missing.is_empty():
		game.message = word(game, "need", false, [requirement_names(game, missing)])
		return false
	if game.skill_points <= 0:
		game.message = game.LocaleSystem.text("no_points")
		return false
	var old_max_hp: int = game.player_max_hp
	game.talent_levels[talent_id] = rank(game, talent_id) + 1
	game.skill_points -= 1
	game.SkillSystem.recalculate_resources(game)
	game.player_hp = mini(game.player_hp + game.player_max_hp - old_max_hp, game.player_max_hp)
	game.message = word(game, "unlocked", false, [word(game, talent_id), rank(game, talent_id), max_rank(talent_id)])
	game.play_sfx("level_up")
	game.notify_tutorial("talent_tree")
	return true


## Собирает читабельные названия зависимостей для подсказки заблокированного узла.
static func requirement_names(game: Node, requirements: Array[String]) -> String:
	var names: Array[String] = []
	for talent_id in requirements:
		names.append(word(game, talent_id))
	return ", ".join(names)


## Возвращает число очков, уже вложенных во все ранги дерева.
static func spent_points(game: Node) -> int:
	var result := 0
	for talent_id in game.talent_levels: result += rank(game, String(talent_id))
	return result


## Сбрасывает билд за фиксированную плату и возвращает все вложенные очки без потери уровня.
static func respec(game: Node, free: bool = false) -> bool:
	var spent := spent_points(game)
	if spent <= 0: game.message = word(game, "respec_empty"); return false
	if not free and game.coins < RESPEC_COST: game.message = word(game, "respec_money", false, [RESPEC_COST]); return false
	if not free: game.coins -= RESPEC_COST
	game.talent_levels = default_levels(); game.skill_points += spent
	game.SkillSystem.recalculate_resources(game)
	game.message = word(game, "respec_done", false, [spent]); game.play_sfx("coin"); game.notify_tutorial("talent_respec")
	return true


## Возвращает постоянную прибавку к урону от боевых талантов.
static func combat_damage_bonus(game: Node) -> int:
	return rank(game, "combat_strength") + int(has(game, "combat_master"))


## Возвращает множитель скорости от ловкости и освоения всей боевой ветви.
static func movement_multiplier(game: Node) -> float:
	return 1.0 + rank(game, "combat_agility") * 0.04 + (0.10 if has(game, "combat_master") else 0.0)


## Возвращает прибавку здоровья, которую SkillSystem включает в общий расчёт ресурсов.
static func health_bonus(game: Node) -> int:
	return rank(game, "combat_vitality") * 10


## Возвращает число клеток, которое мотыга может обработать одним действием.
static func tilling_size(game: Node) -> int:
	if has(game, "farm_field_master"):
		return 9
	if has(game, "farm_wide_till"):
		return 3
	return 1


## Возвращает смещения грядок: линия направлена от героя, а улучшение создаёт квадрат 3×3.
static func tilling_offsets(game: Node) -> Array[Vector2i]:
	if tilling_size(game) == 1:
		return [Vector2i.ZERO]
	if tilling_size(game) == 9:
		var square: Array[Vector2i] = []
		for y in range(-1, 2):
			for x in range(-1, 2):
				square.append(Vector2i(x, y))
		return square
	var direction := Vector2i(roundi(game.facing.x), roundi(game.facing.y))
	if direction == Vector2i.ZERO:
		direction = Vector2i.RIGHT
	return [Vector2i.ZERO, direction, direction * 2]


## Проверяет доступность редкой культуры до расходования семян и энергии.
static func can_plant_crop(game: Node, crop_kind: String) -> bool:
	return crop_kind not in ["pumpkin", "melon", "cotton", "sunflower"] or has(game, "farm_exotic_crops")


## Проверяет, доступна ли герою рыба с указанными требованиями каталога.
static func can_catch_fish(game: Node, fish: Dictionary) -> bool:
	var required_talent := String(fish.get("requires", ""))
	if not required_talent.is_empty() and not has(game, required_talent):
		return false
	if bool(fish.get("advanced_rod", false)) and game.inventory_item_count("advanced_fishing_rod") <= 0:
		return false
	return true


## Возвращает прибавку к размеру рыбы от таланта охоты за крупным уловом.
static func fishing_size_bonus(game: Node) -> float:
	return rank(game, "fish_big_game") * 0.08


## Возвращает прибавку к высоте управляемой зоны для мастера рыбалки.
static func fishing_bar_bonus(game: Node) -> float:
	return 0.06 if has(game, "fish_master") else 0.0


## Проверяет требование таланта, указанное непосредственно в рецепте.
static func recipe_unlocked(game: Node, recipe: Dictionary) -> bool:
	for talent_id in recipe.get("talents", []):
		if not has(game, String(talent_id)):
			return false
	var single_talent := String(recipe.get("talent", ""))
	return single_talent.is_empty() or has(game, single_talent)


## Рассчитывает фактическую цену ингредиента с учётом профессии и таланта бережливости.
static func recipe_material_cost(game: Node, amount: int) -> int:
	var result: int = game.SkillSystem.material_cost(game, amount)
	if rank(game, "craft_efficient") > 0 and result >= 3:
		result -= mini(rank(game, "craft_efficient"), result - 1)
	return maxi(1, result)
