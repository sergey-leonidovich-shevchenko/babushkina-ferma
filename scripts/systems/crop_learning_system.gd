extends RefCounted

const Crops := preload("res://scripts/systems/crop_catalog_system.gd")
const WORDS := {
	"timing":["%d с • 2 полива\n%s","%ds • water twice\n%s","%ds • 2 riegos\n%s","%ds • zweimal gießen\n%s","%ds • 2 arrosages\n%s","%d秒 • 浇水两次\n%s"],
	"pause":["Завтра рост остановится до подходящего сезона","Growth pauses tomorrow until a suitable season","Mañana el crecimiento espera su temporada","Ab morgen ruht das Wachstum bis zur Saison","Dès demain, croissance en repos jusqu’à la saison","明日起暂停生长，等待适宜季节"],
	"wait":["Подходящий сезон через %d дн.; семена сохранены","Suitable season in %d days; seeds kept","Temporada en %d días; semillas conservadas","Saison in %d Tagen; Saat bleibt erhalten","Saison dans %d jours ; graines conservées","%d天后进入适宜季节；保留种子"],
}

## Подставляет короткую подсказку на выбранном языке без изменения мирового состояния.
static func word(game: Node, id: String, values: Array=[]) -> String:
	var index:int=maxi(0,game.LocaleSystem.LOCALES.find(game.LocaleSystem.current))
	var text:String=WORDS[id][index]
	return text%values if not values.is_empty() else text

## Объясняет базовую длительность и реальные разрешённые сезоны в существующей карточке семян.
static func seed_info(game: Node, seed: String) -> String:
	var crop:=Crops.crop_for_seed(seed)
	if crop.is_empty(): return ""
	var seasons:Array[String]=[]
	for season in Crops.data(crop).seasons: seasons.append(game.LocaleSystem.ui("season_"+season))
	return word(game,"timing",[int(Crops.growth_duration(crop)),", ".join(seasons)])

## Предупреждает о завтрашнем покое без уничтожения посева и без модального окна.
static func last_day_warning(game: Node, crop: String) -> String:
	return word(game,"pause") if not Crops.grows_in_season(crop,game.WorldEventSystem.season(game.day+1)) else ""
