extends RefCounted

## Добавляет самостоятельные узлы трав, ягод и плодовых деревьев после прежнего каталога, сохраняя его индексы.
static func forage() -> Array:
	var result:=[]
	for entry in [["field_mint",Vector2(384,600)],["chamomile",Vector2(504,600)],["nettle",Vector2(384,792)],["field_mint",Vector2(504,792)],["chamomile",Vector2(1440,408)],["nettle",Vector2(1560,408)]]:
		result.append({"id":"village_garden:"+str(result.size()),"kind":entry[0],"location":"village_garden","position":entry[1],"active":true,"ready_at":0.0,"stage":3})
	for entry in [["apple",Vector2(360,360)],["apple",Vector2(624,360)],["pear",Vector2(1392,360)],["cherry",Vector2(1656,360)],["plum",Vector2(360,984)],["apple",Vector2(888,984)],["pear",Vector2(1416,984)],["berries",Vector2(1680,984)],["berries",Vector2(1680,480)]]:
		result.append({"id":"village_orchard:"+str(result.size()),"kind":entry[0],"location":"village_orchard","position":entry[1],"active":true,"ready_at":0.0,"stage":3})
	for entry in [["mushroom",Vector2(1512,984)],["berries",Vector2(1656,912)]]:
		result.append({"id":"village_river:"+str(result.size()),"kind":entry[0],"location":"village_river","position":entry[1],"active":true,"ready_at":0.0,"stage":3})
	return result
