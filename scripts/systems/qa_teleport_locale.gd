extends RefCounted

const TEXT := {
	"title":["Камень телепортации · QA","Teleport stone · QA","Piedra de teletransporte · QA","Teleportstein · QA","Pierre de téléportation · QA","传送石 · QA"],
	"use":["Переместиться","Teleport","Teletransportar","Teleportieren","Téléporter","传送"],
	"all":["Все","All","Todo","Alle","Tout","全部"],
	"world":["Мир","World","Mundo","Welt","Monde","世界"],
	"village":["Деревня","Village","Aldea","Dorf","Village","村庄"],
	"cave":["Пещеры","Caves","Cuevas","Höhlen","Grottes","洞穴"],
	"interior":["Помещения","Interiors","Interiores","Innenräume","Intérieurs","室内"],
	"search":["Поиск по названию или ID · F","Search by name or ID · F","Buscar nombre o ID · F","Name oder ID suchen · F","Chercher un nom ou ID · F","按名称或 ID 搜索 · F"],
	"empty":["Локации не найдены","No locations found","Sin ubicaciones","Keine Orte gefunden","Aucun lieu trouvé","未找到地点"],
	"hint":["↑↓ выбор · Enter/A перенос · Esc/B закрыть","↑↓ select · Enter/A teleport · Esc/B close","↑↓ elegir · Enter/A viajar · Esc/B cerrar","↑↓ wählen · Enter/A reisen · Esc/B schließen","↑↓ choisir · Enter/A voyager · Esc/B fermer","↑↓ 选择 · Enter/A 传送 · Esc/B 关闭"],
	"detail":["Любая локация без затрат. Камень остаётся в рюкзаке. Сюжетные замки обходятся только при переносе; задания и награды не завершаются автоматически.","Travel anywhere for free. The stone stays in your bag. Travel bypasses access gates; quests and rewards are not completed automatically.","Viaja gratis. La piedra permanece en la mochila. Omite bloqueos de acceso; no completa misiones ni entrega premios.","Kostenlose Reise. Der Stein bleibt im Rucksack. Zugangssperren werden umgangen; Quests und Belohnungen werden nicht automatisch abgeschlossen.","Voyage gratuit. La pierre reste dans le sac. Les accès sont contournés ; aucune quête ni récompense n’est automatiquement terminée.","免费前往任意地点，石头保留在背包中。传送绕过通行限制，不自动完成任务或发放奖励。"],
	"failed":["Не удалось найти безопасное место. Перенос отменён.","No safe arrival found. Teleport cancelled.","No hay llegada segura. Viaje cancelado.","Kein sicherer Ankunftsort. Reise abgebrochen.","Aucune arrivée sûre. Voyage annulé.","找不到安全落点，已取消传送。"],
	"disabled":["Камень доступен только в режиме разработки.","The stone is available only in development mode.","La piedra solo está disponible en desarrollo.","Der Stein ist nur im Entwicklungsmodus verfügbar.","La pierre est réservée au mode développement.","传送石仅在开发模式可用。"],
}

## Возвращает подпись тестового переноса на выбранном языке игры.
static func text(game: Node, key: String) -> String:
	return String(TEXT[key][game.LocaleSystem.index()])
