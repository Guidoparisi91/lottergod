extends Node

# Le pide al jugador que vaya a un punto concreto y muestrea a donde va de
# verdad. Si corre siempre para el mismo lado sin importar el destino, aca se ve.

const ESCENA := "res://maps/map_01/arena_pruebas.tscn"

var _f := 0
var _raiz: Node
var _jug: Node3D
var _mundo: Node
var _destino: Vector3
var _inicio: Vector3


func _ready() -> void:
	_raiz = (load(ESCENA) as PackedScene).instantiate()
	get_tree().root.add_child.call_deferred(_raiz)
	await get_tree().process_frame
	get_tree().current_scene = _raiz
	_mundo = _raiz


func _process(_d: float) -> void:
	_f += 1

	if _f == 45:
		var js := get_tree().get_nodes_in_group("player_local")
		if js.is_empty():
			print("MOV> no spawneo ningun jugador")
			get_tree().quit(1)
			return
		_jug = js[0]
		_inicio = _jug.global_position
		# Destino: 15 m hacia el CENTRO del mapa.
		var hacia := (Vector3.ZERO - _inicio)
		hacia.y = 0.0
		_destino = _inicio + hacia.normalized() * 15.0
		print("MOV> jugador arranca en (%.1f, %.1f, %.1f)" % [_inicio.x, _inicio.y, _inicio.z])
		print("MOV> le pido ir a      (%.1f, %.1f, %.1f)" % [_destino.x, _destino.y, _destino.z])
		_jug.move_to(_destino)

	if _jug != null and _f > 45 and _f % 30 == 0:
		var p := _jug.global_position
		var falta := Vector2(p.x - _destino.x, p.z - _destino.z).length()
		var rec := Vector2(p.x - _inicio.x, p.z - _inicio.z)
		print("MOV> f%3d  pos (%6.1f, %5.1f, %6.1f)  recorrido (%.1f, %.1f)  falta %.1f"
			% [_f, p.x, p.y, p.z, rec.x, rec.y, falta])

	if _f == 285:
		var p := _jug.global_position
		var esperado := Vector2(_destino.x - _inicio.x, _destino.z - _inicio.z).normalized()
		var real := Vector2(p.x - _inicio.x, p.z - _inicio.z)
		if real.length() < 0.5:
			print("MOV> RESULTADO: no se movio")
		else:
			var ang := rad_to_deg(esperado.angle_to(real.normalized()))
			print("MOV> RESULTADO: se movio %.1f unidades, desviado %.0f grados del destino"
				% [real.length(), absf(ang)])
		get_tree().quit(0)
