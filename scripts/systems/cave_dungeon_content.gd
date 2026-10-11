extends RefCounted

const Arena := preload("res://scripts/systems/cave_boss_arena_data.gd")

const RESOURCES := [
	{"location":"cave_fungal","position":Vector2(456,336),"kind":"crystal","hits":3}, {"location":"cave_fungal","position":Vector2(1632,288),"kind":"green_crystal","hits":3}, {"location":"cave_fungal","position":Vector2(1992,864),"kind":"stone","hits":2},
	{"location":"cave_moon","position":Vector2(480,288),"kind":"crystal","hits":3}, {"location":"cave_moon","position":Vector2(1944,528),"kind":"green_crystal","hits":3}, {"location":"cave_moon","position":Vector2(1656,888),"kind":"crystal","hits":3},
	{"location":"cave_lake","position":Vector2(528,384),"kind":"crystal","hits":3}, {"location":"cave_lake","position":Vector2(1512,864),"kind":"stone","hits":2}, {"location":"cave_lake","position":Vector2(1944,384),"kind":"green_crystal","hits":3},
	{"location":"cave_mine","position":Vector2(456,336),"kind":"metal","hits":3}, {"location":"cave_mine","position":Vector2(1992,384),"kind":"metal","hits":3}, {"location":"cave_mine","position":Vector2(1656,888),"kind":"red_crystal","hits":3},
	{"location":"cave_sanctum","position":Vector2(888,288),"kind":"red_crystal","hits":3}, {"location":"cave_sanctum","position":Vector2(2064,864),"kind":"metal","hits":3}, {"location":"cave_sanctum","position":Vector2(888,984),"kind":"crystal","hits":3},
]
const ENEMIES := [
	{"location":"cave_fungal","position":Vector2(648,600),"kind":"skeleton","level":2}, {"location":"cave_fungal","position":Vector2(1752,600),"kind":"cave_guardian","level":2},
	{"location":"cave_lake","position":Vector2(1728,504),"kind":"cave_guardian","level":3},
	{"location":"cave_mine","position":Vector2(648,480),"kind":"skeleton","level":3}, {"location":"cave_mine","position":Vector2(1872,720),"kind":"skeleton","level":4},
	{"location":"cave_sanctum","position":Vector2(432,648),"kind":"skeleton","level":4}, {"location":"cave_sanctum","position":Arena.BOSS,"kind":"cave_guardian","level":5,"cave_boss":true},
]
const LOOT := [
	{"location":"cave_fungal","count":2,"types":["chest","sack"],"positions":[Vector2(672,816),Vector2(1728,816)]},
	{"location":"cave_moon","count":1,"types":["chest"],"positions":[Vector2(816,360)]},
	{"location":"cave_lake","count":1,"types":["chest"],"positions":[Vector2(1968,864)]},
	{"location":"cave_mine","count":2,"types":["chest","trash"],"positions":[Vector2(720,864),Vector2(1776,432)]},
	{"location":"cave_sanctum","count":1,"types":["chest"],"positions":[Arena.CHEST]},
]
