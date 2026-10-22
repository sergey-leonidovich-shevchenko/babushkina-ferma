extends RefCounted

const BACKGROUND := Color("f5ecd4")
const PANEL := Color("eee1bf")
const INSET := Color("dfd0a7")
const EDGE := Color("b3a077")
const TEXT := Color("463c2b")
const MUTED := Color("584e38")
const ACCENT := Color("647451")
const ON_ACCENT := Color("fbf4df")
const ACCENT_TEXT := Color("3f512e")
const SELECTED := Color("d3c29a")
const DISABLED := Color("7d7057")
const DANGER := Color("89362f")
const SUCCESS := Color("3f512e")
const INFO := Color("325368")
const TRACK := Color("c7b995")

## Даёт цвет подписи редкости с достаточным контрастом на светлом фоне, сохраняя яркие метки предметов отдельно.
static func rarity_ink(rarity:String) -> Color:
	return {"common":MUTED,"uncommon":ACCENT_TEXT,"rare":INFO,"epic":Color("5e3678"),"legendary":Color("6f4618")}.get(rarity,TEXT)
