extends RefCounted

const TEXT := {
	"put":["Положить ×%d", "Store ×%d", "Guardar ×%d", "Lagern ×%d", "Déposer ×%d", "存入%d个"],
	"stack":["Весь стек", "Whole stack", "Toda la pila", "Ganzer Stapel", "Toute la pile", "整组"],
	"storage_subtitle":["Рюкзак слева · Предмет по центру · Хранилище справа · Мир на паузе", "Bag left · Item center · Storage right · World paused", "Mochila izquierda · Objeto central · Almacén derecha · Mundo pausado", "Rucksack links · Gegenstand mittig · Lager rechts · Welt pausiert", "Sac à gauche · Objet au centre · Stockage à droite · Monde en pause", "左侧背包 · 中间物品 · 右侧储存 · 世界暂停"],
	"grid_help":["Колесо/свайп: строки • Tab/L3: сторона • Стрелки: выбор • Enter/A: 1 • D/M: внести • S/T: сортировка • Esc/B: закрыть", "Wheel/swipe: rows · Tab/L3: side · Arrows: select · Enter/A: 1 · D/M: store · S/T: sort · Esc/B: close", "Rueda/deslizar: filas · Tab/L3: lado · Flechas: elegir · Enter/A: 1 · D/M: guardar · S/T: ordenar · Esc/B: cerrar", "Rad/Wischen: Zeilen · Tab/L3: Seite · Pfeile: Auswahl · Enter/A: 1 · D/M: lagern · S/T: sortieren · Esc/B: schließen", "Molette/glisser : lignes · Tab/L3 : côté · Flèches : choix · Enter/A : 1 · D/M : déposer · S/T : trier · Esc/B : fermer", "滚轮/滑动：行 · Tab/L3：切换侧 · 方向键：选择 · Enter/A：1个 · D/M：存入 · S/T：排序 · Esc/B：关闭"],
	"title":["Шкаф снабжения","Supply cabinet","Armario de suministros","Vorratsschrank","Armoire de fournitures","物资柜"],
	"subtitle":["Разработка · Все предметы по 999 · Мир на паузе","Development · Every item ×999 · World paused","Desarrollo · Cada objeto ×999 · Mundo en pausa","Entwicklung · Alle Gegenstände ×999 · Welt pausiert","Développement · Chaque objet ×999 · Monde en pause","开发 · 每种物品999个 · 世界已暂停"],
	"context":["Открыть шкаф снабжения","Open supply cabinet","Abrir armario de suministros","Vorratsschrank öffnen","Ouvrir l’armoire","打开物资柜"],
	"all":["Все","All","Todo","Alle","Tout","全部"],
	"craft":["Крафт","Crafting","Fabricación","Handwerk","Artisanat","制作"],
	"food":["Еда","Food","Comida","Essen","Nourriture","食物"],
	"alchemy":["Алхимия","Alchemy","Alquimia","Alchemie","Alchimie","炼金"],
	"equipment":["Снаряжение","Equipment","Equipo","Ausrüstung","Équipement","装备"],
	"tools":["Инструменты","Tools","Herramientas","Werkzeuge","Outils","工具"],
	"seeds":["Семена","Seeds","Semillas","Samen","Graines","种子"],
	"other":["Прочее","Other","Otros","Sonstiges","Divers","其他"],
	"search":["Поиск по названию или ID · F","Search name or ID · F","Buscar nombre o ID · F","Name oder ID suchen · F","Rechercher nom ou ID · F","搜索名称或ID · F"],
	"found":["Найдено: %d","Found: %d","Encontrados: %d","Gefunden: %d","Trouvés : %d","找到：%d"],
	"refill":["Пополнить ×999","Refill ×999","Reponer ×999","Auffüllen ×999","Remplir ×999","补充至999"],
	"refilled":["Запасы пополнены, минимум 999 каждого","Stocks refilled to at least 999 each","Existencias: al menos 999 de cada objeto","Vorräte auf mindestens 999 aufgefüllt","Stocks remplis à au moins 999 chacun","每种库存至少补充至999"],
	"take":["Взять ×%d","Take ×%d","Tomar ×%d","Nehmen ×%d","Prendre ×%d","拿取%d个"],
	"stock":["В шкафу: %d","In cabinet: %d","En armario: %d","Im Schrank: %d","Dans l’armoire : %d","柜内：%d"],
	"bag":["В рюкзаке: %d","In bag: %d","En mochila: %d","Im Rucksack: %d","Dans le sac : %d","背包：%d"],
	"taken":["%s ×%d — в рюкзаке","%s ×%d added to bag","%s ×%d en la mochila","%s ×%d im Rucksack","%s ×%d dans le sac","%s ×%d已放入背包"],
	"empty":["По запросу ничего не найдено","No matching items","No hay coincidencias","Keine passenden Gegenstände","Aucun objet correspondant","未找到匹配物品"],
	"unique":["Этот предмет используется по одному","This item is used one at a time","Este objeto se usa de uno en uno","Dieser Gegenstand wird einzeln genutzt","Cet objet s’utilise à l’unité","此物品每次使用一个"],
	"help":["Стрелки: выбор • Tab/LB/RB: вкладка • Enter/A: 1 • X: 100 • Y: 999 • D/Start: внести всё • M/View: совп. • S/T/R3: сорт. • R: запас • Esc/B: закрыть","Arrows: select • Tab/LB/RB: tab • Enter/A: 1 • X: 100 • Y: 999 • D/Start: store all • M/View: matching • S/T/R3: sort • R: refill • Esc/B: close","Flechas: elegir • Tab/LB/RB: pestaña • Enter/A: 1 • X: 100 • Y: 999 • D/Start: guardar todo • M/View: coincidentes • S/T/R3: ordenar • R: reponer • Esc/B: cerrar","Pfeile: wählen • Tab/LB/RB: Kategorie • Enter/A: 1 • X: 100 • Y: 999 • D/Start: alles lagern • M/View: passende • S/T/R3: sortieren • R: auffüllen • Esc/B: schließen","Flèches : choisir • Tab/LB/RB : onglet • Enter/A : 1 • X : 100 • Y : 999 • D/Start : tout déposer • M/View : similaires • S/T/R3 : trier • R : remplir • Esc/B : fermer","方向键：选择 • Tab/LB/RB：分类 • Enter/A：1 • X：100 • Y：999 • D/Start：全部存入 • M/View：已有 • S/T/R3：排序 • R：补充 • Esc/B：关闭"],
}

## Даёт самостоятельные подписи временного шкафа на всех языках игры.
static func text(game: Node, key: String, args: Array=[]) -> String:
	var label:String=TEXT.get(key,[key,key,key,key,key,key])[game.LocaleSystem.index()]
	return label%args if not args.is_empty() else label
