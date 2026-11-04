class_name GameTable
extends Control

signal leave_to_lobby_requested

@onready var opp_name_label: Label = $VBox/TopBar/OpponentInfo/NameLabel
@onready var opp_mana_label: Label = $VBox/TopBar/OpponentInfo/ManaLabel
@onready var opp_souls_label: Label = $VBox/TopBar/OpponentInfo/SoulsLabel
@onready var opp_score_label: Label = $VBox/TopBar/OpponentInfo/ScoreLabel
@onready var opp_hand_label: Label = $VBox/TopBar/OpponentInfo/HandCountLabel

@onready var opp_graveyard_count: Label = $VBox/OpponentBoardArea/OppGraveyard/VBox/CountLabel
@onready var opp_deck_count: Label = $VBox/OpponentBoardArea/OppDeck/VBox/CountLabel
@onready var opp_slots_container: HBoxContainer = $VBox/OpponentBoardArea/OppSlotsContainer

@onready var phase_label: Label = $VBox/MidBar/CenterBox/PhaseLabel
@onready var cycle_progress_label: Label = $VBox/MidBar/CenterBox/CycleProgressLabel
@onready var turn_banner: Label = $VBox/MidBar/CenterBox/TurnBanner

@onready var buttons_row: HBoxContainer = $VBox/MidBar/CenterBox/ButtonsRow
@onready var end_turn_btn: Button = $VBox/MidBar/CenterBox/ButtonsRow/EndTurnButton
@onready var discard_mode_btn: Button = $VBox/MidBar/CenterBox/ButtonsRow/DiscardModeButton

@onready var discard_bar: HBoxContainer = $VBox/MidBar/CenterBox/DiscardBar
@onready var discard_info_label: Label = $VBox/MidBar/CenterBox/DiscardBar/DiscardInfoLabel
@onready var confirm_discard_btn: Button = $VBox/MidBar/CenterBox/DiscardBar/ConfirmDiscardBtn
@onready var cancel_discard_btn: Button = $VBox/MidBar/CenterBox/DiscardBar/CancelDiscardBtn

@onready var battle_log_text: RichTextLabel = $VBox/MidBar/LogBox/BattleLog

@onready var player_graveyard_count: Label = $VBox/PlayerBoardArea/PlayerGraveyard/VBox/CountLabel
@onready var player_deck_count: Label = $VBox/PlayerBoardArea/PlayerDeck/VBox/CountLabel
@onready var player_slots_container: HBoxContainer = $VBox/PlayerBoardArea/PlayerSlotsContainer

@onready var my_name_label: Label = $VBox/BottomBar/PlayerInfo/NameLabel
@onready var my_mana_label: Label = $VBox/BottomBar/PlayerInfo/ManaLabel
@onready var my_souls_label: Label = $VBox/BottomBar/PlayerInfo/SoulsLabel
@onready var my_score_label: Label = $VBox/BottomBar/PlayerInfo/ScoreLabel

@onready var hand_container: HBoxContainer = $VBox/HandArea/Scroll/HandContainer
@onready var target_hint_label: Label = $VBox/HandArea/TargetHintLabel

@onready var pay_dialog: PanelContainer = $PaymentDialog
@onready var pay_dialog_label: Label = $PaymentDialog/VBox/Label
@onready var pay_mana_btn: Button = $PaymentDialog/VBox/Buttons/PayManaBtn
@onready var pay_souls_btn: Button = $PaymentDialog/VBox/Buttons/PaySoulsBtn
@onready var pay_cancel_btn: Button = $PaymentDialog/VBox/Buttons/PayCancelBtn

@onready var game_over_panel: PanelContainer = $GameOverDialog
@onready var game_over_title: Label = $GameOverDialog/VBox/TitleLabel
@onready var game_over_details: Label = $GameOverDialog/VBox/DetailsLabel
@onready var restart_btn: Button = $GameOverDialog/VBox/Buttons/RestartBtn
@onready var exit_to_lobby_btn: Button = $GameOverDialog/VBox/Buttons/ExitBtn

