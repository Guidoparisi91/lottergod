# -*- coding: utf-8 -*-
"""Genera maps/map_01/arena.tscn a partir de pueblo.tscn.

Planta (200x200, origen al centro, jugable hasta +-97):

  - PLAZA DEL BOSS al centro (+-24), amurallada, con CUATRO entradas de 16.
    Es el unico lugar iluminado y sin cobertura: pegarle al boss te expone.
  - ANILLO exterior de casas y callejones, oscuro. Ahi van los nidos.
  - DIAGONAL SO<->NE despejada: la ruta rapida entre los dos spawns, que pasa
    por la plaza. Es la calle larga, la de los momentos de "ahi esta".
  - BARRERAS invisibles en +-97 para que nadie se vaya a las lomas.

Se escribe el .tscn como TEXTO a proposito: PackedScene.pack() sobre una
escena instanciada pierde el script del nodo raiz y aplana las instancias.
"""
import io
import os
import re
import math

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BASE = os.path.join(RAIZ, "maps", "map_01", "pueblo.tscn")
SAL = os.path.join(RAIZ, "maps", "map_01", "arena.tscn")

LIMITE = 97.0        # hasta aca llega el jugador
PLAZA = 24.0         # medio lado de la plaza del boss
ENTRADA = 16.0       # ancho de cada entrada a la plaza
MURO_ANCHO = 4.0     # pieza de muro del kit a escala 2
MURO_ALTO = 6.24
MURO_GRUESO = 0.8
KIT = "res://assets/environment/medieval_village/glTF/"

# Casas nuevas: (x, z, grados). Ninguna pisa la diagonal SO-NE (|z-x| > 16)
# ni cae a menos de 20 de las tres casas que ya estaban en el pueblo.
CASAS = [
    (-46, 4, 15), (4, -46, -20), (-4, 46, 200), (48, -16, 110),
    (-58, 28, 250), (58, -28, 70), (-26, 52, 330), (26, -52, 150),
    (-70, -26, 40), (70, 26, 220), (-26, -70, 300), (26, 70, 120),
]


def arboles():
    """Anillo exterior, sin tapar la diagonal rapida."""
    out = []
    for ang in range(0, 360, 9):
        r = 88.0 + 5.0 * math.sin(math.radians(ang * 3.0))
        x = r * math.cos(math.radians(ang))
        z = r * math.sin(math.radians(ang))
        if abs(z - x) < 22:
            continue
        out.append((x, z, (ang * 37) % 360, 1.0 + 0.35 * math.sin(ang)))
    return out


def t3d(x, y, z, grados=0.0, esc=1.0):
    r = math.radians(grados)
    c = math.cos(r) * esc
    s = math.sin(r) * esc
    return ("Transform3D(%.4f, 0, %.4f, 0, %.4f, 0, %.4f, 0, %.4f, "
            "%.4f, %.4f, %.4f)" % (c, -s, esc, s, c, x, y, z))


