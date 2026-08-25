class_name TerrainManager
extends Node3D

const CHUNK_SIZE    = 128
const GRID_RADIUS   = 2
const GEN_THRESHOLD = 50.0

var _player:      Node3D
var _chunks:      Dictionary = {}
var _run_seed:    int
var _noise:       FastNoiseLite
var _grass_tex:   Texture2D
var _rock_scenes: Array

func _ready() -> void:
	_run_seed  = randi()
	_grass_tex = preload("res://assets/Textures/Pasto/Grass004_1K-PNG_Color.png")
	_rock_scenes = [
		preload("res://demo/assets/models/RockA.tscn"),
		preload("res://demo/assets/models/RockB.tscn"),
		preload("res://demo/assets/models/RockC.tscn"),
	]
	_noise            = FastNoiseLite.new()
	_noise.seed       = _run_seed
	_noise.frequency  = 0.015

	_generate_chunk(Vector2i(0, 0))
	_create_borders()

func setup(player: Node3D) -> void:
	_player = player

func _process(_delta: float) -> void:
	if not _player:
		return
	var pc = _world_to_chunk(_player.global_position)
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			var c = pc + Vector2i(dx, dz)
			if abs(c.x) > GRID_RADIUS or abs(c.y) > GRID_RADIUS:
				continue
			if _chunks.has(c):
				continue
			if _near_chunk(c):
				_generate_chunk(c)

func _world_to_chunk(pos: Vector3) -> Vector2i:
	return Vector2i(roundi(pos.x / CHUNK_SIZE), roundi(pos.z / CHUNK_SIZE))

func _near_chunk(c: Vector2i) -> bool:
	var center = Vector2(c.x * CHUNK_SIZE, c.y * CHUNK_SIZE)
	var pp     = Vector2(_player.global_position.x, _player.global_position.z)
	return pp.distance_to(center) < CHUNK_SIZE * 0.5 + GEN_THRESHOLD

func _generate_chunk(c: Vector2i) -> void:
	_chunks[c] = true

	var root = Node3D.new()
	root.name     = "Chunk_%d_%d" % [c.x, c.y]
	root.position = Vector3(c.x * CHUNK_SIZE, 0.0, c.y * CHUNK_SIZE)
	add_child(root)

	# Piso
	var mat   = StandardMaterial3D.new()
	mat.albedo_texture = _grass_tex
	mat.uv1_scale      = Vector3(8.0, 8.0, 1.0)

	var plane      = PlaneMesh.new()
	plane.size     = Vector2(CHUNK_SIZE, CHUNK_SIZE)
	plane.material = mat

	var mesh_inst  = MeshInstance3D.new()
	mesh_inst.mesh = plane
	root.add_child(mesh_inst)

	# Colisión
	var body   = StaticBody3D.new()
	var cshape = CollisionShape3D.new()
	var box    = BoxShape3D.new()
	box.size       = Vector3(CHUNK_SIZE, 0.2, CHUNK_SIZE)
	cshape.shape   = box
	body.position  = Vector3(0.0, -0.1, 0.0)
	body.add_child(cshape)
	root.add_child(body)

	_scatter_rocks(root, c)

func _scatter_rocks(root: Node3D, c: Vector2i) -> void:
	var rng  = RandomNumberGenerator.new()
	rng.seed = hash(str(_run_seed) + str(c))

	var count = rng.randi_range(5, 12)
	var half  = CHUNK_SIZE * 0.5 - 8.0

	for i in count:
		var lx = rng.randf_range(-half, half)
		var lz = rng.randf_range(-half, half)

		# Mantener el centro del chunk inicial libre para el spawn del player
		if c == Vector2i(0, 0) and Vector2(lx, lz).length() < 20.0:
			continue

		var rock = _rock_scenes[rng.randi() % _rock_scenes.size()].instantiate()
		root.add_child(rock)
		rock.position  = Vector3(lx, 0.0, lz)
		rock.rotation.y = rng.randf() * TAU
		var s = rng.randf_range(0.6, 2.0)
		rock.scale = Vector3(s, s, s)

func _create_borders() -> void:
	var limit     = float(GRID_RADIUS * CHUNK_SIZE) + CHUNK_SIZE * 0.5
	var thickness = 4.0
	var h         = 10.0
	var walls = [
		[Vector3(0, h * 0.5,  limit), Vector3(limit * 2 + thickness, h, thickness)],
		[Vector3(0, h * 0.5, -limit), Vector3(limit * 2 + thickness, h, thickness)],
		[Vector3( limit, h * 0.5, 0), Vector3(thickness, h, limit * 2 + thickness)],
		[Vector3(-limit, h * 0.5, 0), Vector3(thickness, h, limit * 2 + thickness)],
	]
	for w in walls:
		var body   = StaticBody3D.new()
		var cshape = CollisionShape3D.new()
		var box    = BoxShape3D.new()
		box.size      = w[1]
		cshape.shape  = box
		body.position = w[0]
		body.add_child(cshape)
		add_child(body)