const SLOT_VIEW_SCENE = preload("res://scenes/slot_view.tscn")
const CARD_VIEW_SCENE = preload("res://scenes/card_view.tscn")
const FLOATING_TEXT_SCENE = preload("res://scenes/floating_text.tscn")

var local_player_id: int = 1
var selected_card_for_play: Dictionary = {}
var selected_payment_mode: String = ""
var is_targeting_slot: bool = false

var is_in_discard_mode: bool = false
var selected_discard_ids: Array = []

var opp_slot_views: Array[SlotView] = []
var player_slot_views: Array[SlotView] = []

func _ready() -> void:
	local_player_id = multiplayer.get_unique_id()
	if local_player_id == 0 or (local_player_id == 1 and not NetworkManager.is_host):
		local_player_id = 1
	
	end_turn_btn.pressed.connect(_on_end_turn_pressed)
	discard_mode_btn.pressed.connect(_on_discard_mode_pressed)
	confirm_discard_btn.pressed.connect(_on_confirm_discard_pressed)
	cancel_discard_btn.pressed.connect(_exit_discard_mode)
	
	pay_mana_btn.pressed.connect(func(): _confirm_payment("MANA"))
	pay_souls_btn.pressed.connect(func(): _confirm_payment("SOULS"))
	pay_cancel_btn.pressed.connect(_cancel_selection)
	
	restart_btn.pressed.connect(_on_restart_pressed)
	exit_to_lobby_btn.pressed.connect(_on_exit_to_lobby_pressed)
	
	pay_dialog.visible = false
	game_over_panel.visible = false
	target_hint_label.visible = false
	discard_bar.visible = false
	
	_create_slots()
	
	var gm = get_node_or_null("/root/Main/GameManager") as GameManager
	if gm:
		gm.state_updated.connect(_on_game_state_updated)
		gm.log_message_added.connect(_on_log_message_added)
		gm.combat_fx_requested.connect(_on_combat_fx_requested)
		gm.draw_card_fx_requested.connect(_on_draw_card_fx_requested)
		_on_game_state_updated(gm.game_state)

func _create_slots() -> void:
	for c in opp_slots_container.get_children():
		c.queue_free()
	for c in player_slots_container.get_children():
		c.queue_free()
	opp_slot_views.clear()
	player_slot_views.clear()
	
	for i in range(5):
		var sv = SLOT_VIEW_SCENE.instantiate() as SlotView
		opp_slots_container.add_child(sv)
		sv.setup(i, false)
		opp_slot_views.append(sv)
		
	for i in range(5):
		var sv = SLOT_VIEW_SCENE.instantiate() as SlotView
		player_slots_container.add_child(sv)
		sv.setup(i, true)
		sv.slot_selected.connect(_on_slot_selected)
		sv.sacrifice_clicked.connect(_on_sacrifice_clicked)
		player_slot_views.append(sv)

