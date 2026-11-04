extends Node

# Синглтон сетевого взаимодействия (ENet Multiplayer)

signal peer_connected(id: int)
signal peer_disconnected(id: int)
signal connection_succeeded
signal connection_failed
signal server_disconnected
signal players_updated

var peer: ENetMultiplayerPeer
var is_host: bool = false
var local_name: String = "Некромант"
var players: Dictionary = {} # peer_id -> { "name": String }

func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

func host_game(port: int, player_name: String) -> Error:
	disconnect_game()
	local_name = player_name
	peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(port, 2)
	if error != OK:
		print("[NetworkManager] Ошибка создания сервера: ", error)
		return error
	multiplayer.multiplayer_peer = peer
	is_host = true
	players[1] = { "name": local_name }
	players_updated.emit()
	print("[NetworkManager] Сервер запущен на порту ", port)
	return OK

func join_game(address: String, port: int, player_name: String) -> Error:
	disconnect_game()
	local_name = player_name
	peer = ENetMultiplayerPeer.new()
	var error = peer.create_client(address, port)
	if error != OK:
		print("[NetworkManager] Ошибка подключения к ", address, ":", port)
		return error
	multiplayer.multiplayer_peer = peer
	is_host = false
	print("[NetworkManager] Подключение к ", address, ":", port, "...")
	return OK

func disconnect_game() -> void:
	if peer:
		peer.close()
		peer = null
	multiplayer.multiplayer_peer = null
	players.clear()
	is_host = false

func _on_peer_connected(id: int) -> void:
	print("[NetworkManager] Подключился пир: ", id)
	# Отправляем свое имя новому пиру
	rpc_id(id, "register_player", local_name)
	peer_connected.emit(id)

func _on_peer_disconnected(id: int) -> void:
	print("[NetworkManager] Пир отключился: ", id)
	players.erase(id)
	players_updated.emit()
	peer_disconnected.emit(id)

func _on_connected_to_server() -> void:
	print("[NetworkManager] Успешно подключились к серверу!")
	var my_id = multiplayer.get_unique_id()
	players[my_id] = { "name": local_name }
	# Регистрируем себя на хосте
	rpc_id(1, "register_player", local_name)
	connection_succeeded.emit()

func _on_connection_failed() -> void:
	print("[NetworkManager] Не удалось подключиться к серверу.")
	disconnect_game()
	connection_failed.emit()

func _on_server_disconnected() -> void:
	print("[NetworkManager] Сервер разорвал соединение.")
	disconnect_game()
	server_disconnected.emit()

@rpc("any_peer", "call_local", "reliable")
func register_player(player_name: String) -> void:
	var sender_id = multiplayer.get_remote_sender_id()
	if sender_id == 0:
		sender_id = multiplayer.get_unique_id()
	players[sender_id] = { "name": player_name }
	print("[NetworkManager] Игрок зарегистрирован: id=", sender_id, " name=", player_name)
	players_updated.emit()
	
	# Если мы хост, рассылаем обновленный список игроков всем клиентам
	if is_host:
		for pid in multiplayer.get_peers():
			rpc_id(pid, "sync_player_list", players)

@rpc("authority", "call_local", "reliable")
func sync_player_list(synced_players: Dictionary) -> void:
	players = synced_players
	players_updated.emit()

func get_local_ip() -> String:
	for ip in IP.get_local_addresses():
		if ip.begins_with("192.168.") or ip.begins_with("10.") or ip.begins_with("169.254.") or (ip.begins_with("172.") and not ip.begins_with("172.16.0.")):
			return ip
	return "127.0.0.1"
