extends RefCounted

const WORDS := {
	"interval":["раз в %d дн.","every %d days","cada %d días","alle %d Tage","tous les %d j","每%d天"],
	"kitchen_route":["Общая кухня / личная ур. %d","Public kitchen / private lv. %d","Cocina pública / privada nv. %d","Gemeinschaftsküche / privat St. %d","Cuisine publique / privée niv. %d","公共厨房 / 私人%d级"],
	"raw":["Сырьё","Raw inputs","Materias primas","Rohstoffe","Matières premières","原料"],
	"steps":["Шаги","Steps","Pasos","Schritte","Étapes","步骤"],
	"sources":["Источники","Sources","Fuentes","Quellen","Sources","来源"],
	"stock":["Учесть рюкзак","Use backpack","Usar mochila","Rucksack nutzen","Utiliser le sac","使用背包"],
	"variant":["Вариант %d/%d","Route %d/%d","Variante %d/%d","Variante %d/%d","Variante %d/%d","路线 %d/%d"],
	"batch":["Партий: %d","Batches: %d","Lotes: %d","Chargen: %d","Lots : %d","批次：%d"],
	"level":["ур. %d","lv. %d","nv. %d","St. %d","niv. %d","%d级"],
	"empty":["Всё нужное уже в рюкзаке","Everything needed is in your backpack","Todo está en la mochila","Alles Nötige im Rucksack","Tout est dans le sac","所需物品已在背包中"],
	"unknown":["Источник не описан","Source not documented","Fuente sin describir","Quelle nicht beschrieben","Source non documentée","来源未记录"],
	"partial":["Часть цепочки требует внешнего источника","Part of the chain needs an external source","Parte necesita una fuente externa","Ein Teil braucht eine externe Quelle","Une partie nécessite une source externe","部分链条需要外部来源"],
	"limit":["Расчёт ограничен: уменьши число партий","Plan limit: reduce batches","Límite: reduce los lotes","Planlimit: weniger Chargen wählen","Limite : réduis les lots","规划达到上限，请减少批次"],
	"note":["Топливо и постройка отдельно • Y: панель плана","Fuel and construction separate • Y: plan controls","Combustible y obra aparte • Y: panel","Brennstoff und Bau separat • Y: Plansteuerung","Combustible et construction séparés • Y : panneau","燃料和建造另计 • Y：规划面板"],
	"shop":["Лавка","Shop","Tienda","Laden","Boutique","商店"],
	"crop":["Вырастить","Grow","Cultivar","Anbauen","Cultiver","种植"],
	"gather":["Собрать","Gather","Recolectar","Sammeln","Cueillir","采集"],
	"mine":["Добыть киркой","Mine","Extraer","Abbauen","Miner","采矿"],
	"tree":["Рубка деревьев","Chop trees","Talar árboles","Bäume fällen","Abattre des arbres","伐木"],
	"animal":["Уход за животными","Animal care","Cuidar animales","Tierpflege","Soins aux animaux","照料动物"],
	"fish":["Рыбалка","Fishing","Pesca","Angeln","Pêche","钓鱼"],
	"trap":["Крабовая ловушка","Crab trap","Trampa de cangrejos","Krabbenfalle","Casier à crabes","蟹笼"],
	"enemy":["Добыча врага","Enemy loot","Botín enemigo","Gegnerbeute","Butin ennemi","敌人掉落"],
	"wildlife":["Охота","Hunting","Caza","Jagd","Chasse","狩猎"],
	"recycle":["Изучить и разобрать","Study and recycle","Estudiar y reciclar","Erforschen und zerlegen","Étudier et démonter","研究并拆解"],
	"quest":["Награда за задание","Quest reward","Recompensa","Auftragsbelohnung","Récompense de quête","任务奖励"],
	"apiary":["Пчеловодство","Beekeeping","Apicultura","Imkerei","Apiculture","养蜂"],
}

## Переводит краткие подписи плана и источников, сохраняя имена предметов в общем каталоге.
static func word(game: Node, id: String, values: Array=[]) -> String:
	var index:int=maxi(0,game.LocaleSystem.LOCALES.find(game.LocaleSystem.current))
	var text:String=WORDS.get(id,WORDS.unknown)[index]
	return text%values if not values.is_empty() else text

## Описывает подтверждённый источник с его местом, исходным предметом или необходимым уровнем.
static func source_text(game: Node, record: Dictionary) -> String:
	var text:=word(game,String(record.type))
	if record.has("location"): text+=" • "+game.LocaleSystem.location(record.location)
	if record.has("item"): text+=" • "+game.inventory_item_name(record.item)
	if record.type=="recycle": text+=" ×%d → ≤×%d"%[record.batch,record.amount]
	if record.has("seed"): text+=" • "+game.inventory_item_name(record.seed)
	if record.has("quest"): text+=" • "+game.LocaleSystem.quest(record.quest,"title")
	if record.has("level"): text+=" • "+word(game,"level",[record.level])
	if record.has("interval"): text+=" • "+word(game,"interval",[record.interval])
	if record.get("condition","always") in ["day","night"]: text+=" • "+game.LocaleSystem.ui("alchemy_"+record.condition)
	if record.has("seasons"):
		var seasons:Array[String]=[]
		for season in record.seasons: seasons.append(game.LocaleSystem.ui("season_"+season).left(3))
		text+=" • "+", ".join(seasons)
	return text
