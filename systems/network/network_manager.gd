extends Node

const PORT      = 7777
const MAX_PEERS = 4

var multiplayer_mode: bool    = false
var connected_peers:  Array[int] = []

signal player_joined(peer_id: int)
signal player_left(peer_id: int)
signal connection_failed

func host() -> Error:
	var peer = ENetMultiplayerPeer.new()
	var err  = peer.create_server(PORT, MAX_PEERS)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	connected_peers  = [1]
	multiplayer_mode = true
	return OK

func join(ip: String) -> Error:
	var peer = ENetMultiplayerPeer.new()
	var err  = peer.create_client(ip, PORT)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_failed)
	multiplayer_mode = true
	return OK

func _on_peer_connected(id: int):
	connected_peers.append(id)
	player_joined.emit(id)

func _on_peer_disconnected(id: int):
	connected_peers.erase(id)
	player_left.emit(id)

func _on_connected():
	# El servidor nos mandará la lista completa de peers antes de iniciar
	player_joined.emit(multiplayer.get_unique_id())

func _on_failed():
	multiplayer_mode = false
	connection_failed.emit()
