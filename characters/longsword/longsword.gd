extends CharacterBody3D

const RUN_MULTIPLIER  = 1.114  # RUN_SPEED / WALK_SPEED, reducido 20% de 1.393
const GRAVITY         = -20.0
const STOP_DISTANCE   = 0.25
const IDLE_DELAY      = 0.15
const ATTACK_SPEED    = 1.5
const TILE_SIZE       = 1.5

# Multiplicadores de skills (sobre stats.attack)
const Q_MULTIPLIER    = 15.0
const Q_CD            = 6.0
const W_DURATION      = 4.0
const W_CD            = 10.0
const E_MULTIPLIER    = 12.0
const E_CD            = 7.0
const E_DISTANCE      = 9.6
const E_DASH_DURATION = 0.68

const STAMINA_DRAIN    = 10.0
const STAMINA_REGEN    = 100.0
const STAMINA_REGEN_CD = 5.0
const HP_REGEN         = 1.0
const HP_REGEN_CD      = 5.0
const MANA_REGEN       = 5.0
const MANA_REGEN_CD    = 2.0

# --- Feedback de golpe recibido ---
## Altura del numero de danio sobre el pivote. El personaje esta sobredimensionado
## (ver CLAUDE.md), por eso 3.0 y no la altura nominal de la capsula.
const DMG_NUMBER_HEIGHT := 3.0
const DMG_NUMBER_COLOR  := Color(1.0, 0.35, 0.30)
## Con cuanto danio de un solo golpe la vinieta llega al maximo, como fraccion
## del HP total. Un cuarto de la vida de una = pantalla roja del todo.
const HIT_FULL_FRACTION := 0.25

@export var stats: CharacterStats

var current_hp:      float
var current_stamina: float
var current_mana:    float

var target_pos:   Vector3
var moving:       bool = false
var idle_timer:   float = 0.0
var current_anim: String = ""
var attacking:    bool = false
var is_running:   bool = false

signal hp_changed(current: float, maximum: float)
signal stamina_changed(current: float, maximum: float)
signal mana_changed(current: float, maximum: float)
signal xp_changed(current: int, maximum: int)
signal attack_finished
signal skill_changed(skill: String, cd_remaining: float, cd_max: float)
signal skill_charged(skill: String, is_charged: bool)
signal leveled_up(new_level: int)

@onready var nav_agent:  NavigationAgent3D = $NavigationAgent3D
@onready var idle_node:  Node3D = $Idle
@onready var walk_node:  Node3D = $Walking
@onready var run_node:   Node3D = $Running
@onready var slash_node: Node3D = $Slash
@onready var jump_node:  Node3D = $JumpAttack

var idle_anim:  AnimationPlayer = null
var walk_anim:  AnimationPlayer = null
var run_anim:   AnimationPlayer = null
var slash_anim: AnimationPlayer = null
var jump_anim:  AnimationPlayer = null

var dust_particles: CPUParticles3D = null

var _prev_xz:       Vector2 = Vector2.ZERO
var _stuck_timer:   float   = 0.0
const STUCK_TIME:   float   = 0.35

var attack_target_ref:   Node3D = null
var last_attack_target:  Node3D = null
var stamina_regen_timer: float  = 0.0
var hp_regen_timer:      float  = 0.0
var mana_regen_timer:    float  = 0.0

var q_timer:          float = 0.0
var q_charged:        bool  = false
var w_timer:          float = 0.0
var e_charges:        int   = 2
var e_recharge_timer: float = 0.0
var shield_active:    bool  = false
var shield_timer:     float = 0.0

const E_MAX_CHARGES = 2

var e_dashing:      bool    = false
var e_dash_start:   Vector3 = Vector3.ZERO
var e_dash_end:     Vector3 = Vector3.ZERO
var e_dash_elapsed: float   = 0.0
var e_dash_duration:float   = 1.0
var e_hit_set:      Array   = []

