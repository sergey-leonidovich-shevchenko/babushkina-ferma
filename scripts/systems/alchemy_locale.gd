extends RefCounted

const Products := preload("res://scripts/systems/alchemy_product_data.gd")
const Herbs := preload("res://scripts/systems/alchemy_herb_data.gd")
const UI := {
	"alchemy_title":["АЛХИМИЯ · РАНГ %d","ALCHEMY · RANK %d","ALQUIMIA · RANGO %d","ALCHEMIE · RANG %d","ALCHIMIE · RANG %d","炼金术 · 等级%d"],
	"alchemy_service":["Алхимический стол","Alchemy table","Mesa de alquimia","Alchemietisch","Table d’alchimie","炼金桌"],
	"alchemy_context":["Открыть алхимию","Open alchemy","Abrir alquimia","Alchemie öffnen","Ouvrir l’alchimie","打开炼金术"],
	"alchemy_progress":["Открытий: %d · Опыт: %d","Discoveries: %d · XP: %d","Descubrimientos: %d · EXP: %d","Entdeckungen: %d · EP: %d","Découvertes : %d · EXP : %d","发现：%d · 经验：%d"],
	"alchemy_mix_summary":["Компонентов: %d · Ранг %d","Ingredients: %d · Rank %d","Ingredientes: %d · Rango %d","Zutaten: %d · Rang %d","Ingrédients : %d · Rang %d","材料：%d · 等级%d"],
	"alchemy_batch_summary":["Выход: ×%d · Партий: %d","Output: ×%d · Batches: %d","Salida: ×%d · Lotes: %d","Ergebnis: ×%d · Menge: %d","Sortie : ×%d · Lots : %d","产出：×%d · 批数：%d"],
	"alchemy_help":["Tab / LB–RB: раздел · ↑↓: рецепт · Shift+Enter / X: партия","Tab / LB–RB: section · ↑↓: recipe · Shift+Enter / X: batch","Tab / LB–RB: sección · ↑↓: receta · Shift+Enter / X: lote","Tab / LB–RB: Bereich · ↑↓: Rezept · Shift+Enter / X: Menge","Tab / LB–RB : rubrique · ↑↓ : recette · Shift+Enter / X : lot","Tab / LB–RB：分类 · ↑↓：配方 · Shift+Enter / X：批量"],
	"alchemy_rank_need":["Нужен ранг %d (текущий %d)","Rank %d required (current %d)","Requiere rango %d (actual %d)","Rang %d nötig (aktuell %d)","Rang %d requis (actuel %d)","需要等级%d（当前%d）"],
	"alchemy_lab_need":["Нужна лаборатория усадьбы","Estate laboratory required","Requiere laboratorio","Gutshoflabor nötig","Laboratoire du domaine requis","需要庄园实验室"],
	"alchemy_station_need":["Подойди к алхимическому столу дома","Approach the home alchemy table","Acércate a la mesa de casa","Zum Alchemietisch im Haus gehen","Approche de la table à la maison","请靠近家中的炼金桌"],
	"alchemy_byproduct":["Побочно: %s ×%d","Byproduct: %s ×%d","Subproducto: %s ×%d","Nebenprodukt: %s ×%d","Sous-produit : %s ×%d","副产物：%s ×%d"],
	"alchemy_source":["Свойство: %s · %s","Property: %s · %s","Propiedad: %s · %s","Eigenschaft: %s · %s","Propriété : %s · %s","性质：%s · %s"],
	"alchemy_cleanse":["Снимает текущие укусы мух","Removes current fly bites","Elimina mordeduras de moscas","Entfernt aktive Fliegenbisse","Enlève les morsures de mouches","清除当前苍蝇叮咬"],
	"alchemy_repellent":["Защита от мух: %.0f с","Fly protection: %.0f s","Protección de moscas: %.0f s","Fliegenschutz: %.0f s","Protection contre les mouches : %.0f s","驱蝇保护：%.0f秒"],
	"alchemy_mining":["Добыча +1 за удар: %.0f с","Mining +1 per hit: %.0f s","Minería +1 por golpe: %.0f s","Abbau +1 pro Schlag: %.0f s","Extraction +1 par coup : %.0f s","每次采矿+1：%.0f秒"],
	"alchemy_night":["Созревает ночью","Ready at night","Lista de noche","Nachts bereit","Disponible la nuit","夜间可采集"],
	"alchemy_day":["Созревает днём","Ready during daytime","Lista de día","Tagsüber bereit","Disponible le jour","白天可采集"],
	"alchemy_all":["Все рецепты","All recipes","Todas las recetas","Alle Rezepte","Toutes les recettes","全部配方"],
	"alchemy_juice":["Пресс · соки","Press · juices","Prensa · jugos","Presse · Säfte","Presse · jus","压榨 · 汁液"],
	"alchemy_dried":["Сушка · травы","Drying · herbs","Secado · hierbas","Trocknen · Kräuter","Séchage · herbes","晾干 · 草药"],
	"alchemy_powder":["Ступка · порошки","Mortar · powders","Mortero · polvos","Mörser · Pulver","Mortier · poudres","研钵 · 粉末"],
	"alchemy_tincture":["Настойки","Tinctures","Tinturas","Tinkturen","Teintures","浸液"],
	"alchemy_essence":["Эссенции","Essences","Esencias","Essenzen","Essences","精华"],
	"alchemy_potions":["Зелья и бальзамы","Potions and balms","Pociones y bálsamos","Tränke und Balsame","Potions et baumes","药剂与香膏"],
	"alchemy_supplies":["Основы и тара","Bases and vials","Bases y frascos","Grundlagen und Flaschen","Bases et fioles","基质与容器"],
}
const PROPERTIES := {
	"vital":["восстановление","restoration","restauración","Heilung","restauration","恢复"],"clarity":["ясность","clarity","claridad","Klarheit","clarté","清明"],
	"vigor":["бодрость","vigor","vigor","Kraft","vigueur","活力"],"ward":["защита","ward","protección","Schutz","protection","防护"],
	"life":["рост","growth","crecimiento","Wachstum","croissance","生长"],"veil":["скрытность","stealth","sigilo","Tarnung","furtivité","隐匿"],
	"purity":["очищение","purity","pureza","Reinigung","pureté","净化"],"heat":["жар","heat","calor","Hitze","chaleur","热能"],
	"cold":["холод","cold","frío","Kälte","froid","寒冷"],"ether":["эфир","ether","éter","Äther","éther","以太"],
}
const TUTORIAL := {
	"alchemy_herbs":["Травы растут в разных биомах. E — сбор; после сбора куст восстановится. Сонный корень, паслёнка и орхидея доступны ночью.","Herbs grow across biomes. E harvests; patches regrow. Dreamroot, nightshade and ghost orchid are available at night.","Las hierbas crecen por los biomas. E recoge; vuelven a crecer. Raíz del sueño, hierba nocturna y orquídea se recogen de noche.","Kräuter wachsen in verschiedenen Biomen. E erntet; sie wachsen nach. Traumwurzel, Nachtschatten und Geisterorchidee sind nachts verfügbar.","Les herbes poussent dans les biomes. E récolte ; elles repoussent. Racine du rêve, solanée et orchidée se récoltent la nuit.","各种生态区都有草药。E采集后会再生。梦根、夜影草和幽灵兰在夜间可采集。"],
	"alchemy_processing":["Дома у стола E открывает алхимию. Две травы дают сок и жмых либо две сушёные травы; две сушёные травы дают порошок. Tab меняет раздел.","E at the home table opens alchemy. Two herbs yield juice and pulp or two dried herbs; two dried herbs yield powder. Tab changes section.","E en la mesa abre alquimia. Dos hierbas dan jugo y pulpa o dos hierbas secas; dos secas dan polvo. Tab cambia sección.","E am Haustisch öffnet Alchemie. Zwei Kräuter ergeben Saft und Trester oder zwei getrocknete Kräuter; zwei getrocknete ergeben Pulver. Tab wechselt den Bereich.","E à la table ouvre l’alchimie. Deux herbes donnent jus et marc ou deux herbes séchées ; deux séchées donnent une poudre. Tab change de rubrique.","在家中桌旁按E打开炼金术。两份草药可制成汁液与草渣或两份干草；两份干草可磨成粉末。Tab切换分类。"],
	"alchemy_brewing":["У каждого зелья свои ингредиенты и ранг. Настойки требуют растворитель и талант «Алхимия». Ранг растёт за разные открытия; жмых идёт в корм.","Potions have specific ingredients and ranks. Tinctures need solvent and the Alchemy talent. Different discoveries raise rank; pulp becomes feed.","Cada poción requiere ingredientes y rango. Las tinturas necesitan disolvente y talento Alquimia. Descubrimientos distintos suben el rango; la pulpa da pienso.","Tränke benötigen bestimmte Zutaten und Ränge. Tinkturen brauchen Lösungsmittel und Alchemietalent. Verschiedene Entdeckungen steigern den Rang; Trester wird Futter.","Chaque potion demande ses ingrédients et son rang. Les teintures exigent solvant et talent Alchimie. Les découvertes augmentent le rang ; le marc devient du fourrage.","药剂需要特定材料和等级。浸液需要溶剂和炼金术天赋。发现不同配方可升级；草渣可制成饲料。"],
	"alchemy_effects":["Очищающий отвар снимает укусы мух; бальзам также защищает от новых укусов. Масло рудокопа даёт +1 ресурс за удар 60 секунд. Пауза останавливает эффекты.","Purifying decoction removes fly bites; insect balm also blocks new bites. Miner's oil adds one resource per hit for 60 seconds. Pausing freezes effects.","La decocción elimina mordeduras; el bálsamo evita nuevas. Aceite del minero da +1 recurso por golpe durante 60 s. La pausa detiene efectos.","Reinigungssud entfernt Fliegenbisse; Balsam verhindert neue. Bergmannsöl gibt 60 Sekunden +1 Ressource pro Schlag. Pause stoppt die Effekte.","La décoction retire les morsures ; le baume en empêche de nouvelles. L’huile ajoute une ressource par coup pendant 60 secondes. La pause fige les effets.","净化煎剂清除苍蝇叮咬；驱虫香膏还防止新的叮咬。矿工油在60秒内每次采矿增加1资源。暂停时效果不消耗时间。"],
}

