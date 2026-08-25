extends Control

@onready var ip_input     : LineEdit = $VBox/IPInput
@onready var btn_host     : Button   = $VBox/BtnHost
@onready var btn_join     : Button   = $VBox/BtnJoin
@onready var btn_start    : Button   = $VBox/BtnStart
@onready var status_label : Label    = $VBox/StatusLabel
@onready var peers_label  : Label    = $VBox/PeersLabel

func _ready():
	btn_start.visible = false
	NetworkManager.player_joined.connect(_on_player_joined)
	NetworkManager.player_left.connect(_on_player_left)
	NetworkManager.connection_failed.connect(_on_connection_failed)

func _on_host_pressed():
	var err = NetworkManager.host()
	if err != OK:
		status_label.text = "Error al crear servidor"
		return
	status_label.text = "Esperando jugadores...  (tu ID: 1)"
	btn_host.disabled = true
	btn_join.disabled = true
	btn_start.visible = true
	_update_peers()

func _on_join_pressed():
	var ip = ip_input.text.strip_edges()
	if ip.is_empty():
		ip = "127.0.0.1"
	var err = NetworkManager.join(ip)
	if err != OK:
		status_label.text = "Error al conectar"
		return
	status_label.text = "Conectando a %s..." % ip
	btn_host.disabled = true
	btn_join.disabled = true

func _on_start_pressed():
	if not multiplayer.is_server():
		return
	_load_world.rpc(NetworkManager.connected_peers)

func _on_player_joined(id: int):
	status_label.text = "Conectado — tu ID: %d" % multiplayer.get_unique_id()
	_update_peers()

func _on_player_left(_id: int):
	_update_peers()

func _on_connection_failed():
	status_label.text = "Conexion fallida"
	btn_host.disabled = false
	btn_join.disabled = false

func _update_peers():
	peers_label.text = "Jugadores conectados: %d" % NetworkManager.connected_peers.size()

@rpc("authority", "call_local", "reliable")
func _load_world(peers: Array):
	NetworkManager.connected_peers = peers
	get_tree().change_scene_to_file("res://maps/map_01/world.tscn")
