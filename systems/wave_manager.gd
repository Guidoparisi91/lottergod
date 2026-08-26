class_name WaveManager
extends Node3D

signal wave_started(wave: int)
signal stats_changed(wave: int, kills: int)

@export var enemy_scene:         PackedScene
@export var wave_duration:       float = 60.0  # segundos hasta la siguiente wave
@export var base_spawn_interval: float = 3.0   # tiempo entre spawns en wave 1
@export var min_spawn_interval:  float = 0.5   # límite mínimo de spawn rate
@export var spawn_radius_min:    float = 20.0
@export var spawn_radius_max:    float = 40.0
@export var max_alive_base:      int   = 12    # máximo de enemigos vivos en wave 1
@export var max_alive_per_wave:  int   = 3     # extra por wave
## true  = nacen yendo hacia el jugador, sin importar la distancia (asedio).
## false = nacen patrullando y solo reaccionan si entrás en su detection_range,
##         así el spawn_radius pasa a importar y hay que ir a buscarlos.
@export var spawn_alerted:       bool  = true

## Cuántos ángulos se prueban antes de dar por perdido el spawn de este tick.
const INTENTOS_SPAWN := 8

var current_wave: int   = 0
var kills_total:  int   = 0
var _wave_timer:  float = 3.0  # delay antes de la wave 1
var _spawn_timer: float = 0.0
var _id_counter:  int   = 0

func _ready() -> void:
	add_to_group("wave_manager")

func _process(delta: float) -> void:
	if NetworkManager.multiplayer_mode and not multiplayer.is_server():
		return
	if get_tree().get_nodes_in_group("player_local").is_empty():
		return

	# Avance de wave por tiempo
	_wave_timer -= delta
	if _wave_timer <= 0.0:
		_wave_timer   = wave_duration
		current_wave += 1
		emit_signal("wave_started", current_wave)
		emit_signal("stats_changed", current_wave, kills_total)
		if NetworkManager.multiplayer_mode:
			_rpc_notify.rpc(current_wave, kills_total)

	if current_wave == 0:
		return

	# Cap de enemigos vivos
	var alive     = get_tree().get_nodes_in_group("enemy").size()
	var max_alive = max_alive_base + current_wave * max_alive_per_wave
	if alive >= max_alive:
		return

	# Spawn continuo
	_spawn_timer -= delta
	if _spawn_timer > 0.0:
		return
	var interval     = maxf(min_spawn_interval, base_spawn_interval - (current_wave - 1) * 0.25)
	_spawn_timer     = interval
	var batch        = 1 + int(current_wave / 5)  # más enemigos por tick en waves avanzadas
	for i in batch:
		if alive + i >= max_alive:
			break
		var pos = _random_pos()
		if pos == null:
			# Ningún ángulo dio suelo firme. Mejor saltear este tick que soltar
			# un enemigo al vacío: quedaría vivo para siempre ocupando cupo.
			break
		_id_counter += 1
		_do_spawn(pos, _id_counter, current_wave)
		if NetworkManager.multiplayer_mode:
			_rpc_spawn.rpc(pos, _id_counter, current_wave)

## Devuelve una posición con suelo debajo, o null si tras varios intentos no
## encontró ninguna (el jugador está cerca del borde del mapa, por ejemplo).
func _random_pos() -> Variant:
	var center = _get_center()
	for intento in INTENTOS_SPAWN:
		var angle  = randf() * TAU
		var radius = randf_range(spawn_radius_min, spawn_radius_max)
		var pos    = _pos_from_angle(center, angle, radius)
		if pos != null:
			return pos
	return null

## Raycast hacia abajo en ese punto. null si no hay nada donde pararse.
func _pos_from_angle(center: Vector3, angle: float, radius: float) -> Variant:
	var offset   = Vector3(sin(angle) * radius, 0.0, cos(angle) * radius)
	var base_pos = center + offset
	var space    = get_world_3d().direct_space_state
	var query    = PhysicsRayQueryParameters3D.create(
		base_pos + Vector3.UP * 200.0,
		base_pos + Vector3.DOWN * 50.0
	)
	var hit = space.intersect_ray(query)
	if hit.is_empty():
		return null
	return hit.position + Vector3.UP * 0.5

func _get_center() -> Vector3:
	var players = get_tree().get_nodes_in_group("player_local") \
				+ get_tree().get_nodes_in_group("player_remote")
	if players.is_empty():
		return global_position
	var center = Vector3.ZERO
	var count  = 0
	for p in players:
		if is_instance_valid(p):
			center += p.global_position
			count  += 1
	return center / count if count > 0 else global_position

func _do_spawn(pos: Vector3, eid: int, wave: int) -> void:
	if not enemy_scene:
		return
	var e      = enemy_scene.instantiate()
	e.name     = "WaveEnemy_%d_%d" % [wave, eid]
	get_parent().add_child(e)
	e.global_position = pos

	var hp_mult:    float = 1.0 + (wave - 1) * 0.15
	var speed_mult: float = 1.0 + (wave - 1) * 0.05
	e.configure(hp_mult, speed_mult)

	var locals = get_tree().get_nodes_in_group("player_local")
	if not locals.is_empty():
		e.setup(locals[0])
		if spawn_alerted:
			e.player = locals[0]
			e.state  = BaseEnemy.State.APPROACH
		else:
			# Nace neutral: patrulla su zona de spawn y solo reacciona cuando
			# el jugador entra en detection_range.
			e.set_patrol_area(pos, Vector2(12.0, 12.0))
			e.state = BaseEnemy.State.PATROL

@rpc("authority", "reliable")
func _rpc_spawn(pos: Vector3, eid: int, wave: int) -> void:
	_do_spawn(pos, eid, wave)

func on_any_enemy_killed(_killer_id: int) -> void:
	if NetworkManager.multiplayer_mode and not multiplayer.is_server():
		return
	kills_total += 1
	emit_signal("stats_changed", current_wave, kills_total)
	if NetworkManager.multiplayer_mode:
		_rpc_notify.rpc(current_wave, kills_total)

@rpc("authority", "reliable")
func _rpc_notify(wave: int, kills: int) -> void:
	current_wave = wave
	emit_signal("stats_changed", wave, kills)
	emit_signal("wave_started", wave)
