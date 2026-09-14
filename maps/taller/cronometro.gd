extends CanvasLayer
## Cronómetro de la mesa de trabajo. En grayboxing la planta se juzga con
## números: cuánto se tarda de A a B y cuánto hay en línea recta.
## T pone el reloj en cero y marca el punto de partida. Solo vive en el taller.

var _t := 0.0
var _origen := Vector3.ZERO
var _label: Label


func _ready() -> void:
	var estilo := LabelSettings.new()
	estilo.font_size = 20
	estilo.outline_size = 6
	estilo.outline_color = Color.BLACK

	_label = Label.new()
	_label.label_settings = estilo
	_label.position = Vector2(16, 16)
	add_child(_label)


func _unhandled_input(event: InputEvent) -> void:
	var tecla := event as InputEventKey
	if tecla == null or not tecla.pressed or tecla.echo:
		return
	if tecla.physical_keycode == KEY_T:
		_t = 0.0
		var p := _jugador()
		if p != null:
			_origen = p.global_position


func _process(delta: float) -> void:
	_t += delta
	var p := _jugador()
	if p == null:
		return
	var pos := p.global_position
	var recta := Vector2(pos.x - _origen.x, pos.z - _origen.z).length()
	_label.text = "%.1f s   ·   %.1f u en línea recta   (T reinicia)\nx %.1f   z %.1f" \
		% [_t, recta, pos.x, pos.z]


func _jugador() -> Node3D:
	return get_tree().get_first_node_in_group("player_local") as Node3D
