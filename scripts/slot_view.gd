class_name SlotView
extends PanelContainer

signal slot_selected(slot_idx: int)
signal sacrifice_clicked(slot_idx: int)

@onready var title_label: Label = $VBox/TitleLabel
@onready var category_label: Label = $VBox/CategoryLabel
@onready var desc_label: Label = $VBox/DescLabel
@onready var stats_label: Label = $VBox/StatsLabel
@onready var action_btn: Button = $VBox/ActionButton

var slot_index: int = 0
var is_player_slot: bool = true
var creature_data: Variant = null

var empty_style: StyleBoxFlat
var occupied_style: StyleBoxFlat
var opponent_style: StyleBoxFlat
var combat_focus_style: StyleBoxFlat

func _ready() -> void:
	custom_minimum_size = Vector2(130, 150)
	action_btn.pressed.connect(_on_action_pressed)
	_setup_styles()

func _setup_styles() -> void:
	empty_style = StyleBoxFlat.new()
	empty_style.bg_color = Color("#110e17", 0.7)
	empty_style.border_width_left = 1
	empty_style.border_width_top = 1
	empty_style.border_width_right = 1
	empty_style.border_width_bottom = 1
	empty_style.border_color = Color("#2d243b")
	empty_style.corner_radius_top_left = 6
	empty_style.corner_radius_top_right = 6
	empty_style.corner_radius_bottom_left = 6
	empty_style.corner_radius_bottom_right = 6
	
	occupied_style = empty_style.duplicate()
	occupied_style.bg_color = Color("#1a1526")
	occupied_style.border_color = Color("#5c7cfa")
	occupied_style.border_width_left = 2
	occupied_style.border_width_top = 2
	occupied_style.border_width_right = 2
	occupied_style.border_width_bottom = 2
	
	opponent_style = empty_style.duplicate()
	opponent_style.bg_color = Color("#211417")
	opponent_style.border_color = Color("#e03131")
	opponent_style.border_width_left = 2
	opponent_style.border_width_top = 2
	opponent_style.border_width_right = 2
	opponent_style.border_width_bottom = 2
	
	combat_focus_style = occupied_style.duplicate()
	combat_focus_style.border_color = Color("#ffd43b")
	combat_focus_style.border_width_left = 3
	combat_focus_style.border_width_top = 3
	combat_focus_style.border_width_right = 3
	combat_focus_style.border_width_bottom = 3
	
	add_theme_stylebox_override("panel", empty_style)

func setup(idx: int, for_player: bool) -> void:
	slot_index = idx
	is_player_slot = for_player

func update_creature(creature: Variant, eff_stats: Dictionary, is_my_turn: bool, is_targeting: bool) -> void:
	creature_data = creature
	
	if creature == null:
		title_label.text = "Слот %d" % (slot_index + 1)
		title_label.modulate = Color("#6c757d")
		category_label.text = ""
		desc_label.text = ""
		stats_label.text = ""
		add_theme_stylebox_override("panel", empty_style)
		
		if is_player_slot and is_targeting:
			action_btn.visible = true
			action_btn.text = "Выбрать слот"
			action_btn.modulate = Color("#38d9a9")
			action_btn.disabled = false
		else:
			action_btn.visible = false
	else:
		title_label.text = creature.name
		title_label.modulate = Color.WHITE
		category_label.text = creature.category
		desc_label.text = creature.desc
		
		var atk = eff_stats.get("atk", creature.base_atk)
		var hp = eff_stats.get("hp", creature.current_hp)
		
		stats_label.text = "%d ⚔ | %d 🩸" % [atk, hp]
		
		if is_player_slot:
			add_theme_stylebox_override("panel", occupied_style)
			if is_my_turn:
				action_btn.visible = true
				action_btn.text = "Жертва 💀"
				action_btn.modulate = Color("#ff6b6b")
				action_btn.disabled = false
			else:
				action_btn.visible = false
		else:
			add_theme_stylebox_override("panel", opponent_style)
			action_btn.visible = false

# Визуальная анимация выпада при атаке
func play_attack_anim(is_upward: bool) -> void:
	var delta_y = -30.0 if is_upward else 30.0
	var orig_y = position.y
	var tween = create_tween()
	tween.tween_property(self, "position:y", orig_y + delta_y, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position:y", orig_y, 0.25).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)

# Визуальная анимация получения удара
func play_hit_anim() -> void:
	var orig_pos = position
	var tween = create_tween()
	modulate = Color(2.0, 0.4, 0.4) # Вспышка красным
	tween.tween_property(self, "position:x", orig_pos.x + 8.0, 0.05)
	tween.tween_property(self, "position:x", orig_pos.x - 8.0, 0.05)
	tween.tween_property(self, "position:x", orig_pos.x, 0.05)
	tween.tween_property(self, "modulate", Color.WHITE, 0.2)

func set_combat_focus(active: bool) -> void:
	if active and creature_data != null:
		add_theme_stylebox_override("panel", combat_focus_style)
	elif creature_data != null:
		if is_player_slot:
			add_theme_stylebox_override("panel", occupied_style)
		else:
			add_theme_stylebox_override("panel", opponent_style)
	else:
		add_theme_stylebox_override("panel", empty_style)

func _on_action_pressed() -> void:
	if creature_data == null:
		slot_selected.emit(slot_index)
	else:
		sacrifice_clicked.emit(slot_index)
