class_name BaseEnemy
extends CharacterBody3D

## Clase base para todos los enemigos.
## Cada tipo de enemigo hereda de acá y sobreescribe lo que necesite.

signal died(killer_id: int)

const GRAVITY = -20.0
## Por debajo de esta altura el enemigo se considera caído del mapa y se descarta.
const VOID_Y  = -30.0

@export var max_hp:        float = 5.0
@export var speed:         float = 3.5
@export var detection_range: float = 10.0
@export var attack_range:  float = 1.5
@export var attack_damage: float = 1.0
@export var attack_cooldown: float = 1.5
@export var xp_reward:     int   = 10

## Multiplicador del feedback de impacto (números, flash, estallido, hitstop).
## Los bosses lo suben para que pegarles se sienta distinto a pegarle a un trash mob.
@export var feedback_scale: float = 1.0
## Color del número de daño flotante.
@export var damage_number_color: Color = Color(1.0, 0.95, 0.6)
## Color del estallido al morir.
@export var death_burst_color: Color = Color(0.8, 0.15, 0.12)
## 0 = el knockback lo mueve entero, 1 = inamovible. Los bosses van alto:
## un jefe que sale volando de un espadazo deja de dar miedo.
@export_range(0.0, 1.0) var knockback_resistance: float = 0.0
## Resistencia a que lo corran de lugar caminándole encima. 0 = se empuja como
## una caja, 1 = plantado. Es distinto de `knockback_resistance`: eso frena el
## impulso de un golpe, esto frena el empujón físico de un cuerpo contra otro.
@export_range(0.0, 1.0) var push_resistance: float = 0.0

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
## Separación entre la cabeza del modelo y la barra, en metros. La altura de la
## cabeza se mide sola del AABB, así que este número NO hay que retocarlo al
## cambiar `body_scale`: un valor chico sirve para un goblin y para un boss.
@export var hp_bar_height: float = 0.5
var _alto_cabeza_cache: float = 0.0
## Escala de la barra de HP en unidades de mundo (la barra es top_level, así que
## NO hereda el `scale` del enemigo: un boss grande necesita subirla a mano).
@export var hp_bar_scale: float = 1.0

enum State { IDLE, PATROL, CHASE, APPROACH }
var state = State.IDLE

@export var approach_speed_mult: float = 2.5
@export var approach_distance:   float = 30.0

## Velocidad de giro, en radianes por segundo aproximados. Los bosses grandes van
## bajo (4–6): un jefe pesado que gira como un trompo no se lee como pesado, y
## además vuelve inútil rodearlo.
@export var turn_speed: float = 10.0
## Segundos que lleva con el ataque listo sin poder encarar. Acelera el giro.
var _espera_de_giro: float = 0.0

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
	for nodo in find_children("*", "MeshInstance3D", true, false):
		var m := nodo as MeshInstance3D
		# La barra de HP es UI flotante: nada de sombras ni de iluminación global.
		if m == null or m.is_in_group("hp_bar_part"):
			continue
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


## Las subclases con animaciones lo sobreescriben. Mientras es true, el enemigo
## está comprometido con su animación de ataque y NO puede reorientarse.
func esta_atacando() -> bool:
	return false


## ¿Tiene el objetivo lo bastante al frente como para arrancar un ataque? Las
## subclases cuerpo a cuerpo lo atan a su cono de golpe, para no lanzar golpes
## que ya se sabe que van a fallar. Por defecto, cualquier dirección sirve.
func _tiene_de_frente(_dir: Vector3) -> bool:
	return true


## Gira hacia una dirección de forma gradual. Reemplaza al `rotation.y = atan2()`
## directo, que producía giros instantáneos de 180 grados — y peor, permitía que
## el enemigo se diera vuelta en pleno wind-up, anulando la ventana de esquive.
func _girar_hacia(dir: Vector3, delta: float, urgencia: float = 1.0) -> void:
	if esta_atacando() or dir.length() < 0.01:
		return
	var objetivo := atan2(dir.x, dir.z)
	rotation.y = lerp_angle(rotation.y, objetivo, minf(1.0, delta * turn_speed * urgencia))

func set_patrol_area(center: Vector3, size: Vector2):
	spawn_position = center
	patrol_size    = size
	patrol_target  = _pick_patrol_target()

