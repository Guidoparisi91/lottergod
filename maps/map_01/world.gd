extends Node3D

const ATTACK_RANGE = 2.5

@onready var camera: Camera3D = $IsoCamera
@onready var hud              = $HUD

const SPAWN_ORIGIN = Vector3(0.0, 5.0, 0.0)

var local_player: CharacterBody3D = null
var player_scene = preload("res://characters/longsword/longsword.tscn")

var holding_attack:        bool    = false
var holding_left:          bool    = false
var holding_right:         bool    = false
var held_mouse_pos:        Vector2 = Vector2.ZERO
var pending_attack_target: Node3D  = null

var cursor_normal:    ImageTexture = null
var cursor_enemy:     ImageTexture = null
var cursor_over_enemy: bool        = false

func _ready():
	var default_player = get_node_or_null("Player")
	if default_player:
		default_player.queue_free()

	_setup_atmosphere()
	_create_cursors()

	if not NetworkManager.multiplayer_mode:
		_spawn_player(1)
		return

	for peer_id in NetworkManager.connected_peers:
		_spawn_player(peer_id)

	multiplayer.peer_disconnected.connect(_on_peer_disconnected)

## Punto de aparición del jugador. Si la escena tiene un nodo llamado
## "PlayerSpawn" (un Marker3D alcanza), manda su posición — así el spawn se
## mueve visualmente en el editor. Sin ese nodo, cae en SPAWN_ORIGIN.
func _spawn_origin() -> Vector3:
	var marca := get_node_or_null("PlayerSpawn")
	if marca is Node3D:
		return (marca as Node3D).global_position
	return SPAWN_ORIGIN


func _spawn_player(peer_id: int):
	var p = player_scene.instantiate()
	p.name = "Player_%d" % peer_id
	p.set_multiplayer_authority(peer_id)

	var idx       = NetworkManager.connected_peers.find(peer_id)
	var spawn_pos = _spawn_origin() + Vector3(max(0, idx) * 2.0, 0.0, 0.0)
	p.position    = spawn_pos

	add_child(p)

	var my_id = multiplayer.get_unique_id()
	if not NetworkManager.multiplayer_mode:
		my_id = 1

	if peer_id == my_id:
		local_player       = p
		p.spawn_position   = spawn_pos
		camera.target      = p
		hud.setup(p)
		p.add_to_group("player_local")
		for enemy in get_tree().get_nodes_in_group("enemy"):
			enemy.setup(p)
		for pit in get_tree().get_nodes_in_group("enemy_pit"):
			pit.setup(p)
		p.attack_finished.connect(_on_attack_finished)
		p.skill_changed.connect(hud.on_skill_changed)
		p.skill_charged.connect(hud.on_skill_charged)
	else:
		p.add_to_group("player_remote")

func _on_peer_disconnected(id: int):
	var node = get_node_or_null("Player_%d" % id)
	if node:
		node.queue_free()

func _input(event: InputEvent):
	if not local_player:
		return

	if event is InputEventMouseMotion and holding_left:
		held_mouse_pos = event.position
		if not local_player.attacking and not holding_right:
			_move_to_cursor(event.position)
		return

	if event is InputEventKey and event.pressed and not event.echo:
		if event.is_action("skill_q"):
			local_player.cast_q()
		elif event.is_action("skill_w"):
			local_player.cast_w()
		elif event.is_action("skill_e"):
			var mouse_pos  = get_viewport().get_mouse_position()
			var result     = _raycast(mouse_pos)
			var cursor_pos = result.position if result else Vector3.ZERO
			local_player.cast_e(cursor_pos)
		return

	if not event is InputEventMouseButton:
		return

	var is_left  = event.button_index == MOUSE_BUTTON_LEFT
	var is_right = event.button_index == MOUSE_BUTTON_RIGHT

	if event.pressed and (is_left or is_right):
		held_mouse_pos = event.position
		if is_right:
			pending_attack_target = null
			local_player.stop()
			holding_right = true
		if is_left:
			holding_left = true
		holding_attack = true
		_try_attack_or_move(event.position, is_right)
	else:
		if is_left:
			holding_left = false
		if is_right:
			holding_right = false
		holding_attack = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) \
					  or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)

