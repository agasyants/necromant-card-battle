class_name GameManager
extends Node

# Авторитетный менеджер матча с циклом из 3 ходов, пошаговым боем и механикой сброса

signal state_updated(state: Dictionary)
signal log_message_added(msg: String)
signal combat_fx_requested(slot_idx: int, clash_data: Dictionary)
signal draw_card_fx_requested(player_id: int, card_name: String)

const WIN_SCORE: int = 10
const SLOTS_COUNT: int = 5
const TURNS_PER_CYCLE: int = 3 # Ровно 3 хода до фазы боя

var next_instance_id: int = 1
var is_ai_mode: bool = false
var ai_controller: AIController = null

var game_state: Dictionary = {
	"round": 1,
	"turn_in_cycle": 1,
	"cycle_starter_id": 1,
	"active_player_id": 1,
	"phase": "WAITING_PLAYERS",
	"p1_id": 1,
	"p2_id": 0,
	"players": {},
	"battle_log": [],
	"winner_id": 0
}

func _ready() -> void:
	ai_controller = AIController.new()
	add_child(ai_controller)
	ai_controller.setup(self, 2)

# Запуск матча
func start_match(p1_id: int, p1_name: String, p2_id: int, p2_name: String, ai_mode: bool = false) -> void:
	if not NetworkManager.is_host and not ai_mode:
		return
	
	is_ai_mode = ai_mode
	next_instance_id = 1
	game_state.round = 1
	game_state.turn_in_cycle = 1
	game_state.cycle_starter_id = p1_id
	game_state.active_player_id = p1_id
	game_state.p1_id = p1_id
	game_state.p2_id = p2_id
	game_state.phase = "PLANNING"
	game_state.battle_log.clear()
	game_state.winner_id = 0
	
	game_state.players = {
		p1_id: _init_player_data(p1_id, p1_name, 1),
		p2_id: _init_player_data(p2_id, p2_name, 0)
	}
	
	# Стартовая рука: по 3 карты
	for i in range(3):
		_draw_card_silent(p1_id)
		_draw_card_silent(p2_id)
	
	_add_log("[color=#38d9a9]Матч начался! Победные очки начисляются ТОЛЬКО за прямые удары по некроманту.[/color]")
	_add_log("Цикл 1, Ход 1/3. Начинает: %s (Мана: 1)" % p1_name)
	
	_broadcast_state()

func _init_player_data(id: int, name: String, starting_mana: int = 1) -> Dictionary:
	var deck = CardDatabase.create_starter_deck()
	return {
		"id": id,
		"name": name,
		"mana": starting_mana,
		"max_mana": starting_mana,
		"souls": 0,
		"score": 0,
		"graveyard_count": 0,
		"turns_taken": 1 if starting_mana > 0 else 0,
		"has_discarded_this_turn": false,
		"deck": deck,
		"hand": [],
		"board": [null, null, null, null, null]
	}

func _draw_card_silent(player_id: int) -> void:
	var p = game_state.players[player_id]
	if p.deck.is_empty() or p.hand.size() >= 7:
		return
	var card_id = p.deck.pop_front()
	var template = CardDatabase.get_card(card_id)
	template["inst_id"] = next_instance_id
	next_instance_id += 1
	p.hand.append(template)

func _draw_card(player_id: int) -> void:
	var p = game_state.players[player_id]
	if p.deck.is_empty():
		_add_log("[color=#e03131]У игрока %s пуста колода![/color]" % p.name)
		return
	if p.hand.size() >= 7:
		_add_log("[color=#ffd43b]Рука игрока %s переполнена (макс 7 карт)![/color]" % p.name)
		return
	
	var card_id = p.deck.pop_front()
	var template = CardDatabase.get_card(card_id)
	template["inst_id"] = next_instance_id
	next_instance_id += 1
	p.hand.append(template)
	
	_add_log("[color=#74c0fc]%s берет карту «%s» (в колоде: %d)[/color]" % [p.name, template.name, p.deck.size()])
	rpc("play_draw_fx", player_id, template.name)

@rpc("authority", "call_local", "reliable")
func play_draw_fx(player_id: int, card_name: String) -> void:
	draw_card_fx_requested.emit(player_id, card_name)