func _physics_process(delta: float):
	# Clientes: solo interpolar posición recibida del host
	if NetworkManager.multiplayer_mode and not is_multiplayer_authority():
		global_position = global_position.lerp(_remote_pos, delta * 15.0)
		rotation.y      = lerp_angle(rotation.y, _remote_rot_y, delta * 15.0)
		_update_hp_bar()
		return

	# Red de seguridad: si se cayó del mapa, se descarta. Sin esto queda cayendo
	# para siempre, sigue contando en el grupo "enemy" y ahoga al spawner, que
	# nunca vuelve a llegar por debajo de su tope de vivos.
	if global_position.y < VOID_Y:
		_despawn_por_caida()
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
			_move_to_patrol_target(delta)
		State.CHASE:
			_chase_and_attack(delta)
		State.APPROACH:
			_approach_to_player(delta)

	if knockback_velocity.length() > 0.1:
		velocity.x = knockback_velocity.x
		velocity.z = knockback_velocity.z
		knockback_velocity = knockback_velocity.lerp(Vector3.ZERO, delta * 8.0)
	else:
		knockback_velocity = Vector3.ZERO

	var _pos_previa := global_position
	if state != State.IDLE or not is_on_floor() or knockback_velocity.length() > 0.1:
		move_and_slide()

	# Anti-empujón: descuenta el desplazamiento que NO vino de su propia velocidad.
	# `move_and_slide()` resuelve la penetración con el jugador corriéndolo de
	# lugar, así que sin esto a un boss lo movés de a metros caminándole encima.
	if push_resistance > 0.0:
		var esperado: Vector3 = Vector3(velocity.x, 0.0, velocity.z) * delta
		var real:     Vector3 = global_position - _pos_previa
		real.y = 0.0
		var exceso: Vector3 = real - esperado
		if exceso.length() > 0.0005:
			global_position -= exceso * push_resistance

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

func _move_to_patrol_target(delta: float):
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
	_girar_hacia(dir, delta)

func _approach_to_player(delta: float):
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
	_girar_hacia(dir, delta)

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

func _chase_and_attack(delta: float):
	if player == null:
		return

	# Comprometido con la animación: no persigue ni se reorienta. Sin esto, si te
	# alejás durante el wind-up el enemigo sale a perseguirte con la animación
	# corriendo y se ve como si patinara.
	if esta_atacando():
		velocity.x = 0.0
		velocity.z = 0.0
		return

	var dist = global_position.distance_to(player.global_position)

	if dist < attack_range:
		velocity.x = 0
		velocity.z = 0

		# Reorientarse ENTRE golpes. `_girar_hacia` no hace nada mientras dura la
		# animación, así que el enemigo se compromete a cada ataque pero después
		# vuelve a buscarte. Sin esto se queda pegándole al aire para siempre.
		var hacia := player.global_position - global_position
		hacia.y = 0.0

		# Con el ataque listo pero sin poder encarar, va girando cada vez más
		# decidido. Sin esta válvula, un jugador orbitando lo deja dando vueltas
		# para siempre sin lanzar un solo golpe.
		var urgencia := 1.0
		if attack_timer <= 0.0 and not esta_atacando():
			_espera_de_giro += delta
			urgencia = 1.0 + minf(_espera_de_giro * 1.5, 2.5)
		else:
			_espera_de_giro = 0.0

		_girar_hacia(hacia, delta, urgencia)

		# Y no arranca un golpe si todavía no te encaró: primero gira, después pega.
		if attack_timer <= 0.0 and not esta_atacando() and _tiene_de_frente(hacia):
			attack_timer    = attack_cooldown
			_espera_de_giro = 0.0
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
	_girar_hacia(dir, delta)

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
	_damage_player(player, attack_damage)


## El HP de cada jugador lo lleva su propio dueno. La IA del enemigo corre solo
## en el host, asi que si le pega a la copia local de un jugador remoto el golpe
## se pierde: el proximo `_sync_state` del dueno pisa el HP y el cliente nunca
## ve el dano. Todo dano a un jugador pasa por aca.
func _damage_player(target: Node, amount: float) -> void:
	if target == null or not is_instance_valid(target):
		return
	var owner_id := target.get_multiplayer_authority()
	if NetworkManager.multiplayer_mode and owner_id != multiplayer.get_unique_id():
		target.take_damage_rpc.rpc_id(owner_id, amount)
	else:
		target.take_damage(amount)

func take_damage(amount: float):
	# El feedback va ANTES del redirect a red: quien pega tiene que ver el golpe
	# en su propia pantalla sin esperar el round-trip al host.
	_play_hit_feedback(amount)
	# En multijugador: clientes redirigen el daño al host
	if NetworkManager.multiplayer_mode and not is_multiplayer_authority():
		_take_damage_rpc.rpc_id(1, amount)
		return
	last_attacker_id = multiplayer.get_unique_id() if NetworkManager.multiplayer_mode else 1
	_apply_damage(amount)

@rpc("any_peer", "reliable")
func _take_damage_rpc(amount: float):
	# No llamar take_damage() para no pisar last_attacker_id
	last_attacker_id = multiplayer.get_remote_sender_id()
	_play_hit_feedback(amount)
	_apply_damage(amount)

## Punto único donde el HP baja. Todo lo que quita vida pasa por acá.
func _apply_damage(amount: float) -> void:
	current_hp = clamp(current_hp - amount, 0, max_hp)
	_on_damaged(amount)
	if current_hp <= 0:
		_die()

## Hook para subclases: fases de boss, enrage, gritos al ser golpeado.
func _on_damaged(_amount: float) -> void:
	pass

func _play_hit_feedback(amount: float) -> void:
	var top := global_position + Vector3(0.0, hp_bar_height * 0.85, 0.0)
	CombatFeedback.flash(self)
	CombatFeedback.damage_number(top, amount, damage_number_color, feedback_scale)
	CombatFeedback.hitstop(feedback_scale)

