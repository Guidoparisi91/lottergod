class_name BaseBoss
extends MeleeEnemy

## Base para todos los jefes.
##
## Un boss NO es "un enemigo con más HP". Lo que lo hace un boss:
##   - se planta: el knockback casi no lo mueve
##   - se lee: wind-up lento, tenés tiempo de salirte si mirás
##   - pega en serio: pocos golpes te matan, así que retirarse importa
##   - tiene fases: cambia de comportamiento a medida que baja de vida
##   - el feedback está amplificado, para que pegarle se sienta distinto
##
## Las subclases concretas (GoblinKing, etc.) solo declaran stats y
## opcionalmente sobreescriben `_on_phase_changed()`.

## Porcentajes de vida donde arranca cada fase nueva, de mayor a menor.
## Ej: [0.66, 0.33] -> fase 1 al 100%, fase 2 bajo 66%, fase 3 bajo 33%.
@export var phase_thresholds: Array[float] = [0.66, 0.33]

## Cuánto se acelera el ataque por fase. Fase 2 = x1.15, fase 3 = x1.30, etc.
@export var phase_attack_speedup: float = 0.15

var phase: int = 1

signal phase_changed(new_phase: int)


func _ready():
	# Defaults de "jefe". Las subclases pueden pisarlos antes de llamar super.
	if knockback_resistance == 0.0:
		knockback_resistance = 0.85
	if feedback_scale == 1.0:
		feedback_scale = 2.0
	if hp_bar_scale == 1.0:
		hp_bar_scale = 3.0
	super._ready()
	add_to_group("boss")


func _on_damaged(_amount: float) -> void:
	_check_phase()


func _check_phase() -> void:
	if max_hp <= 0.0:
		return
	var pct := current_hp / max_hp
	# La fase es 1 + cuántos umbrales ya cruzamos hacia abajo
	var target_phase := 1
	for t in phase_thresholds:
		if pct < t:
			target_phase += 1
	if target_phase == phase:
		return
	phase = target_phase
	_on_phase_changed(phase)
	phase_changed.emit(phase)


## Comportamiento por defecto al cambiar de fase: se pone más rápido y más agresivo.
## Sobreescribir en subclases para agregar ataques nuevos, invocaciones, etc.
func _on_phase_changed(new_phase: int) -> void:
	var steps := new_phase - 1
	attack_anim_speed += phase_attack_speedup * steps
	attack_cooldown    = max(0.5, attack_cooldown - 0.25 * steps)

	# Marca visual de que algo cambió: fogonazo y un pulso de números en rojo
	CombatFeedback.flash(self, Color(1.0, 0.35, 0.15, 0.8))
	CombatFeedback.death_burst(
		global_position + Vector3(0.0, _alto_cabeza() * 0.5, 0.0),
		feedback_scale * 0.7,
		Color(1.0, 0.4, 0.1)
	)
