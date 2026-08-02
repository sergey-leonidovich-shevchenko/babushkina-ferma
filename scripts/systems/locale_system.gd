extends RefCounted

const LOCALES := ["ru", "en", "es", "de", "fr", "zh"]
const LANGUAGE_NAMES := ["Русский", "English", "Español", "Deutsch", "Français", "简体中文"]
const SETTINGS_PATH := "user://farm-settings.cfg"

static var current := "ru"

const UI := {
	"choose_language":["ВЫБЕРИТЕ ЯЗЫК","CHOOSE LANGUAGE","ELIGE IDIOMA","SPRACHE WÄHLEN","CHOISIR LA LANGUE","选择语言"],
	"confirm":["Enter / A / касание — выбрать","Enter / A / touch — select","Enter / A / toque — elegir","Enter / A / Tippen — wählen","Entrée / A / toucher — choisir","Enter / A / 触摸 — 选择"],
	"title":["БАБУШКИНА ФЕРМА","GRANDMA'S FARM","LA GRANJA DE LA ABUELA","OMAS BAUERNHOF","LA FERME DE GRAND-MÈRE","奶奶的农场"],
	"title_subtitle":["ТАЙНА ЛУННОЙ ДОЛИНЫ","MYSTERY OF MOON VALLEY","EL MISTERIO DEL VALLE LUNAR","DAS GEHEIMNIS DES MONDTALS","LE MYSTÈRE DE LA VALLÉE LUNAIRE","月光谷之谜"],
	"title_features":["ФЕРМА • ПРИКЛЮЧЕНИЯ • РЕМЁСЛА","FARM • ADVENTURE • CRAFT","GRANJA • AVENTURA • OFICIOS","FARM • ABENTEUER • HANDWERK","FERME • AVENTURE • ARTISANAT","农场 • 冒险 • 工艺"],
	"press_any":["НАЧАТЬ ПРИКЛЮЧЕНИЕ","BEGIN ADVENTURE","COMENZAR LA AVENTURA","ABENTEUER BEGINNEN","COMMENCER L'AVENTURE","开始冒险"],
	"title_controls":["Enter / A / касание","Enter / A / touch","Enter / A / toque","Enter / A / Tippen","Entrée / A / toucher","Enter / A / 触摸"],
	"sound_on":["Звук включён","Sound enabled","Sonido activado","Ton eingeschaltet","Son activé","声音已开启"],
	"sound_off":["Звук выключен","Sound muted","Sonido silenciado","Ton ausgeschaltet","Son coupé","声音已静音"],
	"day":["ДЕНЬ %d   %02d:%02d","DAY %d   %02d:%02d","DÍA %d   %02d:%02d","TAG %d   %02d:%02d","JOUR %d   %02d:%02d","第%d天   %02d:%02d"],
	"resources":["⚡ %d   🪙 %d   Семена: %d   Морковь: %d","⚡ %d   🪙 %d   Seeds: %d   Carrots: %d","⚡ %d   🪙 %d   Semillas: %d   Zanahorias: %d","⚡ %d   🪙 %d   Samen: %d   Karotten: %d","⚡ %d   🪙 %d   Graines : %d   Carottes : %d","⚡ %d   🪙 %d   种子：%d   胡萝卜：%d"],
	"skills":["K • НАВЫКИ","K • SKILLS","K • HABILIDADES","K • FÄHIGKEITEN","K • COMPÉTENCES","K • 技能"],
	"quests":["J • ЗАДАНИЯ","J • QUESTS","J • MISIONES","J • AUFGABEN","J • QUÊTES","J • 任务"],
	"tutorial":["ОБУЧЕНИЕ %d/%d  [T скрыть • Y заново • F9 QA]","TUTORIAL %d/%d  [T hide • Y reset • F9 QA]","TUTORIAL %d/%d  [T ocultar • Y reiniciar • F9 QA]","TUTORIAL %d/%d  [T aus • Y neu • F9 QA]","TUTORIEL %d/%d  [T masquer • Y relancer • F9 QA]","教程 %d/%d  [T 隐藏 • Y 重置 • F9 测试]"],
	"action":["E • действие","E • action","E • acción","E • Aktion","E • action","E • 操作"],
	"new_nearby":["НОВОЕ РЯДОМ • ≤3 КЛЕТКИ","NEW NEARBY • ≤3 TILES","NUEVO CERCA • ≤3 CASILLAS","NEU IN DER NÄHE • ≤3 FELDER","NOUVEAU À PROXIMITÉ • ≤3 CASES","附近新发现 • ≤3格"],
	"hide":["H • скрыть","H • hide","H • ocultar","H • ausblenden","H • masquer","H • 隐藏"],
	"inventory":["БЕЗРАЗМЕРНЫЙ РЮКЗАК • TAB","UNLIMITED BACKPACK • TAB","MOCHILA ILIMITADA • TAB","UNENDLICHER RUCKSACK • TAB","SAC SANS LIMITE • TAB","无限背包 • TAB"],
	"eat":["СЪЕСТЬ • A","USE • A","USAR • A","BENUTZEN • A","UTILISER • A","使用 • A"],
	"equip":["НАДЕТЬ • X","EQUIP • X","EQUIPAR • X","ANLEGEN • X","ÉQUIPER • X","装备 • X"],
	"equipment":["ЭКИПИРОВКА","EQUIPMENT","EQUIPO","AUSRÜSTUNG","ÉQUIPEMENT","装备"],
	"workbench":["ВЕРСТАК • РЕЦЕПТЫ","WORKBENCH • RECIPES","BANCO • RECETAS","WERKBANK • REZEPTE","ÉTABLI • RECETTES","工作台 • 配方"],
	"shop":["СЕЛЬСКАЯ ЛАВКА","VILLAGE SHOP","TIENDA RURAL","DORFLADEN","BOUTIQUE DU VILLAGE","乡村商店"],
	"product":["ТОВАР / СРОК РОСТА","ITEM / GROW TIME","PRODUCTO / CULTIVO","WARE / WACHSTUM","ARTICLE / CROISSANCE","商品 / 生长时间"],
	"buy":["КУПИТЬ","BUY","COMPRAR","KAUFEN","ACHETER","购买"],
	"sell":["ПРОДАТЬ","SELL","VENDER","VERKAUFEN","VENDRE","出售"],
	"quest_log":["ЖУРНАЛ ЗАДАНИЙ","QUEST JOURNAL","DIARIO DE MISIONES","AUFGABENBUCH","JOURNAL DES QUÊTES","任务日志"],
	"objective":["Цель: %s","Objective: %s","Objetivo: %s","Ziel: %s","Objectif : %s","目标：%s"],
	"reward":["Награда: %d монет • %d XP • %s ×%d","Reward: %d coins • %d XP • %s ×%d","Recompensa: %d monedas • %d XP • %s ×%d","Belohnung: %d Münzen • %d XP • %s ×%d","Récompense : %d pièces • %d XP • %s ×%d","奖励：%d金币 • %d经验 • %s ×%d"],
	"available":["НЕ ВЗЯТО","AVAILABLE","DISPONIBLE","VERFÜGBAR","DISPONIBLE","可接取"],
	"active":["АКТИВНО","ACTIVE","ACTIVA","AKTIV","ACTIVE","进行中"],
	"completed":["ВЫПОЛНЕНО","COMPLETED","COMPLETADA","ERLEDIGT","TERMINÉE","已完成"],
	"character":["РАЗВИТИЕ ПЕРСОНАЖА","CHARACTER DEVELOPMENT","DESARROLLO DEL PERSONAJE","CHARAKTERENTWICKLUNG","PROGRESSION DU PERSONNAGE","角色成长"],
	"level_points":["Уровень %d • очков: %d","Level %d • points: %d","Nivel %d • puntos: %d","Stufe %d • Punkte: %d","Niveau %d • points : %d","等级%d • 点数：%d"],
	"rank":["РАНГ %d","RANK %d","RANGO %d","RANG %d","RANG %d","等级 %d"],
	"empty":["Пусто","Empty","Vacío","Leer","Vide","空"],
	"ready":["готово","ready","listo","bereit","prêt","可收获"],
	"home":["ДОМ • сон [N]","HOME • sleep [N]","CASA • dormir [N]","HAUS • schlafen [N]","MAISON • dormir [N]","家 • 睡觉 [N]"],
	"seeds_sign":["СЕМЕНА","SEEDS","SEMILLAS","SAMEN","GRAINES","种子"],
	"shop_sign":["Лавка [B]","Shop [B]","Tienda [B]","Laden [B]","Boutique [B]","商店 [B]"],
	"sell_sign":["Продажа [E]","Sell [E]","Vender [E]","Verkauf [E]","Vendre [E]","出售 [E]"],
	"hint_enemy":["Опасный противник. F атакует, R меняет оружие.","Dangerous enemy. F attacks; R changes weapon.","Enemigo peligroso. F ataca; R cambia arma.","Gefährlicher Gegner. F greift an; R wechselt Waffen.","Ennemi dangereux. F attaque ; R change d'arme.","危险敌人。F攻击，R切换武器。"],
	"hint_forage":["Собери через E. Урожай вырастет снова.","Harvest with E. The produce will regrow.","Cosecha con E. Volverá a crecer.","Ernte mit E. Die Pflanze wächst nach.","Récolte avec E. La plante repoussera.","按E采集，作物会再次生长。"],
	"hint_wildlife":["Пугливый зверь: разговаривать нельзя, он убегает; F — охота.","Timid wildlife: it cannot talk and flees; F hunts.","Animal tímido: no habla y huye; F permite cazar.","Scheues Tier: Kein Gespräch, es flieht; F startet die Jagd.","Animal peureux : impossible de parler, il fuit ; F chasse.","胆小的动物不会交谈且会逃跑；按F狩猎。"],
	"hint_item":["Подбери через E: предмет попадёт в рюкзак.","Pick up with E: the item goes to your backpack.","Recoge con E: irá a tu mochila.","Mit E aufnehmen: Der Gegenstand landet im Rucksack.","Ramasse avec E : l'objet va dans le sac.","按E拾取物品并放入背包。"],
	"hint_quest_item":["Подбери через E и отнеси старосте Мирону.","Pick it up with E and bring it to Elder Miron.","Recógelo con E y llévalo al anciano Miron.","Nimm es mit E auf und bringe es Ältestem Miron.","Ramasse-le avec E et rapporte-le à l'ancien Miron.","按E拾取并交给村长米隆。"],
	"hint_container":["Случайная находка. Нажми E, чтобы обыскать один раз.","Random stash. Press E to search it once.","Escondite aleatorio. Pulsa E para buscar una vez.","Zufallsversteck. Drücke E, um es einmal zu durchsuchen.","Cache aléatoire. Appuie sur E pour la fouiller une fois.","随机藏匿物。按E搜索一次。"],
	"new_item":["Новый предмет: %s","New item: %s","Objeto nuevo: %s","Neuer Gegenstand: %s","Nouvel objet : %s","新物品：%s"],
	"row":["строка %d/%d","row %d/%d","fila %d/%d","Zeile %d/%d","ligne %d/%d","行 %d/%d"],
	"head":["Голова","Head","Cabeza","Kopf","Tête","头部"], "body":["Тело","Body","Cuerpo","Körper","Corps","身体"], "legs":["Ноги","Legs","Piernas","Beine","Jambes","腿部"],
	"hands":["Руки","Hands","Manos","Hände","Mains","双手"], "offhand":["Щит","Off hand","Mano secundaria","Nebenhand","Main secondaire","副手"], "ring":["Кольцо","Ring","Anillo","Ring","Anneau","戒指"],
	"mana_label":["МАНА %d/%d","MANA %d/%d","MANÁ %d/%d","MANA %d/%d","MANA %d/%d","法力 %d/%d"],
	"stamina_label":["СИЛЫ %d/%d","STAMINA %d/%d","ENERGÍA %d/%d","AUSDAUER %d/%d","ENDURANCE %d/%d","耐力 %d/%d"],
	"effects":["ЭФФЕКТЫ:","EFFECTS:","EFECTOS:","EFFEKTE:","EFFETS :","效果："],
	"grandma_stock":["Бабушкины запасы","Grandma's stock","Reservas de la abuela","Omas Vorräte","Réserves de Grand-mère","奶奶的库存"],
	"inventory_help":["Колесо/PgUp/PgDn — прокрутка • E съесть • Q надеть • 1–0 назначить • M переместить • X выбросить","Wheel/PgUp/PgDn — scroll • E use • Q equip • 1–0 assign • M move • X drop","Rueda/PgUp/PgDn — mover • E usar • Q equipar • 1–0 asignar • M mover • X tirar","Rad/PgUp/PgDn — scrollen • E nutzen • Q anlegen • 1–0 belegen • M bewegen • X ablegen","Molette/PgUp/PgDn — défiler • E utiliser • Q équiper • 1–0 assigner • M déplacer • X jeter","滚轮/PgUp/PgDn滚动 • E使用 • Q装备 • 1–0分配 • M移动 • X丢弃"],
	"craft_help":["↑↓ рецепт • Enter создать • C/Esc закрыть","↑↓ recipe • Enter craft • C/Esc close","↑↓ receta • Enter crear • C/Esc cerrar","↑↓ Rezept • Enter herstellen • C/Esc schließen","↑↓ recette • Entrée fabriquer • C/Esc fermer","↑↓配方 • Enter制作 • C/Esc关闭"],
	"shop_help":["↑↓ выбрать   Enter купить   X продать   B закрыть","↑↓ select   Enter buy   X sell   B close","↑↓ elegir   Enter comprar   X vender   B cerrar","↑↓ wählen   Enter kaufen   X verkaufen   B schließen","↑↓ choisir   Entrée acheter   X vendre   B fermer","↑↓选择   Enter购买   X出售   B关闭"],
	"hint_location":["Новая область: исследуй окружение, ресурсы и существ.","New area: explore its surroundings, resources, and creatures.","Nueva zona: explora recursos y criaturas.","Neues Gebiet: Erkunde Umgebung, Ressourcen und Wesen.","Nouvelle zone : explore les ressources et les créatures.","新区域：探索环境、资源和生物。"],
	"quest_close":["J или Esc — закрыть","J or Esc — close","J o Esc — cerrar","J oder Esc — schließen","J ou Échap — fermer","J或Esc — 关闭"],
	"skill_help":["Стрелки/D-pad — выбрать • Enter/A — вложить очко • K/Esc/Y — закрыть","Arrows/D-pad — select • Enter/A — spend point • K/Esc/Y — close","Flechas/D-pad — elegir • Enter/A — gastar punto • K/Esc/Y — cerrar","Pfeile/D-pad — wählen • Enter/A — Punkt setzen • K/Esc/Y — schließen","Flèches/D-pad — choisir • Entrée/A — dépenser • K/Esc/Y — fermer","方向键/D-pad选择 • Enter/A加点 • K/Esc/Y关闭"],
	"quest_tracker":["ЗАДАНИЯ [J]","QUESTS [J]","MISIONES [J]","AUFGABEN [J]","QUÊTES [J]","任务 [J]"],
}

