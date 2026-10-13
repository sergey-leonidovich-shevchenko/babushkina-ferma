extends RefCounted

const GRID := 24
const FLOOR := Rect2(168,288,816,240)
const STAIR_RECT := Rect2(792,432,72,72)
const CHEST_POSITION := Vector2(900,480)
const CABINET_POINT := Vector2(204,408)
const ALCHEMY_POINT := Vector2(708,504)
const POTTERY_POSITION := Vector2(492,456)
const POTTERY_POINT := Vector2(492,504)
const BED_POINT := Vector2(324,432)
const KITCHEN_POINT := Vector2(936,408)
const KINDS := ["rustic_table","wooden_chair","woven_rug","potted_fern","wooden_wardrobe"]
const PROPS := [
	{"kind":"bed","position":Vector2(324,384),"direction":0},
	{"kind":"woven_rug","position":Vector2(708,504),"direction":0,"decorative":true},
	{"kind":"wooden_wardrobe","position":Vector2(204,360),"direction":0,"decorative":true},
	{"kind":"potted_fern","position":Vector2(480,360),"direction":0,"decorative":true},
	{"kind":"shop","position":Vector2(768,360),"direction":0,"decorative":true},
	{"kind":"cauldron","position":Vector2(936,360),"direction":0},
	{"kind":"rustic_table","position":Vector2(708,456),"direction":0,"decorative":true},
	{"kind":"pottery","position":POTTERY_POSITION,"direction":0},
	{"kind":"wooden_chair","position":Vector2(612,456),"direction":3,"decorative":true},
	{"kind":"wooden_chair","position":Vector2(780,456),"direction":1,"decorative":true},
]
