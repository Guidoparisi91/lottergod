extends Node

# Test de la arena. Lo que verifica:
#   1. CONTENCION: que el borde este cerrado en todo el perimetro. Tira rayos
#      desde adentro hacia afuera a la altura del jugador; si alguno sale sin
#      chocar, ahi hay un agujero por el que alguien se va a las lomas.
#   2. Que los muros de la plaza del boss frenen, y que las CUATRO entradas
#      esten realmente abiertas (si una se tapo, la plaza deja de tener sus
#      cuatro accesos y se puede campear).
#   3. Que los dos spawns esten sobre piso solido y separados.
#
# En METROS desde 2026-09-14 (antes el mundo iba x2).

const ESCENA := "res://maps/map_01/arena_pruebas.tscn"
const LIMITE := 48.5
const ALTURA := 1.5

var _f := 0
var _raiz: Node


func _ready() -> void:
	_raiz = (load(ESCENA) as PackedScene).instantiate()
	get_tree().root.add_child.call_deferred(_raiz)
	await get_tree().process_frame
	get_tree().current_scene = _raiz


func _choca(desde: Vector3, hasta: Vector3) -> bool:
	var espacio := get_viewport().world_3d.direct_space_state
	var p := PhysicsRayQueryParameters3D.create(desde, hasta)
	p.collide_with_areas = false
	return not espacio.intersect_ray(p).is_empty()


func _process(_d: float) -> void:
	_f += 1
	if _f != 30:
		return

	# --- 1. perimetro ---
	var fugas := 0
	var probados := 0
	for i in 72:
		var a := TAU * float(i) / 72.0
		var dir := Vector3(cos(a), 0.0, sin(a))
		# El borde es un CUADRADO, no un circulo: si escalamos por el radio, en
		# las diagonales el rayo termina en (-45, 45), que todavia esta adentro,
		# y el test reporta una fuga que no existe. Escalamos por la componente
		# mas grande para salir de verdad por el lado que toque.
		var mayor := maxf(absf(dir.x), absf(dir.z))
		var desde: Vector3 = dir * ((LIMITE - 6.0) / mayor) + Vector3(0, ALTURA, 0)
		var hasta: Vector3 = dir * ((LIMITE + 15.0) / mayor) + Vector3(0, ALTURA, 0)
		probados += 1
		if not _choca(desde, hasta):
			fugas += 1
			if fugas <= 4:
				print("TEST> FUGA en angulo %d grados (dir %.2f, %.2f)" % [
					int(rad_to_deg(a)), dir.x, dir.z])
	print("TEST> perimetro: %d/%d direcciones cerradas" % [probados - fugas, probados])

	# --- 2. plaza del boss: muros frenan, entradas abiertas ---
	var entradas_abiertas := 0
	for dir: Vector3 in [Vector3(0, 0, -1), Vector3(0, 0, 1), Vector3(-1, 0, 0), Vector3(1, 0, 0)]:
		var desde: Vector3 = dir * 20.0 + Vector3(0, ALTURA, 0)
		var hasta: Vector3 = dir * 5.0 + Vector3(0, ALTURA, 0)
		if not _choca(desde, hasta):
			entradas_abiertas += 1
	print("TEST> entradas a la plaza abiertas: %d de 4" % entradas_abiertas)

	var muros_frenan := 0
	for dir: Vector3 in [Vector3(0, 0, -1), Vector3(0, 0, 1), Vector3(-1, 0, 0), Vector3(1, 0, 0)]:
		# 10 m al costado de la entrada: ahi tiene que haber muro
		var lado := Vector3(dir.z, 0.0, dir.x) * 10.0
		var desde: Vector3 = dir * 20.0 + lado + Vector3(0, ALTURA, 0)
		var hasta: Vector3 = dir * 5.0 + lado + Vector3(0, ALTURA, 0)
		if _choca(desde, hasta):
			muros_frenan += 1
	print("TEST> tramos de muro que frenan: %d de 4" % muros_frenan)

	# --- 3. spawns ---
	var marcas := get_tree().get_nodes_in_group("player_spawn")
	marcas.sort_custom(func(a, b): return String(a.name) < String(b.name))  # StringName "<" compara por hash, no alfabeticamente
	print("TEST> marcadores de spawn: %d" % marcas.size())
	for m in marcas:
		var p := (m as Node3D).global_position
		var suelo := _choca(p + Vector3(0, 1.5, 0), p - Vector3(0, 3, 0))
		print("TEST>   %s en (%.0f, %.0f)  piso solido: %s" % [m.name, p.x, p.z, suelo])
	if marcas.size() >= 2:
		var d: float = (marcas[0].global_position - marcas[1].global_position).length()
		print("TEST> distancia entre spawns: %.0f m" % d)

	# --- 4. nidos y boss ---
	print("TEST> nidos: %d" % get_tree().get_nodes_in_group("enemy_pit").size())
	var boss := _raiz.get_node_or_null("GoblinKing")
	if boss != null:
		print("TEST> boss en (%.0f, %.0f)" % [boss.global_position.x, boss.global_position.z])

	get_tree().quit(0)
