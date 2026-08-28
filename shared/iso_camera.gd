extends Camera3D

const ARM_MIN      = 5.0
const ARM_MAX      = 20.0
const ARM_SPEED    = 1.0
const PITCH_MIN    = -80.0
const PITCH_MAX    = -30.0
const PITCH_SPEED  = 0.3
const YAW_SPEED    = 0.4

var arm:   float   = ARM_MAX
var pitch: float   = -60.0
var yaw:   float   = 45.0
var target: Node3D = null
var dragging: bool = false

var _shake_amount: float = 0.0
var _shake_decay:  float = 0.0

func _ready():
	_apply_transform()

func _input(event: InputEvent):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			dragging = event.pressed
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			arm = clamp(arm - ARM_SPEED, ARM_MIN, ARM_MAX)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			arm = clamp(arm + ARM_SPEED, ARM_MIN, ARM_MAX)

	if event is InputEventMouseMotion and dragging:
		pitch = clamp(pitch + event.relative.y * PITCH_SPEED, PITCH_MIN, PITCH_MAX)
		yaw  -= event.relative.x * YAW_SPEED

func _process(delta: float):
	if target:
		global_position = target.global_position + _offset() + _shake_offset(delta)
		rotation_degrees = Vector3(pitch, yaw, 0.0)

## Sacudon de impacto. Lo dispara CombatFeedback.camera_shake().
## `amount` es la amplitud en unidades de mundo; `duration`, cuanto tarda en morir.
func shake(amount: float = 0.25, duration: float = 0.18):
	# No acumula: un golpe fuerte pisa a uno flojo, pero dos flojos no suman uno
	# fuerte. Si se sumaran, una rafaga de golpes chicos te marea la pantalla.
	# Escalado por zoom: el shake esta en unidades de MUNDO, asi que el mismo
	# valor se ve enorme con la camara encima y no se nota desde lejos. Contra
	# el brazo actual, el temblor mide siempre lo mismo en pantalla.
	var por_zoom := amount * (arm / ARM_MAX)
	_shake_amount = maxf(_shake_amount, por_zoom)
	_shake_decay  = _shake_amount / maxf(duration, 0.01)

func _shake_offset(delta: float) -> Vector3:
	if _shake_amount <= 0.0:
		return Vector3.ZERO
	_shake_amount = maxf(0.0, _shake_amount - _shake_decay * delta)
	# La vertical va a la mitad: en camara isometrica el temblor en Y se lee
	# como que salta el piso, y marea mucho mas rapido que el lateral.
	return Vector3(
		randf_range(-_shake_amount, _shake_amount),
		randf_range(-_shake_amount, _shake_amount) * 0.5,
		randf_range(-_shake_amount, _shake_amount)
	)

func _offset() -> Vector3:
	var p = deg_to_rad(-pitch)
	var y = deg_to_rad(yaw)
	return Vector3(
		arm * sin(y)  * cos(p),
		arm * sin(p),
		arm * cos(y)  * cos(p)
	)

func _apply_transform():
	rotation_degrees = Vector3(pitch, yaw, 0.0)
