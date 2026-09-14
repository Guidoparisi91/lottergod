# -*- coding: utf-8 -*-
"""Genera maps/map_01/arena_pruebas.tscn a partir de pruebas.tscn.

Es la escena JUGABLE de la arena: instancia arena.tscn y le suma jugador,
camara, HUD, boss al centro, los dos spawns opuestos y los nidos.

La luz cambia a noche a proposito. DESIGN.md §6 lo tiene [DECIDIDO]: con
vision limitada dos jugadores alcanzan para llenar un mapa; a plena luz
hacen falta diez. La plaza del boss queda como el unico lugar iluminado,
que es lo que implementa "pegarle al boss tiene que dejarte expuesto".

Todo en METROS (1 u = 1 m) desde 2026-09-14: antes el mundo iba x2.
"""
import io
import os
import re

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BASE = os.path.join(RAIZ, "maps", "map_01", "pruebas.tscn")
SAL = os.path.join(RAIZ, "maps", "map_01", "arena_pruebas.tscn")

SPAWNS = [(-40.0, -40.0), (40.0, 40.0)]

# Nidos: dos en las esquinas neutras (NO y SE, contestados) y uno cerca de
# cada spawn (el farmeo "de casa"). Ninguno sobre la diagonal rapida.
NIDOS = [
    ("NidoNoroeste", -30.0, 30.0, 5),
    ("NidoSudeste", 30.0, -30.0, 5),
    ("NidoOeste", -37.0, -7.0, 4),
    ("NidoEste", 37.0, 7.0, 4),
]


def main():
    txt = io.open(BASE, encoding="utf-8").read()

    txt = re.sub(r'^\[gd_scene([^\]]*?) uid="[^"]*"\]', r'[gd_scene\1]',
                 txt, count=1, flags=re.M)

    # el mapa pasa a ser la arena
    txt = txt.replace('path="res://maps/map_01/pueblo.tscn" id="pueblo"',
                      'path="res://maps/map_01/arena.tscn" id="pueblo"')
    txt = re.sub(r'\[ext_resource type="PackedScene"[^\]]*id="pueblo"\]',
                 '[ext_resource type="PackedScene" path="res://maps/map_01/arena.tscn" id="pueblo"]',
                 txt)
    txt = txt.replace('[node name="Pueblo" parent="."',
                      '[node name="Arena" parent="."')

    # script del nido
    ancla = list(re.finditer(r'^\[ext_resource[^\]]*\]$', txt, flags=re.M))[-1]
    txt = (txt[:ancla.end()]
           + '\n[ext_resource type="Script" path="res://enemies/enemy_pit.gd" id="pit_script"]'
           + txt[ancla.end():])

    # ---- noche ----------------------------------------------------------
    txt = txt.replace('sky_top_color = Color(0.18, 0.24, 0.35, 1)',
                      'sky_top_color = Color(0.02, 0.03, 0.07, 1)')
    txt = txt.replace('sky_horizon_color = Color(0.52, 0.56, 0.62, 1)',
                      'sky_horizon_color = Color(0.09, 0.11, 0.17, 1)')
    txt = txt.replace('ground_bottom_color = Color(0.13, 0.13, 0.14, 1)',
                      'ground_bottom_color = Color(0.02, 0.02, 0.03, 1)')
    txt = txt.replace('ground_horizon_color = Color(0.52, 0.56, 0.62, 1)',
                      'ground_horizon_color = Color(0.09, 0.11, 0.17, 1)')
    txt = txt.replace('ambient_light_color = Color(0.42, 0.46, 0.55, 1)',
                      'ambient_light_color = Color(0.22, 0.28, 0.45, 1)')
    txt = txt.replace('ambient_light_energy = 0.22',
                      'ambient_light_energy = 0.07')
    # La niebla deja de ser decorado: es la que recorta la vision.
    txt = txt.replace('fog_light_color = Color(0.52, 0.56, 0.62, 1)',
                      'fog_light_color = Color(0.05, 0.06, 0.11, 1)')
    txt = txt.replace('fog_depth_begin = 45.0', 'fog_depth_begin = 22.5')
    txt = txt.replace('fog_depth_end = 95.0', 'fog_depth_end = 60.0')

    # sol -> luna
    txt = txt.replace('light_energy = 1.25',
                      'light_energy = 0.22\nlight_color = Color(0.62, 0.72, 1, 1)')

    # ---- boss al centro --------------------------------------------------
    txt = re.sub(
        r'(\[node name="GoblinKing"[^\]]*\]\ntransform = )Transform3D\([^)]*\)',
        r'\1Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0.5, 0)', txt)

    # ---- spawns opuestos -------------------------------------------------
    nuevo = []
    for i, (x, z) in enumerate(SPAWNS):
        nuevo.append(
            '[node name="PlayerSpawn%d" type="Marker3D" parent="." groups=["player_spawn"]]\n'
            'transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, %.1f, 1, %.1f)\n' % (i, x, z))
    txt = re.sub(r'\[node name="PlayerSpawn" type="Marker3D"[^\]]*\]\ntransform = Transform3D\([^)]*\)\n?',
                 "\n".join(nuevo), txt)

    # ---- nidos -----------------------------------------------------------
    pits = ['\n']
    for nom, x, z, cupo in NIDOS:
        pits.append(
            '[node name="%s" type="Node3D" parent="." groups=["enemy_pit"]]\n'
            'transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, %.1f, 0, %.1f)\n'
            'script = ExtResource("pit_script")\n'
            'enemy_scene = ExtResource("goblin")\n'
            'max_enemies = %d\n'
            'patrol_size = Vector2(9, 9)\n'
            'spawn_interval = 6.0\n\n' % (nom, x, z, cupo))

    txt = txt.rstrip() + "\n\n" + "".join(pits).lstrip("\n")
    io.open(SAL, "w", encoding="utf-8", newline="\n").write(txt)
    print("arena_pruebas.tscn escrito")
    print("  spawns : %s" % ", ".join("(%.0f,%.0f)" % s for s in SPAWNS))
    print("  nidos  : %d" % len(NIDOS))


main()
