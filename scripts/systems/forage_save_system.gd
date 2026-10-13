extends RefCounted

const Herbs := preload("res://scripts/systems/alchemy_herb_data.gd")
const LEGACY_COUNT := 16

## Восстанавливает растения по стабильным ID, не подменяя старые посаженные деревья новыми травами.
static func restore(game: Node, records: Array) -> void:
	game.food_nodes=game.ForageSystem.default_nodes()
	var used:={}
	for index in records.size():
		var saved:Dictionary=records[index]; var kind:=String(saved.get("kind","")); var target:=-1
		var id:=String(saved.get("id",""))
		if id.begins_with("herb:") or id.begins_with("village_"):
			target=game.food_nodes.find_custom(func(node): return node.get("id","")==id)
		elif index<LEGACY_COUNT and (kind.is_empty() or kind==game.food_nodes[index].kind): target=index
		if target>=0 and not used.has(target):
			used[target]=true
			game.food_nodes[target].active=saved.active; game.food_nodes[target].ready_at=saved.ready_at
			if int(saved.get("stage",-1))>=0: game.food_nodes[target].stage=clampi(int(saved.stage),0,3)
			continue
		if game.OrchardSystem.handles(kind) and saved.get("planted_by_player",true):
			var point:Array=saved.get("position",[400.0,400.0])
			game.food_nodes.append({"kind":kind,"location":String(saved.get("location","overworld")),"position":Vector2(point[0],point[1]),"active":saved.active,"ready_at":saved.ready_at,"stage":clampi(int(saved.get("stage",0)),0,3),"planted_by_player":true})
