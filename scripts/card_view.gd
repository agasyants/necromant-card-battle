class_name CardView
extends PanelContainer

signal card_clicked(card_data: Dictionary)
signal discard_toggled(card_inst_id: int, selected: bool)

@onready var title_label: Label = $Margin/VBox/Header/TitleLabel
@onready var cost_label: Label = $Margin/VBox/Header/CostLabel
@onready var art_texture: TextureRect = $Margin/VBox/ArtFrame/ArtTexture
@onready var art_placeholder: CenterContainer = $Margin/VBox/ArtFrame/ArtPlaceholder
@onready var icon_label: Label = $Margin/VBox/ArtFrame/ArtPlaceholder/IconLabel
@onready var category_label: Label = $Margin/VBox/CategoryRibbon/CategoryLabel
@onready var desc_label: Label = $Margin/VBox/DescBox/DescLabel
@onready var atk_label: Label = $Margin/VBox/Footer/AtkBadge/AtkLabel
@onready var hp_label: Label = $Margin/VBox/Footer/HpBadge/HpLabel
@onready var play_btn: Button = $Margin/VBox/PlayButton

var card_data: Dictionary = {}
var is_playable: bool = false
var is_discard_mode: bool = false
var is_selected_for_discard: bool = false
var is_elevated: bool = false

var base_color: Color = Color("#adb5bd")
var default_style: StyleBoxFlat
var hover_style: StyleBoxFlat
var playable_style: StyleBoxFlat
var discard_selected_style: StyleBoxFlat

func _ready() -> void:
	custom_minimum_size = Vector2(170, 245)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	play_btn.pressed.connect(_on_play_pressed)

func _setup_styles_for_category(cat_color: Color) -> void:
	base_color = cat_color
	
	default_style = StyleBoxFlat.new()
	default_style.bg_color = Color("#14101c")
	default_style.border_width_left = 2
	default_style.border_width_top = 2
	default_style.border_width_right = 2
	default_style.border_width_bottom = 2
	default_style.border_color = cat_color.lerp(Color("#3a304a"), 0.5)
	default_style.corner_radius_top_left = 8
	default_style.corner_radius_top_right = 8
	default_style.corner_radius_bottom_left = 8
	default_style.corner_radius_bottom_right = 8
	default_style.shadow_size = 4
	default_style.shadow_color = Color(0, 0, 0, 0.4)
	
	playable_style = default_style.duplicate()
	playable_style.border_color = Color("#38d9a9")
	playable_style.border_width_left = 2
	playable_style.border_width_top = 2
	playable_style.border_width_right = 2
	playable_style.border_width_bottom = 2
	playable_style.shadow_color = Color("#38d9a9", 0.3)
	playable_style.shadow_size = 6
	
	hover_style = default_style.duplicate()
	hover_style.border_color = Color("#74c0fc")
	hover_style.border_width_left = 3
	hover_style.border_width_top = 3
	hover_style.border_width_right = 3
	hover_style.border_width_bottom = 3
	hover_style.bg_color = Color("#1e172a")
	hover_style.shadow_size = 10
	hover_style.shadow_color = Color("#4dabf7", 0.4)
	
	discard_selected_style = default_style.duplicate()
	discard_selected_style.border_color = Color("#ff6b6b")
	discard_selected_style.border_width_left = 3
	discard_selected_style.border_width_top = 3
	discard_selected_style.border_width_right = 3
	discard_selected_style.border_width_bottom = 3
	discard_selected_style.bg_color = Color("#2b151a")
	discard_selected_style.shadow_color = Color("#ff6b6b", 0.4)