# Начало хода игрока: мана растет на +1 (до 5) каждый свой ход и восполняется
func _start_player_turn(player_id: int) -> void:
	game_state.active_player_id = player_id
	var p = game_state.players[player_id]
	p.turns_taken += 1
	p.max_mana = mini(5, p.turns_taken)
	p.mana = p.max_mana
	p.has_discarded_this_turn = false
	_draw_card(player_id)

func _create_board_creature(card_id: String, owner_id: int) -> Dictionary:
	var template = CardDatabase.get_card(card_id)
	var inst = {
		"inst_id": next_instance_id,
		"card_id": card_id,
		"owner_id": owner_id,
		"name": template.name,
		"category": template.category,
		"base_atk": template.attack,
		"base_hp": template.health,
		"current_hp": template.health,
		"desc": template.desc,
		"color": template.color
	}
	next_instance_id += 1
	return inst

func get_effective_stats(player_id: int, slot_idx: int) -> Dictionary:
	if not game_state.players.has(player_id):
		return { "atk": 0, "hp": 0 }
	var p = game_state.players[player_id]
	if slot_idx < 0 or slot_idx >= p.board.size():
		return { "atk": 0, "hp": 0 }
	var c = p.board[slot_idx]
	if c == null:
		return { "atk": 0, "hp": 0 }
	
	var atk = c.base_atk
	var hp = c.current_hp
	
	# Костяной Голем: +1 к атаке за каждого погибшего союзника
	if c.card_id == "bone_golem":
		atk += p.graveyard_count
	
	# Король Костей: если есть на столе, все союзные скелеты получают +1 к силе
	var has_king = false
	for slot in p.board:
		if slot != null and slot.card_id == "bone_king":
			has_king = true
			break
	if has_king and c.category == "Скелет" and c.card_id != "bone_king":
		atk += 1
	
	# Стена Плоти: соседние союзники получают +1/+1
	for n_idx in [slot_idx - 1, slot_idx + 1]:
		if n_idx >= 0 and n_idx < SLOTS_COUNT:
			var neighbor = p.board[n_idx]
			if neighbor != null and neighbor.card_id == "wall_of_flesh":
				atk += 1
				hp += 1
	
	return { "atk": maxi(0, atk), "hp": hp }

# --- RPC ДЕЙСТВИЯ ИГРОКОВ ---

@rpc("any_peer", "call_local", "reliable")
func rpc_request_play_card(card_inst_id: int, slot_idx: int, payment_choice: String) -> void:
	if not NetworkManager.is_host and not is_ai_mode:
		return
	var sender_id = multiplayer.get_remote_sender_id()
	if sender_id == 0:
		sender_id = multiplayer.get_unique_id()
	if is_ai_mode and game_state.active_player_id == 2:
		sender_id = 2
	
	if game_state.phase != "PLANNING" or sender_id != game_state.active_player_id:
		return
	
	var p = game_state.players[sender_id]
	if slot_idx < 0 or slot_idx >= SLOTS_COUNT or p.board[slot_idx] != null:
		return
	
	var card_index = -1
	var card_data = {}
	for i in range(p.hand.size()):
		if p.hand[i].inst_id == card_inst_id:
			card_index = i
			card_data = p.hand[i]
			break
	if card_index == -1:
		return
	
	var mana_needed = 0
	var souls_needed = 0
	var pay_mode = card_data.pay_mode
	
	if pay_mode == "MANA":
		mana_needed = card_data.mana_cost
	elif pay_mode == "SOULS":
		souls_needed = card_data.soul_cost
	elif pay_mode == "AND":
		mana_needed = card_data.mana_cost
		souls_needed = card_data.soul_cost
	elif pay_mode == "OR":
		if payment_choice == "SOULS":
			souls_needed = card_data.soul_cost
		else:
			mana_needed = card_data.mana_cost
	
	if p.mana < mana_needed or p.souls < souls_needed:
		return
	
	p.mana -= mana_needed
	p.souls -= souls_needed
	p.hand.remove_at(card_index)
	
	var creature = _create_board_creature(card_data.id, sender_id)
	p.board[slot_idx] = creature
	_add_log("[color=#4dabf7]%s призывает %s в слот %d.[/color]" % [p.name, creature.name, slot_idx + 1])
	
	_trigger_on_play(sender_id, slot_idx, creature)
	_broadcast_state()

