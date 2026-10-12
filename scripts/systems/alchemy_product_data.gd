extends RefCounted

const BASE_ITEMS := {
	"glass_vial":["Пустой флакон","Empty vial","Frasco vacío","Leeres Fläschchen","Fiole vide","空瓶"],
	"clean_water":["Чистая вода","Clean water","Agua limpia","Sauberes Wasser","Eau propre","清水"],
	"distilled_water":["Дистиллированная вода","Distilled water","Agua destilada","Destilliertes Wasser","Eau distillée","蒸馏水"],
	"herb_solvent":["Травяной растворитель","Herbal solvent","Disolvente herbal","Kräuterlösungsmittel","Solvant végétal","草本溶剂"],
	"herb_oil":["Растительное масло","Herbal oil","Aceite vegetal","Pflanzenöl","Huile végétale","植物油"],
	"mineral_base":["Минеральная основа","Mineral base","Base mineral","Mineralbasis","Base minérale","矿物基质"],
	"herb_pulp":["Травяной жмых","Herbal pulp","Pulpa vegetal","Kräutertrester","Marc végétal","草渣"],
	"vital_essence":["Эссенция жизни","Vital essence","Esencia vital","Lebensessenz","Essence vitale","生命精华"],
	"ember_essence":["Эссенция жара","Ember essence","Esencia de brasa","Glutessenz","Essence de braise","余烬精华"],
	"frost_essence":["Эссенция инея","Frost essence","Esencia de escarcha","Frostessenz","Essence de givre","霜冻精华"],
	"shadow_essence":["Эссенция тени","Shadow essence","Esencia de sombra","Schattenessenz","Essence d’ombre","暗影精华"],
	"ether_essence":["Эфирная эссенция","Ether essence","Esencia etérea","Ätheressenz","Essence éthérée","以太精华"],
}
const BASE_POTIONS := {
	"meadow_tonic":{"names":["Луговой тоник","Meadow tonic","Tónico del prado","Wiesentonikum","Tonique des prés","草地补剂"],"heal":25},
	"clarity_drops":{"names":["Капли ясности","Clarity drops","Gotas de claridad","Klarheitstropfen","Gouttes de clarté","清明滴剂"],"mana":15},
	"vigor_infusion":{"names":["Настой бодрости","Vigor infusion","Infusión de vigor","Kraftaufguss","Infusion de vigueur","活力浸剂"],"energy":4},
	"honey_balm":{"names":["Медовый бальзам","Honey balm","Bálsamo de miel","Honigbalsam","Baume au miel","蜜制香膏"],"heal":40},
	"hunter_elixir":{"names":["Эликсир охотника","Hunter elixir","Elixir del cazador","Jägerelixier","Élixir du chasseur","猎人灵药"],"timer":"strength_timer","duration":45.0},
	"stone_skin_draught":{"names":["Каменная кожа","Stone skin","Piel de piedra","Steinhaut","Peau de pierre","石肤药剂"],"timer":"defense_timer","duration":45.0},
	"wind_step_elixir":{"names":["Шаг ветра","Wind step","Paso del viento","Windschritt","Pas du vent","风步灵药"],"timer":"speed_timer","duration":40.0},
	"moon_veil_potion":{"names":["Лунная вуаль","Moon veil","Velo lunar","Mondschleier","Voile lunaire","月纱药剂"],"timer":"invisibility_timer","duration":25.0},
	"life_balsam":{"names":["Живой бальзам","Living balsam","Bálsamo viviente","Lebensbalsam","Baume vivant","生命香膏"],"timer":"regeneration_timer","duration":30.0},
	"greater_healing":{"names":["Крепкое лечебное зелье","Greater healing","Curación mayor","Starker Heiltrank","Soin supérieur","强效治疗药剂"],"heal":90},
	"greater_mana":{"names":["Крепкое зелье маны","Greater mana","Maná mayor","Starker Manatrank","Mana supérieur","强效法力药剂"],"mana":50},
	"balanced_elixir":{"names":["Эликсир равновесия","Balance elixir","Elixir de equilibrio","Gleichgewichtselixier","Élixir d’équilibre","平衡灵药"],"heal":35,"mana":15,"energy":4},
	"purifying_decoction":{"names":["Очищающий отвар","Purifying decoction","Decocción purificante","Reinigungssud","Décoction purifiante","净化煎剂"],"cleanse":true},
	"insect_repellent":{"names":["Бальзам от насекомых","Insect balm","Bálsamo repelente","Insektenschutzbalsam","Baume anti-insectes","驱虫香膏"],"effect":"repellent","duration":60.0,"cleanse":true},
	"miners_oil":{"names":["Масло рудокопа","Miner's oil","Aceite del minero","Bergmannsöl","Huile du mineur","矿工油"],"effect":"mining","duration":60.0},
	"solar_concentrate":{"names":["Солнечный концентрат","Solar concentrate","Concentrado solar","Sonnenkonzentrat","Concentré solaire","日光浓缩剂"],"heal":120,"mana":30},
}
const FORM_NAMES := {
	"juice":["Сок: %s","Juice: %s","Jugo: %s","Saft: %s","Jus : %s","汁液：%s"],
	"dried":["Сушёная трава: %s","Dried: %s","Seco: %s","Getrocknet: %s","Séché : %s","干草：%s"],
	"powder":["Порошок: %s","Powder: %s","Polvo: %s","Pulver: %s","Poudre : %s","粉末：%s"],
	"tincture":["Настойка: %s","Tincture: %s","Tintura: %s","Tinktur: %s","Teinture : %s","浸液：%s"],
}
const Herbs := preload("res://scripts/systems/alchemy_herb_data.gd")
const COLORS := {"glass_vial":"c5d0b6","clean_water":"a3ced9","distilled_water":"c0deea","vital_essence":"cc8d7d","ember_essence":"d79960","frost_essence":"acd1de","shadow_essence":"9d8ab8","ether_essence":"b7aedf","meadow_tonic":"d5c283","clarity_drops":"87baa1","vigor_infusion":"a8b87c","honey_balm":"d7ae6c","hunter_elixir":"be866e","stone_skin_draught":"a6b7c2","wind_step_elixir":"96c6ba","moon_veil_potion":"ae9eca","life_balsam":"9aba84","greater_healing":"c98380","greater_mana":"97aad8","balanced_elixir":"b3c6aa","purifying_decoction":"b4b899","insect_repellent":"a8bd91","miners_oil":"bcac87","solar_concentrate":"e1c479"}