func setup(data: Dictionary, can_play: bool, in_discard_mode: bool = false, is_discarded: bool = false) -> void:
	if is_elevated:
		is_elevated = false
		position.y += 18
	
	card_data = data
	is_playable = can_play
	is_discard_mode = in_discard_mode
	is_selected_for_discard = is_discarded
	
	var cat_color = data.get("color", Color("#adb5bd"))
	_setup_styles_for_category(cat_color)
	
	# Текстовые поля
	title_label.text = data.get("name", "Карта")
	
	var cat_name = data.get("category", "")
	var spaced_cat = ""
	for i in range(cat_name.length()):
		spaced_cat += cat_name[i] + " "
	category_label.text = spaced_cat.strip_edges()
	category_label.modulate = cat_color
	
	# Стоимость
	var cost_text = ""
	var pay_mode = data.get("pay_mode", "MANA")
	var m = data.get("mana_cost", 0)
	var s = data.get("soul_cost", 0)
	
	if pay_mode == "MANA":
		cost_text = "%d 🔮" % m
		cost_label.modulate = Color("#74c0fc")
	elif pay_mode == "SOULS":
		cost_text = "%d 💀" % s
		cost_label.modulate = Color("#b197fc")
	elif pay_mode == "OR":
		cost_text = "%d🔮/%d💀" % [m, s]
		cost_label.modulate = Color("#ffd43b")
	elif pay_mode == "AND":
		cost_text = "%d🔮+%d💀" % [m, s]
		cost_label.modulate = Color("#ff922b")
		
	cost_label.text = cost_text
	desc_label.text = data.get("desc", "")
	
	# Статы
	var atk = data.get("attack", 0)
	var hp = data.get("health", 1)
	atk_label.text = "%d ⚔" % atk
	hp_label.text = "%d 🩸" % hp
	
	# Настройка арта / картинки карты
	_setup_card_art(data)
	
	# Режим сброса или обычный режим розыгрыша
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
		if is_playable:
			add_theme_stylebox_override("panel", playable_style)
			play_btn.disabled = false
			play_btn.text = "Призвать"
			play_btn.modulate = Color("#38d9a9")
		else:
			add_theme_stylebox_override("panel", default_style)
			play_btn.disabled = true
			play_btn.text = "Недоступно"
			play_btn.modulate = Color("#868e96")

func _setup_card_art(data: Dictionary) -> void:
	var art_path = data.get("art", "")
	if art_path != "" and ResourceLoader.exists(art_path):
		var tex = load(art_path) as Texture2D
		if tex:
			art_texture.texture = tex
			art_texture.visible = true
			art_placeholder.visible = false
			return
			
	if data.has("art_texture") and data["art_texture"] is Texture2D:
		art_texture.texture = data["art_texture"]
		art_texture.visible = true
		art_placeholder.visible = false
		return
		
	# Заглушка по умолчанию: атмосферная тематическая иконка
	art_texture.texture = null
	art_texture.visible = false
	art_placeholder.visible = true
	
	var custom_icon = data.get("art_icon", "")
	if custom_icon != "":
		icon_label.text = custom_icon
	else:
		var cat = data.get("category", "")
		if cat == "Скелет":
			icon_label.text = "💀"
		elif cat == "Призрак":
			icon_label.text = "👻"
		elif cat == "Плоть":
			icon_label.text = "🥩"
		elif cat == "Элита":
			icon_label.text = "👑"
		elif cat == "Зомби":
			icon_label.text = "🧟"
		else:
			icon_label.text = "🎴"

# Функция для прямой подстановки текстуры в карту из внешнего кода
func set_art_texture(texture: Texture2D) -> void:
	if texture:
		art_texture.texture = texture
		art_texture.visible = true
		art_placeholder.visible = false
	else:
		art_texture.texture = null
		art_texture.visible = false
		art_placeholder.visible = true

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
	if not is_elevated:
		is_elevated = true
		position.y -= 18
		z_index = 10
		add_theme_stylebox_override("panel", hover_style)

func _on_mouse_exited() -> void:
	if is_discard_mode:
		return
	if is_elevated:
		is_elevated = false
		position.y += 18
		z_index = 0
	if is_playable:
		add_theme_stylebox_override("panel", playable_style)
	else:
		add_theme_stylebox_override("panel", default_style)