func _trigger_on_play(player_id: int, slot_idx: int, creature: Dictionary) -> void:
	var opp_id = _get_opponent_id(player_id)
	var opp = game_state.players[opp_id]
	var p = game_state.players[player_id]
	
	if creature.card_id == "whisper_of_darkness":
		if opp.score > 0:
			opp.score -= 1
			p.score += 1
			_add_log("[color=#b197fc]Шёпот Тьмы похищает 1 очко у %s и передает %s![/color]" % [opp.name, p.name])
		else:
			p.score += 1
			_add_log("[color=#b197fc]Шёпот Тьмы приносит +1 очко игроку %s![/color]" % p.name)
		_check_win_condition()
		
	elif creature.card_id == "shadow_assassin":
		var opp_c = opp.board[slot_idx]
		if opp_c != null:
			opp_c.current_hp -= 2
			_add_log("[color=#b197fc]Тень Склепа наносит 2 урона вражескому %s![/color]" % opp_c.name)
			if opp_c.current_hp <= 0:
				_kill_creature(opp_id, slot_idx, "от Тени Склепа")
				_check_win_condition()

# Механика замены/сброса карт из руки с мгновенным добором новых
@rpc("any_peer", "call_local", "reliable")
func rpc_request_discard_cards(card_inst_ids: Array) -> void:
	if not NetworkManager.is_host and not is_ai_mode:
		return
	var sender_id = multiplayer.get_remote_sender_id()
	if sender_id == 0:
		sender_id = multiplayer.get_unique_id()
	if is_ai_mode and game_state.active_player_id == 2:
		sender_id = 2
	
	if game_state.phase != "PLANNING" or sender_id != game_state.active_player_id:
		return
	
	var p = game_state.players[sender_id]
	if p.has_discarded_this_turn:
		_add_log("[color=#ffd43b]%s уже использовал замену карт в этот ход![/color]" % p.name)
		return
	
	if card_inst_ids.is_empty():
		return
	
	var discarded_names = []
	var to_remove = []
	var returned_card_ids = []
	for i in range(p.hand.size()):
		var card = p.hand[i]
		if card_inst_ids.has(card.inst_id):
			to_remove.append(i)
			discarded_names.append(card.name)
			returned_card_ids.append(card.card_id)
	
	if to_remove.is_empty():
		return
		
	# Удаляем выбранные карты из руки (с конца)
	to_remove.reverse()
	for idx in to_remove:
		p.hand.remove_at(idx)
	
	# Сброшенные карты возвращаются в колоду (на дно), НЕ идут в склеп и ни на что не влияют
	for cid in returned_card_ids:
		p.deck.append(cid)
	
	p.has_discarded_this_turn = true
	
	# На их место ТУТ ЖЕ приходят новые карты из колоды!
	var count_to_draw = to_remove.size()
	for i in range(count_to_draw):
		_draw_card_silent(sender_id)
	
	_add_log("[color=#74c0fc]%s заменяет %d карт: [%s]. Пришли новые карты![/color]" % [
		p.name,
		count_to_draw,
		", ".join(discarded_names)
	])
	
	rpc("play_draw_fx", sender_id, "Замена: +%d" % count_to_draw)
	_broadcast_state()

@rpc("any_peer", "call_local", "reliable")
func rpc_request_sacrifice(slot_idx: int) -> void:
	if not NetworkManager.is_host and not is_ai_mode:
		return
	var sender_id = multiplayer.get_remote_sender_id()
	if sender_id == 0:
		sender_id = multiplayer.get_unique_id()
	if is_ai_mode and game_state.active_player_id == 2:
		sender_id = 2
	
	if game_state.phase != "PLANNING" or sender_id != game_state.active_player_id:
		return
	
	var p = game_state.players[sender_id]
	if slot_idx < 0 or slot_idx >= SLOTS_COUNT or p.board[slot_idx] == null:
		return
	
	var c_name = p.board[slot_idx].name
	_add_log("[color=#ff6b6b]%s приносит в жертву %s![/color]" % [p.name, c_name])
	_kill_creature(sender_id, slot_idx, "через жертву")
	_broadcast_state()

