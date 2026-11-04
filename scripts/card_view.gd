class_name CardView
extends PanelContainer

signal card_clicked(card_data: Dictionary)
signal discard_toggled(card_inst_id: int, selected: bool)

@onready var title_label: Label = $VBox/Header/TitleLabel
@onready var category_label: Label = $VBox/CategoryLabel
@onready var cost_label: Label = $VBox/Header/CostLabel
@onready var desc_label: Label = $VBox/DescLabel
@onready var stats_label: Label = $VBox/Footer/StatsLabel
@onready var play_btn: Button = $VBox/PlayButton

var card_data: Dictionary = {}
var is_playable: bool = false
var is_discard_mode: bool = false
var is_selected_for_discard: bool = false
var is_elevated: bool = false

var default_style: StyleBoxFlat
var hover_style: StyleBoxFlat
var discard_selected_style: StyleBoxFlat

func _ready() -> void:
	custom_minimum_size = Vector2(140, 190)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	play_btn.pressed.connect(_on_play_pressed)
	_setup_styles()

func _setup_styles() -> void:
	default_style = StyleBoxFlat.new()
	default_style.bg_color = Color("#18141f")
	default_style.border_width_left = 2
	default_style.border_width_top = 2
	default_style.border_width_right = 2
	default_style.border_width_bottom = 2
	default_style.border_color = Color("#3b324d")
	default_style.corner_radius_top_left = 8
	default_style.corner_radius_top_right = 8
	default_style.corner_radius_bottom_left = 8
	default_style.corner_radius_bottom_right = 8
	
	hover_style = default_style.duplicate()
	hover_style.border_color = Color("#748ffc")
	hover_style.bg_color = Color("#221b2e")
	
	discard_selected_style = default_style.duplicate()
	discard_selected_style.border_color = Color("#f03e3e")
	discard_selected_style.bg_color = Color("#2b151a")
	
	add_theme_stylebox_override("panel", default_style)

func setup(data: Dictionary, can_play: bool, in_discard_mode: bool = false, is_discarded: bool = false) -> void:
	if is_elevated:
		is_elevated = false
		position.y += 10
	
	card_data = data
	is_playable = can_play
	is_discard_mode = in_discard_mode
	is_selected_for_discard = is_discarded
	
	title_label.text = data.get("name", "Карта")
	category_label.text = data.get("category", "")
	
	var cost_text = ""
	var pay_mode = data.get("pay_mode", "MANA")
	var m = data.get("mana_cost", 0)
	var s = data.get("soul_cost", 0)
	
	if pay_mode == "MANA":
		cost_text = "%d 🔮" % m
	elif pay_mode == "SOULS":
		cost_text = "%d 💀" % s
	elif pay_mode == "OR":
		cost_text = "%d🔮/%d💀" % [m, s]
	elif pay_mode == "AND":
		cost_text = "%d🔮+%d💀" % [m, s]
		
	cost_label.text = cost_text
	desc_label.text = data.get("desc", "")
	
	var atk = data.get("attack", 0)
	var hp = data.get("health", 1)
	stats_label.text = "%d ⚔ | %d 🩸" % [atk, hp]
	
	if is_discard_mode:
		play_btn.disabled = false
		if is_selected_for_discard:
			play_btn.text = "✓ Заменить"
			play_btn.modulate = Color("#4dabf7")
			add_theme_stylebox_override("panel", discard_selected_style)
		else:
			play_btn.text = "Оставить"
			play_btn.modulate = Color("#ced4da")
			add_theme_stylebox_override("panel", default_style)
	else:
		add_theme_stylebox_override("panel", default_style)
		play_btn.disabled = not is_playable
		if is_playable:
			play_btn.text = "Призвать"
			play_btn.modulate = Color("#38d9a9")
		else:
			play_btn.text = "Недоступно"
			play_btn.modulate = Color("#868e96")

func _on_play_pressed() -> void:
	if is_discard_mode:
		is_selected_for_discard = not is_selected_for_discard
		discard_toggled.emit(card_data.inst_id, is_selected_for_discard)
		setup(card_data, is_playable, true, is_selected_for_discard)
	elif is_playable:
		card_clicked.emit(card_data)

func _on_mouse_entered() -> void:
	if is_discard_mode:
		return
	if is_playable and not is_elevated:
		is_elevated = true
		position.y -= 10
		add_theme_stylebox_override("panel", hover_style)

func _on_mouse_exited() -> void:
	if is_discard_mode:
		return
	if is_elevated:
		is_elevated = false
		position.y += 10
	add_theme_stylebox_override("panel", default_style)
