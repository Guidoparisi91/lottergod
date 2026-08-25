class_name BaseEnemy
extends CharacterBody3D

## Clase base para todos los enemigos.
## Cada tipo de enemigo hereda de acá y sobreescribe lo que necesite.

signal died(killer_id: int)

const GRAVITY = -20.0

@export var max_hp:        float = 5.0
@export var speed:         float = 3.5
@export var detection_range: float = 10.0
@export var attack_range:  float = 1.5
@export var attack_damage: float = 1.0
@export var attack_cooldown: float = 1.5
@export var xp_reward:     int   = 10

var current_hp: float
var player: Node3D = null
var attack_timer: float = 0.0
var knockback_velocity: Vector3 = Vector3.ZERO

var last_attacker_id: int = 1

var _remote_pos:   Vector3 = Vector3.ZERO
var _remote_rot_y: float   = 0.0
var _sync_timer:   float   = 0.0
const _SYNC_RATE:  float   = 0.05

var _terrain: Node = null

# HP bar (creada por código; cada enemigo puede personalizar la altura)
var hp_fill: MeshInstance3D = null
@export var hp_bar_height: float = 2.4

enum State { IDLE, PATROL, CHASE, APPROACH }
var state = State.IDLE

@export var approach_speed_mult: float = 2.5
@export var approach_distance:   float = 30.0

@export var patrol_size: Vector2 = Vector2(6.0, 6.0)
var spawn_position: Vector3 = Vector3.ZERO
var patrol_target:  Vector3 = Vector3.ZERO
var patrol_idle_timer: float = 0.0

func _ready():
	add_to_group("enemy")
	current_hp = max_hp
	# Enemies en layer 2: colisionan con terreno (mask 1) pero no bloquean al player (layer 1)
	collision_layer = 2
	collision_mask  = 1
	_create_hp_bar()
	spawn_position = global_position
	patrol_target  = _pick_patrol_target()
	state          = State.PATROL
	for m in find_children("*", "MeshInstance3D", true, false):
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		m.gi_mode     = GeometryInstance3D.GI_MODE_DYNAMIC
	_terrain = _find_terrain3d()

func _find_terrain3d() -> Node:
	return _search_terrain(get_tree().root)

func _search_terrain(node: Node) -> Node:
	if node.get_class() == "Terrain3D":
		return node
	for c in node.get_children():
		var r = _search_terrain(c)
		if r:
			return r
	return null

func setup(p: Node3D):
	player = p

func set_patrol_area(center: Vector3, size: Vector2):
	spawn_position = center
	patrol_size    = size
	patrol_target  = _pick_patrol_target()

func _physics_process(delta):
	# Clientes: solo interpolar posición recibida del host
	if NetworkManager.multiplayer_mode and not is_multiplayer_authority():
		global_position = global_position.lerp(_remote_pos, delta * 15.0)
		rotation.y      = lerp_angle(rotation.y, _remote_rot_y, delta * 15.0)
		_update_hp_bar()
		return

	# Terrain3D genera chunks de colisión solo cerca de la cámara, así que
	# move_and_slide() no puede detectar el suelo en zonas alejadas del jugador.
	# Solución: leer el heightmap directo (no depende de física) y forzar Y cada frame.
	if _terrain and is_instance_valid(_terrain):
		velocity.y = 0.0
	elif not is_on_floor():
		velocity.y += GRAVITY * delta
	else:
		velocity.y = 0.0

	attack_timer -= delta

	match state:
		State.IDLE:
			velocity.x = 0
			velocity.z = 0
			_check_vision()
			patrol_idle_timer -= delta
			if patrol_idle_timer <= 0.0:
				patrol_target = _pick_patrol_target()
				state = State.PATROL
		State.PATROL:
			_check_vision()
			_move_to_patrol_target()
		State.CHASE:
			_chase_and_attack()
		State.APPROACH:
			_approach_to_player()

	if knockback_velocity.length() > 0.1:
		velocity.x = knockback_velocity.x
		velocity.z = knockback_velocity.z
		knockback_velocity = knockback_velocity.lerp(Vector3.ZERO, delta * 8.0)
	else:
		knockback_velocity = Vector3.ZERO

	if state != State.IDLE or not is_on_floor() or knockback_velocity.length() > 0.1:
		move_and_slide()

	# Snap Y al terreno después de move_and_slide() — sin depender de chunks de física.
	# Offset 0: el fondo de la cápsula está en Y=0 del root (center=0.9, height=1.8 → bottom=0).
	if _terrain and is_instance_valid(_terrain):
		global_position.y = _terrain.data.get_height(global_position)

	_update_hp_bar()

	# Host: enviar estado a todos los clientes cada 20Hz
	if NetworkManager.multiplayer_mode:
		_sync_timer -= delta
		if _sync_timer <= 0.0:
			_sync_timer = _SYNC_RATE
			_sync_enemy_state.rpc(global_position, rotation.y, current_hp, int(state), _get_sync_anim())