const TEXT := {
	"welcome":["Добро пожаловать на Бабушкину ферму!","Welcome to Grandma's Farm!","¡Bienvenido a la Granja de la Abuela!","Willkommen auf Omas Bauernhof!","Bienvenue à la Ferme de Grand-mère !","欢迎来到奶奶的农场！"],
	"new_day":["Наступил день %d","Day %d begins","Comienza el día %d","Tag %d beginnt","Le jour %d commence","第%d天开始了"],
	"face_plot":["Подойди к грядке и повернись к ней","Stand by a plot and face it","Acércate a una parcela y mírala","Stell dich an ein Beet und schau hin","Approche d'une parcelle et fais-lui face","靠近田地并面向它"],
	"no_energy":["Сил нет. Нажми N у кровати","No stamina. Press N by the bed","Sin energía. Pulsa N junto a la cama","Keine Ausdauer. Drücke N am Bett","Plus d'endurance. Appuie sur N près du lit","没有耐力。在床边按N"],
	"soil_ready":["Земля готова. Выбери семена [2]","Soil ready. Select seeds [2]","Tierra lista. Elige semillas [2]","Boden bereit. Wähle Samen [2]","Sol prêt. Choisis les graines [2]","土地已备好。选择种子[2]"],
	"already_tilled":["Эта грядка уже вспахана","This plot is already tilled","Esta parcela ya está arada","Dieses Beet ist schon gepflügt","Cette parcelle est déjà labourée","这块地已经耕过"],
	"no_seeds":["Семена кончились. Купи их в лавке","Out of seeds. Buy some at the shop","Sin semillas. Compra en la tienda","Keine Samen. Kaufe welche im Laden","Plus de graines. Achètes-en à la boutique","种子用完了，去商店购买"],
	"till_first":["Сначала вспаши пустую землю","Till empty soil first","Primero ara la tierra","Pflüge zuerst leeren Boden","Laboure d'abord le sol","先耕空地"],
	"watered":["Полито! Растение начало расти","Watered! The plant is growing","¡Regado! La planta está creciendo","Gegossen! Die Pflanze wächst","Arrosé ! La plante pousse","已浇水！植物开始生长"],
	"nothing_water":["Здесь нечего поливать","Nothing to water here","No hay nada que regar","Hier gibt es nichts zu gießen","Rien à arroser ici","这里没有可浇水的植物"],
	"harvested":["Собрано: %s ×%d","Harvested: %s ×%d","Cosechado: %s ×%d","Geerntet: %s ×%d","Récolté : %s ×%d","已收获：%s ×%d"],
	"not_ripe":["Урожай ещё не созрел","The crop is not ripe yet","El cultivo aún no está listo","Die Ernte ist noch nicht reif","La récolte n'est pas encore mûre","作物尚未成熟"],
	"sleep_near_home":["Чтобы спать, подойди к дому","Go near the house to sleep","Acércate a casa para dormir","Geh zum Haus, um zu schlafen","Approche de la maison pour dormir","靠近房屋才能睡觉"],
	"morning":["День %d, 06:00. Доброе утро!","Day %d, 06:00. Good morning!","Día %d, 06:00. ¡Buenos días!","Tag %d, 06:00. Guten Morgen!","Jour %d, 06:00. Bonjour !","第%d天，06:00。早上好！"],
	"inventory_open":["Рюкзак открыт","Backpack opened","Mochila abierta","Rucksack geöffnet","Sac ouvert","背包已打开"],
	"moved":["Предмет перемещён","Item moved","Objeto movido","Gegenstand verschoben","Objet déplacé","物品已移动"],
	"dropped":["Предмет выброшен рядом","Item dropped nearby","Objeto tirado cerca","Gegenstand abgelegt","Objet jeté à proximité","物品已丢在附近"],
	"picked":["Поднято: %s","Picked up: %s","Recogido: %s","Aufgenommen: %s","Ramassé : %s","已拾取：%s"],
	"cannot_use":["Этот предмет нельзя использовать","This item cannot be used","Este objeto no se puede usar","Dieser Gegenstand ist nicht nutzbar","Cet objet ne peut pas être utilisé","此物品无法使用"],
	"journal_open":["Журнал заданий открыт","Quest journal opened","Diario de misiones abierto","Aufgabenbuch geöffnet","Journal des quêtes ouvert","任务日志已打开"],
	"no_enemy":["Рядом нет противника","No enemy nearby","No hay enemigos cerca","Kein Gegner in der Nähe","Aucun ennemi à proximité","附近没有敌人"],
	"recipe_select":["Выбери рецепт и нажми Enter","Choose a recipe and press Enter","Elige una receta y pulsa Enter","Wähle ein Rezept und drücke Enter","Choisis une recette et appuie sur Entrée","选择配方并按Enter"],
	"saved":["Игра сохранена","Game saved","Partida guardada","Spiel gespeichert","Partie sauvegardée","游戏已保存"], "save_failed":["Не удалось сохранить игру","Could not save game","No se pudo guardar","Speichern fehlgeschlagen","Échec de la sauvegarde","保存失败"],
	"loaded":["Игра загружена","Game loaded","Partida cargada","Spiel geladen","Partie chargée","游戏已加载"], "load_failed":["Сохранение не найдено","Save not found","No se encontró partida","Kein Spielstand gefunden","Sauvegarde introuvable","未找到存档"],
	"tutorial_reset":["Обучение начато заново","Tutorial restarted","Tutorial reiniciado","Tutorial neu gestartet","Tutoriel relancé","教程已重新开始"],
	"fish_no_rod":["У тебя нет удочки","You have no fishing rod","No tienes caña","Du hast keine Angel","Tu n'as pas de canne","你没有鱼竿"], "fish_need_water":["Подойди к пруду или реке","Go to a pond or river","Acércate al estanque o río","Geh zu Teich oder Fluss","Approche d'un étang ou d'une rivière","靠近池塘或河流"],
	"fish_cast":["Поплавок в воде... жди поклёвки","Float in the water... wait for a bite","Flotador en el agua... espera","Schwimmer im Wasser... warte","Flotteur à l'eau... attends","浮漂入水……等待咬钩"], "fish_caught":["Поймана рыба ×%d!","Fish caught ×%d!","¡Pez capturado ×%d!","Fisch gefangen ×%d!","Poisson attrapé ×%d !","钓到鱼 ×%d！"],
	"fish_wait":["Рыба ещё не клюнула","No bite yet","Aún no pica","Noch kein Biss","Ça ne mord pas encore","鱼还没咬钩"], "fish_bite":["КЛЮЁТ! Нажми E ещё раз","BITE! Press E again","¡PICA! Pulsa E otra vez","BISS! Drücke E erneut","ÇA MORD ! Appuie encore sur E","咬钩了！再次按E"],
	"bought":["Куплено: %s","Bought: %s","Comprado: %s","Gekauft: %s","Acheté : %s","已购买：%s"], "sold":["Продано: %s +%d монет","Sold: %s +%d coins","Vendido: %s +%d monedas","Verkauft: %s +%d Münzen","Vendu : %s +%d pièces","已出售：%s +%d金币"],
	"no_coins":["Не хватает монет","Not enough coins","No hay monedas suficientes","Nicht genug Münzen","Pas assez de pièces","金币不足"], "no_product":["У тебя нет этого товара","You do not have this item","No tienes este objeto","Du hast diesen Gegenstand nicht","Tu n'as pas cet objet","你没有此商品"],
	"needs":["Не хватает: %s","Missing: %s","Falta: %s","Fehlt: %s","Manque : %s","缺少：%s"], "crafted":["Создано: %s","Crafted: %s","Creado: %s","Hergestellt: %s","Fabriqué : %s","已制作：%s"],
	"dry_crop":["Земля подсохла — нужен второй полив","Soil is dry — water again","La tierra está seca — riega otra vez","Boden ist trocken — erneut gießen","Le sol est sec — arrose encore","土地干了——需要再次浇水"], "crop_ready":["Морковь созрела — собери её руками [4]","Carrot is ripe — harvest by hand [4]","Zanahoria lista — recoge a mano [4]","Karotte reif — mit Händen ernten [4]","Carotte mûre — récolte à la main [4]","胡萝卜成熟——徒手收获[4]"],
	"no_resource":["Рядом нет залежей для добычи","No mineable resource nearby","No hay recursos cerca","Keine Lagerstätte in der Nähe","Aucun gisement à proximité","附近没有可开采资源"], "need_pickaxe":["Для добычи выбери кирку [5]","Select pickaxe [5] to mine","Elige el pico [5]","Wähle die Spitzhacke [5]","Choisis la pioche [5]","选择镐[5]进行开采"],
	"mined":["Добыто: %s ×%d","Mined: %s ×%d","Extraído: %s ×%d","Abgebaut: %s ×%d","Extrait : %s ×%d","已开采：%s ×%d"], "depleted":["Жила исчерпана","Vein depleted","Veta agotada","Ader erschöpft","Gisement épuisé","矿脉已枯竭"],
	"assigned":["%s назначен в слот %d","%s assigned to slot %d","%s asignado al espacio %d","%s auf Platz %d gelegt","%s assigné à l'emplacement %d","%s已分配到槽位%d"], "in_hand":["В руках: %s","In hand: %s","En mano: %s","In der Hand: %s","En main : %s","手持：%s"],
	"no_points":["Нет свободных очков навыков","No free skill points","No hay puntos libres","Keine freien Fertigkeitspunkte","Aucun point libre","没有可用技能点"], "rank_up":["%s: ранг %d","%s: rank %d","%s: rango %d","%s: Rang %d","%s : rang %d","%s：等级%d"],
	"shop_buy_only":["Этот товар лавка только покупает","The shop only buys this item","La tienda solo compra este objeto","Der Laden kauft diesen Gegenstand nur","La boutique achète seulement cet objet","商店只收购此商品"], "shop_sell_only":["Этот товар лавка не покупает","The shop does not buy this item","La tienda no compra este objeto","Der Laden kauft diesen Gegenstand nicht","La boutique n'achète pas cet objet","商店不收购此商品"],
	"carrot_quest":["Задание: принеси бабушке 10 морковок","Quest: bring Grandma 10 carrots","Misión: lleva 10 zanahorias a la abuela","Aufgabe: Bring Oma 10 Karotten","Quête : apporte 10 carottes à Grand-mère","任务：给奶奶带10根胡萝卜"],
	"carrot_done":["Квест выполнен! +50 монет, +25 XP и лук","Quest complete! +50 coins, +25 XP and bow","¡Misión completa! +50 monedas, +25 XP y arco","Aufgabe erfüllt! +50 Münzen, +25 XP und Bogen","Quête terminée ! +50 pièces, +25 XP et arc","任务完成！+50金币、+25经验和弓"],
	"carrot_wait":["Бабушка ждёт морковь: %d/10","Grandma awaits carrots: %d/10","La abuela espera zanahorias: %d/10","Oma wartet auf Karotten: %d/10","Grand-mère attend les carottes : %d/10","奶奶等待胡萝卜：%d/10"],
	"thanks":["Спасибо за помощь!","Thank you for your help!","¡Gracias por tu ayuda!","Danke für deine Hilfe!","Merci pour ton aide !","谢谢你的帮助！"],
	"mission_started":["%s: %s. Открой журнал [J]","%s: %s. Open journal [J]","%s: %s. Abre el diario [J]","%s: %s. Öffne das Buch [J]","%s : %s. Ouvre le journal [J]","%s：%s。打开日志[J]"],
	"mission_wait":["%s ждёт: %s %d/%d","%s awaits: %s %d/%d","%s espera: %s %d/%d","%s wartet: %s %d/%d","%s attend : %s %d/%d","%s等待：%s %d/%d"],
	"mission_done":["%s выполнено! +%d монет, +%d XP, %s","%s complete! +%d coins, +%d XP, %s","¡%s completa! +%d monedas, +%d XP, %s","%s erfüllt! +%d Münzen, +%d XP, %s","%s terminée ! +%d pièces, +%d XP, %s","%s完成！+%d金币，+%d经验，%s"],
	"level_up":["Новый уровень %d! Получено очко навыка [K]","Level %d! Skill point gained [K]","¡Nivel %d! Punto de habilidad [K]","Stufe %d! Fertigkeitspunkt [K]","Niveau %d ! Point de compétence [K]","升到%d级！获得技能点[K]"],
}

