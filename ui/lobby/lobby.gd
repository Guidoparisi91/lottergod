extends Control

@onready var ip_input     : LineEdit = $VBox/IPInput
@onready var btn_host     : Button   = $VBox/BtnHost
@onready var btn_join     : Button   = $VBox/BtnJoin
@onready var btn_start    : Button   = $VBox/BtnStart
@onready var status_label : Label    = $VBox/StatusLabel
@onready var peers_label  : Label    = $VBox/PeersLabel

# --- Arranque automatico por linea de comandos (solo para probar) ---
#
# Pensado para "Ejecutar multiples instancias" del editor: una ventana hostea,
# la otra se une, y la partida arranca sola cuando estan todas. Sin flags no
# cambia absolutamente nada, asi que es inofensivo en un build de verdad.
#
#   --auto-host          hostea y arranca cuando hay suficientes jugadores
#   --auto-join          se une a 127.0.0.1
#   --ip=192.168.0.5     a donde unirse (implica --auto-join)
#   --jugadores=3        cuantos esperar antes de arrancar (default 2)

const AUTO_JUGADORES := 2
## Margen para que el cliente recien conectado termine de armarse antes de
## recibir el cambio de escena. Sin esto la carrera es rara pero real.
const AUTO_START_DELAY := 0.4

var _auto_host: bool = false
var _auto_lanzado: bool = false
var _auto_jugadores: int = AUTO_JUGADORES

func _ready():
	btn_start.visible = false
	NetworkManager.player_joined.connect(_on_player_joined)
	NetworkManager.player_left.connect(_on_player_left)
	NetworkManager.connection_failed.connect(_on_connection_failed)
	_crear_boton_solo()
	_auto_arranque()

## Boton "Jugar solo", creado por codigo y NO en el .tscn a proposito: asi no hay
## que abrir la escena en Godot para tocarlo, y no se pisa si esta abierta.
##
## En web es la UNICA puerta de entrada: ENet no puede abrir un socket UDP en el
## navegador, asi que Hostear siempre falla ahi. Y es, ademas, el arranque real de
## la v1 — un jugador contra bots (ver DESIGN.md 15.9).
func _crear_boton_solo() -> void:
	var b := Button.new()
	b.name = "BtnSolo"
	b.text = "Jugar solo"
	b.pressed.connect(_on_solo_pressed)
	var vbox := ip_input.get_parent()
	vbox.add_child(b)
	vbox.move_child(b, ip_input.get_index())

func _on_solo_pressed() -> void:
	NetworkManager.multiplayer_mode = false
	get_tree().change_scene_to_file("res://maps/map_01/pruebas.tscn")

func _auto_arranque() -> void:
	var args := OS.get_cmdline_args() + OS.get_cmdline_user_args()
	var quiere_host := false
	var quiere_join := false
	var ip := "127.0.0.1"
	for a in args:
		if a == "--auto-host":
			quiere_host = true
		elif a == "--auto-join":
			quiere_join = true
		elif a.begins_with("--ip="):
			ip = a.substr(5)
			quiere_join = true
		elif a.begins_with("--jugadores="):
			_auto_jugadores = maxi(2, a.substr(12).to_int())

	# El host tiene prioridad: si te mandas los dos flags a la misma ventana,
	# hostear es lo unico que tiene sentido.
	if quiere_host:
		_auto_host = true
		_on_host_pressed()
	elif quiere_join:
		ip_input.text = ip
		_on_join_pressed()

## Arranca la partida sin tocar "Iniciar" cuando ya estan todos.
func _chequear_auto_start() -> void:
	if not _auto_host or _auto_lanzado or not multiplayer.is_server():
		return
	if NetworkManager.connected_peers.size() < _auto_jugadores:
		return
	_auto_lanzado = true
	status_label.text = "Arrancando solo (%d jugadores)..." % _auto_jugadores
	await get_tree().create_timer(AUTO_START_DELAY).timeout
	_on_start_pressed()

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
	_chequear_auto_start()

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
	get_tree().change_scene_to_file("res://maps/map_01/pruebas.tscn")