func _on_game_state_updated(state: Dictionary) -> void:
	if not state.has("players"):
		return
	if not state.players.has(local_player_id):
		local_player_id = multiplayer.get_unique_id()
	if not state.players.has(local_player_id):
		local_player_id = 1
	if not state.players.has(local_player_id):
		return
	
	var my_data = state.players[local_player_id]
	var opp_id = _get_opponent_id(state, local_player_id)
	var opp_data = state.players.get(opp_id, {})
	
	var is_my_turn = (state.phase == "PLANNING" and state.active_player_id == local_player_id)
	var turn_in_cycle = state.get("turn_in_cycle", 1)
	var round_num = state.get("round", 1)
	
	# Если ход сменился, а мы были в режиме сброса — выходим
	if not is_my_turn and is_in_discard_mode:
		_exit_discard_mode()
	
	# 1. Верхняя панель (Оппонент)
	if not opp_data.is_empty():
		opp_name_label.text = "💀 " + opp_data.get("name", "Оппонент")
		opp_mana_label.text = "Мана: %d/%d 🔮" % [opp_data.get("mana", 0), opp_data.get("max_mana", 1)]
		opp_souls_label.text = "Души: %d 💀" % opp_data.get("souls", 0)
		opp_score_label.text = "Очки: %d / 10 ⭐" % opp_data.get("score", 0)
		opp_hand_label.text = "В руке: %d 🎴" % opp_data.get("hand", []).size()
		opp_deck_count.text = str(opp_data.get("deck", []).size())
		opp_graveyard_count.text = "%d 💀" % opp_data.get("graveyard_count", 0)
	
	# 2. Нижняя панель (Игрок)
	my_name_label.text = "🧙 " + my_data.get("name", "Вы")
	my_mana_label.text = "Мана: %d/%d 🔮" % [my_data.get("mana", 0), my_data.get("max_mana", 1)]
	my_souls_label.text = "Души: %d 💀" % my_data.get("souls", 0)
	my_score_label.text = "Очки: %d / 10 ⭐" % my_data.get("score", 0)
	player_deck_count.text = str(my_data.get("deck", []).size())
	player_graveyard_count.text = "%d 💀" % my_data.get("graveyard_count", 0)
	
	# 3. Индикация 3 ходов до боя
	phase_label.text = "ЦИКЛ БОЯ %d" % round_num
	var d1 = "●" if turn_in_cycle >= 1 else "○"
	var d2 = "●" if turn_in_cycle >= 2 else "○"
	var d3 = "●" if turn_in_cycle >= 3 else "○"
	cycle_progress_label.text = "[%s Ход 1] [%s Ход 2] [%s Ход 3]  ➔  ⚔️ БОЙ" % [d1, d2, d3]
	
	# Кнопка замены карт
	var has_discarded = my_data.get("has_discarded_this_turn", false)
	if not is_in_discard_mode:
		discard_mode_btn.disabled = not is_my_turn or has_discarded or my_data.get("hand", []).is_empty()
		if has_discarded:
			discard_mode_btn.text = "Заменено ✓"
			discard_mode_btn.modulate = Color("#868e96")
		else:
			discard_mode_btn.text = "Замена карт 🔄"
			discard_mode_btn.modulate = Color("#ced4da")
	
	if state.phase == "PLANNING":
		if is_my_turn:
			turn_banner.text = "★ ВАШ ХОД (Ход %d из 3) ★" % turn_in_cycle
			turn_banner.modulate = Color("#38d9a9")
			end_turn_btn.disabled = false
			end_turn_btn.text = "Завершить ход ➔"
		else:
			var opp_name = opp_data.get("name", "Оппонент")
			turn_banner.text = "Ход оппонента (%s) • %d из 3" % [opp_name, turn_in_cycle]
			turn_banner.modulate = Color("#adb5bd")
			end_turn_btn.disabled = true
			end_turn_btn.text = "Ожидание хода..."
	elif state.phase == "BATTLE":
		turn_banner.text = "⚔️ ФАЗА БОЯ! РАЗРЕШЕНИЕ СХВАТКИ ⚔️"
		turn_banner.modulate = Color("#ffd43b")
		end_turn_btn.disabled = true
		end_turn_btn.text = "Идет бой..."
	elif state.phase == "GAME_OVER":
		turn_banner.text = "МАТЧ ОКОНЧЕН"
		turn_banner.modulate = Color("#f03e3e")
		end_turn_btn.disabled = true
		_show_game_over(state)
	
	# 4. Обновление существ
	var gm = get_node_or_null("/root/Main/GameManager") as GameManager
	if not opp_data.is_empty():
		var opp_board = opp_data.get("board", [])
		for i in range(5):
			var creature = opp_board[i] if i < opp_board.size() else null
			var eff_stats = gm.get_effective_stats(opp_id, i) if gm else {}
			opp_slot_views[i].update_creature(creature, eff_stats, false, false)
			
	var my_board = my_data.get("board", [])
	for i in range(5):
		var creature = my_board[i] if i < my_board.size() else null
		var eff_stats = gm.get_effective_stats(local_player_id, i) if gm else {}
		player_slot_views[i].update_creature(creature, eff_stats, is_my_turn and not is_in_discard_mode, is_targeting_slot)
		
	# 5. Обновление руки
	_update_hand(my_data.get("hand", []), my_data.get("mana", 0), my_data.get("souls", 0), is_my_turn)
	
	# 6. Обновление лога
	_render_log(state.get("battle_log", []))