@rpc("authority", "unreliable_ordered")
func _sync_enemy_state(pos: Vector3, rot_y: float, hp: float, s: int, anim: String):
	_remote_pos   = pos
	_remote_rot_y = rot_y
	current_hp    = hp
	state         = s
	_apply_sync_anim(anim)

## Subclases sobreescriben para enviar su estado de animación actual
func _get_sync_anim() -> String:
	return ""

## Subclases sobreescriben para aplicar la animación recibida del host
func _apply_sync_anim(_anim: String) -> void:
	pass

func _pick_patrol_target() -> Vector3:
	var x = randf_range(-patrol_size.x * 0.5, patrol_size.x * 0.5)
	var z = randf_range(-patrol_size.y * 0.5, patrol_size.y * 0.5)
	return spawn_position + Vector3(x, 0.0, z)

func _move_to_patrol_target():
	var diff = patrol_target - global_position
	# Solo XZ: el Y del enemy siempre difiere del patrol_target.y por el terrain snap.
	var dist = Vector2(diff.x, diff.z).length()
	if dist < 0.5:
		patrol_idle_timer = randf_range(2.0, 5.0)
		state = State.IDLE
		velocity.x = 0
		velocity.z = 0
		return
	var dir = patrol_target - global_position
	dir.y = 0
	dir = dir.normalized()
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed
	rotation.y = atan2(dir.x, dir.z)

func _approach_to_player():
	var nearest = _get_nearest_player()
	if nearest == null:
		state = State.IDLE
		return
	player = nearest
	var dist = global_position.distance_to(player.global_position)
	if dist <= approach_distance:
		state = State.CHASE
		return
	var dir = player.global_position - global_position
	dir.y = 0
	dir = dir.normalized()
	var sep = _enemy_separation_force()
	if sep.length() > 0.01:
		dir = (dir + sep * 0.6).normalized()
	velocity.x = dir.x * speed * approach_speed_mult
	velocity.z = dir.z * speed * approach_speed_mult
	rotation.y = atan2(dir.x, dir.z)

func _check_vision():
	var nearest = _get_nearest_player()
	if nearest == null:
		return
	if global_position.distance_to(nearest.global_position) < detection_range:
		player = nearest
		state = State.CHASE

func _get_nearest_player() -> Node3D:
	var best: Node3D = null
	var best_dist := INF
	for p in get_tree().get_nodes_in_group("player_local") \
			+ get_tree().get_nodes_in_group("player_remote"):
		if not is_instance_valid(p):
			continue
		var d = global_position.distance_to(p.global_position)
		if d < best_dist:
			best_dist = d
			best = p
	return best

func _chase_and_attack():
	if player == null:
		return
	var dist = global_position.distance_to(player.global_position)

	if dist < attack_range:
		velocity.x = 0
		velocity.z = 0
		if attack_timer <= 0.0:
			attack_timer = attack_cooldown
			_do_attack()
		return

	var target = _get_surround_target()
	var dir    = target - global_position
	dir.y = 0
	if dir.length() < 0.1:
		dir = player.global_position - global_position
		dir.y = 0
	dir = dir.normalized()

	# Separación entre enemigos para que no se apilen
	var sep = _enemy_separation_force()
	dir = (dir + sep).normalized()

	velocity.x = dir.x * speed
	velocity.z = dir.z * speed
	rotation.y = atan2(dir.x, dir.z)

func _get_surround_target() -> Vector3:
	var chasers: Array = []
	for e in get_tree().get_nodes_in_group("enemy"):
		if e.get("state") == State.CHASE:
			chasers.append(e)
	chasers.sort_custom(func(a, b): return a.get_instance_id() < b.get_instance_id())

	var idx   = chasers.find(self)
	var total = max(chasers.size(), 1)

	# Ángulo base = dirección actual del enemigo al jugador + offset de slot
	var my_angle    = atan2(global_position.x - player.global_position.x,
							global_position.z - player.global_position.z)
	var slot_offset = TAU * idx / total
	var angle       = my_angle + slot_offset * 0.4

	# Radio que crece con la cantidad de enemigos pero nunca supera attack_range
	var min_r = total * 1.0 / PI
	var r     = clamp(min_r, attack_range * 0.5, attack_range * 0.92)

	return player.global_position + Vector3(sin(angle) * r, 0.0, cos(angle) * r)

