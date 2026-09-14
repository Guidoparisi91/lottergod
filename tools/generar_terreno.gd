extends SceneTree

# Genera el terreno HTerrain del pueblo y lo mete en pruebas.tscn.
#
# Todo en METROS desde 2026-09-14 (antes el mundo iba x2: si comparas con
# commits viejos, distancias y alturas eran el doble y el ruido la mitad de fino).
#
# El pueblo vive sobre un plano de 100x100 centrado en el origen. La idea NO es
# reemplazarlo: es rodearlo. El terreno queda liso bajo el pueblo (para que el
# adoquin y las casas sigan apoyando igual) y sube en lomas hacia afuera, asi
# el mapa deja de terminar en un borde recto contra el vacio.

const RES        := 513                          # 513 vertices...
const ESCALA     := 1.0                          # ...a 1 m = 512 m de lado
const DIR        := "res://maps/map_01/terreno"
const ESCENA     := "res://maps/map_01/pruebas.tscn"

# Ojo: NO es distancia al centro, es distancia al BORDE del cuadrado del pueblo
# (max(|x|,|z|)). Con distancia radial habria que dejar liso hasta 71 —la esquina
# del plano de 100x100— y las lomas quedaban tan lejos que el jugador, que ve unos
# 20 m, no las veia nunca. Asi arrancan apenas pasado el adoquin.
const BORDE_LISO  := 52.0    # el plano llega a 50: 2 de margen
const BORDE_LOMAS := 130.0
const ALTURA      := 19.0
const DETALLE     := 3.5     # altura extra del ruido fino
const DEFORME     := 27.5    # cuanto se deforma el borde para que no sea un circulo
const BASE_Y      := -0.175  # apenas debajo del adoquin, para no pelear en z

const TEX_PASTO  := "res://assets/Textures/Pasto/Grass004_1K-PNG_Color.png"
const TEX_TIERRA := "res://assets/Textures/Tierra/tierra_base.png"


func _init() -> void:
	var data := HTerrainData.new()
	data.resize(RES)
	print("terreno: %dx%d vertices, %.0f unidades de lado" % [RES, RES, (RES - 1) * ESCALA])

	# Tres capas: la forma de las lomas, el detalle, y una que deforma el BORDE
	# entre lo liso y lo alto. Sin esa tercera el pueblo queda en un crater
	# perfectamente circular y se lee como un bug, no como un valle.
	var forma := FastNoiseLite.new()
	forma.noise_type = FastNoiseLite.TYPE_SIMPLEX
	forma.frequency = 0.007
	forma.fractal_octaves = 3

	var detalle := FastNoiseLite.new()
	detalle.noise_type = FastNoiseLite.TYPE_SIMPLEX
	detalle.frequency = 0.022
	detalle.fractal_octaves = 3

	var deforme := FastNoiseLite.new()
	deforme.noise_type = FastNoiseLite.TYPE_SIMPLEX
	deforme.frequency = 0.0052
	deforme.seed = 7

	var alturas := PackedFloat32Array()
	alturas.resize(RES * RES)

	var mitad := (RES - 1) * 0.5
	for z in RES:
		for x in RES:
			# a unidades de mundo, centrado en el origen
			var wx := (x - mitad) * ESCALA
			var wz := (z - mitad) * ESCALA
			var base := maxf(absf(wx), absf(wz))
			# El warp del borde tiene que crecer HACIA AFUERA. Si se suma plano,
			# le mete hasta DEFORME unidades al radio en cualquier punto: las
			# lomas arrancan antes de BORDE_LISO y el terreno asoma por encima
			# del adoquin dentro de la arena. Se lo escala por el propio
			# smoothstep sin warp, que vale 0 en toda la zona lisa.
			var previo := smoothstep(BORDE_LISO, BORDE_LOMAS, base)
			var d := base + deforme.get_noise_2d(wx, wz) * DEFORME * previo
			var t := 0.0 if base <= BORDE_LISO else smoothstep(BORDE_LISO, BORDE_LOMAS, d)
			var n := forma.get_noise_2d(wx, wz) * 0.5 + 0.5        # -> 0..1
			var dt := detalle.get_noise_2d(wx, wz) * 0.5 + 0.5
			alturas[z * RES + x] = BASE_Y + t * (ALTURA * n + DETALLE * dt)

	var img := data.get_image(HTerrainData.CHANNEL_HEIGHT)
	for z in RES:
		for x in RES:
			img.set_pixel(x, z, Color(alturas[z * RES + x], 0.0, 0.0))

	# Normales: en el flujo del editor las hornea el pincel al pintar. Como aca
	# generamos por codigo, las calculamos del gradiente (ojo: el paso horizontal
	# entre vertices es ESCALA, no 1, o las lomas salen con relieve exagerado).
	var nrm := data.get_image(HTerrainData.CHANNEL_NORMAL)
	for z in RES:
		for x in RES:
			var xl := alturas[z * RES + maxi(x - 1, 0)]
			var xr := alturas[z * RES + mini(x + 1, RES - 1)]
			var zu := alturas[maxi(z - 1, 0) * RES + x]
			var zd := alturas[mini(z + 1, RES - 1) * RES + x]
			var n3 := Vector3(xl - xr, 2.0 * ESCALA, zu - zd).normalized()
			nrm.set_pixel(x, z, HTerrainData.encode_normal(n3))

	data.notify_full_change()

	DirAccess.make_dir_recursive_absolute(DIR)
	if not data.save_data(DIR):
		push_error("no se pudo guardar el terreno en " + DIR)
		quit(1)
		return
	print("datos guardados en ", DIR)
	quit(0)
