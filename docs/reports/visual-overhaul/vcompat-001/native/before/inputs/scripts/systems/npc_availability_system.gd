extends RefCounted

const WORDS := {
	"work":["работает","working","trabajando","arbeitet","travaille","工作中"],
	"morning":["утро","morning","mañana","morgens","matin","早晨"],
	"evening":["вечер","evening","tarde","abends","soir","傍晚"],
	"rest":["отдыхает","resting","descansando","ruht","se repose","休息中"],
	"shelter":["пережидает непогоду","sheltering","se refugia","sucht Schutz","à l’abri","避雨中"],
	"nearby":["пока здесь","still here","aún aquí","noch hier","encore ici","仍在此处"],
}
const PHASES := {"работает":"work","идёт на работу":"morning","гуляет по своему району":"evening","возвращается домой":"evening","сон":"rest","укрывается от непогоды":"shelter","shelter":"shelter","morning":"morning","evening":"evening","work":"work"}

## Возвращает фактическое место жителя, включая отложенный уход из видимой области.
static func location(game: Node, npc_id: String) -> String:
	return String(game.npc_movement.get(npc_id,{}).get("location",game.QuestSystem.NPCS.get(npc_id,{}).get("location","overworld")))

## Подписывает место и фазу распорядка без цифровых часов и без мутации расписания из UI.
static func hint(game: Node, npc_id: String) -> String:
	var actor: Dictionary = game.npc_movement.get(npc_id,{})
	var phase: String = "nearby" if actor.get("schedule_deferred",false) else PHASES.get(actor.get("schedule",""),"work")
	return game.LocaleSystem.location(location(game,npc_id)) + " · " + String(WORDS[phase][game.LocaleSystem.index()])

## Находит единственного известного заказчика миссии через общий реестр жителей.
static func giver(game: Node, mission_id: String) -> String:
	for npc_id in game.QuestSystem.NPCS:
		if mission_id in game.QuestSystem.NPCS[npc_id].missions: return npc_id
	return ""