var _sync_timer:   float   = 0.0
const _SYNC_RATE:  float   = 0.05
var _remote_pos:   Vector3 = Vector3.ZERO
var _remote_rot_y: float   = 0.0


var dead:           bool    = false
var respawn_timer:  float   = 0.0
const RESPAWN_TIME: float   = 3.0
var spawn_position: Vector3 = Vector3.ZERO
var last_safe_pos:  Vector3 = Vector3.ZERO

func _ready():
	scale = Vector3(2.0, 2.0, 2.0)

	for node in [idle_node, walk_node, run_node, slash_node, jump_node]:
		for mesh in node.find_children("*", "MeshInstance3D", true, false):
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			mesh.gi_mode     = GeometryInstance3D.GI_MODE_DYNAMIC

	idle_anim  = idle_node.find_child("AnimationPlayer", true, false)
	walk_anim  = walk_node.find_child("AnimationPlayer", true, false)
	run_anim   = run_node.find_child("AnimationPlayer", true, false)
	slash_anim = slash_node.find_child("AnimationPlayer", true, false)
	jump_anim  = jump_node.find_child("AnimationPlayer", true, false)

	_force_loop(idle_anim)
	_force_loop(walk_anim)
	_force_loop(run_anim)

	if not stats:
		stats = CharacterStats.new()

	current_hp      = stats.max_hp
	current_stamina = stats.max_stamina
	current_mana    = stats.max_mana

	nav_agent.path_desired_distance  = 0.3
	nav_agent.target_desired_distance = STOP_DISTANCE

	# Loop mode y root motion aplican a todos (local y remoto)
	if slash_anim:
		for n in slash_anim.get_animation_list():
			slash_anim.get_animation(n).loop_mode = Animation.LOOP_NONE

	if jump_anim:
		for n in jump_anim.get_animation_list():
			jump_anim.get_animation(n).loop_mode = Animation.LOOP_NONE
		_fix_root_motion(jump_anim)

	if not is_multiplayer_authority():
		_set_state("idle")
		return

	_setup_dust_particles()

	if slash_anim:
		slash_anim.animation_finished.connect(_on_slash_finished)

	if jump_anim:
		jump_anim.animation_finished.connect(_on_jump_finished)

	_set_state("idle")

func _force_loop(ap: AnimationPlayer):
	if not ap:
		return
	for n in ap.get_animation_list():
		ap.get_animation(n).loop_mode = Animation.LOOP_LINEAR

func _set_state(state: String):
	if current_anim == state:
		# One-shots terminados: permitir replay (necesario en clientes remotos)
		var finished = (state == "slash" and slash_anim and not slash_anim.is_playing()) \
					or (state == "jump"  and jump_anim  and not jump_anim.is_playing())
		if not finished:
			return
	current_anim = state
	idle_node.visible  = false
	walk_node.visible  = false
	run_node.visible   = false
	slash_node.visible = false
	jump_node.visible  = false
	match state:
		"walk":
			walk_node.visible = true
			if walk_anim and not walk_anim.is_playing():
				walk_anim.play(walk_anim.get_animation_list()[0])
		"run":
			run_node.visible = true
			if run_anim and not run_anim.is_playing():
				run_anim.play(run_anim.get_animation_list()[0])
		"slash":
			attacking = true
			slash_node.visible = true
			if slash_anim:
				slash_anim.play(slash_anim.get_animation_list()[0], -1, ATTACK_SPEED)
		"jump":
			attacking = true
			jump_node.visible = true
			if jump_anim:
				var jname  = jump_anim.get_animation_list()[0]
				var jspeed = jump_anim.get_animation(jname).length / E_DASH_DURATION
				jump_anim.play(jname, -1, jspeed)
		_:
			idle_node.visible = true
			if idle_anim and not idle_anim.is_playing():
				idle_anim.play(idle_anim.get_animation_list()[0])