# Пошаговая визуализация ударов и урона
func _on_combat_fx_requested(slot_idx: int, clash_data: Dictionary) -> void:
	if slot_idx < 0 or slot_idx >= 5:
		return
	
	var p_slot = player_slot_views[slot_idx]
	var o_slot = opp_slot_views[slot_idx]
	
	p_slot.set_combat_focus(true)
	o_slot.set_combat_focus(true)
	
	var is_p1 = (local_player_id == 1)
	
	if clash_data.has_c1 and clash_data.has_c2:
		p_slot.play_attack_anim(true)
		o_slot.play_attack_anim(false)
		p_slot.play_hit_anim()
		o_slot.play_hit_anim()
		
		var my_dmg = clash_data.c1_dmg if is_p1 else clash_data.c2_dmg
		var opp_dmg = clash_data.c2_dmg if is_p1 else clash_data.c1_dmg
		
		_spawn_floating_text("-%d 🩸" % opp_dmg, Color("#ff6b6b"), o_slot.global_position + Vector2(65, 30))
		_spawn_floating_text("-%d 🩸" % my_dmg, Color("#ff6b6b"), p_slot.global_position + Vector2(65, 30))
		
		var my_died = clash_data.c1_died if is_p1 else clash_data.c2_died
		var opp_died = clash_data.c2_died if is_p1 else clash_data.c1_died
		
		# ВНИМАНИЕ: Смерть карты дает ТОЛЬКО душу, но НЕ дает победных очков!
		if my_died:
			_spawn_floating_text("💀 ПАЛ! (+1 Душа)", Color("#38d9a9"), p_slot.global_position + Vector2(65, 75))
		if opp_died:
			_spawn_floating_text("💀 ПАЛ! (+1 Душа)", Color("#38d9a9"), o_slot.global_position + Vector2(65, 75))
			
	elif (is_p1 and clash_data.direct_p1_dmg > 0) or (not is_p1 and clash_data.direct_p2_dmg > 0):
		var dmg = clash_data.direct_p1_dmg if is_p1 else clash_data.direct_p2_dmg
		p_slot.play_attack_anim(true)
		_spawn_floating_text("+%d ⭐ Прямой удар!" % dmg, Color("#ffd43b"), opp_score_label.global_position + Vector2(50, -5))
		
	elif (is_p1 and clash_data.direct_p2_dmg > 0) or (not is_p1 and clash_data.direct_p1_dmg > 0):
		var dmg = clash_data.direct_p2_dmg if is_p1 else clash_data.direct_p1_dmg
		o_slot.play_attack_anim(false)
		_spawn_floating_text("+%d ⭐ Урон по вам!" % dmg, Color("#ff6b6b"), my_score_label.global_position + Vector2(50, -5))
	
	await get_tree().create_timer(0.7).timeout
	p_slot.set_combat_focus(false)
	o_slot.set_combat_focus(false)

func _on_draw_card_fx_requested(player_id: int, card_name: String) -> void:
	if player_id == local_player_id:
		var deck_pos = $VBox/PlayerBoardArea/PlayerDeck.global_position + Vector2(42, 20)
		_spawn_floating_text("+1 🎴 %s" % card_name, Color("#4dabf7"), deck_pos)
	else:
		var deck_pos = $VBox/OpponentBoardArea/OppDeck.global_position + Vector2(42, 20)
		_spawn_floating_text("+1 🎴 Взята карта", Color("#adb5bd"), deck_pos)