const ITEMS := {
	"hoe":["Мотыга","Hoe","Azada","Hacke","Houe","锄头"], "seeds":["Семена моркови","Carrot seeds","Semillas de zanahoria","Karottensamen","Graines de carotte","胡萝卜种子"],
	"water":["Лейка","Watering can","Regadera","Gießkanne","Arrosoir","水壶"], "hand":["Руки","Hands","Manos","Hände","Mains","双手"], "pickaxe":["Кирка","Pickaxe","Pico","Spitzhacke","Pioche","镐"], "fishing_rod":["Удочка","Fishing rod","Caña","Angelrute","Canne à pêche","鱼竿"],
	"carrot":["Морковь","Carrot","Zanahoria","Karotte","Carotte","胡萝卜"], "apple":["Лесное яблоко","Forest apple","Manzana silvestre","Waldapfel","Pomme sauvage","森林苹果"], "berries":["Лесные ягоды","Wild berries","Bayas silvestres","Waldbeeren","Baies sauvages","野莓"],
	"nut":["Крепкий орех","Hard nut","Nuez dura","Harte Nuss","Noix robuste","硬坚果"], "mushroom":["Красный гриб","Red mushroom","Seta roja","Roter Pilz","Champignon rouge","红蘑菇"], "orange":["Сочный апельсин","Juicy orange","Naranja jugosa","Saftige Orange","Orange juteuse","多汁橙子"],
	"watermelon":["Сочный арбуз","Juicy watermelon","Sandía jugosa","Saftige Wassermelone","Pastèque juteuse","多汁西瓜"], "healing_potion":["Лечебное зелье","Healing potion","Poción curativa","Heiltrank","Potion de soin","治疗药水"],
	"slime":["Слизь","Slime gel","Gel de limo","Schleim","Gelée de slime","史莱姆胶"], "wood":["Древесина","Wood","Madera","Holz","Bois","木材"], "stone":["Камень","Stone","Piedra","Stein","Pierre","石头"], "crystal":["Синий кристалл","Blue crystal","Cristal azul","Blauer Kristall","Cristal bleu","蓝水晶"],
	"red_crystal":["Красный кристалл","Red crystal","Cristal rojo","Roter Kristall","Cristal rouge","红水晶"], "green_crystal":["Зелёный кристалл","Green crystal","Cristal verde","Grüner Kristall","Cristal vert","绿水晶"], "fish":["Речная рыба","River fish","Pez de río","Flussfisch","Poisson de rivière","河鱼"],
	"sword":["Лесной меч","Forest sword","Espada del bosque","Waldschwert","Épée sylvestre","森林剑"], "bow":["Охотничий лук","Hunting bow","Arco de caza","Jagdbogen","Arc de chasse","猎弓"], "crystal_sword":["Кристальный меч","Crystal sword","Espada de cristal","Kristallschwert","Épée de cristal","水晶剑"],
	"fiber":["Лесное волокно","Forest fiber","Fibra forestal","Waldfaser","Fibre forestière","森林纤维"], "rare_seeds":["Редкие семена","Rare seeds","Semillas raras","Seltene Samen","Graines rares","稀有种子"], "metal":["Металл","Metal","Metal","Metall","Métal","金属"], "bones":["Кости","Bones","Huesos","Knochen","Os","骨头"],
	"ancient_key":["Древний ключ","Ancient key","Llave antigua","Alter Schlüssel","Clé ancienne","远古钥匙"], "blue_gem":["Синий алмаз","Blue diamond","Diamante azul","Blauer Diamant","Diamant bleu","蓝钻石"], "moon_relic":["Лунная реликвия","Moon relic","Reliquia lunar","Mondreliquie","Relique lunaire","月之遗物"],
	"raw_meat":["Сырое мясо","Raw meat","Carne cruda","Rohes Fleisch","Viande crue","生肉"], "hide":["Оленья шкура","Deer hide","Piel de ciervo","Hirschhaut","Peau de cerf","鹿皮"], "fur":["Лисий мех","Fox fur","Piel de zorro","Fuchsfell","Fourrure de renard","狐皮"],
	"tusk":["Кабаний клык","Boar tusk","Colmillo de jabalí","Eberhauer","Défense de sanglier","野猪獠牙"], "bat_wing":["Крыло летучей мыши","Bat wing","Ala de murciélago","Fledermausflügel","Aile de chauve-souris","蝙蝠翼"], "lizard_scale":["Чешуя листохвоста","Leaf-tail scale","Escama de lagarto","Blattschwanzschuppe","Écaille de lézard","叶尾蜥鳞片"],
	"iron_helmet":["Железный шлем","Iron helmet","Casco de hierro","Eisenhelm","Casque de fer","铁头盔"], "guardian_armor":["Доспех хранителя","Guardian armor","Armadura del guardián","Wächterrüstung","Armure du gardien","守护者铠甲"], "travel_boots":["Походные сапоги","Travel boots","Botas de viaje","Reisestiefel","Bottes de voyage","旅行靴"],
	"crystal_ring":["Алмазный талисман","Diamond talisman","Talismán de diamante","Diamanttalisman","Talisman de diamant","钻石护符"], "orc_blade":["Клинок орка","Orc blade","Hoja orca","Orkklinge","Lame orque","兽人之刃"], "oak_shield":["Дубовый щит","Oak shield","Escudo de roble","Eichenschild","Bouclier de chêne","橡木盾"],
}

