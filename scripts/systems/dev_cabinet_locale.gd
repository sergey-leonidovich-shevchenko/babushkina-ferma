extends RefCounted

const TEXT := {
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
	"refilled":["Все запасы пополнены до 999","Every stock refilled to 999","Todo repuesto a 999","Alle Vorräte auf 999 aufgefüllt","Tous les stocks remis à 999","所有库存补充至999"],
	"take":["Взять ×%d","Take ×%d","Tomar ×%d","Nehmen ×%d","Prendre ×%d","拿取%d个"],
	"stock":["В шкафу: %d","In cabinet: %d","En armario: %d","Im Schrank: %d","Dans l’armoire : %d","柜内：%d"],
	"bag":["В рюкзаке: %d","In bag: %d","En mochila: %d","Im Rucksack: %d","Dans le sac : %d","背包：%d"],
	"taken":["%s ×%d — в рюкзаке","%s ×%d added to bag","%s ×%d en la mochila","%s ×%d im Rucksack","%s ×%d dans le sac","%s ×%d已放入背包"],
	"empty":["По запросу ничего не найдено","No matching items","No hay coincidencias","Keine passenden Gegenstände","Aucun objet correspondant","未找到匹配物品"],
	"unique":["Этот предмет используется по одному","This item is used one at a time","Este objeto se usa de uno en uno","Dieser Gegenstand wird einzeln genutzt","Cet objet s’utilise à l’unité","此物品每次使用一个"],
	"help":["↑↓←→: выбор · Tab/Q/E/LB/RB: вкладка · Enter/A: 1 · Shift+Enter/X: 100 · Ctrl+Enter/Y: всё · R: пополнить · Esc/B: закрыть","Arrows: select · Tab/Q/E/LB/RB: tab · Enter/A: 1 · Shift+Enter/X: 100 · Ctrl+Enter/Y: all · R: refill · Esc/B: close","Flechas: elegir · Tab/Q/E/LB/RB: pestaña · Enter/A: 1 · Shift+Enter/X: 100 · Ctrl+Enter/Y: todo · R: reponer · Esc/B: cerrar","Pfeile: wählen · Tab/Q/E/LB/RB: Kategorie · Enter/A: 1 · Shift+Enter/X: 100 · Ctrl+Enter/Y: alle · R: auffüllen · Esc/B: schließen","Flèches : choisir · Tab/Q/E/LB/RB : onglet · Enter/A : 1 · Shift+Enter/X : 100 · Ctrl+Enter/Y : tout · R : remplir · Esc/B : fermer","方向键：选择 · Tab/Q/E/LB/RB：分类 · Enter/A：1 · Shift+Enter/X：100 · Ctrl+Enter/Y：全部 · R：补充 · Esc/B：关闭"],
}

## Даёт самостоятельные подписи временного шкафа на всех языках игры.
static func text(game: Node, key: String, args: Array=[]) -> String:
	var label:String=TEXT.get(key,[key,key,key,key,key,key])[game.LocaleSystem.index()]
	return label%args if not args.is_empty() else label
