class_name CharacterStats
extends Resource

## Stats persistentes de un personaje jugable.
## Se serializa a disco para guardar progresión entre sesiones.

# --- Identidad ---
@export var character_name: String = "Unnamed"
@export var character_class: String = "longsword"   # coincide con la carpeta en characters/

# --- Progresión ---
@export var level: int   = 1
@export var experience: int = 0

# --- Stats base (sin equipamiento) ---
@export var base_max_hp:      float = 100.0
@export var base_max_stamina: float = 200.0
@export var base_max_mana:    float = 100.0
@export var base_attack:      float = 1.0
@export var base_defense:     float = 0.0
@export var base_speed:       float = 7.0

# --- Stats calculados (base + bonos de equipo) ---
var max_hp:      float
var max_stamina: float
var max_mana:    float
var attack:      float
var defense:     float
var speed:       float

# XP necesaria para pasar al siguiente nivel (escala lineal por ahora)
const XP_PER_LEVEL := 100

func _init():
	recalculate()

func recalculate():
	# Por ahora solo copia los base; cuando haya inventario se sumarán los bonos
	max_hp      = base_max_hp      + (level - 1) * 10.0
	max_stamina = base_max_stamina + (level - 1) * 20.0
	max_mana    = base_max_mana    + (level - 1) * 15.0
	attack      = base_attack      + (level - 1) * 0.25
	defense     = base_defense     + (level - 1) * 0.1
	speed       = base_speed

func add_experience(amount: int) -> bool:
	experience += amount
	var leveled_up := false
	while experience >= xp_to_next_level():
		experience -= xp_to_next_level()
		level      += 1
		leveled_up  = true
		recalculate()
	return leveled_up

func xp_to_next_level() -> int:
	return level * XP_PER_LEVEL