func _physics_process(delta):
	if not is_multiplayer_authority():
		global_position = global_position.lerp(_remote_pos, delta * 20.0)
		rotation.y      = lerp_angle(rotation.y, _remote_rot_y, delta * 20.0)
		return

	if dead:
		respawn_timer -= delta
		if respawn_timer <= 0.0:
			_respawn()
		return

	if not is_on_floor():
		velocity.y += GRAVITY * delta
	else:
		velocity.y = 0.0
		last_safe_pos = global_position

	_tick_cooldowns(delta)
	_tick_sync(delta)

	if attacking:
		if e_dashing:
			e_dash_elapsed = min(e_dash_elapsed + delta, e_dash_duration)
			var t = e_dash_elapsed / e_dash_duration
			global_position.x = lerp(e_dash_start.x, e_dash_end.x, t)
			global_position.z = lerp(e_dash_start.z, e_dash_end.z, t)
			velocity.x = 0.0
			velocity.z = 0.0
			move_and_slide()
			_check_dash_hits()
		else:
			velocity.x = 0
			velocity.z = 0
			move_and_slide()
		return

	var shift = Input.is_action_pressed("shift_run")
	if moving and shift and current_stamina > 0:
		is_running = true
		current_stamina = max(0, current_stamina - STAMINA_DRAIN * delta)
		stamina_regen_timer = STAMINA_REGEN_CD
	else:
		is_running = false
		stamina_regen_timer -= delta
		if stamina_regen_timer <= 0.0 and current_stamina < stats.max_stamina:
			current_stamina = min(stats.max_stamina, current_stamina + STAMINA_REGEN)
			stamina_regen_timer = STAMINA_REGEN_CD
	stamina_changed.emit(current_stamina, stats.max_stamina)
	if dust_particles:
		dust_particles.emitting = is_running and moving

	var walk_speed = stats.speed
	var speed      = walk_speed * RUN_MULTIPLIER if is_running else walk_speed

	if moving:
		idle_timer = IDLE_DELAY
		var flat_self   = Vector3(global_position.x, 0.0, global_position.z)
		var flat_target = Vector3(target_pos.x, 0.0, target_pos.z)
		var to_target   = flat_target - flat_self
		if to_target.length() < STOP_DISTANCE:
			moving = false
			velocity.x = 0
			velocity.z = 0
		else:
			# Usá el path del nav_agent si hay uno válido; si no, va directo
			var next_pos = nav_agent.get_next_path_position()
			var to_next  = Vector3(next_pos.x - global_position.x, 0.0, next_pos.z - global_position.z)
			var dir      = to_next.normalized() if to_next.length() > 0.4 else to_target.normalized()
			velocity.x = dir.x * speed
			velocity.z = dir.z * speed
			rotation.y = atan2(dir.x, dir.z)
		_set_state("run" if is_running else "walk")
	else:
		velocity.x = 0
		velocity.z = 0
		idle_timer -= delta
		if idle_timer <= 0.0:
			_set_state("idle")

	move_and_slide()

	# Si el player intenta moverse pero físicamente no avanza, cancelar
	if moving and not attacking:
		var cur_xz = Vector2(global_position.x, global_position.z)
		if cur_xz.distance_to(_prev_xz) < delta * 0.5:
			_stuck_timer += delta
			if _stuck_timer >= STUCK_TIME:
				moving        = false
				_stuck_timer  = 0.0
		else:
			_stuck_timer = 0.0
		_prev_xz = cur_xz

	_regen_hp(delta)
	_regen_mana(delta)