const LOCATIONS := {
	"overworld":["Деревня и гильдия","Village and guild","Aldea y gremio","Dorf und Gilde","Village et guilde","村庄与公会"], "forest":["Обычный лес","Common forest","Bosque común","Gewöhnlicher Wald","Forêt ordinaire","普通森林"],
	"rocky":["Каменистая область","Rocky region","Región rocosa","Felsgebiet","Région rocheuse","岩石地区"], "ruins":["Орочьи руины","Orc ruins","Ruinas orcas","Orkruinen","Ruines orques","兽人遗迹"],
	"cave":["Кристальные пещеры","Crystal caves","Cuevas de cristal","Kristallhöhlen","Grottes de cristal","水晶洞穴"], "cursed":["Проклятая земля","Cursed land","Tierra maldita","Verfluchtes Land","Terre maudite","诅咒之地"], "glassworks":["Мастерская стеклодува","Glassblower workshop","Taller de vidrio","Glasbläserwerkstatt","Atelier du verrier","玻璃工坊"],
}

const TUTORIAL := {
	"move":["Пройди немного стрелками или WASD","Move with arrows or WASD","Muévete con flechas o WASD","Bewege dich mit Pfeilen oder WASD","Déplace-toi avec les flèches ou WASD","用方向键或WASD移动"],
	"audio_feedback":["Проверь музыку локации и звук действия","Check location music and an action sound","Comprueba la música y un sonido de acción","Prüfe Gebietsmusik und Aktionsklang","Vérifie la musique et un son d'action","检查区域音乐和动作音效"],
	"character_animation":["Пройди во все четыре стороны","Walk in all four directions","Camina en cuatro direcciones","Gehe in alle vier Richtungen","Marche dans les quatre directions","向四个方向行走"],
	"forage_harvest":["Собери дикий урожай [E]","Harvest a wild plant [E]","Cosecha una planta [E]","Ernte eine Wildpflanze [E]","Récolte une plante [E]","采集野生作物 [E]"],
	"forage_regrow":["Дождись повторного созревания","Wait for a plant to regrow","Espera el nuevo crecimiento","Warte auf neues Wachstum","Attends la repousse","等待植物再生"],
	"forage_sale":["Продай дикий урожай","Sell wild produce","Vende productos silvestres","Verkaufe Wildfrüchte","Vends une récolte sauvage","出售野生作物"],
	"talk":["Поговори с бабушкой [E]","Talk to Grandma [E]","Habla con la abuela [E]","Sprich mit Oma [E]","Parle à Grand-mère [E]","和奶奶交谈 [E]"],
	"hold_action":["Держи движение + E с мотыгой","Hold movement + E with the hoe","Mantén movimiento + E con la azada","Halte Bewegung + E mit der Hacke","Maintiens mouvement + E avec la houe","拿锄头时按住移动键+E"],
	"plant":["Вспаши и посади морковь","Till soil and plant carrots","Ara y planta zanahorias","Pflüge und pflanze Karotten","Laboure et plante des carottes","耕地并种胡萝卜"],
	"water":["Полей морковь лейкой [3]","Water carrots with slot [3]","Riega con la regadera [3]","Gieße mit der Kanne [3]","Arrose avec l'arrosoir [3]","用水壶浇水 [3]"],
	"rewater":["Полей повторно после красной капли","Water again after the red drop","Riega tras la gota roja","Gieße nach dem roten Tropfen","Arrose après la goutte rouge","红色水滴出现后再次浇水"],
	"harvest":["Собери зрелую морковь руками [4]","Harvest ripe carrots by hand [4]","Cosecha zanahorias a mano [4]","Ernte reife Karotten per Hand [4]","Récolte les carottes à la main [4]","徒手收获胡萝卜 [4]"],
	"shop":["Открой сельскую лавку","Open the village shop","Abre la tienda","Öffne den Dorfladen","Ouvre la boutique","打开乡村商店"],
	"trade":["Купи или продай товар","Buy or sell an item","Compra o vende un objeto","Kaufe oder verkaufe Ware","Achète ou vends un objet","购买或出售商品"],
	"quest_complete":["Принеси бабушке 10 морковок","Bring Grandma 10 carrots","Lleva 10 zanahorias a la abuela","Bring Oma 10 Karotten","Apporte 10 carottes à Grand-mère","给奶奶带10根胡萝卜"],
	"fight":["Атакуй слизня [F]","Attack the slime [F]","Ataca al limo [F]","Greife den Schleim an [F]","Attaque le slime [F]","攻击史莱姆 [F]"],
	"combat_animation":["Проверь замах, реакцию и смерть врага","Check the swing, hit reaction, and enemy death","Comprueba el golpe, la reacción y la muerte","Prüfe Schlag, Trefferreaktion und Tod","Vérifie l'attaque, la réaction et la mort","检查攻击、受击与死亡动画"],
	"loot":["Подбери добычу [E]","Pick up loot [E]","Recoge el botín [E]","Sammle Beute ein [E]","Ramasse le butin [E]","拾取战利品 [E]"],
	"inventory":["Открой рюкзак [Tab]","Open backpack [Tab]","Abre la mochila [Tab]","Öffne den Rucksack [Tab]","Ouvre le sac [Tab]","打开背包 [Tab]"],
	"hotbar":["Назначь предмет клавишей 1–0","Assign an item with 1–0","Asigna un objeto con 1–0","Belege einen Platz mit 1–0","Assigne un objet avec 1–0","用1–0设置快捷物品"],
	"eat":["Употреби еду из рюкзака","Use food from the backpack","Usa comida de la mochila","Benutze Essen aus dem Rucksack","Utilise un aliment du sac","使用背包中的食物"],
	"equipment":["Надень экипировку [Q]","Equip an item [Q]","Equipa un objeto [Q]","Lege Ausrüstung an [Q]","Équipe un objet [Q]","装备物品 [Q]"],
	"mine":["Добудь ресурс киркой [5]","Mine a resource with [5]","Extrae un recurso con [5]","Baue eine Ressource mit [5] ab","Extrais une ressource avec [5]","用镐采集资源 [5]"],
	"fish":["Поймай рыбу у воды [6]","Catch a fish by water [6]","Pesca junto al agua [6]","Fange einen Fisch [6]","Attrape un poisson [6]","在水边钓鱼 [6]"],
	"craft_window":["Создай предмет на верстаке","Craft at the workbench","Fabrica en el banco","Stelle etwas an der Werkbank her","Fabrique à l'établi","在工作台制作物品"],
	"equip":["Переключи оружие [R]","Switch weapon [R]","Cambia de arma [R]","Wechsle die Waffe [R]","Change d'arme [R]","切换武器 [R]"],
	"collision":["Перейди реку по мосту","Cross the river by bridge","Cruza el río por el puente","Überquere den Fluss über die Brücke","Traverse la rivière par le pont","从桥上过河"],
	"travel":["Войди в пещеру [E]","Enter the cave [E]","Entra en la cueva [E]","Betritt die Höhle [E]","Entre dans la grotte [E]","进入洞穴 [E]"],
	"locations":["Посети следующую локацию","Visit the next location","Visita la siguiente zona","Besuche das nächste Gebiet","Visite la zone suivante","前往下一个地区"],
	"mission_accept":["Возьми миссию у NPC","Accept a mission from an NPC","Acepta una misión","Nimm eine Mission an","Accepte une mission","从NPC处接取任务"],
	"mission_complete":["Выполни сюжетную миссию","Complete a story mission","Completa una misión principal","Schließe eine Hauptmission ab","Termine une mission principale","完成主线任务"],
	"journal":["Открой журнал [J]","Open journal [J]","Abre el diario [J]","Öffne das Aufgabenbuch [J]","Ouvre le journal [J]","打开任务日志 [J]"],
	"side_mission":["Выполни побочную миссию","Complete a side mission","Completa una misión secundaria","Schließe eine Nebenmission ab","Termine une mission secondaire","完成支线任务"],
	"colored_crystal":["Добудь цветной кристалл","Mine a colored crystal","Extrae un cristal de color","Baue einen Farbkristall ab","Extrais un cristal coloré","采集彩色水晶"],
	"day":["Закончи день у дома [N]","End the day at home [N]","Termina el día en casa [N]","Beende den Tag am Haus [N]","Termine la journée à la maison [N]","在家结束一天 [N]"],
	"level_up":["Получи новый уровень","Gain a new level","Sube de nivel","Steige eine Stufe auf","Gagne un niveau","提升等级"],
	"skill_point":["Вложи очко навыка [K]","Spend a skill point [K]","Gasta un punto [K]","Vergib einen Punkt [K]","Dépense un point [K]","分配技能点 [K]"],
	"profession":["Развивай ремесло практикой","Train a profession","Entrena una profesión","Trainiere einen Beruf","Entraîne un métier","训练一种职业"],
	"save":["Сохрани и загрузи игру","Save and load the game","Guarda y carga la partida","Speichere und lade das Spiel","Sauvegarde et charge la partie","保存并加载游戏"],
	"wildlife":["Найди пугливого зверя","Find a timid animal","Encuentra un animal tímido","Finde ein scheues Tier","Trouve un animal peureux","找到胆小的动物"],
	"world_loot":["Обыщи случайный тайник [E]","Search a random stash [E]","Busca un escondite [E]","Durchsuche ein Versteck [E]","Fouille une cache [E]","搜索随机藏匿物 [E]"],
	"watermelon":["Собери и съешь арбуз","Harvest and eat watermelon","Cosecha y come sandía","Ernte und iss Wassermelone","Récolte et mange une pastèque","收获并吃西瓜"],
	"potion":["Создай и используй зелье","Craft and use a potion","Fabrica y usa una poción","Stelle einen Trank her","Fabrique et utilise une potion","制作并使用药水"],
	"shield":["Создай и надень щит","Craft and equip a shield","Fabrica y equipa un escudo","Baue und trage einen Schild","Fabrique et équipe un bouclier","制作并装备盾牌"],
	"lizard":["Найди лугового листохвоста","Find the meadow leaf-tail","Encuentra al lagarto de pradera","Finde den Wiesen-Blattschwanz","Trouve le lézard des prés","找到草地叶尾蜥"],
}

