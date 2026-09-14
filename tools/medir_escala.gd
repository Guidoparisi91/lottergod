extends Node

# Mide los tamanos y distancias del juego CORRIENDO, no los que dice el codigo.
# Sirve para cambiar la escala del mundo sin cambiar como se juega: se corre
# antes y despues, y los numeros tienen que dar en la proporcion esperada
# (las distancias escalan, los tiempos y angulos quedan iguales).
#
# Salida: lineas "ESC> clave = valor" y dos fotos en user://escala_*.png

const ESCENA := "res://maps/map_01/arena_pruebas.tscn"
const GOBLIN := "res://enemies/goblin/enemy.tscn"

var _f := 0
var _jug: CharacterBody3D
var _mundo: Node
var _gob: Node3D
var _inicio: Vector3
var _dir: Vector3


func _ready() -> void:
	_mundo = (load(ESCENA) as PackedScene).instantiate()
	get_tree().root.add_child.call_deferred(_mundo)
	await get_tree().process_frame
	get_tree().current_scene = _mundo


func _p(clave: String, valor: float) -> void:
	print("ESC> %-28s = %8.3f" % [clave, valor])


func _physics_process(_d: float) -> void:
	_f += 1

	if _f == 30:
		_jug = get_tree().get_first_node_in_group("player_local") as CharacterBody3D
		if _jug == null:
			print("ESC> ERROR: no spawneo el jugador")
			get_tree().quit(1)
			return
		_medir_cuerpo("jugador", _jug)
		var cam := get_viewport().get_camera_3d()
		_p("camara.brazo", cam.get("arm"))
		_p("camara.distancia_al_jugador", cam.global_position.distance_to(_jug.global_position))
		_p("camara.ancho_visible_suelo", _ancho_visible(cam))
		_p("alcance_ataque_base", _mundo.get("ATTACK_RANGE"))

		# Un goblin de prueba, lejos de todo.
		_gob = (load(GOBLIN) as PackedScene).instantiate() as Node3D
		_mundo.add_child(_gob)
		_gob.global_position = _jug.global_position + Vector3(0, 1, 12) * _escala_ref()

		var boss := get_tree().get_first_node_in_group("boss") as Node3D
		if boss:
			_medir_cuerpo("boss", boss)
			_p("boss.velocidad", boss.get("speed"))
			_p("boss.rango_ataque", boss.get("attack_range"))
			_p("boss.deteccion", boss.get("detection_range"))

		for m in get_tree().get_nodes_in_group("player_spawn"):
			var n := m as Node3D
			_p("spawn.%s.x" % n.name, n.global_position.x)
			_p("spawn.%s.z" % n.name, n.global_position.z)

	if _f == 60:
		_medir_cuerpo("goblin", _gob)
		_p("goblin.velocidad", _gob.get("speed"))
		_p("goblin.rango_ataque", _gob.get("attack_range"))
		_p("goblin.deteccion", _gob.get("detection_range"))
		_p("goblin.radio_cuerpo", _gob.call("radio_cuerpo"))
		_p("alcance_contra_goblin", _mundo.call("_alcance_contra", _gob))
		var barra := _gob.get_node("HPBar") as Node3D
		_p("goblin.barra_hp.altura", barra.global_position.y - _gob.global_position.y)
		var fondo := barra.get_child(0) as MeshInstance3D
		_p("goblin.barra_hp.ancho", barra.global_transform.basis.get_scale().x * (fondo.mesh as BoxMesh).size.x)
		_gob.queue_free()

		# Caminar hacia el centro por la diagonal despejada.
		_inicio = _jug.global_position
		_dir = (Vector3.ZERO - _inicio)
		_dir.y = 0.0
		_dir = _dir.normalized()
		_jug.call("move_to", _inicio + _dir * 30.0 * _escala_ref())

	if _f == 70:
		_inicio = _jug.global_position
	if _f == 130:
		var rec := _jug.global_position - _inicio
		rec.y = 0.0
		_p("jugador.velocidad_real_u_s", rec.length())   # 60 frames = 1 s
		_jug.call("stop")

	if _f == 140:
		_foto("user://escala_caminando.png")
		_inicio = _jug.global_position
		_jug.call("cast_e", _inicio + _dir * 20.0 * _escala_ref())
	if _f == 230:
		var rec := _jug.global_position - _inicio
		rec.y = 0.0
		_p("jugador.dash_e", rec.length())

	if _f == 300:
		# Encuadre fijo en la plaza, cerca del boss: comparable antes y despues.
		# (Relativo al boss no sirve: patrulla al azar y cada foto sale distinta.)
		var e := _escala_ref()
		_jug.global_position = Vector3(-8.0 * e, _jug.global_position.y, 4.0 * e)
	if _f == 318:
		# Feedback flotante en la misma foto: el cartel de nivel y un numero de
		# danio. Van en unidades de mundo, asi que tambien tienen que escalar.
		_jug.call("_show_levelup_text")
		CombatFeedback.damage_number(_jug.global_position + Vector3(1.0, 1.0, 0.0) * _escala_ref(), 88.0)
	if _f == 330:
		_foto("user://escala_boss.png")
		print("ESC> listo")
		get_tree().quit(0)


