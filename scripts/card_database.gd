class_name CardDatabase
extends RefCounted

# База данных карт нежити для игры «Крипта Двух Королей»

const CARDS: Dictionary = {
	"bone_servant": {
		"id": "bone_servant",
		"name": "Костяной Слуга",
		"category": "Скелет",
		"mana_cost": 1,
		"soul_cost": 1,
		"pay_mode": "OR", # Можно оплатить 1 маной ИЛИ 1 душой
		"attack": 1,
		"health": 1,
		"desc": "При смерти: дарует +1 доп. душу (всего +2).",
		"color": Color("#868e96"),
	},
	"heap_of_bones": {
		"id": "heap_of_bones",
		"name": "Кучка Костей",
		"category": "Скелет",
		"mana_cost": 1,
		"soul_cost": 0,
		"pay_mode": "MANA",
		"attack": 0,
		"health": 3,
		"desc": "При смерти: призывает Костяного Слугу (1/1).",
		"color": Color("#adb5bd"),
	},
	"bone_golem": {
		"id": "bone_golem",
		"name": "Костяной Голем",
		"category": "Скелет",
		"mana_cost": 4,
		"soul_cost": 0,
		"pay_mode": "MANA",
		"attack": 3,
		"health": 5,
		"desc": "Пассив: +1 к силе за каждого павшего союзника.",
		"color": Color("#ced4da"),
	},
	"whisper_of_darkness": {
		"id": "whisper_of_darkness",
		"name": "Шёпот Тьмы",
		"category": "Призрак",
		"mana_cost": 0,
		"soul_cost": 1,
		"pay_mode": "SOULS",
		"attack": 1,
		"health": 2,
		"desc": "При выходе: крадет 1 победное очко у оппонента.",
		"color": Color("#4dabf7"),
	},
	"wall_of_flesh": {
		"id": "wall_of_flesh",
		"name": "Стена Плоти",
		"category": "Плоть",
		"mana_cost": 3,
		"soul_cost": 0,
		"pay_mode": "MANA",
		"attack": 1,
		"health": 6,
		"desc": "Пассив: соседние союзники получают +1/+1.",
		"color": Color("#f06595"),
	},
	"bone_king": {
		"id": "bone_king",
		"name": "Король Костей",
		"category": "Элита",
		"mana_cost": 3,
		"soul_cost": 3,
		"pay_mode": "AND", # Требует И 3 маны, И 3 души!
		"attack": 4,
		"health": 6,
		"desc": "Пассив: все ваши скелеты получают +1 к силе.",
		"color": Color("#ffd43b"),
	},
	"crypt_ghoul": {
		"id": "crypt_ghoul",
		"name": "Чумной Упырь",
		"category": "Зомби",
		"mana_cost": 2,
		"soul_cost": 2,
		"pay_mode": "OR",
		"attack": 2,
		"health": 3,
		"desc": "При смерти: наносит 2 урона существу напротив.",
		"color": Color("#51cf66"),
	},
	"shadow_assassin": {
		"id": "shadow_assassin",
		"name": "Тень Склепа",
		"category": "Призрак",
		"mana_cost": 0,
		"soul_cost": 2,
		"pay_mode": "SOULS",
		"attack": 3,
		"health": 1,
		"desc": "При выходе: наносит 2 урона существу напротив.",
		"color": Color("#b197fc"),
	}
}

static func get_card(id: String) -> Dictionary:
	if CARDS.has(id):
		return CARDS[id].duplicate(true)
	return {}

static func create_starter_deck() -> Array[String]:
	var deck: Array[String] = [
		"bone_servant", "bone_servant", "bone_servant",
		"heap_of_bones", "heap_of_bones",
		"whisper_of_darkness", "whisper_of_darkness",
		"crypt_ghoul", "crypt_ghoul",
		"shadow_assassin", "shadow_assassin",
		"wall_of_flesh", "wall_of_flesh",
		"bone_golem",
		"bone_king"
	]
	deck.shuffle()
	return deck