const SKILLS := {
	"vitality":["Здоровье|+10 к максимальному здоровью","Vitality|+10 maximum health","Vitalidad|+10 de salud máxima","Vitalität|+10 maximales Leben","Vitalité|+10 santé maximale","生命|最大生命+10"],
	"mana":["Мана|+10 маны и быстрее восстановление","Mana|+10 mana and faster recovery","Maná|+10 maná y recuperación","Mana|+10 Mana und Regeneration","Mana|+10 mana et récupération","法力|法力+10并加速恢复"],
	"stamina":["Стамина|+2 к запасу сил","Stamina|+2 stamina","Energía|+2 de energía","Ausdauer|+2 Ausdauer","Endurance|+2 endurance","耐力|耐力+2"],
	"farming":["Фермерство|Опыт за грядки; больше урожая","Farming|Farm XP; larger harvests","Agricultura|XP agrícola; más cosecha","Landwirtschaft|Farm-XP; mehr Ernte","Agriculture|XP agricole; récoltes accrues","耕作|获得耕作经验；提高收成"],
	"smithing":["Кузнечное дело|Опыт за крафт; дешёвые рецепты","Smithing|Craft XP; cheaper recipes","Herrería|XP de creación; recetas baratas","Schmieden|Herstellungs-XP; günstigere Rezepte","Forge|XP de fabrication; recettes réduites","锻造|制作经验；降低配方消耗"],
	"combat":["Бой|Опыт за победы; больше урона","Combat|Battle XP; more damage","Combate|XP de batalla; más daño","Kampf|Kampf-XP; mehr Schaden","Combat|XP de bataille; plus de dégâts","战斗|战斗经验；提高伤害"],
	"mining":["Горное дело|Опыт за добычу; больше руды","Mining|Mining XP; more ore","Minería|XP minera; más mineral","Bergbau|Bergbau-XP; mehr Erz","Minage|XP de minage; plus de minerai","采矿|采矿经验；增加矿石"],
	"fishing":["Рыбалка|Опыт за улов; быстрее поклёвка","Fishing|Fishing XP; faster bites","Pesca|XP de pesca; pique rápido","Angeln|Angel-XP; schnellerer Biss","Pêche|XP de pêche; touche rapide","钓鱼|钓鱼经验；更快咬钩"],
}

