extends Node

# Reproduce lo que hace world.gd._raycast() para una grilla de posiciones de
# pantalla y reporta CONTRA QUE choca cada una. Si el personaje corre siempre
# al mismo lado, es porque todos los clicks estan pegando en el mismo collider.

const ESCENA := "res://maps/map_01/arena_pruebas.tscn"

var _f := 0
var _raiz: Node


func _ready() -> void:
	_raiz = (load(ESCENA) as PackedScene).instantiate()
	get_tree().root.add_child.call_deferred(_raiz)
	await get_tree().process_frame
	get_tree().current_scene = _raiz


func _process(_d: float) -> void:
	_f += 1
	if _f != 45:
		return

	var cam := get_viewport().get_camera_3d()
	if cam == null:
		print("DIAG> NO HAY CAMARA ACTIVA")
		get_tree().quit(1)
		return

	var jugadores := get_tree().get_nodes_in_group("player_local")
	var jug: Node3D = jugadores[0] if not jugadores.is_empty() else null
	print("DIAG> camara en %s" % cam.global_position)
	if jug != null:
		print("DIAG> jugador en %s" % jug.global_position)

	var vp := get_viewport().get_visible_rect().size

	for fy in 5:
		var linea := ""
		for fx in 5:
			var mp := Vector2(vp.x * (0.1 + 0.2 * fx), vp.y * (0.1 + 0.2 * fy))
			var origen := cam.project_ray_origin(mp)
			# Llamamos al _raycast REAL de world.gd, no a una copia: si la copia
			# se desincroniza del original el diagnostico miente.
			var r: Dictionary = _raiz.call("_raycast", mp)
			if r.is_empty():
				linea += "[ SIN CHOQUE ] "
			else:
				var c: Node = r.collider
				var p: Vector3 = r.position
				linea += "[%s d=%.0f] " % [c.name, origen.distance_to(p)]
		print("DIAG> fila %d: %s" % [fy, linea])

	get_tree().quit(0)
