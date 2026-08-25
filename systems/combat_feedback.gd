extends Node

## Feedback de impacto compartido (autoload: CombatFeedback).
##
## Todo lo que hace que pegar y morir se SIENTA: flash de golpe, números de daño
## flotantes, hitstop (micro-congelamiento en el impacto) y estallido de muerte.
##
## Es puramente visual: no toca lógica de combate ni se sincroniza por red.
## Cada cliente genera su propio feedback a partir del daño que ya recibió.

# --- Flash de golpe ---
const FLASH_TIME  := 0.09
const FLASH_COLOR := Color(1.0, 1.0, 1.0, 0.65)

# --- Hitstop ---
## Cuánto dura el micro-freeze, en segundos REALES (no afectados por time_scale).
const HITSTOP_TIME  := 0.045
## A qué velocidad corre el juego durante el hitstop (0.05 = 5%).
const HITSTOP_SCALE := 0.05

# --- Números de daño ---
const DMG_RISE_TIME := 0.85

var _hitstop_until: float = 0.0
var _hitstop_on:    bool  = false

# meshes -> material_overlay que tenían antes del flash (para restaurar el tinte)
var _flash_restore: Dictionary = {}


func _process(_delta: float) -> void:
	if _hitstop_on and Time.get_ticks_msec() / 1000.0 >= _hitstop_until:
		_hitstop_on        = false
		Engine.time_scale  = 1.0


# ---------------------------------------------------------------- flash

## Pinta brevemente todas las mallas bajo `body` para marcar el impacto.
func flash(body: Node3D, color: Color = FLASH_COLOR) -> void:
	if body == null or not is_instance_valid(body):
		return
	var mat = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = color

	var meshes := body.find_children("*", "MeshInstance3D", true, false)
	for m in meshes:
		if not _flash_restore.has(m):
			_flash_restore[m] = m.material_overlay
		m.material_overlay = mat

	# ignore_time_scale = true: si no, el hitstop (time_scale 0.05) estiraría
	# este flash de 0.09s a casi 2 segundos reales.
	await get_tree().create_timer(FLASH_TIME, true, false, true).timeout

	for m in meshes:
		if is_instance_valid(m):
			m.material_overlay = _flash_restore.get(m, null)
		_flash_restore.erase(m)


## Tinte permanente (lo usan los enemigos para diferenciarse sin arte nuevo).
func apply_tint(body: Node3D, color: Color) -> void:
	if body == null or color.a <= 0.0:
		return
	var mat = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = color
	for m in body.find_children("*", "MeshInstance3D", true, false):
		m.material_overlay = mat


# ---------------------------------------------------------------- hitstop

## Micro-congelamiento en el impacto. Es el truco más barato y más efectivo
## para que un golpe se sienta pesado. Se saltea en multijugador: cambiar
## time_scale localmente desincronizaría la simulación.
func hitstop(strength: float = 1.0) -> void:
	# Solo se apaga si hay OTRO jugador: hostear solo sigue siendo una partida
	# de a uno y ahí el hitstop no desincroniza nada.
	if NetworkManager.multiplayer_mode and NetworkManager.connected_peers.size() > 1:
		return
	_hitstop_until = Time.get_ticks_msec() / 1000.0 + HITSTOP_TIME * strength
	if not _hitstop_on:
		_hitstop_on       = true
		Engine.time_scale = HITSTOP_SCALE


# ---------------------------------------------------------------- números

func damage_number(world_pos: Vector3, amount: float, color: Color = Color(1, 1, 1), size: float = 1.0) -> void:
	var host := _host()
	if host == null:
		return

	var label := Label3D.new()
	label.text             = str(int(round(amount)))
	label.font_size        = int(64 * size)
	label.modulate         = color
	label.billboard        = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test    = true
	label.outline_size     = int(14 * size)
	label.outline_modulate = Color(0, 0, 0, 1)
	host.add_child(label)

	# Dispersión lateral para que golpes seguidos no se apilen en el mismo pixel
	var jitter := Vector3(randf_range(-0.6, 0.6), 0.0, randf_range(-0.6, 0.6))
	label.global_position = world_pos + jitter

	var tween := label.create_tween().set_parallel(true)
	tween.tween_property(label, "global_position:y", world_pos.y + 2.2, DMG_RISE_TIME) \
		 .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, DMG_RISE_TIME * 0.6) \
		 .set_delay(DMG_RISE_TIME * 0.4)
	tween.finished.connect(label.queue_free)


# ---------------------------------------------------------------- muerte

func death_burst(world_pos: Vector3, size: float = 1.0, color: Color = Color(0.8, 0.15, 0.12)) -> void:
	var host := _host()
	if host == null:
		return

	var p := CPUParticles3D.new()
	host.add_child(p)
	p.global_position = world_pos

	p.emitting             = false
	p.one_shot             = true
	p.amount               = int(40 * size)
	p.lifetime             = 0.9
	p.explosiveness        = 1.0
	p.randomness           = 0.6
	p.direction            = Vector3(0, 1, 0)
	p.spread               = 65.0
	p.gravity              = Vector3(0, -12.0, 0)
	p.initial_velocity_min = 3.0 * size
	p.initial_velocity_max = 8.0 * size
	p.scale_amount_min     = 0.15 * size
	p.scale_amount_max     = 0.4  * size
	p.damping_min          = 1.0
	p.damping_max          = 4.0

	var mat := StandardMaterial3D.new()
	mat.transparency               = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode               = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color               = color

	var grad := Gradient.new()
	grad.set_color(0, Color(color.r, color.g, color.b, 1.0))
	grad.set_color(1, Color(color.r * 0.4, color.g * 0.2, color.b * 0.2, 0.0))
	p.color_ramp = grad

	var mesh := SphereMesh.new()
	mesh.radius   = 0.14
	mesh.height   = 0.28
	mesh.material = mat
	p.mesh = mesh

	p.emitting = true
	get_tree().create_timer(p.lifetime + 0.3, true, false, true).timeout.connect(p.queue_free)


# ---------------------------------------------------------------- interno

## Nodo donde colgar efectos que deben sobrevivir a la muerte del enemigo.
func _host() -> Node:
	var scene := get_tree().current_scene
	return scene if scene != null else get_tree().root