const QUESTS := {
	"story_relic.type":["СЮЖЕТ","STORY","HISTORIA","STORY","HISTOIRE","主线"], "story_relic.title":["Сердце пещеры","Heart of the Cave","Corazón de la cueva","Herz der Höhle","Cœur de la grotte","洞穴之心"],
	"story_relic.giver":["Староста Мирон","Elder Miron","Anciano Miron","Ältester Miron","Ancien Miron","村长米隆"], "story_relic.description":["Победи Хранителя глубин и принеси Лунную реликвию.","Defeat the Depth Guardian and bring the Moon Relic.","Derrota al Guardián y trae la Reliquia Lunar.","Besiege den Tiefenwächter und bringe die Mondreliquie.","Vaincs le Gardien et rapporte la Relique lunaire.","击败深渊守护者并带回月之遗物。"],
	"side_seed.type":["ПОБОЧНОЕ","SIDE","SECUNDARIA","NEBENQUEST","SECONDAIRE","支线"], "side_seed.title":["Редкий росток","Rare Sprout","Brote raro","Seltener Spross","Pousse rare","稀有幼苗"],
	"side_seed.giver":["Травница Агафья","Herbalist Agafya","Herbolaria Agafya","Kräuterfrau Agafya","Herboriste Agafya","草药师阿加菲娅"], "side_seed.description":["Победи хищное растение и принеси редкое семя.","Defeat the predatory plant and bring a rare seed.","Derrota la planta depredadora y trae una semilla rara.","Besiege die Raubpflanze und bringe einen seltenen Samen.","Vaincs la plante prédatrice et rapporte une graine rare.","击败食人植物并带回稀有种子。"],
}