func _process(delta):
	if local_player:
		_update_cursor()
	if not local_player or local_player.attacking:
		if pending_attack_target and local_player and local_player.attacking:
			pending_attack_target = null
		return

	# Auto-attack si el cursor está sobre un enemigo en rango con left o right hold
	if holding_left or holding_right:
		var result = _raycast(get_viewport().get_mouse_position())
		if result and (result.collider.is_in_group("enemy") or result.collider.is_in_group("player_remote")):
			var d = local_player.global_position.distance_to(result.collider.global_position)
			if d <= ATTACK_RANGE:
				pending_attack_target = null
				local_player.attack_target(result.collider)
				return
		# Sin enemigo bajo el cursor: reanudar movimiento si el jugador quedó quieto (ej: después de un dash)
		if holding_left and not holding_right and not local_player.moving:
			_move_to_cursor(get_viewport().get_mouse_position())

	# Ataque pendiente: llegó al enemigo clickeado desde lejos
	if not pending_attack_target:
		return
	if not is_instance_valid(pending_attack_target):
		pending_attack_target = null
		return
	var dist = local_player.global_position.distance_to(pending_attack_target.global_position)
	if dist <= ATTACK_RANGE:
		local_player.attack_target(pending_attack_target)
		pending_attack_target = null


func _move_to_cursor(mouse_pos: Vector2):
	var result = _raycast(mouse_pos)
	if result and not result.collider.is_in_group("enemy") and not result.collider.is_in_group("player_remote"):
		pending_attack_target = null
		local_player.move_to(result.position)

func _try_attack_or_move(mouse_pos: Vector2, right_click: bool):
	var result = _raycast(mouse_pos)
	if not result:
		return
	var collider = result.collider
	if collider.is_in_group("enemy") or collider.is_in_group("player_remote"):
		var dist = local_player.global_position.distance_to(collider.global_position)
		if dist <= ATTACK_RANGE:
			pending_attack_target = null
			local_player.attack_target(collider)
		elif not right_click:
			pending_attack_target = collider
			local_player.move_to(collider.global_position)
	elif not right_click:
		pending_attack_target = null
		local_player.move_to(result.position)
	if right_click:
		pending_attack_target = null
		if not collider.is_in_group("enemy") and not collider.is_in_group("player_remote"):
			if not local_player.moving:
				local_player.face_toward(result.position)

func _on_attack_finished():
	if not holding_attack:
		return
	var result = _raycast(held_mouse_pos)
	if result and (result.collider.is_in_group("enemy") or result.collider.is_in_group("player_remote")):
		var dist = local_player.global_position.distance_to(result.collider.global_position)
		if dist <= ATTACK_RANGE:
			local_player.attack_target(result.collider)


