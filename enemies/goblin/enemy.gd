extends MeleeEnemy

## Goblin — enemigo melee básico.
##
## Toda la lógica vive en la cadena BaseEnemy -> AnimatedEnemy -> MeleeEnemy.
## Acá solo van los números que definen QUÉ ES un goblin.
## Si necesitás tocar cómo pelea, se toca arriba en la cadena, no acá.

func _ready():
	max_hp          = 50.0
	speed           = 3.5
	detection_range = 10.0
	attack_range    = 2.0
	attack_damage   = 5.0
	attack_cooldown = 1.5
	xp_reward       = 120

	body_scale        = 2.0
	attack_anim_speed = 1.5
	hit_percent       = 0.45

	# Margen sobre la cabeza, NO altura absoluta: la altura sale de la cápsula.
	hp_bar_height = 0.5
	hp_bar_scale  = 1.5

	super._ready()
