extends BaseBoss

## Goblin King — primer jefe. Reusa las animaciones del goblin, escalado y lento.
##
## OJO: este script NO tiene números. Todos los stats (vida, daño, escala,
## velocidad del wind-up, tinte) están como overrides en `goblin_king.tscn`,
## así los podés tocar desde el inspector sin tocar código.
##
## Es a propósito y es el patrón que quiero de acá en adelante: el código define
## COMPORTAMIENTO, la escena define VALORES.

## En la última fase se mueve más rápido: ya no podés simplemente caminar lejos.
@export var final_phase_speed_mult: float = 1.35

var _base_speed_cached: float = 0.0


func _ready():
	super._ready()
	_base_speed_cached = speed


func _on_phase_changed(new_phase: int) -> void:
	super._on_phase_changed(new_phase)

	# Última fase: se enfurece y te persigue en serio
	if new_phase > phase_thresholds.size():
		speed = _base_speed_cached * final_phase_speed_mult
