class_name Lobby
extends Control

signal start_game_requested
signal back_to_menu_requested

@onready var name_input: LineEdit = $Panel/VBox/NameInput
@onready var host_port_input: LineEdit = $Panel/VBox/HostSection/HBox/PortInput
@onready var host_btn: Button = $Panel/VBox/HostSection/HostButton
@onready var ip_info_label: Label = $Panel/VBox/HostSection/IpInfoLabel

@onready var client_ip_input: LineEdit = $Panel/VBox/JoinSection/HBox/IpInput
@onready var client_port_input: LineEdit = $Panel/VBox/JoinSection/HBox/PortInput
@onready var join_btn: Button = $Panel/VBox/JoinSection/JoinButton

@onready var status_label: Label = $Panel/VBox/StatusLabel
@onready var back_btn: Button = $Panel/VBox/BackBtn

func _ready() -> void:
	host_btn.pressed.connect(_on_host_pressed)
	join_btn.pressed.connect(_on_join_pressed)
	back_btn.pressed.connect(func():
		NetworkManager.disconnect_game()
		back_to_menu_requested.emit()
	)
	
	NetworkManager.connection_succeeded.connect(_on_connection_succeeded)
	NetworkManager.connection_failed.connect(_on_connection_failed)
	NetworkManager.peer_connected.connect(_on_peer_connected)
	NetworkManager.players_updated.connect(_on_players_updated)
	NetworkManager.server_disconnected.connect(_on_server_disconnected)
	
	var local_ip = NetworkManager.get_local_ip()
	ip_info_label.text = "Ваш локальный IP: " + local_ip
	
	if OS.get_cmdline_args().has("--client"):
		name_input.text = "Некромант 2"
	else:
		name_input.text = "Некромант 1"

func set_initial_name(pname: String) -> void:
	name_input.text = pname

func _on_host_pressed() -> void:
	var player_name = name_input.text.strip_edges()
	if player_name.is_empty():
		player_name = "Некромант 1"
		
	var port = int(host_port_input.text)
	if port <= 0:
		port = 7777
		
	status_label.text = "Запуск сервера на порту %d..." % port
	status_label.modulate = Color("#ffd43b")
	
	var err = NetworkManager.host_game(port, player_name)
	if err == OK:
		status_label.text = "Сервер запущен! Ожидание второго игрока..."
		status_label.modulate = Color("#38d9a9")
		host_btn.disabled = true
		join_btn.disabled = true
	else:
		status_label.text = "Ошибка запуска сервера: код %d" % err
		status_label.modulate = Color("#e03131")

func _on_join_pressed() -> void:
	var player_name = name_input.text.strip_edges()
	if player_name.is_empty():
		player_name = "Некромант 2"
		
	var ip = client_ip_input.text.strip_edges()
	if ip.is_empty():
		ip = "127.0.0.1"
		
	var port = int(client_port_input.text)
	if port <= 0:
		port = 7777
		
	status_label.text = "Подключение к %s:%d..." % [ip, port]
	status_label.modulate = Color("#ffd43b")
	
	var err = NetworkManager.join_game(ip, port, player_name)
	if err != OK:
		status_label.text = "Ошибка соединения: код %d" % err
		status_label.modulate = Color("#e03131")
	else:
		host_btn.disabled = true
		join_btn.disabled = true

func _on_connection_succeeded() -> void:
	status_label.text = "Успешное подключение! Ожидание синхронизации..."
	status_label.modulate = Color("#38d9a9")

func _on_connection_failed() -> void:
	status_label.text = "Не удалось подключиться к серверу."
	status_label.modulate = Color("#e03131")
	host_btn.disabled = false
	join_btn.disabled = false

func _on_server_disconnected() -> void:
	status_label.text = "Соединение с сервером разорвано."
	status_label.modulate = Color("#e03131")
	host_btn.disabled = false
	join_btn.disabled = false

func _on_peer_connected(peer_id: int) -> void:
	print("[Lobby] Пир подключен: ", peer_id)

func _on_players_updated() -> void:
	var count = NetworkManager.players.size()
	print("[Lobby] Игроков в лобби: ", count)
	if count >= 2:
		status_label.text = "Оба игрока подключены! Запуск матча..."
		status_label.modulate = Color("#38d9a9")
		await get_tree().create_timer(0.5).timeout
		start_game_requested.emit()
