extends Node

# Главный контроллер переключения экранов

@onready var main_menu: MainMenu = $MainMenu
@onready var lobby: Lobby = $Lobby
@onready var deck_browser: DeckBrowser = $DeckBrowser
@onready var game_manager: GameManager = $GameManager

const GAME_TABLE_SCENE = preload("res://scenes/game_table.tscn")
var current_game_table: GameTable = null

func _ready() -> void:
	# Начальное состояние: видно только главное меню
	main_menu.visible = true
	lobby.visible = false
	deck_browser.visible = false
	
	main_menu.play_ai_selected.connect(_on_play_ai_selected)
	main_menu.multiplayer_selected.connect(_on_multiplayer_selected)
	main_menu.deck_browser_selected.connect(_on_deck_browser_selected)
	
	lobby.back_to_menu_requested.connect(_on_back_to_menu)
	lobby.start_game_requested.connect(_on_lobby_start_game_requested)
	
	deck_browser.back_to_menu_requested.connect(_on_back_to_menu)
	
	NetworkManager.peer_disconnected.connect(_on_peer_disconnected)
	NetworkManager.server_disconnected.connect(_on_server_disconnected)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F11 or (event.keycode == KEY_ENTER and event.alt_pressed):
			var current_mode = DisplayServer.window_get_mode()
			if current_mode == DisplayServer.WINDOW_MODE_FULLSCREEN or current_mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			else:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

func _on_play_ai_selected(player_name: String) -> void:
	main_menu.visible = false
	lobby.visible = false
	deck_browser.visible = false
	
	_load_game_table()
	game_manager.start_match(1, player_name, 2, "Лич-Архивариус", true)

func _on_multiplayer_selected(player_name: String) -> void:
	main_menu.visible = false
	lobby.set_initial_name(player_name)
	lobby.visible = true

func _on_deck_browser_selected() -> void:
	main_menu.visible = false
	deck_browser.visible = true

func _on_back_to_menu() -> void:
	lobby.visible = false
	deck_browser.visible = false
	main_menu.visible = true

func _on_lobby_start_game_requested() -> void:
	if NetworkManager.is_host:
		var p1_id = 1
		var p1_name = NetworkManager.players.get(1, {}).get("name", "Некромант 1")
		var p2_id = -1
		var p2_name = "Некромант 2"
		
		for pid in NetworkManager.players.keys():
			if pid != 1:
				p2_id = pid
				p2_name = NetworkManager.players[pid].get("name", "Некромант 2")
				break
				
		if p2_id != -1:
			rpc("load_game_scene")
			game_manager.start_match(p1_id, p1_name, p2_id, p2_name, false)

@rpc("call_local", "reliable")
func load_game_scene() -> void:
	lobby.visible = false
	main_menu.visible = false
	_load_game_table()

func _load_game_table() -> void:
	if current_game_table != null:
		current_game_table.queue_free()
		
	current_game_table = GAME_TABLE_SCENE.instantiate() as GameTable
	add_child(current_game_table)
	current_game_table.leave_to_lobby_requested.connect(_return_to_menu)

func _return_to_menu() -> void:
	if current_game_table != null:
		current_game_table.queue_free()
		current_game_table = null
	main_menu.visible = true

func _on_peer_disconnected(id: int) -> void:
	if current_game_table != null and not game_manager.is_ai_mode:
		_return_to_menu()
		lobby.status_label.text = "Оппонент отключился от игры."
		lobby.status_label.modulate = Color("#e03131")

func _on_server_disconnected() -> void:
	if current_game_table != null and not game_manager.is_ai_mode:
		_return_to_menu()
		lobby.status_label.text = "Хост закрыл соединение."
		lobby.status_label.modulate = Color("#e03131")
