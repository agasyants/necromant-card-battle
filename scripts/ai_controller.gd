class_name AIController
extends Node

# ИИ-контроллер для соло-режима против бота («Лич-Архивариус»)

var game_manager: GameManager
var ai_id: int = 2
var is_thinking: bool = false

func setup(gm: GameManager, bot_id: int = 2) -> void:
	game_manager = gm
	ai_id = bot_id
	if not game_manager.state_updated.is_connected(_on_state_updated):
		game_manager.state_updated.connect(_on_state_updated)

func _on_state_updated(state: Dictionary) -> void:
	if not game_manager.is_ai_mode:
		return
	
	if state.get("phase") == "PLANNING" and state.get("active_player_id") == ai_id:
		if not is_thinking:
			_take_turn()

func _take_turn() -> void:
	is_thinking = true
	await get_tree().create_timer(0.7).timeout
	
	if not game_manager.is_ai_mode or game_manager.game_state.active_player_id != ai_id:
		is_thinking = false
		return
	
	var s = game_manager.game_state
	var ai_data = s.players.get(ai_id, {})
	var opp_id = game_manager._get_opponent_id(ai_id)
	var opp_data = s.players.get(opp_id, {})
	
	if ai_data.is_empty():
		is_thinking = false
		return
	
	# Сброс лишних тяжелых карт, если рука забита
	var hand = ai_data.get("hand", [])
	var cur_mana = ai_data.get("mana", 0)
	var cur_souls = ai_data.get("souls", 0)
	if not ai_data.get("has_discarded_this_turn", false) and hand.size() >= 5:
		var discard_candidates = []
		for card in hand:
			if not _can_afford(card, cur_mana, cur_souls) and card.mana_cost >= 4:
				discard_candidates.append(card.inst_id)
		if not discard_candidates.is_empty():
			game_manager.rpc_request_discard_cards(discard_candidates)
			await get_tree().create_timer(0.5).timeout
	
	# Цикл розыгрыша карт из руки
	var played_any = true
	var max_iterations = 6
	while played_any and max_iterations > 0:
		max_iterations -= 1
		played_any = false
		
		s = game_manager.game_state
		ai_data = s.players.get(ai_id, {})
		hand = ai_data.get("hand", [])
		cur_mana = ai_data.get("mana", 0)
		cur_souls = ai_data.get("souls", 0)
		var board = ai_data.get("board", [])
		var opp_board = opp_data.get("board", [])
		
		var empty_slots: Array[int] = []
		for i in range(5):
			if board[i] == null:
				empty_slots.append(i)
		
		if empty_slots.is_empty() or hand.is_empty():
			break
		
		var playable_cards: Array[Dictionary] = []
		for card in hand:
			if _can_afford(card, cur_mana, cur_souls):
				playable_cards.append(card)
		
		if playable_cards.is_empty():
			if _try_sacrifice_for_value(ai_data):
				await get_tree().create_timer(0.5).timeout
				played_any = true
				continue
			break
		
		playable_cards.sort_custom(func(a, b):
			var score_a = a.attack * 2 + a.health + a.mana_cost + a.soul_cost
			var score_b = b.attack * 2 + b.health + b.mana_cost + b.soul_cost
			return score_a > score_b
		)
		var chosen_card = playable_cards[0]
		var target_slot = _choose_best_slot(empty_slots, opp_board)
		
		var pay_mode = chosen_card.pay_mode
		var pay_choice = "MANA"
		if pay_mode == "SOULS":
			pay_choice = "SOULS"
		elif pay_mode == "AND":
			pay_choice = "AND"
		elif pay_mode == "OR":
			if cur_mana >= chosen_card.mana_cost:
				pay_choice = "MANA"
			else:
				pay_choice = "SOULS"
		
		game_manager.rpc_request_play_card(chosen_card.inst_id, target_slot, pay_choice)
		played_any = true
		await get_tree().create_timer(0.6).timeout
	
	await get_tree().create_timer(0.6).timeout
	is_thinking = false
	if game_manager.game_state.active_player_id == ai_id and game_manager.game_state.phase == "PLANNING":
		game_manager.rpc_request_end_turn()

func _can_afford(card: Dictionary, mana: int, souls: int) -> bool:
	var mode = card.get("pay_mode", "MANA")
	var m = card.get("mana_cost", 0)
	var s = card.get("soul_cost", 0)
	
	if mode == "MANA":
		return mana >= m
	elif mode == "SOULS":
		return souls >= s
	elif mode == "AND":
		return mana >= m and souls >= s
	elif mode == "OR":
		return mana >= m or souls >= s
	return false

func _choose_best_slot(empty_slots: Array[int], opp_board: Array) -> int:
	for slot_idx in empty_slots:
		if slot_idx < opp_board.size() and opp_board[slot_idx] != null:
			if opp_board[slot_idx].base_atk >= 2:
				return slot_idx
				
	for slot_idx in empty_slots:
		if slot_idx < opp_board.size() and opp_board[slot_idx] == null:
			return slot_idx
			
	return empty_slots[0]

func _try_sacrifice_for_value(ai_data: Dictionary) -> bool:
	var board = ai_data.get("board", [])
	for i in range(board.size()):
		var c = board[i]
		if c != null and c.card_id == "bone_servant" and ai_data.get("souls", 0) < 2:
			game_manager.rpc_request_sacrifice(i)
			return true
	return false
