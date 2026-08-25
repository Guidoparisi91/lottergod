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


func _deliver_hit() -> void:
	if not is_instance_valid(self) or player == null or not is_instance_valid(player):
		return
	if global_position.distance_to(player.global_position) <= attack_range * hit_range_mult:
		player.take_damage(attack_damage)
		_on_hit_landed()


## Hook para que las subclases agreguen efectos al conectar (bosses, etc).
func _on_hit_landed() -> void:
	pass