func _kill_creature(player_id: int, slot_idx: int, cause: String = "") -> void:
	var p = game_state.players[player_id]
	var c = p.board[slot_idx]
	if c == null:
		return
	
	p.board[slot_idx] = null
	p.graveyard_count += 1
	p.souls += 1 # Смерть своего существа дает душу владельцу
	_add_log("Душа существа %s освобождена (+1 душа)." % c.name)
	
	if c.card_id == "bone_servant":
		p.souls += 1
		_add_log("[color=#ffd43b]Эффект Костяного Слуги: дополнительная душа (+1)![/color]")
	elif c.card_id == "heap_of_bones":
		p.board[slot_idx] = _create_board_creature("bone_servant", player_id)
		_add_log("[color=#adb5bd]Из обломков Кучки Костей собирается Костяной Слуга (1/1)![/color]")
	elif c.card_id == "crypt_ghoul":
		var opp_id = _get_opponent_id(player_id)
		var opp = game_state.players[opp_id]
		var opp_c = opp.board[slot_idx]
		if opp_c != null:
			opp_c.current_hp -= 2
			_add_log("[color=#51cf66]Взрыв яда Чумного Упыря! 2 урона по %s[/color]" % opp_c.name)
			if opp_c.current_hp <= 0:
				_kill_creature(opp_id, slot_idx, "от взрыва яда")
				_check_win_condition()

# Завершение хода игроком
@rpc("any_peer", "call_local", "reliable")
func rpc_request_end_turn() -> void:
	if not NetworkManager.is_host and not is_ai_mode:
		return
	var sender_id = multiplayer.get_remote_sender_id()
	if sender_id == 0:
		sender_id = multiplayer.get_unique_id()
	if is_ai_mode and game_state.active_player_id == 2:
		sender_id = 2
	
	if game_state.phase != "PLANNING" or sender_id != game_state.active_player_id:
		return
	
	if game_state.turn_in_cycle < TURNS_PER_CYCLE:
		# Передаем ход оппоненту в рамках текущего цикла (ходы 1 -> 2 -> 3)
		game_state.turn_in_cycle += 1
		var next_player_id = _get_opponent_id(sender_id)
		_start_player_turn(next_player_id)
		
		var next_p = game_state.players[next_player_id]
		_add_log("[color=#38d9a9]Ход %d/%d. Ходит: %s (Мана: %d/%d)[/color]" % [game_state.turn_in_cycle, TURNS_PER_CYCLE, next_p.name, next_p.mana, next_p.max_mana])
		_broadcast_state()
	else:
		# Наступил 3-й ход и он завершен -> ФАЗА БОЯ!
		_resolve_combat_phase()

# Пошаговое разрешение Фазы Боя
func _resolve_combat_phase() -> void:
	game_state.phase = "BATTLE"
	_broadcast_state()
	
	_add_log("[color=#ffd43b][b]══════════ НАЧАЛО ФАЗЫ БОЯ (ЦИКЛ %d) ══════════[/b][/color]" % game_state.round)
	
	var p1 = game_state.players[game_state.p1_id]
	var p2 = game_state.players[game_state.p2_id]
	
	for slot in range(SLOTS_COUNT):
		var c1 = p1.board[slot]
		var c2 = p2.board[slot]
		
		var clash_data = {
			"slot": slot,
			"has_c1": c1 != null,
			"has_c2": c2 != null,
			"c1_name": c1.name if c1 else "",
			"c2_name": c2.name if c2 else "",
			"c1_dmg": 0,
			"c2_dmg": 0,
			"c1_died": false,
			"c2_died": false,
			"direct_p1_dmg": 0,
			"direct_p2_dmg": 0
		}
		
		if c1 != null and c2 != null:
			var s1 = get_effective_stats(p1.id, slot)
			var s2 = get_effective_stats(p2.id, slot)
			
			clash_data.c1_dmg = s2.atk
			clash_data.c2_dmg = s1.atk
			
			c1.current_hp -= s2.atk
			c2.current_hp -= s1.atk
			
			_add_log("⚔️ Слот %d: [color=#74c0fc]%s[/color] (%d⚔) и [color=#ff8787]%s[/color] (%d⚔) сражаются!" % [slot + 1, c1.name, s1.atk, c2.name, s2.atk])
			
			var c1_died = c1.current_hp <= 0
			var c2_died = c2.current_hp <= 0
			
			clash_data.c1_died = c1_died
			clash_data.c2_died = c2_died
			
			rpc("play_slot_combat_fx", slot, clash_data)
			
			# ВНИМАНИЕ: Смерть карты НЕ дает очков врагу! Очки — ТОЛЬКО прямой урон по склепу!
			if c1_died and p1.board[slot] != null and p1.board[slot].inst_id == c1.inst_id:
				_kill_creature(p1.id, slot, "в бою")
				_add_log("[color=#ff6b6b]💀 %s повержен![/color]" % c1.name)
			if c2_died and p2.board[slot] != null and p2.board[slot].inst_id == c2.inst_id:
				_kill_creature(p2.id, slot, "в бою")
				_add_log("[color=#ff6b6b]💀 %s повержен![/color]" % c2.name)
				
		elif c1 != null and c2 == null:
			var s1 = get_effective_stats(p1.id, slot)
			if s1.atk > 0:
				p1.score += s1.atk
				clash_data.direct_p1_dmg = s1.atk
				_add_log("[color=#ffd43b]💥 %s прорывает ряд и бьет по склепу! (+%d очков игроку %s)[/color]" % [c1.name, s1.atk, p1.name])
				rpc("play_slot_combat_fx", slot, clash_data)
				
		elif c2 != null and c1 == null:
			var s2 = get_effective_stats(p2.id, slot)
			if s2.atk > 0:
				p2.score += s2.atk
				clash_data.direct_p2_dmg = s2.atk
				_add_log("[color=#ffd43b]💥 %s прорывает ряд и бьет по склепу! (+%d очков игроку %s)[/color]" % [c2.name, s2.atk, p2.name])
				rpc("play_slot_combat_fx", slot, clash_data)
		
		await get_tree().create_timer(0.85).timeout
		_broadcast_state()
	
	_add_log("[color=#ffd43b]══════════ ФАЗА БОЯ ЗАВЕРШЕНА ══════════[/color]")
	
	if _check_win_condition():
		_broadcast_state()
		return
	
	# Начинаем следующий 3-ходовый цикл
	game_state.round += 1
	game_state.phase = "PLANNING"
	game_state.turn_in_cycle = 1
	
	# Чередуем того, кто начинает новый цикл
	game_state.cycle_starter_id = _get_opponent_id(game_state.cycle_starter_id)
	_start_player_turn(game_state.cycle_starter_id)
	
	var starter_p = game_state.players[game_state.cycle_starter_id]
	_add_log("[b]ЦИКЛ %d (Ход 1/3)[/b]" % game_state.round)
	_add_log("Ход начинает: %s (Мана: %d/%d)" % [starter_p.name, starter_p.mana, starter_p.max_mana])
	
	_broadcast_state()

