class_name MainMenu
extends Control

signal play_ai_selected(player_name: String)
signal multiplayer_selected(player_name: String)
signal deck_browser_selected

@onready var name_input: LineEdit = $Panel/VBox/NameInput
@onready var btn_ai: Button = $Panel/VBox/BtnAI
@onready var btn_multiplayer: Button = $Panel/VBox/BtnMultiplayer
@onready var btn_deck: Button = $Panel/VBox/BtnDeck
@onready var btn_exit: Button = $Panel/VBox/BtnExit

func _ready() -> void:
	btn_ai.pressed.connect(_on_ai_pressed)
	btn_multiplayer.pressed.connect(_on_multiplayer_pressed)
	btn_deck.pressed.connect(_on_deck_pressed)
	btn_exit.pressed.connect(func(): get_tree().quit())
	
	if OS.get_cmdline_args().has("--client"):
		name_input.text = "Некромант 2"
	else:
		name_input.text = "Некромант 1"

func _get_name() -> String:
	var n = name_input.text.strip_edges()
	return n if not n.is_empty() else "Некромант"

func _on_ai_pressed() -> void:
	play_ai_selected.emit(_get_name())

func _on_multiplayer_pressed() -> void:
	multiplayer_selected.emit(_get_name())

func _on_deck_pressed() -> void:
	deck_browser_selected.emit()