func _play_death_feedback() -> void:
	var center := global_position + Vector3(0.0, hp_bar_height * 0.5, 0.0)
	CombatFeedback.death_burst(center, feedback_scale, death_burst_color)
	CombatFeedback.hitstop(feedback_scale * 1.8)

## Radio horizontal del cuerpo, ya escalado por `body_scale`. Quien ataca lo suma
## a su propio alcance: sin esto, un enemigo grande es imposible de golpear porque
## la distancia se mide contra su CENTRO y el cuerpo ocupa casi todo el rango.
func radio_cuerpo() -> float:
	for hijo in get_children():
		var c := hijo as CollisionShape3D
		if c == null or c.shape == null:
			continue
		var forma: Shape3D = c.shape
		if forma is CapsuleShape3D:
			return (forma as CapsuleShape3D).radius * scale.x
		if forma is SphereShape3D:
			return (forma as SphereShape3D).radius * scale.x
		if forma is BoxShape3D:
			var medidas: Vector3 = (forma as BoxShape3D).size
			return maxf(medidas.x, medidas.z) * 0.5 * scale.x
	return 0.4 * scale.x


func configure(hp_mult: float, speed_mult: float) -> void:
	max_hp     = max_hp * hp_mult
	speed      = speed  * speed_mult
	current_hp = max_hp

## Se cayó del mundo. No es una muerte: no hay feedback, no da XP y no suma a
## las bajas del jugador. Solo libera el cupo que ocupaba en el spawner.
func _despawn_por_caida() -> void:
	emit_signal("died", 0)
	if NetworkManager.multiplayer_mode and is_multiplayer_authority():
		_rpc_die.rpc(0)
	queue_free()


func _die():
	_play_death_feedback()
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
	_play_death_feedback()
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
	knockback_velocity = impulse * (1.0 - knockback_resistance)

@rpc("any_peer", "reliable")
func _apply_knockback_rpc(impulse: Vector3):
	knockback_velocity = impulse * (1.0 - knockback_resistance)

# --- HP Bar 3D ---

func _create_hp_bar():
	var bar_root = Node3D.new()
	bar_root.name = "HPBar"
	bar_root.top_level = true
	bar_root.scale = Vector3(hp_bar_scale, hp_bar_scale, hp_bar_scale)
	add_child(bar_root)

	var bg = MeshInstance3D.new()
	var bg_mesh = BoxMesh.new()
	bg_mesh.size = Vector3(1.0, 0.12, 0.01)
	bg.mesh = bg_mesh
	var bg_mat = StandardMaterial3D.new()
	bg_mat.albedo_color = Color(0.15, 0.15, 0.15)
	bg_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bg.material_override = bg_mat
	# La barra es UI flotante: no debe proyectar sombra ni recibirla.
	bg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	bg.add_to_group("hp_bar_part")
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
	hp_fill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	hp_fill.add_to_group("hp_bar_part")
	bar_root.add_child(hp_fill)

func _update_hp_bar():
	if hp_fill == null:
		return
	var pct = current_hp / max_hp
	hp_fill.scale.x = pct
	hp_fill.position.x = (pct - 1.0) * 0.5

	var barra: Node3D = $HPBar
	barra.global_position = global_position + Vector3(0, _alto_cabeza() + hp_bar_height, 0)

	var cam = get_viewport().get_camera_3d()
	if cam:
		var cam_flat = Vector3(cam.global_position.x, barra.global_position.y, cam.global_position.z)
		if (cam_flat - barra.global_position).length() > 0.01:
			barra.look_at(cam_flat, Vector3.UP)
			# look_at() reconstruye la basis normalizada y se come la escala.
			# Hay que reponerla o la barra vuelve a tamaño 1 en el primer frame.
			barra.scale = Vector3(hp_bar_scale, hp_bar_scale, hp_bar_scale)


## Altura de la cabeza en metros, medida del modelo real y ya escalada. Se calcula
## una sola vez: así la barra queda bien puesta con cualquier `body_scale` sin
## tener que retocar números a mano cada vez que se agranda un enemigo.
func _alto_cabeza() -> float:
	if _alto_cabeza_cache > 0.0:
		return _alto_cabeza_cache

	# Se mide contra la CÁPSULA DE COLISIÓN, no contra el AABB de las mallas.
	#
	# El AABB de un mesh con skeleton no es estable: una animación que estire un
	# brazo lo expande, y como el recurso Mesh es COMPARTIDO entre instancias, ese
	# valor inflado se lo comen todos los enemigos que spawneen después. Pasó: un
	# golpe de la E dejó la barra por las nubes para todos los goblins siguientes.
	#
	# La cápsula es geometría fija y conocida, así que da siempre lo mismo.
	var alto := 1.8
	for hijo in get_children():
		var c := hijo as CollisionShape3D
		if c == null or c.shape == null:
			continue
		var forma: Shape3D = c.shape
		if forma is CapsuleShape3D:
			alto = (forma as CapsuleShape3D).height
			break
		if forma is BoxShape3D:
			alto = (forma as BoxShape3D).size.y
			break

	_alto_cabeza_cache = alto * maxf(scale.y, 0.01)
	return _alto_cabeza_cache