## Описывает реальные эффекты препарата из того же каталога, который применяет игровая логика.
static func effect_text(game: Node, kind: String) -> String:
	if not Products.POTIONS.has(kind):
		var herb:=Herbs.herb_for(kind)
		if herb.is_empty(): return ""
		var data:Dictionary=Herbs.HERBS[herb]
		return game.LocaleSystem.ui("alchemy_source",[PROPERTIES[data.property][game.LocaleSystem.index()],game.LocaleSystem.location(data.location)])
	var data:Dictionary=Products.POTIONS[kind]; var parts:Array[String]=[]
	for pair in [["heal","item_effect_heal"],["mana","item_effect_mana"],["energy","item_effect_energy"]]:
		if data.has(pair[0]): parts.append(game.LocaleSystem.ui(pair[1],[data[pair[0]]]))
	var duration:float=float(data.get("duration",0.0))*game.EstateSystem.potion_multiplier(game)
	match String(data.get("timer","")):
		"strength_timer": parts.append(game.LocaleSystem.ui("item_effect_strength",[1,duration]))
		"speed_timer": parts.append(game.LocaleSystem.ui("item_effect_speed",[30,duration]))
		"defense_timer": parts.append(game.LocaleSystem.ui("item_effect_defense",[4,duration]))
		"regeneration_timer": parts.append(game.LocaleSystem.ui("item_effect_regeneration",[5,duration]))
		"invisibility_timer": parts.append(game.LocaleSystem.ui("item_effect_invisibility",[duration]))
	if data.has("effect"): parts.append(game.LocaleSystem.ui("alchemy_"+String(data.effect),[duration]))
	if data.get("cleanse",false): parts.append(game.LocaleSystem.ui("alchemy_cleanse"))
	return " · ".join(parts)
