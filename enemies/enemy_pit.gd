@tool
class_name EnemyPit
extends Node3D

## Zona de spawn y patrulla para un tipo de enemigo.
## patrol_size: Vector2(ancho, profundidad) en unidades de mundo.

@export var enemy_scene:    PackedScene
@export var max_enemies:    int     = 5
@export var patrol_size:    Vector2 = Vector2(10.0, 10.0)
@export var spawn_interval: float   = 5.0

var _player:     Node3D         = null
var _timer:      float          = 0.0
var _spawned:    Array          = []
var _id_counter: int            = 0
var _gizmo:      MeshInstance3D = null
var _last_size:  Vector2        = Vector2.ZERO
var _terrain:    Node           = null

# --- Editor gizmo ---

func _process(delta):
	if Engine.is_editor_hint():
		if patrol_size != _last_size:
			_last_size = patrol_size
			_update_gizmo()
		return

	if not _player:
		return
	if NetworkManager.multiplayer_mode and not multiplayer.is_server():
		return
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = spawn_interval
	_try_spawn()

func _update_gizmo():
	if not _gizmo or not is_instance_valid(_gizmo):
		_gizmo = MeshInstance3D.new()
		add_child(_gizmo, false, Node.INTERNAL_MODE_BACK)

	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.55, 0.0)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.no_depth_test = true

	var hw = patrol_size.x * 0.5
	var hd = patrol_size.y * 0.5
	var im = ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_LINE_STRIP, mat)
	im.surface_add_vertex(Vector3(-hw, 0.05, -hd))
	im.surface_add_vertex(Vector3( hw, 0.05, -hd))
	im.surface_add_vertex(Vector3( hw, 0.05,  hd))
	im.surface_add_vertex(Vector3(-hw, 0.05,  hd))
	im.surface_add_vertex(Vector3(-hw, 0.05, -hd))
	im.surface_end()
	_gizmo.mesh = im

# --- Runtime ---

func _ready():
	if Engine.is_editor_hint():
		return
	add_to_group("enemy_pit")
	_terrain = _find_terrain3d()

func _find_terrain3d() -> Node:
	return _search_terrain(get_tree().root)

func _search_terrain(node: Node) -> Node:
	if node.get_class() == "Terrain3D":
		return node
	for c in node.get_children():
		var r = _search_terrain(c)
		if r:
			return r
	return null

func setup(player: Node3D):
	_player = player

func _try_spawn():
	_spawned = _spawned.filter(func(e): return is_instance_valid(e))
	if _spawned.size() >= max_enemies:
		return
	_id_counter += 1
	var pos = _random_spawn_pos()
	_do_spawn(pos, _id_counter)
	if NetworkManager.multiplayer_mode:
		_rpc_spawn.rpc(pos, _id_counter)

func _random_spawn_pos() -> Vector3:
	var x    = randf_range(-patrol_size.x * 0.5, patrol_size.x * 0.5)
	var z    = randf_range(-patrol_size.y * 0.5, patrol_size.y * 0.5)
	var base = global_position + Vector3(x, 0.0, z)

	# Terrain3D.get_height() reads the heightmap directly — no physics chunks needed.
	# This is the only reliable way to get ground height for off-screen spawn points.
	if _terrain and is_instance_valid(_terrain):
		var h = _terrain.data.get_height(base)
		return Vector3(base.x, h, base.z)

	# Fallback: raycast (only works if physics chunks are loaded in this area)
	var ref_y = global_position.y
	if _player and is_instance_valid(_player):
		ref_y = _player.global_position.y
	var space = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(
		Vector3(base.x, ref_y + 200.0, base.z),
		Vector3(base.x, ref_y - 100.0, base.z)
	)
	var hit = space.intersect_ray(query)
	if hit:
		return hit.position + Vector3.UP * 0.5
	return Vector3(base.x, ref_y + 2.0, base.z)

func _do_spawn(pos: Vector3, eid: int):
	if not enemy_scene:
		return
	var e = enemy_scene.instantiate()
	e.name = "%s_%d" % [name, eid]
	get_parent().add_child(e)
	e.global_position = pos
	e.set_patrol_area(global_position, patrol_size)
	if _player:
		e.setup(_player)
	_spawned.append(e)

@rpc("authority", "reliable")
func _rpc_spawn(pos: Vector3, eid: int):
	_do_spawn(pos, eid)