static var ITEMS:Dictionary=BASE_ITEMS.merged(preload("res://scripts/systems/apiary_data.gd").RAW)
static var POTIONS:Dictionary=BASE_POTIONS.merged(preload("res://scripts/systems/apiary_data.gd").POTIONS)

## Возвращает цвет сырья либо самостоятельный цвет готового препарата и эссенции.
static func color_for(kind: String) -> Color:
	var herb:=Herbs.herb_for(kind)
	return Color(Herbs.HERBS[herb].tint) if not herb.is_empty() else Color(COLORS.get(kind,preload("res://scripts/systems/apiary_data.gd").COLORS.get(kind,"94bdba")))

## Собирает переводы свежих трав, каждого вида обработки, носителей и готовых препаратов.
static func names() -> Dictionary:
	var result:=ITEMS.duplicate(true)
	for kind in Herbs.HERBS:
		var herb:Dictionary=Herbs.HERBS[kind]; result[kind]=herb.names
		for form in Herbs.FORMS:
			var translated:=[]
			for index in 6: translated.append(FORM_NAMES[form][index]%herb.names[index])
			result[kind+"_"+form]=translated
	for kind in POTIONS: result[kind]=POTIONS[kind].names
	return result

## Возвращает метаданные всех материалов, выделяя употребляемые препараты без съедобного сырья.
static func inventory_items() -> Dictionary:
	var result:={}; var translated:=names()
	for kind in translated:
		result[kind]={"name":translated[kind][0],"short":String(translated[kind][0]).left(9),"color":color_for(kind)}
		if POTIONS.has(kind): result[kind].edible=true
	return result


## Определяет принадлежность каталогу без пересборки переводов каждого кадра.
static func handles(kind: String) -> bool:
	return not Herbs.herb_for(kind).is_empty() or ITEMS.has(kind) or POTIONS.has(kind)
