extends BaseEnemy

## Goblin — primer enemigo del juego.
## Hereda toda la lógica de BaseEnemy; solo sobreescribimos los valores.

@onready var idle_node:  Node3D = $Idle
@onready var walk_node:  Node3D = $Walking
@onready var swipe_node: Node3D = $Swiping

var idle_anim:  AnimationPlayer = null
var walk_anim:  AnimationPlayer = null
var swipe_anim: AnimationPlayer = null

var current_anim: String = ""
var _attacking:   bool   = false

func _ready():
	max_hp          = 50.0
	speed           = 3.5
	detection_range = 10.0
	attack_range    = 2.0
	attack_damage   = 5.0
	attack_cooldown = 1.5
	xp_reward       = 120
	hp_bar_height   = 3.8
	super._ready()

	scale = Vector3(2.0, 2.0, 2.0)

	idle_anim  = _find_anim(idle_node)
	walk_anim  = _find_anim(walk_node)
	swipe_anim = _find_anim(swipe_node)

	_force_loop(idle_anim)
	_force_loop(walk_anim)
	_fix_root_motion(idle_anim)
	_fix_root_motion(walk_anim)
	_fix_root_motion(swipe_anim)

	if swipe_anim and swipe_anim.has_animation(ANIM_NAME):
		swipe_anim.get_animation(ANIM_NAME).loop_mode = Animation.LOOP_NONE
		swipe_anim.animation_finished.connect(_on_swipe_finished)

	_set_anim("idle")


func _find_anim(node: Node) -> AnimationPlayer:
	var results = node.find_children("*", "AnimationPlayer", true, false)
	return results[0] if results.size() > 0 else null

const ANIM_NAME = "mixamo_com"

func _fix_root_motion(ap: AnimationPlayer):
	if not ap or not ap.has_animation(ANIM_NAME):
		return
	var anim = ap.get_animation(ANIM_NAME)
	for i in range(anim.get_track_count()):
		if anim.track_get_type(i) != Animation.TYPE_POSITION_3D:
			continue
		var path = str(anim.track_get_path(i))
		var is_hips = "Hips" in path or "Hip" in path
		for j in range(anim.track_get_key_count(i)):
			var val = anim.track_get_key_value(i, j)
			# Zerear X/Z en todos los tracks. Y solo se preserva en Hips (bob natural).
			anim.track_set_key_value(i, j, Vector3(0.0, val.y if is_hips else 0.0, 0.0))

func _force_loop(ap: AnimationPlayer):
	if not ap:
		return
	if ap.has_animation(ANIM_NAME):
		ap.get_animation(ANIM_NAME).loop_mode = Animation.LOOP_LINEAR

func _set_anim(anim: String):
	# Actualizar visibilidad solo si cambia el estado
	if current_anim != anim:
		current_anim       = anim
		idle_node.visible  = false
		walk_node.visible  = false
		swipe_node.visible = false
		match anim:
			"walk":
				walk_node.visible = true
			"attack":
				_attacking         = true
				swipe_node.visible = true
			_:
				idle_node.visible = true

	# Siempre verificar que el AnimationPlayer esté corriendo
	match anim:
		"walk":
			if walk_anim and not walk_anim.is_playing():
				walk_anim.play(ANIM_NAME)
		"attack":
			if swipe_anim and not swipe_anim.is_playing():
				swipe_anim.speed_scale = 1.5
				swipe_anim.play(ANIM_NAME)
		_:
			if idle_anim and not idle_anim.is_playing():
				idle_anim.play(ANIM_NAME)

func _apply_hit():
	if not is_instance_valid(self) or not player or not is_instance_valid(player):
		return
	if global_position.distance_to(player.global_position) <= attack_range:
		player.take_damage(attack_damage)

func _on_swipe_finished(_anim_name: String):
	_attacking = false
	swipe_anim.seek(0.0, true)  # resetea el mesh al frame 0 antes de ocultarlo
	_set_anim("idle")

func _get_sync_anim() -> String:
	return current_anim

func _apply_sync_anim(anim: String) -> void:
	_set_anim(anim)
	if anim != "attack":
		_attacking = false

func _physics_process(delta):
	super._physics_process(delta)
	# Clientes: animación manejada 100% por el sync del host
	if NetworkManager.multiplayer_mode and not is_multiplayer_authority():
		return
	if _attacking:
		return
	match state:
		State.IDLE:
			_set_anim("idle")
		State.PATROL:
			_set_anim("walk")
		State.CHASE:
			var moving = Vector2(velocity.x, velocity.z).length() > 0.1
			_set_anim("walk" if moving else "idle")
		State.APPROACH:
			_set_anim("walk")

const HIT_PERCENT = 0.45  # el golpe conecta al 45% de la animación

func _do_attack():
	if _attacking:
		return
	_set_anim("attack")
	var duration = swipe_anim.get_animation(ANIM_NAME).length / swipe_anim.speed_scale
	get_tree().create_timer(duration * HIT_PERCENT).timeout.connect(_apply_hit)