@rpc("authority", "call_local", "reliable")
func play_slot_combat_fx(slot_idx: int, clash_data: Dictionary) -> void:
	combat_fx_requested.emit(slot_idx, clash_data)

func _check_win_condition() -> bool:
	var p1 = game_state.players[game_state.p1_id]
	var p2 = game_state.players[game_state.p2_id]
	
	if p1.score >= WIN_SCORE or p2.score >= WIN_SCORE:
		game_state.phase = "GAME_OVER"
		if p1.score > p2.score:
			game_state.winner_id = p1.id
			_add_log("[color=#ffd43b][b]ПОБЕДА! Некромант %s сокрушил врага (%d очков)![/b][/color]" % [p1.name, p1.score])
		elif p2.score > p1.score:
			game_state.winner_id = p2.id
			_add_log("[color=#ffd43b][b]ПОБЕДА! Некромант %s сокрушил врага (%d очков)![/b][/color]" % [p2.name, p2.score])
		else:
			game_state.winner_id = -1
			_add_log("[color=#ced4da][b]НИЧЬЯ! Оба короля обратились в пепел![/b][/color]")
		return true
	return false

@rpc("any_peer", "call_local", "reliable")
func rpc_request_restart() -> void:
	if not NetworkManager.is_host and not is_ai_mode:
		return
	start_match(game_state.p1_id, game_state.players[game_state.p1_id].name, game_state.p2_id, game_state.players[game_state.p2_id].name, is_ai_mode)

func _get_opponent_id(my_id: int) -> int:
	if my_id == game_state.p1_id:
		return game_state.p2_id
	return game_state.p1_id

func _add_log(msg: String) -> void:
	game_state.battle_log.append(msg)
	if game_state.battle_log.size() > 50:
		game_state.battle_log.pop_front()
	log_message_added.emit(msg)

func _broadcast_state() -> void:
	sync_game_state(game_state)
	if not is_ai_mode and multiplayer.multiplayer_peer != null:
		for peer_id in multiplayer.get_peers():
			rpc_id(peer_id, "sync_game_state", game_state)

@rpc("authority", "call_local", "reliable")
func sync_game_state(new_state: Dictionary) -> void:
	game_state = new_state
	state_updated.emit(game_state)