const ENTITIES := {
	"grandmother":["Бабушка","Grandma","Abuela","Oma","Grand-mère","奶奶"], "farm":["Грядки","Farm plots","Parcelas","Beete","Parcelles","田地"], "pond":["Рыбное место","Fishing spot","Zona de pesca","Angelplatz","Coin de pêche","钓鱼点"],
	"bridge":["Мост","Bridge","Puente","Brücke","Pont","桥"], "world_gate":["Золотые врата","Golden gate","Puerta dorada","Goldenes Tor","Porte dorée","金色传送门"], "workbench":["Верстак","Workbench","Banco de trabajo","Werkbank","Établi","工作台"], "slime":["Слизень","Slime","Limo","Schleim","Slime","史莱姆"],
	"deer":["Лесной олень","Forest deer","Ciervo del bosque","Waldhirsch","Cerf forestier","森林鹿"], "fox":["Рыжая лиса","Red fox","Zorro rojo","Rotfuchs","Renard roux","赤狐"], "boar":["Дикий кабан","Wild boar","Jabalí","Wildschwein","Sanglier","野猪"], "bat":["Пещерная мышь","Cave bat","Murciélago","Höhlenfledermaus","Chauve-souris","洞穴蝙蝠"], "lizard":["Луговой листохвост","Meadow leaf-tail","Lagarto de pradera","Wiesen-Blattschwanz","Lézard des prés","草地叶尾蜥"],
	"plant":["Хищное растение","Predatory plant","Planta depredadora","Raubpflanze","Plante prédatrice","食人植物"], "orc":["Орк-разбойник","Orc raider","Orco bandido","Orkräuber","Orc pillard","兽人强盗"], "skeleton":["Скелет","Skeleton","Esqueleto","Skelett","Squelette","骷髅"], "undead":["Проклятый рыцарь","Cursed knight","Caballero maldito","Verfluchter Ritter","Chevalier maudit","诅咒骑士"], "cave_guardian":["Хранитель глубин","Depth Guardian","Guardián profundo","Tiefenwächter","Gardien des profondeurs","深渊守护者"],
	"berries":["Ягодный куст","Berry bush","Arbusto de bayas","Beerenbusch","Buisson à baies","浆果灌木"], "mushroom":["Грибная поляна","Mushroom patch","Claro de setas","Pilzplatz","Carré de champignons","蘑菇地"], "watermelon":["Арбузная бахча","Watermelon patch","Melonar","Melonenfeld","Carré de pastèques","西瓜地"], "apple":["Яблоня","Apple tree","Manzano","Apfelbaum","Pommier","苹果树"], "nut":["Ореховое дерево","Nut tree","Nogal","Nussbaum","Noyer","坚果树"],
	"chest":["Старый сундук","Old chest","Cofre viejo","Alte Truhe","Vieux coffre","旧宝箱"], "bone_pile":["Груда костей","Bone pile","Pila de huesos","Knochenhaufen","Tas d'os","骨堆"], "sack":["Брошенный мешок","Abandoned sack","Saco abandonado","Verlassener Sack","Sac abandonné","废弃麻袋"], "trash":["Куча хлама","Junk pile","Montón de basura","Gerümpelhaufen","Tas de débris","垃圾堆"],
}

