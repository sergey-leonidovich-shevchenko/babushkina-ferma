extends RefCounted

const TEXT := {
	"all":["D • Всё из рюкзака","D • Store all from bag","D • Guardar mochila","D • Alles aus Rucksack","D • Tout déposer du sac","D • 存入背包全部物品"],
	"matching":["M • Совпадающее","M • Store matching","M • Guardar coincidentes","M • Passende einlagern","M • Déposer similaires","M • 存入已有物品"],
	"bag":["S • Рюкзак: %s","S • Bag: %s","S • Mochila: %s","S • Rucksack: %s","S • Sac : %s","S • 背包：%s"],
	"container":["T • Хранилище: %s","T • Storage: %s","T • Almacén: %s","T • Lager: %s","T • Stockage : %s","T • 储存：%s"],
	"sort":["Сортировать","Sort","Ordenar","Sortieren","Trier","排序"],
	"name":["Имя","Name","Nombre","Name","Nom","名称"],
	"category":["Тип","Type","Tipo","Typ","Type","类型"],
	"count":["Количество","Quantity","Cantidad","Menge","Quantité","数量"],
	"summary":["Перенесено: %d видов, %d предметов","Stored: %d types, %d items","Guardado: %d tipos, %d objetos","Eingelagert: %d Arten, %d Gegenstände","Déposé : %d types, %d objets","已存入：%d种，共%d个物品"],
	"none":["Нет подходящих предметов для переноса","No matching items to store","No hay objetos para guardar","Keine passenden Gegenstände zum Einlagern","Aucun objet à déposer","没有可存入的物品"],
	"help":["D/Start: всё из рюкзака • M/View: совпадающее • S/T: сортировка • R3: обе стороны","D/Start: store all • M/View: matching • S/T: sort • R3: both sides","D/Start: guardar todo • M/View: coincidentes • S/T: ordenar • R3: ambos lados","D/Start: alles lagern • M/View: passende • S/T: sortieren • R3: beide Seiten","D/Start : tout déposer • M/View : similaires • S/T : trier • R3 : les deux côtés","D/Start：全部存入 • M/View：已有物品 • S/T：排序 • R3：两侧排序"],
}

## Возвращает подписи общего переноса и сортировки на шести языках игры.
static func text(game: Node, key: String, args: Array=[]) -> String:
	var label:String=TEXT.get(key,[key,key,key,key,key,key])[game.LocaleSystem.index()]
	return label%args if not args.is_empty() else label

## Показывает сторону и текущий порядок сортировки прямо на её кнопке.
static func sort_label(game: Node, side: String) -> String:
	var order:=preload("res://scripts/systems/storage_sort_system.gd").mode(game,side)
	return text(game,"bag" if side=="bag" else "container",[text(game,order if not order.is_empty() else "sort")])
