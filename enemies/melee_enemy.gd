class_name MeleeEnemy
extends AnimatedEnemy

## Enemigo cuerpo a cuerpo: el golpe conecta si el jugador sigue en rango
## cuando termina el wind-up.
##
## Ese "si sigue en rango" es la regla que hace legible el combate: el enemigo
## se compromete a la animación y vos tenés la ventana del wind-up para salirte.
## Cuanto más lento el `attack_anim_speed`, más generosa la ventana.

## Multiplicador de rango al momento de conectar. >1 perdona un poco al enemigo,
## <1 premia más al que se aleja apenas.
@export var hit_range_mult: float = 1.0

## Amplitud del cono de golpe, en grados a cada lado del frente. El golpe solo
## conecta si el jugador está dentro de ese arco: rodear al enemigo por atrás
## tiene que servir de algo. 90 = medio círculo al frente.
@export_range(15.0, 180.0) var hit_arc_degrees: float = 75.0

## Cuán encarado tiene que estar el enemigo para DECIDIR atacar. Va bastante más
## ajustado que `hit_arc_degrees` a propósito:
##   - apuntar estricto  → no lanza golpes de costado que se ven torpes
##   - conectar permisivo → si te movés durante el wind-up, igual te alcanza
## Al revés se ve como un enemigo que le pega al aire sin entender dónde estás.
@export_range(5.0, 90.0) var aim_tolerance_degrees: float = 22.0


## Solo arranca el golpe si ya está bien encarado. Si no lo está, el que llama
## sigue girándolo y reintenta al frame siguiente.
func _tiene_de_frente(dir: Vector3) -> bool:
	if dir.length() < 0.01:
		return true
	return _angulo_al_frente(dir) <= aim_tolerance_degrees


## Ángulo en grados entre el frente del enemigo y una dirección del mundo.
func _angulo_al_frente(dir: Vector3) -> float:
	var frente := Vector3(sin(rotation.y), 0.0, cos(rotation.y))
	var plano  := Vector3(dir.x, 0.0, dir.z)
	if plano.length() < 0.01:
		return 0.0
	return rad_to_deg(frente.angle_to(plano.normalized()))


func _deliver_hit() -> void:
	if not is_instance_valid(self) or player == null or not is_instance_valid(player):
		return

	var hacia := player.global_position - global_position
	hacia.y = 0.0
	if hacia.length() > attack_range * hit_range_mult:
		return

	# El golpe sale hacia donde MIRA el enemigo, no hacia donde está el jugador.
	# Si te pusiste a su espalda durante el wind-up, el golpe pasa de largo.
	if _angulo_al_frente(hacia) > hit_arc_degrees:
		return

	_damage_player(player, attack_damage)
	_on_hit_landed()


## Hook para que las subclases agreguen efectos al conectar (bosses, etc).
func _on_hit_landed() -> void:
	pass
