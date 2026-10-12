extends RefCounted

const NAMES := {
	"workbench":["Верстак","Workbench","Banco de trabajo","Werkbank","Établi","工作台"],
	"sawmill":["Лесопилка","Sawmill","Aserradero","Sägewerk","Scierie","锯木机"],
	"pottery":["Гончарный круг","Pottery wheel","Torno de alfarería","Töpferscheibe","Tour de potier","陶轮"],
	"furnace":["Горн","Furnace","Horno","Schmelzofen","Fourneau","熔炉"],
	"glassblowing":["Стеклодув","Glassblower","Soplado de vidrio","Glasbläserei","Soufflerie","玻璃工坊"],
	"study":["Исследовательский стол","Research desk","Mesa de estudio","Forschungstisch","Table d’étude","研究桌"],
	"recycling":["Разборочный станок","Dismantling bench","Banco de despiece","Zerlegebank","Table de démontage","拆解台"],
	"alchemy":["Алхимический стол","Alchemy desk","Mesa de alquimia","Alchemietisch","Table d’alchimie","炼金桌"],
	"cauldron":["Кухонный котёл","Cooking cauldron","Caldero de cocina","Kochkessel","Chaudron de cuisine","烹饪锅"],
	"forge":["Наковальня","Anvil","Yunque","Amboss","Enclume","铁砧"],
}
const UI := {
	"basement_hold_button":["Сборка\nУдерживай E / A","Assembly\nHold E / A","Montaje\nMantén E / A","Aufbau\nE / A halten","Montage\nMaintenir E / A","组装\n按住E / A"],
	"basement_place_button":["Поставить","Place","Colocar","Platzieren","Placer","放置"],
	"basement_cancel_button":["Отмена","Cancel","Cancelar","Abbrechen","Annuler","取消"],
	"basement_location":["Подвал-мастерская","Cellar workshop","Taller del sótano","Kellerwerkstatt","Atelier du sous-sol","地下工坊"],
	"basement_title":["ЧЕРТЁЖ МАСТЕРСКОЙ","WORKSHOP BLUEPRINT","PLANO DEL TALLER","WERKSTATTBAUPLAN","PLAN DE L’ATELIER","工坊蓝图"],
	"basement_build_tab":["Строить","Build","Construir","Bauen","Construire","建造"],
	"basement_upgrade_tab":["Улучшить","Upgrade","Mejorar","Ausbauen","Améliorer","升级"],
	"basement_dismantle_tab":["Разобрать","Dismantle","Desmontar","Abbauen","Démonter","拆除"],
	"basement_choose":["ВЫБРАТЬ МЕСТО","CHOOSE POSITION","ELEGIR LUGAR","PLATZ WÄHLEN","CHOISIR L’EMPLACEMENT","选择位置"],
	"basement_level":["%s · Уровень %d","%s · Level %d","%s · Nivel %d","%s · Stufe %d","%s · Niveau %d","%s · 等级%d"],
	"basement_work":["Сборка: %.0f с · Энергия: %d/с","Assembly: %.0f s · Energy: %d/s","Montaje: %.0f s · Energía: %d/s","Aufbau: %.0f s · Energie: %d/s","Montage : %.0f s · Énergie : %d/s","组装：%.0f秒 · 精力：每秒%d"],
	"basement_new_level":["Новый станок всегда уровня 1","New stations always start at level 1","Las estaciones nuevas empiezan en nivel 1","Neue Stationen beginnen auf Stufe 1","Toute nouvelle station commence au niveau 1","新工作站始终从等级1开始"],
	"basement_paid":["Материалы спишутся при размещении","Materials are paid when placed","Los materiales se gastan al colocar","Material wird beim Platzieren bezahlt","Matériaux dépensés au placement","确认放置时扣除材料"],
	"basement_return":["Вернутся материалы и остатки:","Materials and debris returned:","Materiales y restos devueltos:","Material und Reste zurück:","Matériaux et débris rendus :","返还材料与废料："],
	"basement_empty":["Станки ещё не построены","No stations built yet","Aún no hay estaciones","Noch keine Stationen gebaut","Aucune station construite","尚未建造工作站"],
	"basement_ready":["Готов к работе","Ready","Listo","Bereit","Prêt","已完成"],
	"basement_building":["Сборка %.1f / %.0f с","Assembly %.1f / %.0f s","Montaje %.1f / %.0f s","Aufbau %.1f / %.0f s","Montage %.1f / %.0f s","组装%.1f / %.0f秒"],
	"basement_hold":["Удерживай E / A / кнопку: сборка","Hold E / A / button to assemble","Mantén E / A / botón para montar","E / A / Taste zum Aufbau halten","Maintenir E / A / bouton pour monter","按住E / A /按钮进行组装"],
	"basement_context":["E / A · Открыть чертёж","E / A · Open blueprint","E / A · Abrir plano","E / A · Bauplan öffnen","E / A · Ouvrir le plan","E / A · 打开蓝图"],
	"basement_station_context":["E / A · %s","E / A · %s","E / A · %s","E / A · %s","E / A · %s","E / A · %s"],
	"basement_help":["Tab/LB/RB: раздел · ↑↓: выбор · Enter/A: действие · Esc/B: закрыть","Tab/LB/RB: tab · ↑↓: select · Enter/A: action · Esc/B: close","Tab/LB/RB: pestaña · ↑↓: elegir · Enter/A: acción · Esc/B: cerrar","Tab/LB/RB: Bereich · ↑↓: wählen · Enter/A: Aktion · Esc/B: schließen","Tab/LB/RB : onglet · ↑↓ : choisir · Entrée/A : agir · Esc/B : fermer","Tab/LB/RB：分类 · ↑↓：选择 · Enter/A：操作 · Esc/B：关闭"],
	"basement_place_help":["ЛКМ/A: поставить · R/RB: поворот · Q/LB: назад · WASD/↑↓: курсор · Esc/B: отмена","Click/A: place · R/RB: rotate · Q/LB: reverse · WASD/↑↓: cursor · Esc/B: cancel","Clic/A: colocar · R/RB: girar · Q/LB: inverso · WASD/↑↓: cursor · Esc/B: cancelar","Klick/A: setzen · R/RB: drehen · Q/LB: zurück · WASD/↑↓: Cursor · Esc/B: abbrechen","Clic/A : placer · R/RB : tourner · Q/LB : inverse · WASD/↑↓ : curseur · Esc/B : annuler","单击/A：放置 · R/RB：旋转 · Q/LB：反转 · WASD/↑↓：光标 · Esc/B：取消"],
	"basement_upgrade_board":["Улучшение — у настенного чертежа","Upgrade at the wall blueprint","Mejora en el plano de la pared","Ausbau am Wandbauplan","Amélioration au plan mural","请到墙上的蓝图升级"],
	"basement_invalid":["Недопустимый станок или поворот","Invalid station or rotation","Estación o giro no válido","Ungültige Station oder Drehung","Station ou rotation invalide","工作站或方向无效"],
	"basement_wall":["За пределами пола","Outside the floor","Fuera del suelo","Außerhalb des Bodens","Hors du sol","超出地板范围"],
	"basement_reserved":["Нужен доступ к лестнице и чертежу","Keep stairs and blueprint accessible","Deja acceso a escalera y plano","Treppe und Bauplan freihalten","Garder l’escalier et le plan accessibles","需要保留楼梯与蓝图通道"],
	"basement_player":["Герой находится на месте стройки","The hero is on the construction site","El héroe está en la obra","Held steht auf dem Bauplatz","Le héros est sur le chantier","角色站在施工位置上"],
	"basement_occupied":["Мешает соседний станок","Another station blocks this spot","Otra estación ocupa el lugar","Eine Station blockiert den Platz","Une station bloque l’emplacement","其他工作站占据了此位置"],
	"basement_approach":["Рабочая сторона недоступна","Working side is inaccessible","El lado de trabajo no es accesible","Arbeitsseite nicht erreichbar","Côté de travail inaccessible","无法到达工作侧"],
	"basement_route":["Перекрывается проход к рабочему месту","A route to a station is blocked","Se bloquea el paso a una estación","Weg zu einer Station wird versperrt","Un passage vers une station est bloqué","工作站通道被堵住"],
	"basement_materials":["Не хватает строительных материалов","Missing construction materials","Faltan materiales de obra","Baumaterial fehlt","Matériaux de construction manquants","施工材料不足"],
	"basement_money":["Не хватает монет для улучшения","Not enough coins to upgrade","Faltan monedas para mejorar","Nicht genug Münzen für Ausbau","Pas assez de pièces pour améliorer","升级所需金币不足"],
	"basement_energy":["Нужна энергия: поешь или отдохни","Need energy: eat or rest","Necesitas energía: come o descansa","Energie fehlt: essen oder ruhen","Besoin d’énergie : manger ou se reposer","精力不足：请进食或休息"],
	"basement_station_need":["Подойди к рабочей стороне готового станка","Approach the working side of a ready station","Acércate al lado de trabajo de una estación lista","Zur Arbeitsseite einer fertigen Station gehen","Approcher le côté de travail d’une station prête","请到已完成工作站的工作侧"],
	"basement_recipe_level":["Станку нужен уровень %d","Station level %d required","Se requiere estación nivel %d","Station der Stufe %d nötig","Station de niveau %d requise","需要等级%d的工作站"],
	"basement_limit":["В мастерской уже слишком много станков","Too many stations in this workshop","Demasiadas estaciones en el taller","Zu viele Stationen in der Werkstatt","Trop de stations dans l’atelier","工坊中的工作站数量已达上限"],
}
const TUTORIAL := {
	"basement_enter":["Подвал мастерской открыт через лестницу дома. Здесь есть большой свободный пол и настенный чертёж.","Enter the cellar via the cottage stairs. It has a large open floor and wall blueprint.","Entra por la escalera de casa. Hay un gran suelo libre y un plano mural.","Über die Haustreppe geht es in den Keller mit freiem Boden und Wandbauplan.","Descends par l’escalier de la maison : grand sol libre et plan mural.","通过屋内楼梯进入地下工坊，里面有宽敞地板和墙上蓝图。"],
	"basement_blueprint":["У чертежа выбирай строительство, улучшение или разборку конкретного станка.","At the blueprint choose construction, upgrade or dismantling of a specific station.","En el plano elige construir, mejorar o desmontar una estación concreta.","Am Bauplan Stationen bauen, ausbauen oder gezielt abbauen.","Au plan, choisis de construire, améliorer ou démonter une station précise.","在蓝图处选择建造、升级或拆除指定工作站。"],
	"basement_place":["Сетка покрывает весь пол. R поворачивает станок; красные клетки и недоступная рабочая сторона запрещают размещение.","The grid covers the whole floor. R rotates; red cells and an inaccessible working side prevent placement.","La cuadrícula cubre todo el suelo. R gira; casillas rojas o lado inaccesible impiden colocar.","Das Raster bedeckt den Boden. R dreht; rote Felder und versperrte Arbeitsseiten verhindern den Bau.","La grille couvre tout le sol. R tourne ; cases rouges et côté inaccessible bloquent le placement.","网格覆盖全部地板。R旋转；红色方格或无法进入的工作侧会阻止放置。"],
	"basement_build":["Материалы списаны один раз. Подойди к обозначенной стороне кучи и удерживай E/A, чтобы собирать молотком.","Materials are paid once. Approach the marked side of the pile and hold E/A to assemble with a hammer.","Los materiales se pagan una vez. Ve al lado marcado y mantén E/A para montar con martillo.","Material ist einmal bezahlt. An der markierten Seite E/A zum Hämmern halten.","Matériaux payés une fois. Côté marqué, maintiens E/A pour monter au marteau.","材料仅扣除一次。到材料堆标记的工作侧，按住E/A用锤子组装。"],
	"basement_finish":["Станок готов. Работает только лицевая сторона; новый экземпляр имеет уровень 1 и свою очередь.","Station ready. Use its working side; new instances have level 1 and independent queues.","Estación lista. Usa su lado de trabajo; cada nueva empieza en nivel 1 y tiene su cola.","Station fertig. Nur Arbeitsseite nutzbar; neue Exemplare haben Stufe 1 und eigene Warteschlangen.","Station prête. Utilise son côté de travail ; niveau 1 et file indépendante au départ.","工作站已完成。仅工作侧可使用；新工作站为等级1，队列互相独立。"],
	"basement_upgrade":["Улучшение оплачивается у чертежа, затем собирается удержанием. Очередь ждёт окончания работ; прогресс партии сохраняется.","Pay an upgrade at the blueprint, then assemble by holding. Production waits and keeps its progress.","Paga la mejora en el plano y monta manteniendo. La cola espera conservando el progreso.","Ausbau am Plan bezahlen und durch Halten aufbauen. Produktion wartet mit erhaltenem Fortschritt.","Paie au plan puis assemble en maintenant. La production attend sans perdre sa progression.","在蓝图处支付升级费用，再按住按钮施工。生产队列暂停并保留进度。"],
	"basement_dismantle":["Разборка возвращает половину потраченных компонентов, остатки дают опилки, лом или осколки. Необработанные партии возвращают своё сырьё.","Dismantling returns half the paid components; leftovers become sawdust, scrap or shards. Unprocessed jobs return their inputs.","Desmontar devuelve la mitad de componentes; restos dan serrín, chatarra o fragmentos. Los trabajos pendientes devuelven su materia prima.","Abbau gibt halbe Bauteile zurück; Reste werden Sägemehl, Schrott oder Scherben. Offene Aufträge geben ihr Material zurück.","Démontage : moitié des composants rendue, restes en sciure, ferraille ou éclats. Travaux inachevés : ingrédients rendus.","拆除返还一半已支付组件，其余变为锯末、废料或碎片。未完成的生产批次返还原料。"],
}

## Возвращает полное название личного станка на одном из шести поддерживаемых языков.
static func name_for(game: Node, kind: String, level: int=1) -> String:
	if kind=="cauldron": return game.LocaleSystem.ui("kitchen_stage%d"%clampi(level,1,3))
	return NAMES[kind][game.LocaleSystem.index()]
