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

func _process(_delta):
	if target:
		global_position = target.global_position + _offset()
		rotation_degrees = Vector3(pitch, yaw, 0.0)

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
