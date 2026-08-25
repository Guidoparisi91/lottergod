class_name AnimatedEnemy
extends BaseEnemy

## Enemigo con animaciones Mixamo separadas en nodos Idle / Walking / Swiping.
##
## Capa de PRESENTACIÓN y ritmo de ataque. No decide QUÉ hace el golpe:
## dispara `_deliver_hit()` en el frame correcto y las subclases lo implementan
## (MeleeEnemy pega en rango, RangedEnemy dispara un proyectil, etc).
##
## Jerarquía:
##   BaseEnemy -> AnimatedEnemy -> MeleeEnemy  -> GoblinEnemy
##                             -> MeleeEnemy  -> BaseBoss -> GoblinKing
##                             -> RangedEnemy -> (futuro)

const ANIM_NAME = "mixamo_com"

## Escala del cuerpo. Se aplica después de que BaseEnemy termine su setup.
@export var body_scale: float = 2.0
## Velocidad de reproducción del ataque. Más bajo = wind-up más lento y más legible.
@export var attack_anim_speed: float = 1.5
## En qué punto de la animación de ataque conecta el golpe (0..1).
@export var hit_percent: float = 0.45
## Tinte permanente del cuerpo. Alpha 0 = sin tinte.
@export var body_tint: Color = Color(0, 0, 0, 0)

@onready var idle_node:  Node3D = $Idle
@onready var walk_node:  Node3D = $Walking
@onready var swipe_node: Node3D = $Swiping

var idle_anim:  AnimationPlayer = null
var walk_anim:  AnimationPlayer = null
var swipe_anim: AnimationPlayer = null

var current_anim: String = ""
var _attacking:   bool   = false


func _ready():
	super._ready()

	scale = Vector3(body_scale, body_scale, body_scale)

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

	if body_tint.a > 0.0:
		CombatFeedback.apply_tint(self, body_tint)

	_set_anim("idle")


func _find_anim(node: Node) -> AnimationPlayer:
	if node == null:
		return null
	var results = node.find_children("*", "AnimationPlayer", true, false)
	return results[0] if results.size() > 0 else null


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
				swipe_anim.speed_scale = attack_anim_speed
				swipe_anim.play(ANIM_NAME)
		_:
			if idle_anim and not idle_anim.is_playing():
				idle_anim.play(ANIM_NAME)


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


## Reproduce la animación de ataque y agenda el golpe en el frame correcto.
func _do_attack():
	if _attacking:
		return
	_set_anim("attack")
	var duration = swipe_anim.get_animation(ANIM_NAME).length / swipe_anim.speed_scale
	get_tree().create_timer(duration * hit_percent).timeout.connect(_deliver_hit)


## Abstracto: qué hace el golpe cuando conecta. Lo implementan las subclases.
func _deliver_hit() -> void:
	pass