func _spawn_floating_text(txt: String, color: Color, pos: Vector2) -> void:
	var ft = FLOATING_TEXT_SCENE.instantiate() as FloatingText
	add_child(ft)
	ft.setup(txt, color, pos)

func _update_hand(hand_cards: Array, cur_mana: int, cur_souls: int, is_my_turn: bool) -> void:
	for c in hand_container.get_children():
		c.queue_free()
		
	for card in hand_cards:
		var can_play = is_my_turn and not is_in_discard_mode and _can_afford(card, cur_mana, cur_souls)
		var is_selected_discard = selected_discard_ids.has(card.inst_id)
		
		var cv = CARD_VIEW_SCENE.instantiate() as CardView
		hand_container.add_child(cv)
		cv.setup(card, can_play, is_in_discard_mode, is_selected_discard)
		cv.card_clicked.connect(_on_card_clicked)
		cv.discard_toggled.connect(_on_card_discard_toggled)

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

# Режим замены карт
func _on_discard_mode_pressed() -> void:
	_cancel_selection()
	is_in_discard_mode = true
	selected_discard_ids.clear()
	
	buttons_row.visible = false
	discard_bar.visible = true
	discard_info_label.text = "Выберите карты для замены (0)"
	confirm_discard_btn.disabled = true
	
	var gm = get_node_or_null("/root/Main/GameManager") as GameManager
	if gm:
		_on_game_state_updated(gm.game_state)

func _on_card_discard_toggled(card_inst_id: int, selected: bool) -> void:
	if selected:
		if not selected_discard_ids.has(card_inst_id):
			selected_discard_ids.append(card_inst_id)
	else:
		selected_discard_ids.erase(card_inst_id)
		
	discard_info_label.text = "Выберите карты для замены (%d)" % selected_discard_ids.size()
	confirm_discard_btn.disabled = selected_discard_ids.is_empty()

func _on_confirm_discard_pressed() -> void:
	if selected_discard_ids.is_empty():
		return
	
	var count = selected_discard_ids.size()
	var gm = get_node_or_null("/root/Main/GameManager") as GameManager
	if gm:
		gm.rpc_id(1, "rpc_request_discard_cards", selected_discard_ids)
	
	var d_pos = $VBox/PlayerBoardArea/PlayerDeck.global_position + Vector2(42, 20)
	_spawn_floating_text("+%d 🎴 Замена!" % count, Color("#4dabf7"), d_pos)
	
	_exit_discard_mode()

func _exit_discard_mode() -> void:
	is_in_discard_mode = false
	selected_discard_ids.clear()
	
	discard_bar.visible = false
	buttons_row.visible = true
	
	var gm = get_node_or_null("/root/Main/GameManager") as GameManager
	if gm:
		_on_game_state_updated(gm.game_state)

func _on_card_clicked(card_data: Dictionary) -> void:
	if is_in_discard_mode:
		return
		
	selected_card_for_play = card_data
	var gm = get_node_or_null("/root/Main/GameManager") as GameManager
	if not gm or not gm.game_state.players.has(local_player_id):
		return
		
	var my_data = gm.game_state.players[local_player_id]
	var cur_mana = my_data.mana
	var cur_souls = my_data.souls
	
	var mode = card_data.get("pay_mode", "MANA")
	var m = card_data.get("mana_cost", 0)
	var s = card_data.get("soul_cost", 0)
	
	if mode == "OR":
		var can_mana = cur_mana >= m
		var can_souls = cur_souls >= s
		
		if can_mana and can_souls:
			pay_dialog_label.text = "Как оплатить карту «%s»?" % card_data.name
			pay_mana_btn.text = "Маной (%d 🔮)" % m
			pay_souls_btn.text = "Душами (%d 💀)" % s
			pay_dialog.visible = true
			return
		elif can_mana:
			_confirm_payment("MANA")
		elif can_souls:
			_confirm_payment("SOULS")
	else:
		_confirm_payment(mode)