func _check_dash_hits():
	var targets = get_tree().get_nodes_in_group("enemy") + get_tree().get_nodes_in_group("player_remote")
	for target in targets:
		if target in e_hit_set:
			continue
		var dist = global_position.distance_to(target.global_position)
		if dist < 1.8:
			e_hit_set.append(target)
			var dmg = stats.attack * E_MULTIPLIER
			if target.is_in_group("enemy"):
				target.take_damage(dmg)
				var push_dir = target.global_position - global_position
				push_dir.y = 0
				if push_dir.length() > 0.01:
					push_dir = push_dir.normalized()
				else:
					push_dir = Vector3(sin(rotation.y), 0, cos(rotation.y))
				target.apply_knockback(push_dir * 10.0)
			else:
				target.take_damage_rpc.rpc_id(target.get_multiplayer_authority(), dmg)

func _snap_to_tile(pos: Vector3) -> Vector3:
	return Vector3(
		floor(pos.x / TILE_SIZE + 0.5) * TILE_SIZE,
		pos.y,
		floor(pos.z / TILE_SIZE + 0.5) * TILE_SIZE
	)

func move_to(pos: Vector3):
	if e_dashing:
		return
	target_pos = _snap_to_tile(pos)
	nav_agent.target_position = target_pos
	moving       = true
	_stuck_timer = 0.0
	if attacking:
		_cancel_attack()

func stop():
	moving = false
	velocity.x = 0
	velocity.z = 0

func face_toward(pos: Vector3):
	var dir = Vector3(pos.x - global_position.x, 0.0, pos.z - global_position.z)
	if dir.length() > 0.1:
		rotation.y = atan2(dir.x, dir.z)

func attack_target(target: Node3D):
	if attacking:
		return
	moving = false
	attack_target_ref  = target
	last_attack_target = target
	var dir = (target.global_position - global_position)
	dir.y = 0
	if dir.length() > 0.01:
		rotation.y = atan2(dir.x, dir.z)
	_set_state("slash")
	var hit_pct = 0.15 if q_charged else 0.5
	var duration = slash_anim.get_animation(slash_anim.get_animation_list()[0]).length
	get_tree().create_timer(duration * hit_pct / ATTACK_SPEED).timeout.connect(_apply_attack_damage)

func _apply_attack_damage():
	if attack_target_ref and is_instance_valid(attack_target_ref):
		var dmg = stats.attack * Q_MULTIPLIER if q_charged else stats.attack * 10.0
		if attack_target_ref.is_in_group("enemy"):
			attack_target_ref.take_damage(dmg)
		else:
			attack_target_ref.take_damage_rpc.rpc_id(
				attack_target_ref.get_multiplayer_authority(), dmg)
		if q_charged:
			q_charged = false
			skill_charged.emit("q", false)
	attack_target_ref = null

func _cancel_attack():
	attacking      = false
	e_dashing      = false
	e_dash_elapsed = 0.0
	attack_target_ref = null
	if slash_anim and slash_anim.is_playing():
		slash_anim.stop()
	if jump_anim and jump_anim.is_playing():
		jump_anim.stop()
	slash_node.visible = false
	jump_node.visible  = false
	current_anim = ""

func _on_slash_finished(_anim_name: String):
	attacking = false
	_set_state("idle")
	attack_finished.emit()

func _on_jump_finished(_anim_name: String):
	global_position = Vector3(e_dash_end.x, global_position.y, e_dash_end.z)
	attacking  = false
	e_dashing  = false
	e_hit_set.clear()
	_set_state("idle")

func _regen_hp(delta: float):
	if current_hp >= stats.max_hp:
		return
	hp_regen_timer -= delta
	if hp_regen_timer <= 0.0:
		current_hp     = min(stats.max_hp, current_hp + HP_REGEN)
		hp_regen_timer = HP_REGEN_CD
		hp_changed.emit(current_hp, stats.max_hp)

func _regen_mana(delta: float):
	if current_mana >= stats.max_mana:
		return
	mana_regen_timer -= delta
	if mana_regen_timer <= 0.0:
		current_mana     = min(stats.max_mana, current_mana + MANA_REGEN)
		mana_regen_timer = MANA_REGEN_CD
		mana_changed.emit(current_mana, stats.max_mana)