## Atmósfera por defecto (día normal). Solo se aplica si la escena NO trae la
## suya: si el WorldEnvironment ya tiene un Environment asignado en el editor,
## manda la escena y esta función no toca nada. Así la iluminación se ajusta
## visualmente y no por código.
func _setup_atmosphere():
	if $WorldEnvironment.environment != null:
		return

	# --- Sky ---
	var sky_mat = ProceduralSkyMaterial.new()
	# Sky — valores por defecto de día normal
	sky_mat.sky_top_color         = Color(0.385, 0.454, 0.55)
	sky_mat.sky_horizon_color     = Color(0.646, 0.656, 0.67)
	sky_mat.sky_curve             = 0.15
	sky_mat.sky_energy_multiplier = 1.0
	sky_mat.ground_bottom_color   = Color(0.2, 0.169, 0.133)
	sky_mat.ground_horizon_color  = Color(0.646, 0.656, 0.67)
	sky_mat.ground_curve          = 0.02
	sky_mat.sun_angle_max         = 30.0

	var sky = Sky.new()
	sky.sky_material = sky_mat

	# --- Environment ---
	var env = Environment.new()
	env.background_mode      = Environment.BG_SKY
	env.sky                  = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 1.0

	# Tonemapping
	env.tonemap_mode     = Environment.TONE_MAPPER_REINHARDT
	env.tonemap_exposure = 1.0
	env.tonemap_white    = 1.0

	# Corrección de color — desactivada (día normal)
	env.adjustment_enabled    = false
	env.adjustment_brightness = 1.0
	env.adjustment_contrast   = 1.0
	env.adjustment_saturation = 1.0

	# Fog — desactivado (listo para activar)
	env.fog_enabled            = false
	env.fog_light_color        = Color(0.52, 0.48, 0.42)
	env.fog_light_energy       = 1.0
	env.fog_sun_scatter        = 0.0
	env.fog_density            = 0.005
	env.fog_aerial_perspective = 0.2

	# Niebla volumétrica — desactivada (listo para activar)
	env.volumetric_fog_enabled         = false
	env.volumetric_fog_density         = 0.008
	env.volumetric_fog_albedo          = Color(0.55, 0.52, 0.48)
	env.volumetric_fog_emission        = Color(0.0, 0.0, 0.0)
	env.volumetric_fog_emission_energy = 0.0
	env.volumetric_fog_anisotropy      = 0.2
	env.volumetric_fog_length          = 64.0
	env.volumetric_fog_detail_spread   = 2.0

	# Glow — desactivado (listo para activar)
	env.glow_enabled    = false
	env.glow_normalized = true
	env.glow_intensity  = 0.5
	env.glow_bloom      = 0.04
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT

	$WorldEnvironment.environment = env

	# --- Luz direccional — igual al .tscn original ---
	var sun: DirectionalLight3D = $DirectionalLight3D
	sun.light_color            = Color(1.0, 1.0, 1.0)
	sun.light_energy           = 1.5
	sun.shadow_enabled         = true
	sun.light_angular_distance = 0.5

func _create_cursors():
	cursor_normal = _make_cursor(Color.WHITE)
	cursor_enemy  = _make_cursor(Color(1.0, 0.15, 0.15))
	Input.set_custom_mouse_cursor(cursor_normal, Input.CURSOR_ARROW, Vector2(12, 12))

func _make_cursor(color: Color) -> ImageTexture:
	var size = 24
	var img  = Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c    = size / 2
	var gap  = 3  # espacio en el centro para mayor legibilidad
	for i in range(size):
		if abs(i - c) >= gap:
			img.set_pixel(i, c,     color)
			img.set_pixel(i, c + 1, color)
			img.set_pixel(c,     i, color)
			img.set_pixel(c + 1, i, color)
	return ImageTexture.create_from_image(img)

func _update_cursor():
	var result     = _raycast(get_viewport().get_mouse_position())
	var over_enemy = result and (result.collider.is_in_group("enemy") \
								or result.collider.is_in_group("player_remote"))
	if over_enemy == cursor_over_enemy:
		return
	cursor_over_enemy = over_enemy
	var tex = cursor_enemy if over_enemy else cursor_normal
	Input.set_custom_mouse_cursor(tex, Input.CURSOR_ARROW, Vector2(12, 12))

func _raycast(mouse_pos: Vector2) -> Dictionary:
	var cam    = get_viewport().get_camera_3d()
	var space  = get_world_3d().direct_space_state
	var origin = cam.project_ray_origin(mouse_pos)
	var end    = origin + cam.project_ray_normal(mouse_pos) * 1000.0
	var query  = PhysicsRayQueryParameters3D.create(origin, end)
	if local_player:
		query.exclude = [local_player.get_rid()]
	return space.intersect_ray(query)
