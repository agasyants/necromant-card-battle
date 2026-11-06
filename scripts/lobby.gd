class_name Lobby
extends Control

signal start_game_requested
signal back_to_menu_requested

@onready var name_input: LineEdit = $Panel/VBox/NameInput
@onready var instruction_btn: Button = $Panel/VBox/InstructionBtn

@onready var host_port_input: LineEdit = $Panel/VBox/HostSection/HBox/PortInput
@onready var host_btn: Button = $Panel/VBox/HostSection/HostButton
@onready var ip_info_label: Label = $Panel/VBox/HostSection/IpBox/IpInfoLabel
@onready var copy_ip_btn: Button = $Panel/VBox/HostSection/IpBox/CopyIpBtn

@onready var client_ip_input: LineEdit = $Panel/VBox/JoinSection/HBox/IpInput
@onready var client_port_input: LineEdit = $Panel/VBox/JoinSection/HBox/PortInput
@onready var join_btn: Button = $Panel/VBox/JoinSection/JoinButton

@onready var status_label: Label = $Panel/VBox/StatusLabel
@onready var back_btn: Button = $Panel/VBox/BackBtn

# Модальное окно инструкции
@onready var instruction_modal: PanelContainer = $InstructionModal
@onready var close_instruction_btn: Button = $InstructionModal/VBox/CloseBtn

var detected_ip: String = "127.0.0.1"

func _ready() -> void:
	instruction_modal.visible = false
	instruction_btn.pressed.connect(func(): instruction_modal.visible = true)
	close_instruction_btn.pressed.connect(func(): instruction_modal.visible = false)
	
	host_btn.pressed.connect(_on_host_pressed)
	join_btn.pressed.connect(_on_join_pressed)
	copy_ip_btn.pressed.connect(_on_copy_ip_pressed)
	
	back_btn.pressed.connect(func():
		NetworkManager.disconnect_game()
		back_to_menu_requested.emit()
	)
	
	NetworkManager.connection_succeeded.connect(_on_connection_succeeded)
	NetworkManager.connection_failed.connect(_on_connection_failed)
	NetworkManager.peer_connected.connect(_on_peer_connected)
	NetworkManager.players_updated.connect(_on_players_updated)
	NetworkManager.server_disconnected.connect(_on_server_disconnected)
	
	var all_ips = NetworkManager.get_all_local_ips()
	detected_ip = NetworkManager.get_local_ip()
	if all_ips.size() > 1:
		var alt_ips: Array = []
		for ip in all_ips:
			if ip != detected_ip:
				alt_ips.append(ip)
		ip_info_label.text = "Ваш IP: %s (альт: %s)" % [detected_ip, ", ".join(alt_ips)]
	else:
		ip_info_label.text = "Ваш IP для второго игрока: " + detected_ip
	
	# Если мы на хотспоте, по умолчанию в поле присоединения подставим типичный IP
	if detected_ip.begins_with("192.168.137."):
		client_ip_input.text = detected_ip
	elif not detected_ip.is_empty() and detected_ip != "127.0.0.1":
		client_ip_input.text = detected_ip

func set_initial_name(pname: String) -> void:
	name_input.text = pname

func _on_copy_ip_pressed() -> void:
	DisplayServer.clipboard_set(detected_ip)
	status_label.text = "IP скопирован в буфер обмена: " + detected_ip
	status_label.modulate = Color("#38d9a9")

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
		status_label.text = "Сервер запущен! Сообщите свой IP (%s) второму игроку." % detected_ip
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
	if count >= 2:
		status_label.text = "Оба игрока подключены! Запуск матча..."
		status_label.modulate = Color("#38d9a9")
		await get_tree().create_timer(0.5).timeout
		start_game_requested.emit()