func take_damage(amount: float):
	if shield_active or dead:
		return
	var actual = max(0.0, amount - stats.defense)
	current_hp = clamp(current_hp - actual, 0, stats.max_hp)
	hp_regen_timer = HP_REGEN_CD
	hp_changed.emit(current_hp, stats.max_hp)
	_feedback_hit(actual)
	if NetworkManager.multiplayer_mode:
		_rpc_hit_feedback.rpc(actual)
	if current_hp <= 0:
		_die()

## Feedback visual de un golpe recibido.
##
## Con los enemigos, todos los peers ven el golpe y cada uno genera su propio
## feedback. Con los jugadores no se puede: el danio viaja por
## `take_damage_rpc.rpc_id(dueno)`, asi que la victima es el UNICO peer que se
## entera —y ademas es el unico que conoce el danio real, con defensa y escudo
## ya aplicados. Por eso acá la victima dispara el suyo y lo replica al resto.
##
## El costo es medio viaje de red antes de que el que pega vea el impacto. En
## LAN es imperceptible; si con gente lejos se nota, la alternativa es que el
## atacante prediga el flash al pegar y la victima no lo re-emita hacia el.
func _feedback_hit(actual: float) -> void:
	if actual <= 0.0:
		return
	CombatFeedback.flash(self)
	CombatFeedback.damage_number(
		global_position + Vector3.UP * DMG_NUMBER_HEIGHT, actual, DMG_NUMBER_COLOR)

	# La pantalla solo se tiñe para el que se esta comiendo el golpe. Un golpe a
	# otro jugador no te enrojece la tuya.
	if not is_multiplayer_authority():
		return
	var techo := maxf(1.0, stats.max_hp * HIT_FULL_FRACTION)
	var fuerza := clampf(actual / techo, 0.40, 1.0)
	CombatFeedback.screen_flash(fuerza)
	CombatFeedback.camera_shake(0.035 + 0.075 * fuerza)
	CombatFeedback.hitstop(0.8)

## Unreliable a proposito: es puro adorno. Si se pierde un paquete se pierde un
## flash, y es preferible a competirle ancho de banda al danio, que si es fiable.
@rpc("any_peer", "unreliable")
func _rpc_hit_feedback(actual: float) -> void:
	_feedback_hit(actual)

func add_experience(amount: int):
	if not stats:
		return
	var did_level_up = stats.add_experience(amount)
	xp_changed.emit(stats.experience, stats.xp_to_next_level())
	if did_level_up:
		current_hp      = min(current_hp, stats.max_hp)
		current_stamina = min(current_stamina, stats.max_stamina)
		leveled_up.emit(stats.level)
		hp_changed.emit(current_hp, stats.max_hp)
		stamina_changed.emit(current_stamina, stats.max_stamina)
		_show_levelup_text()
		if NetworkManager.multiplayer_mode:
			_rpc_show_levelup.rpc()

@rpc("authority", "reliable")
func _rpc_show_levelup():
	_show_levelup_text()

func _show_levelup_text():
	var label = Label3D.new()
	label.text             = "Level UP!"
	label.font_size        = 160
	label.modulate         = Color(1.0, 0.88, 0.0, 1.0)
	label.billboard        = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test    = true
	label.outline_size     = 14
	label.outline_modulate = Color(0.0, 0.0, 0.0, 1.0)
	# Hijo del player para seguirlo; scale 0.5 cancela el 2x del player
	label.scale    = Vector3(0.5, 0.5, 0.5)
	label.position = Vector3(0, 2.0, 0)  # 2 unidades locales = 4 world units sobre los pies
	add_child(label)

	var tween = label.create_tween().set_parallel(true)
	# Animar en espacio local: sube 1 unidad local (= 2 world units)
	tween.tween_property(label, "position:y", 3.0, 1.4)
	tween.tween_property(label, "modulate:a", 0.0, 1.4).set_delay(0.4)
	tween.finished.connect(label.queue_free)

