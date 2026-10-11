extends RefCounted

const WORLD_SIZE := Vector2(2400, 1200)
const START := Vector2(408, 960)
const EXIT := Vector2(408, 1056)
const DEEP_GATE := Vector2(2016, 192)
const WALL_INSET := 12.0
const FLOOR := [
	Vector2(144,360), Vector2(240,288), Vector2(432,240), Vector2(768,192),
	Vector2(1200,192), Vector2(1392,264), Vector2(1632,264), Vector2(1728,168),
	Vector2(1848,168), Vector2(1896,168), Vector2(1896,-120), Vector2(2112,-120), Vector2(2112,168), Vector2(2160,192),
	Vector2(2256,264), Vector2(2280,480), Vector2(2232,720), Vector2(2184,984),
	Vector2(1944,1056), Vector2(1584,1080), Vector2(1344,1032), Vector2(1152,1056),
	Vector2(888,984), Vector2(672,1008), Vector2(576,960), Vector2(480,960),
	Vector2(480,1104), Vector2(336,1104), Vector2(336,960), Vector2(240,864),
	Vector2(120,768), Vector2(96,576),
]
# Первые три пещерные жилы сохраняют индексы прежних сохранений.
const RESOURCES := {2: Vector2(456,312), 3: Vector2(1056,936), 4: Vector2(2184,624)}
const EXTRA_RESOURCES := [
	{"position": Vector2(1176,264), "location": "cave", "kind": "red_crystal", "hits": 3},
	{"position": Vector2(2160,360), "location": "cave", "kind": "metal", "hits": 3},
	{"position": Vector2(2136,840), "location": "cave", "kind": "crystal", "hits": 3},
	{"position": Vector2(168,624), "location": "cave", "kind": "green_crystal", "hits": 3},
]
const DECORATIONS := [
	{"kind": "mushrooms", "position": Vector2(264,384)}, {"kind": "rubble", "position": Vector2(576,312)},
	{"kind": "stalagmites", "position": Vector2(744,240)}, {"kind": "mushrooms", "position": Vector2(1368,336)},
	{"kind": "rubble", "position": Vector2(1656,336)}, {"kind": "stalagmites", "position": Vector2(2184,504)},
	{"kind": "mushrooms", "position": Vector2(2184,792)}, {"kind": "crystal_fragments", "position": Vector2(2088,936)},
	{"kind": "rubble", "position": Vector2(1728,1008)}, {"kind": "stalagmites", "position": Vector2(1464,984)},
	{"kind": "mushrooms", "position": Vector2(888,912)}, {"kind": "rubble", "position": Vector2(624,936)},
	{"kind": "stalagmites", "position": Vector2(216,768)}, {"kind": "mushrooms", "position": Vector2(168,504)},
	{"kind": "rubble", "position": Vector2(1776,240)}, {"kind": "mushrooms", "position": Vector2(2088,240)},
]
