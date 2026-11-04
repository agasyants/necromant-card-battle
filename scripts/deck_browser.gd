class_name DeckBrowser
extends Control

signal back_to_menu_requested

@onready var grid_container: GridContainer = $VBox/Scroll/Grid
@onready var back_btn: Button = $VBox/Header/BackBtn

const CARD_VIEW_SCENE = preload("res://scenes/card_view.tscn")

func _ready() -> void:
	back_btn.pressed.connect(func(): back_to_menu_requested.emit())
	_populate_cards()

func _populate_cards() -> void:
	for c in grid_container.get_children():
		c.queue_free()
		
	for card_id in CardDatabase.CARDS.keys():
		var data = CardDatabase.get_card(card_id)
		var cv = CARD_VIEW_SCENE.instantiate() as CardView
		grid_container.add_child(cv)
		cv.setup(data, false)
		cv.play_btn.visible = false # В режиме просмотра кнопка призыва не нужна