func _confirm_payment(choice: String) -> void:
	pay_dialog.visible = false
	selected_payment_mode = choice
	is_targeting_slot = true
	target_hint_label.text = "➔ Выберите пустой слот на вашем поле для карты «%s»" % selected_card_for_play.name
	target_hint_label.visible = true
	
	var gm = get_node_or_null("/root/Main/GameManager") as GameManager
	if gm:
		_on_game_state_updated(gm.game_state)

func _cancel_selection() -> void:
	pay_dialog.visible = false
	selected_card_for_play = {}
	selected_payment_mode = ""
	is_targeting_slot = false
	target_hint_label.visible = false
	
	var gm = get_node_or_null("/root/Main/GameManager") as GameManager
	if gm:
		_on_game_state_updated(gm.game_state)

func _on_slot_selected(slot_idx: int) -> void:
	if not is_targeting_slot or selected_card_for_play.is_empty():
		return
	
	var card_id = selected_card_for_play.inst_id
	var pay_choice = selected_payment_mode
	_cancel_selection()
	
	var gm = get_node_or_null("/root/Main/GameManager")
	if gm:
		gm.rpc_id(1, "rpc_request_play_card", card_id, slot_idx, pay_choice)

func _on_sacrifice_clicked(slot_idx: int) -> void:
	var gm = get_node_or_null("/root/Main/GameManager")
	if gm:
		gm.rpc_id(1, "rpc_request_sacrifice", slot_idx)

func _on_end_turn_pressed() -> void:
	_cancel_selection()
	_exit_discard_mode()
	var gm = get_node_or_null("/root/Main/GameManager")
	if gm:
		gm.rpc_id(1, "rpc_request_end_turn")

func _render_log(logs: Array) -> void:
	var bbcode = ""
	for line in logs:
		bbcode += line + "\n"
	battle_log_text.text = bbcode
	battle_log_text.scroll_to_line(battle_log_text.get_line_count())

func _on_log_message_added(_msg: String) -> void:
	var gm = get_node_or_null("/root/Main/GameManager") as GameManager
	if gm:
		_render_log(gm.game_state.get("battle_log", []))

func _show_game_over(state: Dictionary) -> void:
	game_over_panel.visible = true
	var winner_id = state.get("winner_id", 0)
	var my_score = state.players[local_player_id].score
	var opp_id = _get_opponent_id(state, local_player_id)
	var opp_score = state.players.get(opp_id, {}).get("score", 0)
	
	if winner_id == local_player_id:
		game_over_title.text = "🏆 ПОБЕДА НЕКРОМАНТА!"
		game_over_title.modulate = Color("#ffd43b")
		game_over_details.text = "Вы подчинили склеп и сокрушили врага!\nСчет: %d против %d" % [my_score, opp_score]
	elif winner_id == -1:
		game_over_title.text = "💀 НИЧЬЯ!"
		game_over_title.modulate = Color("#adb5bd")
		game_over_details.text = "Оба короля пали в прах.\nСчет: %d - %d" % [my_score, opp_score]
	else:
		game_over_title.text = "☠️ ПОРАЖЕНИЕ"
		game_over_title.modulate = Color("#e03131")
		game_over_details.text = "Ваши кости пополнили армию соперника...\nСчет: %d против %d" % [my_score, opp_score]
	
	restart_btn.visible = NetworkManager.is_host or gm_is_ai()

func gm_is_ai() -> bool:
	var gm = get_node_or_null("/root/Main/GameManager") as GameManager
	return gm.is_ai_mode if gm else false

func _on_restart_pressed() -> void:
	game_over_panel.visible = false
	var gm = get_node_or_null("/root/Main/GameManager")
	if gm:
		gm.rpc_request_restart()

func _on_exit_to_lobby_pressed() -> void:
	NetworkManager.disconnect_game()
	leave_to_lobby_requested.emit()

func _get_opponent_id(state: Dictionary, my_id: int) -> int:
	if my_id == state.get("p1_id", 1):
		return state.get("p2_id", 0)
	return state.get("p1_id", 1)
