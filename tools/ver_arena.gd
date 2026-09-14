extends Node

# Harness de inspección: carga una escena jugable de verdad (current_scene, así
# world.gd spawnea el jugador) y saca dos fotos: planta desde arriba y una a
# nivel de suelo con el ángulo de la cámara del juego.

const ESCENA := "res://maps/map_01/arena_pruebas.tscn"

var _f := 0
var _cam: Camera3D


func _ready() -> void:
	var n := (load(ESCENA) as PackedScene).instantiate()
	get_tree().root.add_child.call_deferred(n)
	await get_tree().process_frame
	get_tree().current_scene = n

	_cam = Camera3D.new()
	_cam.far = 4000.0
	get_tree().root.add_child(_cam)


func _process(_d: float) -> void:
	_f += 1
	if _f == 40:
		_cam.position = Vector3(0, 235, 150)
		_cam.look_at(Vector3(0, 0, 0))
		_cam.current = true
	if _f == 75:
		get_viewport().get_texture().get_image().save_png("user://arena_planta.png")
		print("VER> planta lista")
		# nivel de suelo, saliendo del spawn SO hacia el centro
		_cam.position = Vector3(-74, 20, -74)
		_cam.look_at(Vector3(-40, 2, -40))
	if _f == 115:
		get_viewport().get_texture().get_image().save_png("user://arena_suelo.png")
		print("VER> suelo listo")
		get_tree().quit(0)