func _enemy_separation_force() -> Vector3:
	var force      = Vector3.ZERO
	var sep_radius = 2.8
	for e in get_tree().get_nodes_in_group("enemy"):
		if e == self:
			continue
		var diff = global_position - e.global_position
		diff.y   = 0.0
		var d    = diff.length()
		if d < sep_radius and d > 0.01:
			force += diff.normalized() * (1.0 - d / sep_radius)
	return force * 1.8

func _do_attack():
	player.take_damage(attack_damage)

func take_damage(amount: float):
	# En multijugador: clientes redirigen el daño al host
	if NetworkManager.multiplayer_mode and not is_multiplayer_authority():
		_take_damage_rpc.rpc_id(1, amount)
		return
	last_attacker_id = multiplayer.get_unique_id() if NetworkManager.multiplayer_mode else 1
	current_hp = clamp(current_hp - amount, 0, max_hp)
	if current_hp <= 0:
		_die()

@rpc("any_peer", "reliable")
func _take_damage_rpc(amount: float):
	# No llamar take_damage() para no pisar last_attacker_id
	last_attacker_id = multiplayer.get_remote_sender_id()
	current_hp = clamp(current_hp - amount, 0, max_hp)
	if current_hp <= 0:
		_die()

func configure(hp_mult: float, speed_mult: float) -> void:
	max_hp     = max_hp * hp_mult
	speed      = speed  * speed_mult
	current_hp = max_hp

func _die():
	var killer_id = last_attacker_id
	emit_signal("died", killer_id)
	for wm in get_tree().get_nodes_in_group("wave_manager"):
		wm.on_any_enemy_killed(killer_id)
	if NetworkManager.multiplayer_mode:
		_rpc_die.rpc(killer_id)
	# Solo dar XP al asesino
	if not NetworkManager.multiplayer_mode or killer_id == multiplayer.get_unique_id():
		if player and player.has_method("add_experience"):
			player.add_experience(xp_reward)
	queue_free()

@rpc("authority", "reliable")
func _rpc_die(killer_id: int):
	# Solo dar XP si este peer fue el asesino
	if killer_id == multiplayer.get_unique_id():
		if player and player.has_method("add_experience"):
			player.add_experience(xp_reward)
	queue_free()

func apply_knockback(impulse: Vector3):
	# En multijugador: clientes redirigen el knockback al host
	if NetworkManager.multiplayer_mode and not is_multiplayer_authority():
		_apply_knockback_rpc.rpc_id(1, impulse)
		return
	knockback_velocity = impulse

@rpc("any_peer", "reliable")
func _apply_knockback_rpc(impulse: Vector3):
	knockback_velocity = impulse

# --- HP Bar 3D ---

func _create_hp_bar():
	var bar_root = Node3D.new()
	bar_root.name = "HPBar"
	bar_root.top_level = true
	add_child(bar_root)

	var bg = MeshInstance3D.new()
	var bg_mesh = BoxMesh.new()
	bg_mesh.size = Vector3(1.0, 0.12, 0.01)
	bg.mesh = bg_mesh
	var bg_mat = StandardMaterial3D.new()
	bg_mat.albedo_color = Color(0.15, 0.15, 0.15)
	bg_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bg.material_override = bg_mat
	bar_root.add_child(bg)

	hp_fill = MeshInstance3D.new()
	var fill_mesh = BoxMesh.new()
	fill_mesh.size = Vector3(1.0, 0.12, 0.01)
	hp_fill.mesh = fill_mesh
	hp_fill.position.z = -0.006
	var fill_mat = StandardMaterial3D.new()
	fill_mat.albedo_color = Color(0.2, 0.9, 0.2)
	fill_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hp_fill.material_override = fill_mat
	bar_root.add_child(hp_fill)

func _update_hp_bar():
	if hp_fill == null:
		return
	var pct = current_hp / max_hp
	hp_fill.scale.x = pct
	hp_fill.position.x = (pct - 1.0) * 0.5
	$HPBar.global_position = global_position + Vector3(0, hp_bar_height, 0)
	var cam = get_viewport().get_camera_3d()
	if cam:
		var cam_flat = Vector3(cam.global_position.x, $HPBar.global_position.y, cam.global_position.z)
		var to_cam = cam_flat - $HPBar.global_position
		if to_cam.length() > 0.01:
			$HPBar.look_at(cam_flat, Vector3.UP)