def main():
    txt = io.open(BASE, encoding="utf-8").read()

    # La copia NO puede heredar el uid de pueblo.tscn.
    txt = re.sub(r'^\[gd_scene([^\]]*?) uid="[^"]*"\]', r'[gd_scene\1]',
                 txt, count=1, flags=re.M)
    txt = txt.replace('[node name="Pueblo" type="Node3D"',
                      '[node name="Arena" type="Node3D"', 1)

    # El pasto de SimpleGrassTextured usa light_mode 1 ("Normal grass"), que
    # apunta las normales hacia arriba: de noche la luna le pega de lleno y
    # queda fosforescente al lado de todo lo demas.
    #
    # Hay que bajarlo en DOS lugares. El sub-recurso del material no alcanza:
    # el script del addon corre update_all_material() en _ready() y reescribe
    # el material desde sus propias variables exportadas. Si solo tocas el
    # material, en el editor se ve bien y al correr vuelve a estar blanco.
    VERDE = 'Color(0.42, 0.5, 0.4, 1)'
    txt = txt.replace('shader_parameter/albedo = Color(1, 1, 1, 1)',
                      'shader_parameter/albedo = ' + VERDE)
    txt = txt.replace('script = ExtResource("10_jtvp8")\n',
                      'script = ExtResource("10_jtvp8")\nalbedo = ' + VERDE + '\n')

    ext = [
        '[ext_resource type="PackedScene" path="%sWall_UnevenBrick_Straight.gltf" id="ar_muro"]' % KIT,
        '[ext_resource type="PackedScene" path="%sCorner_Exterior_Brick.gltf" id="ar_esquina"]' % KIT,
    ]
    sub = [
        '[sub_resource type="BoxShape3D" id="ar_box_muro"]\nsize = Vector3(%.2f, %.2f, %.2f)\n'
        % (MURO_ANCHO, MURO_ALTO, MURO_GRUESO),
        '[sub_resource type="BoxShape3D" id="ar_box_borde"]\nsize = Vector3(%.1f, 24, 4)\n'
        % (LIMITE * 2 + 8),
    ]

    n = []
    ap = n.append

    # ---- contencion ----------------------------------------------------
    ap('[node name="Barreras" type="Node3D" parent="."]\n')
    bordes = (("Norte", 0.0, -LIMITE, 0.0), ("Sur", 0.0, LIMITE, 0.0),
              ("Oeste", -LIMITE, 0.0, 90.0), ("Este", LIMITE, 0.0, 90.0))
    # groups=["barrera"]: world.gd las excluye del raycast del click. Sin eso,
    # como la camara vuela a y~17 y el muro mide 24, la camara queda DENTRO del
    # muro: cada click hacia el centro del mapa pega en su cara interna —que
    # esta detras del jugador— y el personaje corre para atras.
    for nom, x, z, g in bordes:
        ap('\n[node name="Borde%s" type="StaticBody3D" parent="Barreras" groups=["barrera"]]\ntransform = %s\n'
           % (nom, t3d(x, 12.0, z, g)))
        ap('\n[node name="Forma" type="CollisionShape3D" parent="Barreras/Borde%s"]\nshape = SubResource("ar_box_borde")\n'
           % nom)

    # ---- plaza del boss -------------------------------------------------
    ap('\n[node name="PlazaBoss" type="Node3D" parent="."]\n')
    seg = (PLAZA * 2.0 - ENTRADA) / 2.0
    pasos = int(round(seg / MURO_ANCHO))
    i = 0
    for lado, g in (("N", 0.0), ("S", 0.0), ("O", 90.0), ("E", 90.0)):
        for signo in (-1.0, 1.0):
            for k in range(pasos):
                d = signo * (ENTRADA / 2.0 + MURO_ANCHO * (k + 0.5))
                if lado == "N":
                    x, z = d, -PLAZA
                elif lado == "S":
                    x, z = d, PLAZA
                elif lado == "O":
                    x, z = -PLAZA, d
                else:
                    x, z = PLAZA, d
                i += 1
                ap('\n[node name="Muro%02d" parent="PlazaBoss" instance=ExtResource("ar_muro")]\ntransform = %s\n'
                   % (i, t3d(x, 0.0, z, g, 2.0)))
                ap('\n[node name="MuroCol%02d" type="StaticBody3D" parent="PlazaBoss"]\ntransform = %s\n'
                   % (i, t3d(x, MURO_ALTO / 2.0, z, g)))
                ap('\n[node name="Forma" type="CollisionShape3D" parent="PlazaBoss/MuroCol%02d"]\nshape = SubResource("ar_box_muro")\n'
                   % i)
    for j, (sx, sz) in enumerate(((-1, -1), (1, -1), (-1, 1), (1, 1))):
        ap('\n[node name="Esquina%d" parent="PlazaBoss" instance=ExtResource("ar_esquina")]\ntransform = %s\n'
           % (j, t3d(sx * PLAZA, 0.0, sz * PLAZA, 0.0, 2.0)))

    # ---- luces: el centro brilla, el anillo no --------------------------
    ap('\n[node name="LucesPlaza" type="Node3D" parent="."]\n')
    for j, (sx, sz) in enumerate(((-1, -1), (1, -1), (-1, 1), (1, 1))):
        ap('\n[node name="Farol%d" type="OmniLight3D" parent="LucesPlaza"]\ntransform = %s\n'
           'light_color = Color(1, 0.85, 0.62, 1)\nlight_energy = 6.0\n'
           'omni_range = 46.0\nshadow_enabled = true\n'
           % (j, t3d(sx * (PLAZA - 4.0), 9.0, sz * (PLAZA - 4.0))))

    # ---- casas del anillo -----------------------------------------------
    ap('\n[node name="EdificiosArena" type="Node3D" parent="."]\n')
    for j, (x, z, g) in enumerate(CASAS):
        ap('\n[node name="CasaA%02d" parent="EdificiosArena" instance=ExtResource("3_6s8n4")]\ntransform = %s\n'
           % (j, t3d(x, 0.0, z, g)))
    for j, (x, z, _g) in enumerate(CASAS):
        ap('\n[node name="FarolCalle%02d" type="OmniLight3D" parent="EdificiosArena"]\ntransform = %s\n'
           'light_color = Color(1, 0.78, 0.5, 1)\nlight_energy = 2.2\nomni_range = 18.0\n'
           % (j, t3d(x * 0.86, 6.0, z * 0.86)))

    # ---- arboleda --------------------------------------------------------
    ap('\n[node name="ArboledaArena" type="Node3D" parent="."]\n')
    ids = ['13_k8u3l', '12_uv323', '10_jnmxv', '8_vj73t']
    arb = arboles()
    for j, (x, z, g, e) in enumerate(arb):
        ap('\n[node name="Arbol%02d" parent="ArboledaArena" instance=ExtResource("%s")]\ntransform = %s\n'
           % (j, ids[j % len(ids)], t3d(x, 0.0, z, g, e)))

    # ---- empalme ---------------------------------------------------------
    ult_ext = list(re.finditer(r'^\[ext_resource[^\]]*\]$', txt, flags=re.M))[-1]
    txt = txt[:ult_ext.end()] + "\n" + "\n".join(ext) + txt[ult_ext.end():]

    marca = '[node name="Arena" type="Node3D"'
    corte = txt.index(marca)
    txt = txt[:corte] + "".join(sub) + "\n" + txt[corte:]

    txt = txt.rstrip() + "\n\n" + "".join(n) + "\n"
    io.open(SAL, "w", encoding="utf-8", newline="\n").write(txt)

    print("arena.tscn escrito")
    print("  muros de plaza : %d  (4 entradas de %.0f)" % (i, ENTRADA))
    print("  casas nuevas   : %d" % len(CASAS))
    print("  arboles        : %d" % len(arb))
    print("  barreras       : 4  (limite +-%.0f)" % LIMITE)


main()