static func index() -> int:
	return maxi(LOCALES.find(current), 0)

static func translated(table: Dictionary, key: String, fallback: String = "") -> String:
	var values: Array = table.get(key, [])
	return fallback if values.is_empty() else String(values[index()])

static func ui(key: String, values: Array = []) -> String:
	var result := translated(UI, key, key)
	return result % values if not values.is_empty() else result

static func text(key: String, values: Array = []) -> String:
	var result := translated(TEXT, key, key)
	return result % values if not values.is_empty() else result

static func item(kind: String, short: bool = false) -> String:
	var value := translated(ITEMS, kind, kind)
	return value.left(9) if short else value

static func tutorial(event_name: String) -> String:
	return translated(TUTORIAL, event_name, event_name)

static func location(kind: String) -> String:
	return translated(LOCATIONS, kind, kind)

static func skill(kind: String, description: bool = false) -> String:
	var parts := translated(SKILLS, kind, kind).split("|", true, 1)
	return parts[1] if description and parts.size() > 1 else parts[0]

static func quest(mission_id: String, field: String) -> String:
	return translated(QUESTS, "%s.%s" % [mission_id, field], mission_id)

static func entity(kind: String) -> String:
	return translated(ENTITIES, kind, kind)

static func language_name(locale_index: int) -> String:
	return LANGUAGE_NAMES[clampi(locale_index, 0, LANGUAGE_NAMES.size() - 1)]

static func load_locale(path: String = SETTINGS_PATH) -> String:
	var config := ConfigFile.new()
	if config.load(path) == OK:
		var saved := String(config.get_value("language", "locale", "ru"))
		if saved in LOCALES: current = saved
	TranslationServer.set_locale("zh_CN" if current == "zh" else current)
	return current

static func set_locale(code: String, persist: bool = true, path: String = SETTINGS_PATH) -> bool:
	if code not in LOCALES: return false
	current = code
	TranslationServer.set_locale("zh_CN" if code == "zh" else code)
	if persist:
		var config := ConfigFile.new()
		config.set_value("language", "locale", code)
		return config.save(path) == OK
	return true