func _die():
	dead      = true
	moving    = false
	attacking = false
	velocity  = Vector3.ZERO
	respawn_timer = RESPAWN_TIME
	visible   = false
	_feedback_muerte()
	if NetworkManager.multiplayer_mode:
		_rpc_die.rpc()

## El estallido lo ven todos: se dispara tanto en `_die()` (dueño) como en
## `_rpc_die()` (el resto), asi que no hace falta un RPC propio.
func _feedback_muerte() -> void:
	CombatFeedback.death_burst(
		global_position + Vector3.UP * 1.2, 1.3, Color(0.85, 0.2, 0.15))
	if is_multiplayer_authority():
		CombatFeedback.screen_flash(1.0)
		CombatFeedback.camera_shake(0.18, 0.30)

func _respawn():
	dead            = false
	current_hp      = stats.max_hp
	current_stamina = stats.max_stamina
	current_mana    = stats.max_mana
	hp_regen_timer  = 0.0
	mana_regen_timer = 0.0
	var pos = last_safe_pos if last_safe_pos != Vector3.ZERO else spawn_position
	global_position = pos + Vector3(0, 0.5, 0)
	visible         = true
	_set_state("idle")
	hp_changed.emit(current_hp, stats.max_hp)
	stamina_changed.emit(current_stamina, stats.max_stamina)
	mana_changed.emit(current_mana, stats.max_mana)
	if NetworkManager.multiplayer_mode:
		_rpc_respawn.rpc(global_position)

@rpc("any_peer", "reliable")
func _rpc_die():
	dead    = true
	_feedback_muerte()
	visible = false

@rpc("any_peer", "reliable")
func _rpc_respawn(pos: Vector3):
	dead            = false
	global_position = pos
	_remote_pos     = pos
	current_hp      = stats.max_hp
	visible         = true
	_set_state("idle")

func cast_q():
	if q_timer > 0 or q_charged:
		return
	q_charged = true
	q_timer   = Q_CD
	skill_charged.emit("q", true)
	skill_changed.emit("q", q_timer, Q_CD)
	if attacking and not e_dashing and last_attack_target and is_instance_valid(last_attack_target):
		_cancel_attack()
		attack_target(last_attack_target)

func cast_w():
	if w_timer > 0:
		return
	shield_active = true
	shield_timer  = W_DURATION
	w_timer       = W_CD
	skill_changed.emit("w", w_timer, W_CD)

func cast_e(cursor_world_pos: Vector3 = Vector3.ZERO):
	if e_charges <= 0 or attacking:
		return
	if not jump_anim:
		return
	var anim_name   = jump_anim.get_animation_list()[0]
	var anim_length = jump_anim.get_animation(anim_name).length
	var forward: Vector3
	if cursor_world_pos != Vector3.ZERO:
		var dir = cursor_world_pos - global_position
		dir.y = 0
		forward = dir.normalized() if dir.length() > 0.01 else Vector3(sin(rotation.y), 0, cos(rotation.y))
	else:
		forward = Vector3(sin(rotation.y), 0, cos(rotation.y))
	rotation.y   = atan2(forward.x, forward.z)
	e_dash_start = global_position
	e_dash_end   = global_position + forward * E_DISTANCE
	e_dash_duration  = E_DASH_DURATION
	e_dash_elapsed   = 0.0
	e_hit_set.clear()
	e_dashing        = true
	moving           = false
	_set_state("jump")
	jump_anim.play(anim_name, -1, anim_length / E_DASH_DURATION)
	e_charges -= 1
	if e_recharge_timer <= 0.0:
		e_recharge_timer = E_CD
	skill_changed.emit("e", e_recharge_timer if e_charges == 0 else 0.0, E_CD)