## La escala del mundo segun el propio juego: 1 si el Longsword mide ~1,5 de
## alto, 2 si mide ~3. Los desplazamientos de la prueba se escalan con ella para
## que el recorrido sea el MISMO en los dos mundos.
func _escala_ref() -> float:
	return 2.0 if _alto_cabeza(_jug) > 2.2 else 1.0


func _alto_cabeza(cuerpo: Node3D) -> float:
	for s in cuerpo.find_children("*", "Skeleton3D", true, false):
		var sk := s as Skeleton3D
		if not sk.is_visible_in_tree():
			continue
		var i := sk.find_bone("mixamorig_HeadTop_End")
		if i >= 0:
			# Pose de REPOSO, no la animada: la animada depende de en que frame
			# agarra la medicion y mete ruido que no tiene nada que ver con la escala.
			return (sk.global_transform * sk.get_bone_global_rest(i)).origin.y - cuerpo.global_position.y
	return -1.0


func _medir_cuerpo(nombre: String, cuerpo: Node3D) -> void:
	_p(nombre + ".alto_cabeza", _alto_cabeza(cuerpo))
	_p(nombre + ".escala_raiz", cuerpo.global_transform.basis.get_scale().x)
	for c in cuerpo.find_children("*", "CollisionShape3D", true, false):
		var cs := c as CollisionShape3D
		var cap := cs.shape as CapsuleShape3D
		if cap == null:
			continue
		var esc := cs.global_transform.basis.get_scale().x
		_p(nombre + ".capsula_radio", cap.radius * esc)
		_p(nombre + ".capsula_alto", cap.height * esc)
		_p(nombre + ".capsula_base", cs.global_position.y - cap.height * esc * 0.5 - cuerpo.global_position.y)
		break


## Ancho del suelo que entra en pantalla a la altura del jugador, de borde a borde.
func _ancho_visible(cam: Camera3D) -> float:
	var vp := get_viewport().get_visible_rect().size
	var plano := Plane(Vector3.UP, _jug.global_position.y)
	var a: Variant = plano.intersects_ray(cam.project_ray_origin(Vector2(0, vp.y * 0.5)),
			cam.project_ray_normal(Vector2(0, vp.y * 0.5)))
	var b: Variant = plano.intersects_ray(cam.project_ray_origin(Vector2(vp.x, vp.y * 0.5)),
			cam.project_ray_normal(Vector2(vp.x, vp.y * 0.5)))
	if a == null or b == null:
		return -1.0
	return (a as Vector3).distance_to(b as Vector3)


func _foto(ruta: String) -> void:
	get_viewport().get_texture().get_image().save_png(ruta)
