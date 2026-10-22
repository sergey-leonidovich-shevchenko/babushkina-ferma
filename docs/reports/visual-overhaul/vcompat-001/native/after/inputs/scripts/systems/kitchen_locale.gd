extends RefCounted

const UI := {
	"kitchen_ingredients":["Не хватает ингредиентов","Missing ingredients","Faltan ingredientes","Zutaten fehlen","Ingrédients manquants","食材不足"],
	"kitchen_stage1":["Котелок","Cooking pot","Caldero","Kochkessel","Marmite","锅灶"],
	"kitchen_stage2":["Кухонный очаг","Cookstove","Fogón","Kochherd","Fourneau","炉灶"],
	"kitchen_stage3":["Деревенская печь","Farmhouse oven","Horno rural","Bauernofen","Four de ferme","农家烤炉"],
	"kitchen_summary":["Выход %d · %.1f с · Энергия %d\n%s","Yield %d · %.1f s · Energy %d\n%s","Salida %d · %.1f s · Energía %d\n%s","Ertrag %d · %.1f s · Energie %d\n%s","Production %d · %.1f s · Énergie %d\n%s","产出%d · %.1f秒 · 精力%d\n%s"],
	"kitchen_cold":["Без расхода жара","No heat used","Sin consumir calor","Ohne Hitzeverbrauch","Sans chaleur","不消耗炉温"],
	"kitchen_hot":["Нужно кухонное топливо","Kitchen fuel required","Necesita combustible","Küchenbrennstoff nötig","Combustible nécessaire","需要厨房燃料"],
	"kitchen_status":["Жар %.0f/%.0f · Партии %d/%d","Heat %.0f/%.0f · Jobs %d/%d","Calor %.0f/%.0f · Lotes %d/%d","Hitze %.0f/%.0f · Aufträge %d/%d","Chaleur %.0f/%.0f · Lots %d/%d","炉温%.0f/%.0f · 批次%d/%d"],
	"kitchen_waiting":["Добавь топливо: готовка ждёт","Add fuel: cooking waits","Añade combustible","Brennstoff hinzufügen","Ajoute du combustible","添加燃料后继续烹饪"],
	"kitchen_remaining":["Осталось %.1f с","%.1f s remaining","Quedan %.1f s","Noch %.1f s","Encore %.1f s","剩余%.1f秒"],
	"kitchen_filter_all":["Все рецепты","All recipes","Todas las recetas","Alle Rezepte","Toutes les recettes","全部食谱"],
	"kitchen_filter_hot":["Горячие блюда","Hot dishes","Platos calientes","Warme Gerichte","Plats chauds","热菜"],
	"kitchen_filter_cold":["Заготовки","Preparations","Preparaciones","Vorbereitungen","Préparations","食材加工"],
	"kitchen_help":["Q/LB/RB: топливо · F/Y: загрузить · Tab/←→: раздел · Закрой окно для готовки","Q/LB/RB: fuel · F/Y: load · Tab/←→: category · Close window to cook","Q/LB/RB: combustible · F/Y: cargar · Tab/←→: grupo · Cierra para cocinar","Q/LB/RB: Brennstoff · F/Y: laden · Tab/←→: Gruppe · Zum Kochen schließen","Q/LB/RB : combustible · F/Y : charger · Tab/←→ : groupe · Fermer pour cuire","Q/LB/RB：燃料 · F/Y：添加 · Tab/←→：分类 · 关闭窗口烹饪"],
}
const TUTORIAL := {
	"kitchen_queue":["Личная кухня резервирует ингредиенты и энергию сразу. Блюдо и опыт приходят после работы; открытое окно ставит очередь на паузу.","Your kitchen reserves ingredients and energy. Food and XP arrive after work; open windows pause the queue.","La cocina reserva ingredientes y energía. Comida y experiencia llegan al terminar; las ventanas pausan la cola.","Die Küche reserviert Zutaten und Energie. Essen und Erfahrung erst nach Arbeit; offene Fenster pausieren.","La cuisine réserve ingrédients et énergie. Plat et expérience à la fin ; fenêtres ouvertes en pause.","私人厨房先扣除食材和精力，完成后获得食物与经验；打开窗口会暂停队列。"],
	"kitchen_fuel":["Кухня принимает дерево, брёвна и древесный уголь. Жар тратится только на горячие блюда, заготовки обходятся без него.","Kitchen fuel is wood, logs or charcoal. Only hot dishes use heat; preparations do not.","Usa madera, troncos o carbón vegetal. Solo los platos calientes gastan calor.","Holz, Stämme und Holzkohle heizen die Küche. Nur warme Gerichte verbrauchen Hitze.","Bois, bûches et charbon de bois alimentent la cuisine. Seuls les plats chauds utilisent la chaleur.","厨房使用木材、原木和木炭；只有热菜消耗炉温，食材加工不消耗。"],
	"kitchen_done":["Котелок варит, очаг жарит, печь выпекает. Улучшай у чертежа: прежние блюда сохраняются, очередь растёт до трёх партий.","The pot boils, the stove fries, the oven bakes. Upgrade at the blueprint; earlier dishes remain and queues grow to three.","El caldero hierve, el fogón fríe y el horno hornea. Mejora en el plano; conserva recetas y amplía a tres lotes.","Kessel kocht, Herd brät, Ofen backt. Ausbau am Bauplan behält Rezepte und erweitert auf drei Aufträge.","Marmite : bouillir, fourneau : frire, four : cuire. Améliore au plan, garde les recettes et jusqu’à trois lots.","锅灶煮食、炉灶煎炒、烤炉烘焙；在蓝图处升级，保留原食谱并扩展至三批。"],
}