func _setup_dust_particles():
	dust_particles = CPUParticles3D.new()
	dust_particles.position     = Vector3(0, 0.05, 0)
	dust_particles.local_coords = false
	add_child(dust_particles)

	dust_particles.emitting             = false
	dust_particles.amount               = 20
	dust_particles.lifetime             = 0.7
	dust_particles.explosiveness        = 0.0
	dust_particles.randomness           = 0.7

	dust_particles.direction            = Vector3(0, 1, 0)
	dust_particles.spread               = 70.0
	dust_particles.gravity              = Vector3(0, -4.0, 0)
	dust_particles.initial_velocity_min = 1.5
	dust_particles.initial_velocity_max = 3.5
	dust_particles.scale_amount_min     = 0.2
	dust_particles.scale_amount_max     = 0.45
	dust_particles.damping_min          = 2.0
	dust_particles.damping_max          = 5.0

	var mat = StandardMaterial3D.new()
	mat.transparency               = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode               = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color               = Color(0.72, 0.54, 0.30, 1.0)

	var gradient = Gradient.new()
	gradient.set_color(0, Color(0.72, 0.54, 0.30, 0.85))
	gradient.set_color(1, Color(0.72, 0.54, 0.30, 0.0))
	dust_particles.color_ramp = gradient

	var mesh    = SphereMesh.new()
	mesh.radius = 0.12
	mesh.height = 0.24
	mesh.material = mat
	dust_particles.mesh = mesh

func _fix_root_motion(ap: AnimationPlayer):
	for anim_name in ap.get_animation_list():
		var anim = ap.get_animation(anim_name)
		for i in range(anim.get_track_count()):
			if anim.track_get_type(i) != Animation.TYPE_POSITION_3D:
				continue
			var path = str(anim.track_get_path(i))
			if "Hips" in path or "Hip" in path or "Root" in path or "root" in path:
				for j in range(anim.track_get_key_count(i)):
					var val = anim.track_get_key_value(i, j)
					anim.track_set_key_value(i, j, Vector3(0.0, val.y, 0.0))

func _tick_sync(delta: float):
	if not NetworkManager.multiplayer_mode:
		return
	_sync_timer -= delta
	if _sync_timer <= 0.0:
		_sync_timer = _SYNC_RATE
		_sync_state.rpc(global_position, rotation.y, current_anim, current_hp)

@rpc("any_peer", "unreliable_ordered")
func _sync_state(pos: Vector3, rot_y: float, anim: String, hp: float):
	_remote_pos   = pos
	_remote_rot_y = rot_y
	current_hp    = hp
	_set_state(anim)

@rpc("any_peer", "reliable")
func take_damage_rpc(amount: float):
	take_damage(amount)

func _separation_force() -> Vector3:
	var force   = Vector3.ZERO
	var radius  = 2.2
	var targets = get_tree().get_nodes_in_group("enemy") \
				+ get_tree().get_nodes_in_group("player_remote")
	for ob in targets:
		var diff = global_position - ob.global_position
		diff.y   = 0.0
		var d    = diff.length()
		if d < radius and d > 0.01:
			force += diff.normalized() * ((radius - d) / radius)
	return force

func _tick_cooldowns(delta: float):
	if q_timer > 0:
		q_timer = max(0.0, q_timer - delta)
		skill_changed.emit("q", q_timer, Q_CD)
	if w_timer > 0:
		w_timer = max(0.0, w_timer - delta)
		skill_changed.emit("w", w_timer, W_CD)
	if shield_active:
		shield_timer -= delta
		if shield_timer <= 0:
			shield_active = false
	if e_recharge_timer > 0.0 and e_charges < E_MAX_CHARGES:
		e_recharge_timer -= delta
		if e_recharge_timer <= 0.0:
			e_charges        = E_MAX_CHARGES
			e_recharge_timer = 0.0
		skill_changed.emit("e", e_recharge_timer if e_charges == 0 else 0.0, E_CD)
