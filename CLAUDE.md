# LotterGod — ARPG Looter Extractor

## Stack
Godot **4.7.2** - GDScript - **`gl_compatibility`** - Jolt Physics - ENet multiplayer
- puerto 7777 (LAN local por IP directa, o ZeroTier si las maquinas no comparten red)

> El renderer es `gl_compatibility`, no Forward+: es lo correcto para web y ya está
> puesto en `project.godot`. Todo lo que se construya tiene que verse ahí, que es
> donde corren las pruebas (`--rendering-method gl_compatibility --rendering-driver
> opengl3`) y lo que el navegador va a usar vía WebGL 2.0.

**Las dos maquinas van con la misma version.** Si una abre el proyecto con otra, los
`.import` se reescriben y rebotan en git en cada pull. Instalar siempre con:
`winget install --id GodotEngine.GodotEngine --exact`

**Ejecutable** (winget, mismo layout en las dos maquinas salvo el nombre de usuario):
`%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64.exe`
Winget deja los alias `godot` y `godot_console` en el PATH (hay que reabrir la terminal).
El `_console` es el que hace falta para validar scripts.

> En esta PC quedó también el 4.6.2 portable suelto en `D:\Godot_v4.6.2-stable_win64.exe\`.
> **No abrir el proyecto con ese.**

> **El AssetLib viejo quedó reemplazado por el Asset Store nuevo y la migración de plugins
> NO fue automática.** Muchos addons de años anteriores no aparecen en la pestaña aunque
> existan y funcionen. Buscarlos directo en GitHub e instalar a mano copiando la carpeta
> a `addons/`.

## Concepto
ARPG top-down estilo Helbreath/LoL. Click-to-move, PvP + PvE, loot del equipamiento de enemigos/jugadores muertos. Progresión por nivel y stats.

---

## Estructura del proyecto
```
characters/longsword/    longsword.tscn + longsword.gd
enemies/
  base_enemy.gd          BaseEnemy      — estados, HP bar, daño, knockback
  animated_enemy.gd      AnimatedEnemy  — animaciones Mixamo y ritmo de ataque
  melee_enemy.gd         MeleeEnemy     — pega en rango
  base_boss.gd           BaseBoss       — fases por HP, resistencia a knockback
  enemy_pit.gd           EnemyPit — spawner/zona de patrulla reutilizable (@tool)
  goblin/                enemy.tscn + enemy.gd (extends MeleeEnemy)
  boss/                  goblin_king.tscn + goblin_king.gd (extends BaseBoss)
systems/
  network/               network_manager.gd  ← Autoload "NetworkManager"
  stats/                 character_stats.gd  ← Resource "CharacterStats"
  combat_feedback.gd     ← Autoload "CombatFeedback"
  wave_manager.gd        WaveManager — oleadas por tiempo alrededor del jugador
  terrain_manager.gd
maps/map_01/
  world.tscn/.gd         mapa original (con Terrain3D)
  pueblo.tscn            EL MAPA viejo — piso, casas, props. Solo geometría.
  pruebas.tscn           ESCENA JUGABLE vieja — pueblo + player, cámara, HUD,
						 spawner, boss, PlayerSpawn. De día, un solo spawn.
  arena.tscn             EL MAPA nuevo — generado desde pueblo.tscn. Plaza del
						 boss, anillo de casas, arboleda, barreras. Solo geometría.
  arena_pruebas.tscn     ESCENA JUGABLE nueva — la que se corre. Noche, dos
						 spawns opuestos, boss al centro, cuatro nidos.
  terreno/               datos de HTerrain (data.hterrain + height/normal/splat)
  casa_01.tscn           casa de ejemplo armada con piezas del kit
  parche_tierra/pasto*   Decals para manchas y transiciones
  zona_tierra/pasto      Planos superpuestos para cubrir áreas grandes
tools/                   NO son parte del juego, no se instancian en runtime
  generar_terreno.gd     genera maps/map_01/terreno/ (relieve por ruido)
  generar_arena.py       genera arena.tscn desde pueblo.tscn
  generar_arena_pruebas.py  genera arena_pruebas.tscn desde pruebas.tscn
  test_arena.*           verifica contención, entradas a la plaza y spawns
  ver_arena.*            saca fotos de planta y de suelo
  diag_click.*           qué golpea el raycast del click en cada zona de pantalla
  diag_mover.*           le pide al jugador ir a un punto y mide a dónde va
ui/
  hud/                   hud.tscn + hud.gd
  lobby/                 lobby.tscn + lobby.gd
shared/                  iso_camera.gd
assets/characters/PlayerCharacterLongsword/   FBX Mixamo
assets/environment/medieval_village/          Quaternius MegaKit (176 glTF)
assets/Textures/Piso/    adoquin_*.png — variantes corregidas de color
assets/Textures/Tierra/  tierra/pasto base + parches con alpha orgánico
MapTerrain/              datos Terrain3D (data_directory del plugin)
demo/                    demo Terrain3D — solo referencia, no tocar
addons/zylann.hterrain/  HTerrain — terreno por heightmap (ver abajo)
addons/3DGallery/        visor de modelos 3D (parcheado, ver abajo)
```

**Separación de escenas:** `pueblo.tscn` / `arena.tscn` son **solo el mapa**
(geometría, sin lógica). `pruebas.tscn` / `arena_pruebas.tscn` son las **escenas
jugables** que los instancian y les suman el jugador, la cámara, el HUD y los
spawners. Se construye en una y se prueba con F6 en la otra. Los enemigos y el
spawn del jugador van en la jugable, **nunca** en el mapa.

**Los mapas nuevos se generan, no se editan a mano.** `arena.tscn` sale de
`tools/generar_arena.py`, que parte de `pueblo.tscn` y le agrega todo. Si tocás
el `.tscn` directamente, el próximo `python tools/generar_arena.py` te lo pisa:
los cambios de planta van **en el generador**, donde además quedan explicados.

---

## Sistema de stats (CharacterStats)
Resource en `systems/stats/character_stats.gd`. Se instancia en `player._ready()` si no viene asignado desde el editor.

**Campos exportados (base):** `character_name`, `character_class`, `level`, `experience`, `base_max_hp` (100), `base_max_stamina` (200), `base_attack` (1.0), `base_defense` (0.0), `base_speed` (7.0)

**Stats calculados por `recalculate()`:**
- `max_hp      = base_max_hp      + (level-1) * 10`
- `max_stamina = base_max_stamina + (level-1) * 20`
- `attack      = base_attack      + (level-1) * 0.25`
- `defense     = base_defense     + (level-1) * 0.1`
- `speed       = base_speed` (sin escala por nivel aún)

**XP:** `xp_to_next_level = level * 100`. `add_experience(n)` devuelve `true` si subió de nivel.

**En longsword.gd:** stats se inicializa antes del check de autoridad (necesario para RPCs remotos). Damage aplica defensa: `actual = max(0, amount - stats.defense)`. Señales: `hp_changed`, `stamina_changed`, `xp_changed(current, max)`, `leveled_up(new_level)`.

---

## Personaje — Longsword (`characters/longsword/longsword.gd`)
**Convención de nombres:** cada personaje vive en `characters/<nombre>/` con archivos `<nombre>.gd` y `<nombre>.tscn`. No usar nombres genéricos como `player.gd`.

**Movimiento:** click-to-move, snap a grid de 1.5u. `stats.speed` = walk, `stats.speed * 1.114` = run (reducido 20%).
**Anti-stuck:** si el jugador no avanza ≥0.5u/s durante 0.35s, `moving = false` automático.
**Separación de obstáculos:** `_separation_force()` empuja al jugador lejos de mobs/players remotos en radio 2.2u. También tiene `NavigationAgent3D` listo para cuando se bake la navmesh.
**Stamina:** drena 10/s corriendo, regenera 100pts cada 5s.
**HP:** regenera 1pt cada 5s (timer se reinicia al recibir daño).
**Rango de ataque:** 2.5u. Kiting cancela el slash (excepto E).
**Chain attack:** si el botón queda apretado al terminar el slash, re-ataca automático.
**Muerte:** invisible, respawn en 3s en última posición segura.
**Level UP:** al subir de nivel aparece Label3D "Level UP!" amarillo sobre la cabeza, sube y desaparece (hijo del player para seguirlo en movimiento). En multijugador se replica a todos via `_rpc_show_levelup.rpc()` — todos los peers ven el cartel sobre el jugador que subió de nivel.
**Rotación en lugar:** right-click sobre el piso estando quieto → `face_toward(pos)` rota el personaje hacia ese punto sin moverse.

**Skills:**
| Skill | CD | Efecto |
|---|---|---|
| Ataque básico | — | `stats.attack * 10.0` |
| Q | 6s | Carga espada. Próximo ataque = `stats.attack * 15.0`. Hit a 15% de la anim. |
| W | 10s | Escudo 4s, absorbe todo el daño. |
| E | 7s, 2 cargas | Dash 9.6u + Jump Attack. Daño = `stats.attack * 12.0` en radio 1.8u. No cancelable. |

**Animaciones Mixamo** (`assets/characters/PlayerCharacterLongsword/`):
`Idle.fbx`, `Walking.fbx`, `Running.fbx` (In Place), `Great Sword Slash.fbx` (1.5x speed), `Great Sword Jump Attack.fbx` (root motion XZ eliminado en `_fix_root_motion()`, Y preservado).

---

## HUD (`ui/hud/`)
Tres barras apiladas en esquina inferior izquierda. Cada fila: `[Label fijo] [ProgressBar con texto dentro]`.
- **HP** — rojo, texto `current/max` centrado dentro de la barra
- **SP** (Stamina) — verde
- **XP** — dorado, a la derecha muestra `Lv X` (se actualiza con señal `leveled_up`)

`hud.setup(player)` conecta las 4 señales del jugador. Llamar solo para el jugador local.

---

## Enemigos

**Jerarquía** (refactorizada 2026-08-25):
```
BaseEnemy → AnimatedEnemy → MeleeEnemy → GoblinEnemy
									  → BaseBoss → GoblinKing
						 → RangedEnemy → (futuro)
```
- **BaseEnemy** — estados, HP bar, daño, muerte, knockback, sincronización de red
- **AnimatedEnemy** — capa de presentación: animaciones Mixamo separadas por nodo y
  ritmo de ataque. Dispara `_deliver_hit()` en el frame correcto; no decide qué hace
  el golpe. Exports: `body_scale`, `attack_anim_speed`
- **MeleeEnemy** — implementa `_deliver_hit()` pegando en rango
- **BaseBoss** — `knockback_resistance` alto, wind-up lento, fases por umbral de HP
  (`_on_phase_changed()`), feedback amplificado vía `feedback_scale`

**Puntos únicos de entrada** (respetarlos al extender):
- `_apply_damage(amount)` — **todo** lo que baja HP pasa por acá
- `_on_damaged(amount)` — hook para subclases (fases, enrage, gritos)
- `_get_sync_anim()` / `_apply_sync_anim()` — animación en multijugador

**Caída del mapa:** por debajo de `VOID_Y = -30` el enemigo se descarta solo con
`_despawn_por_caida()`. **No es una muerte**: no da XP, no dispara el estallido y no
suma bajas — solo libera el cupo. Sin esto, un enemigo cayendo al vacío queda vivo
para siempre en el grupo `enemy` y ahoga al spawner, que nunca vuelve a bajar de su
tope de vivos.

**BaseEnemy** (`enemies/base_enemy.gd`): estados `IDLE / PATROL / CHASE / APPROACH`, HP bar 3D billboard, knockback.

**Sistema de patrulla:**
- Estado inicial: `PATROL` → camina a punto random dentro de `patrol_size` (Vector2) centrado en `spawn_position`
- Al llegar al punto: `IDLE` con timer random 2–5s → vuelve a `PATROL`
- Al detectar jugador (radio `detection_range`): `CHASE` — persigue y ataca
- `set_patrol_area(center: Vector3, size: Vector2)`: permite que el pit sobreescriba el área de patrulla post-spawn
- `_pick_patrol_target()`: samplea punto random dentro del rectángulo definido por `patrol_size`

**EnemyPit** (`enemies/enemy_pit.gd`): Node3D con `@tool`. Exports: `enemy_scene`, `max_enemies`, `patrol_size: Vector2`, `spawn_interval`.
- Gestiona su propio pool de enemigos (array de refs, filtra muertos con `is_instance_valid`)
- Spawna con raycast hacia abajo para encontrar la altura real del terreno
- Gizmo naranja (rectángulo) visible en el editor, se actualiza en tiempo real al cambiar `patrol_size`
- En multiplayer: solo el host spawnea, clientes reciben via `_rpc_spawn.rpc(pos, eid)`
- `setup(player)` lo llama world.gd al spawnear el jugador local (grupo `"enemy_pit"`)
- Para agregar un pit: colocar Node3D en la escena, asignar `enemy_pit.gd`, configurar exports, posicionar

**Multijugador host-autoritativo:**
- Solo el host corre la IA y el `move_and_slide()`
- Sync 20Hz via `_sync_enemy_state.rpc()`: posición, rotación, HP, estado, animación (string)
- Clientes interpolan posición recibida (sin física local)
- Animaciones en clientes: 100% dirigidas por el sync. `_physics_process` retorna early en clientes antes del match de animación. Nunca derivar animación de `velocity` en clientes (es siempre 0).
- Patrón virtual para animaciones: `_get_sync_anim() -> String` y `_apply_sync_anim(anim)` en BaseEnemy. Cada subclase implementa ambos.
- Daño de cualquier cliente → `_take_damage_rpc.rpc_id(1, dmg)` → host aplica. `_take_damage_rpc` NO llama `take_damage()` internamente para no pisar `last_attacker_id`.
- XP solo al killer: `_die()` pasa `last_attacker_id` en `_rpc_die.rpc(killer_id)`. Cada peer solo da XP si `killer_id == multiplayer.get_unique_id()`.
- Knockback: mismo patrón, redirige al host

**Detección multi-jugador:**
- `_get_nearest_player()` en BaseEnemy itera `player_local + player_remote` para encontrar el jugador más cercano.
- `_check_vision()` actualiza `player` dinámicamente al más cercano cuando entra en rango.
- El jugador local se agrega al grupo `player_local` en `world.gd`. Remotos van a `player_remote`.
- Escala a N jugadores sin cambios.

**Goblin** (`enemies/goblin/`): HP 50, speed 3.5, detección 10u, ataque 2.0u cada 1.5s, XP 120. Animaciones: Idle, Walking, Swiping. Golpe conecta al 45% de la animación de swipe.

Para agregar enemigo nuevo: crear carpeta en `enemies/`, extender `BaseEnemy`, sobreescribir vars en `_ready()` antes de `super._ready()`, agregar `State.PATROL` en el match de animaciones.

**Ítems futuros:** host spawnea, sincroniza posición, cualquier cliente que agarra manda RPC al host, host valida y borra para todos.

---

## Combate cuerpo a cuerpo — las reglas

El enemigo **se compromete a cada golpe**: durante la animación no gira ni persigue.
Esa es la ventana de esquive, y es lo que hace legible la pelea.

| Perilla | Dónde | Qué hace |
|---|---|---|
| `turn_speed` | BaseEnemy | Giro gradual (`lerp_angle`). Bajo = pesado y fácil de rodear |
| `push_resistance` | BaseEnemy | 0 = se empuja como una caja · 1 = plantado |
| `aim_tolerance_degrees` | MeleeEnemy | Cuán encarado tiene que estar para **lanzar** |
| `hit_arc_degrees` | MeleeEnemy | Cuán ancho es el cono al **conectar** |
| `attack_anim_speed` | AnimatedEnemy | Bajo = wind-up largo y legible |

**La regla que importa: apuntar estricto, conectar permisivo.** `aim_tolerance` va
bastante más ajustado que `hit_arc`. Al revés, el enemigo lanza golpes de costado
que después fallan y se lee como que no entiende dónde estás. (Se probó al revés
y era exactamente eso.)

**Hooks de BaseEnemy** que las subclases sobreescriben:
- `esta_atacando()` — AnimatedEnemy lo ata a su animación. Bloquea giro y persecución
- `_tiene_de_frente(dir)` — MeleeEnemy lo ata a `aim_tolerance_degrees`
- `_girar_hacia(dir, delta, urgencia)` — giro gradual, **no hace nada si está atacando**

**Válvula anti-orbitado:** con el ataque listo pero sin poder encarar, `_espera_de_giro`
acumula y la urgencia sube hasta 3.5×. Sin eso, un jugador girando alrededor lo deja
dando vueltas para siempre sin lanzar un solo golpe.

**Anti-empujón:** `move_and_slide()` resuelve la penetración con el jugador corriendo
al enemigo de lugar — a un boss lo movés de a metros caminándole encima. Se descuenta
el desplazamiento que no vino de su propia velocidad:
`exceso = (pos_real - pos_previa) - velocity * delta`.

**Alcance del jugador:** `world.gd → _alcance_contra()` suma `BaseEnemy.radio_cuerpo()`
al `ATTACK_RANGE`. La distancia se mide contra el **centro**, así que sin esto un
enemigo escalado es imposible de golpear: su propio cuerpo ocupa todo el rango.

## Barra de HP — tres cosas que no son obvias

1. **`look_at()` destruye la escala.** Reconstruye la basis normalizada, así que hay
   que reponer `hp_bar_scale` justo después o la barra vuelve a tamaño 1 en el primer
   frame. Era el motivo de que la barra del boss se viera chica pasara lo que pasara.
2. **La altura se mide sola** del AABB del modelo (`_alto_cabeza()`, cacheada).
   `hp_bar_height` es solo el **margen sobre la cabeza** — no hay que retocarlo al
   cambiar `body_scale`.
3. **Las piezas van en el grupo `hp_bar_part`** para quedar fuera del loop de `_ready`
   que activa sombras en todos los meshes, y fuera del cálculo de altura.

## Tinte de cuerpo (`CombatFeedback.apply_tint`)

**No usar `material_overlay` con `SHADING_MODE_UNSHADED`**: una capa de color plano
encima aplana el modelo, le come el sombreado y se ve como una calcomanía. Lo correcto
es duplicar el material real y mover su `albedo_color` hacia el tinte — conserva
textura, volumen e iluminación, solo cambia de color.

## Spawners — dos sistemas distintos

| | `EnemyPit` | `WaveManager` |
|---|---|---|
| Dónde spawnea | Zona fija del mapa | **Alrededor del jugador**, radio configurable |
| Cuántos | Tope fijo (`max_enemies`) | Escala por oleada |
| Comportamiento | Patrullan hasta verte | Depende de `spawn_alerted` |
| Ritmo | Constante | Oleadas por tiempo, cada vez más rápido |
| Metáfora | Un **nido**: lo encontrás y lo limpiás | Un **asedio**: te llueven encima |

**WaveManager** (`systems/wave_manager.gd`, grupo `wave_manager`):
- `spawn_alerted = true` → nacen en `APPROACH`, van hacia el jugador **ignorando
  `detection_range`**. El `spawn_radius` solo define cuánto tardan en llegar.
- `spawn_alerted = false` → nacen en `PATROL` con área propia de 12×12 y solo
  reaccionan al entrar en `detection_range`. Ahí el `spawn_radius` **sí** importa
  y el mapa (esquinas, líneas de visión) pasa a ser mecánica.
- Nunca spawnea sin suelo: prueba `INTENTOS_SPAWN = 8` ángulos con raycast hacia
  abajo y, si ninguno da, **saltea el tick** en vez de soltar un enemigo al vacío.
- Señales listas para el HUD: `wave_started(wave)`, `stats_changed(wave, kills)`.
  Lleva `current_wave` y `kills_total`. **Todavía sin conectar al HUD.**

## Mapa — el pueblo

Construcción con el **Medieval Village MegaKit de Quaternius** (CC0, 176 piezas glTF).
Es un **kit de construcción**: no trae casas enteras, se arman con muros de 2 m,
esquinas y techos. Ver `casa_01.tscn` como referencia de encastre.

**Medidas del kit:** muros 2,00 × 3,12 m (centrados en X, base en Y=0) · piso 2 × 2 m
· `Roof_RoundTiles_6x6` cubre 8,24 m con aleros, hecho para una planta de 6 × 6.

**Escala:** el pack está en escala real correcta; **el personaje está sobredimensionado**
(su cápsula dice 1,80 m pero el modelo se ve como 3,50). Se compensa escalando el
mundo ×2 — `casa_01.tscn` tiene `scale = 2` en su raíz. **Deuda técnica**: lo correcto
sería achicar el personaje y recalibrar `TILE_SIZE`, rango de ataque y distancia de
cámara de una vez.

**Suelo:** un `PlaneMesh` grande con textura tileada como base, y encima:
- **Decals** (`parche_*.tscn`) para manchas y transiciones — no dan z-fighting
- **Planos superpuestos** (`zona_*.tscn`, y = 0.05) para cubrir áreas grandes de verdad
- La combinación: zona para el área, parches en el borde para romper la línea recta

**Color:** las texturas del pack son **cálidas por diseño** (pueblo mediterráneo
soleado): revoque +48 de amarillez (R−B), tejas +130, madera +62. Para corregir,
**no desaturar** —mata el color y queda gris muerto— sino **subir el azul y bajar
apenas el rojo**, que quita el tinte y conserva la vida. Ver `assets/Textures/Piso/`
para la escala de variantes ya generadas del adoquín.

**Iluminación:** ambiente **azulado** de baja energía + sol **cálido** = sombras frías,
luces cálidas. Un ambiente gris parejo aplasta la geometría. `tonemap_mode`: usar
**AgX (4)**, neutro; ACES (3) empuja todo hacia el naranja.

**Spawn del jugador:** un `Marker3D` llamado exactamente **`PlayerSpawn`** en la raíz
de la escena. `world.gd → _spawn_origin()` lo busca por nombre; sin él cae en la
constante `SPAWN_ORIGIN`. Ponerlo con `Y = 2` para que el personaje apoye bien.

## La arena (`arena.tscn` + `arena_pruebas.tscn`)

El mapa del juego que describe `DESIGN.md` §15.11b: **1v1, gana el que mate al
boss o al otro tres veces.** La planta no es decoración, sale de esa regla.

**200×200, origen al centro, jugable hasta ±97.** No hace falta que sea más
grande: con la cámara en brazo 5–20 ves ~40 unidades, así que de punta a punta
ya son ~40 segundos caminando. El problema del pueblo viejo era estar **vacío**,
no ser chico.

| Zona | Qué es | Qué produce |
|---|---|---|
| **Plaza del boss** (±24) | Amurallada, 4 entradas de 16, cuatro faroles de energía 6 | El **único** lugar iluminado y sin cobertura. Pegarle al boss te expone, que es la regla de §15.11b hecha de luz |
| **Anillo** | 12 casas, callejones, faroles tenues (energía 2.2) | Oscuro y seguro. Farmeás tranquilo, pero cada segundo ahí el otro le pega al boss |
| **Diagonal SO↔NE** | Despejada, pasa por la plaza | La ruta rápida entre spawns y la línea de visión larga: los momentos de "ahí está" |
| **Barreras** (±97) | 4 `StaticBody3D` invisibles de 24 de alto | Contención. Ver la trampa del raycast más abajo |

**La regla de la diagonal está en el generador, no puesta a ojo:** ninguna casa
ni árbol se coloca con `|z − x| < 16`. Si agregás props, respetala o la ruta
rápida deja de existir.

**Spawns:** dos `Marker3D` en el grupo `player_spawn`, en vértices opuestos
(±80). `world.gd → _spawn_origin(idx)` los ordena **por nombre casteado a
String** y le da uno a cada jugador. Sin grupo cae al viejo `PlayerSpawn` único,
así que `pruebas.tscn` sigue andando igual que antes.

**Nidos:** cuatro `EnemyPit`. Dos en las esquinas neutras (NO y SE, contestados)
y uno cerca de cada spawn. Además sigue corriendo el `WaveManager`, que spawnea
alrededor del jugador — son sistemas distintos y conviven (ver §Spawners).

**Iluminación: es mecánica, no adorno.** `DESIGN.md` §6 lo tiene `[DECIDIDO]`:
con visión limitada dos jugadores alcanzan para llenar un mapa; a plena luz
hacen falta diez. Los números que quedaron: ambiente 0.07, sol → luna (energía
0.22, azul), y **la niebla de 45 a 120** en vez de 90 a 190. Esa última es la que
recorta la visión de verdad; las otras dos son atmósfera.

> **Falta el navmesh.** Ahora hay muros de verdad que rodear y ni el jugador ni
> los enemigos saben hacerlo. Clic del otro lado de una casa = el personaje
> camina hasta la pared y se planta (lo frena el anti-stuck de 0,35 s).

## CombatFeedback (`systems/combat_feedback.gd`, autoload)

Flash de golpe, números de daño flotantes, hitstop, estallido de muerte, **viñeta
roja en pantalla** y **shake de cámara**. Puramente visual. Los enemigos lo modulan
con `feedback_scale`.

**Con enemigos, sin red:** todos los peers ven el golpe, así que cada cliente genera
el suyo del daño que ya recibió. Se dispara **antes** del redirect al host, para que
quien pega vea el golpe sin esperar el round-trip.

**Con jugadores, al revés: la víctima dispara y replica.** El daño PvP viaja por
`take_damage_rpc.rpc_id(dueño)`, así que **la víctima es el único peer que se entera**
—y el único que conoce el daño real, con defensa y escudo ya aplicados—. Por eso
`longsword.gd → _feedback_hit()` lo genera local y lo reenvía con
`_rpc_hit_feedback.rpc()` (unreliable: es adorno, no le compite ancho de banda al
daño, que sí es fiable). El costo es medio viaje de red antes de que el que pega vea
el impacto; en LAN es imperceptible.

**Efectos de pantalla** (`screen_flash` / `camera_shake`): van en el autoload y **no
en el HUD**, a propósito. El HUD es *información* —cuánta vida te queda—; esto es
*feedback de combate* y tiene que funcionar con cualquier personaje y con el HUD
apagado. La viñeta cuelga del autoload, así que sobrevive al cambio de escena y no
hay que instanciarla en cada mapa.

- Solo se tiñe la pantalla **de quien se come el golpe** (`is_multiplayer_authority()`).
  Pegarle a otro no te enrojece la tuya.
- Un golpe nuevo **pisa** al anterior en vez de encadenarse. Si se acumularan, una
  ráfaga de golpes flojos dejaría la pantalla roja varios segundos.
- El centro nunca se tiñe: taparte al personaje justo cuando más necesitás verlo es
  exactamente lo contrario de lo que buscamos.
- `camera_shake()` busca la cámara activa y le pide `shake()` por `has_method`, así
  el sistema no queda atado a `iso_camera`.

Perillas: `VIGNETTE_MAX` (opacidad), `VIGNETTE_TIME` (duración), el primer número del
`smoothstep` en `VIGNETTE_SHADER` (cuánto entra hacia el centro — más bajo, más ancha
la franja), y en `longsword.gd` el piso del `clampf` y el argumento de `camera_shake`.

## Trampas de trabajo (aprendidas a los golpes)

- **Godot pisa los archivos que tiene abiertos.** Si una escena está abierta en el
  editor, cualquier edición del `.tscn` desde afuera se pierde en el próximo guardado.
  **Antes de editar un `.tscn` por fuera, cerrar esa pestaña en Godot.**
- **Asignar un script REEMPLAZA el que había.** Un nodo tiene un solo script y Godot
  no avisa. Los spawners y marcadores van siempre en un `Node3D` **nuevo y vacío**,
  nunca encima de un nodo que ya tiene script.
- **`.glb` sobre `.fbx`.** El FBX de Mixamo metió 5 copias de cada textura. Godot
  también importa `.blend` nativo si Blender está configurado en Editor Settings.
- **El sufijo `-col` en el nombre del objeto** genera colisión automática al importar.
  `-colonly` para bloqueadores invisibles, `-noimp` para descartar.
- **`_setup_atmosphere()` respeta la escena:** si el `WorldEnvironment` ya tiene un
  Environment asignado, la función retorna sin tocar nada. La iluminación se ajusta
  visualmente, no por código.
- **`addons/3DGallery` está parcheado**: el original crasheaba en `GalleryManager.gd:30`
  al mover el mouse sin modelo cargado. Si se reinstala, el parche se pierde.
- **Para validar que los scripts compilan**, el comando es:
  ```
  Godot_v4.7.2-stable_win64_console.exe --headless --editor --quit --path .
  ```
  `--headless --quit` a secas **NO compila los scripts** y da falso "todo bien".
  Solo `--editor` fuerza el escaneo y regenera `global_script_class_cache.cfg`.
  Un `Could not resolve class "X"` casi siempre es en cascada: el error real está
  en el script que define esa clase, no donde aparece el mensaje.
- **`set_anchors_preset()` NO es `set_anchors_and_offsets_preset()`.** La primera
  mueve las anclas y recalcula los offsets para **conservar el rect actual** — que en
  un `Control` recién creado por código es **0×0**. El nodo queda en la escena, con su
  material y su shader andando, midiendo cero píxeles: no da error, no aparece en el
  remote tree como roto, simplemente no se ve. Para llenar la pantalla va
  `set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)`. Costó una sesión de
  debug de la viñeta de daño.
- **GDScript no reduce el tipo dentro de un `and`.** `if n is Foo and n.prop` falla
  en parseo porque `n.prop` se evalúa contra el tipo declarado. Castear antes:
  `var f := n as Foo` y después chequear `f == null`.
- **`func _physics_process(delta)` sin tipo hace que `delta` sea Variant**, y ahí
  `var x := algo * delta` no puede inferir el tipo. Tipar el parámetro o la variable.
- **`for x in [ ... ]` también da Variant.** `for dir in [Vector3.UP, ...]` y después
  `dir * 40.0` no infiere. Va `for dir: Vector3 in [...]`, o tipar el resultado.
- **Comparar dos `StringName` con `<` NO ordena alfabéticamente**, compara por hash
  interno. `sort_custom(func(a,b): return a.name < b.name)` sobre nodos devuelve un
  orden arbitrario **pero estable dentro de una corrida**, que es peor que aleatorio:
  parece que anda. Va `String(a.name) < String(b.name)`. Con esto los dos spawns de
  la arena se asignaban al revés y el jugador nacía en el vértice equivocado.
- **`PackedScene.pack()` sobre una escena INSTANCIADA la destroza.** El nodo raíz
  **pierde su script**, se pierde el `uid` de la escena y las instancias se aplanan a
  nodos con `type=` explícito. El juego arranca igual y falla más adelante (el mío:
  `pruebas.tscn` cargaba, pero sin `world.gd` en la raíz no spawneaba el jugador).
  **Para agregarle un nodo a una escena existente desde afuera, editar el `.tscn`
  como TEXTO.** Un diff sano de esa operación es puramente aditivo.
- **Un muro de colisión más alto que la cámara rompe el click-to-move.** La cámara
  iso vuela a `y ≈ 17`; las barreras de la arena miden 24, así que la cámara queda
  **dentro** del muro y cada click hacia el centro pega en su cara interna —que está
  detrás del jugador—. El personaje sale corriendo para atrás, clickees donde
  clickees. Las barreras van al grupo `barrera` y `world.gd → _raycast()` las
  excluye: **sólidas para caminar, invisibles para el mouse.** Los RID se cachean
  porque `_raycast` corre en cada frame para el cursor.
- **SimpleGrassTextured se corrige en DOS lugares.** Usa `light_mode = 1` ("Normal
  grass"), que apunta las normales hacia arriba: de noche la luna le pega de lleno y
  el pasto queda fosforescente al lado de todo lo demás. Bajarle el `albedo` **al
  material no hace nada** — el script del addon corre `update_all_material()` en
  `_ready()` y lo reescribe desde sus variables exportadas. Hay que ponerlo también
  en la propiedad `albedo` **del nodo**. En el editor se ve bien y al correr vuelve
  a estar blanco.
- **Un domain warp se suma escalado por su propia caída, nunca plano.** En el
  generador de terreno el warp le sumaba hasta 55 unidades al radio *en todo punto*,
  así que las lomas arrancaban mucho antes del límite y **el terreno asomaba por
  encima del piso dentro de la zona jugable**. Va multiplicado por el `smoothstep`
  sin warp, que vale 0 en la zona lisa.

## Cámara (`shared/iso_camera.gd`)
Isométrica. Pitch −30° a −80° (default −60°), yaw libre con click medio. Zoom ARM 5–20 (arranca en 20).

**`shake(amount, duration)`** — sacudón de impacto, lo dispara `CombatFeedback.camera_shake()`.
Tres cosas que no son obvias:
1. **El shake está en unidades de MUNDO**, así que el mismo valor se ve enorme con la
   cámara encima y no se nota desde lejos. Se escala por `arm / ARM_MAX` para que
   tiemble lo mismo **en pantalla** a cualquier zoom. Sin eso, calibrarlo es imposible:
   queda bien a una distancia y mal a todas las demás.
2. **No acumula.** Un golpe fuerte pisa a uno flojo, pero dos flojos no suman uno
   fuerte. Si se sumaran, una ráfaga de golpes chicos marea.
3. **La vertical va a la mitad.** En isométrica el temblor en Y se lee como que salta
   el piso, y marea mucho más rápido que el lateral.

## Cursor (`maps/map_01/world.gd → _update_cursor()`)
Crosshair blanco 24x24 generado por código. Rojo sobre grupo `enemy` o `player_remote`. Raycast cada frame.

---

## Multijugador
**Jugadores** — cada cliente es autoridad de su propio personaje.
- Sync 20Hz unreliable_ordered: posición, rotación, animación (`current_anim`), HP.
- Daño PvP: `take_damage_rpc.rpc_id(peer_id, dmg)`.
- Muerte/respawn: RPC reliable.
- `_ready()` en players remotos: todo lo visual (loop modes, `_fix_root_motion`) va ANTES del early return `if not is_multiplayer_authority()`. Los signals (`animation_finished.connect`) van DESPUÉS.
- Animaciones one-shot (slash, jump): `_set_state` permite replay si la animación ya terminó aunque `current_anim` no cambie — necesario para ataques encadenados vistos desde clientes remotos.
- Speed scale custom (ej: jump = `anim_length / E_DASH_DURATION`): el mismo cálculo debe estar en `_set_state` Y en el método que dispara la skill. Si solo está en uno, el remoto ve la animación a velocidad incorrecta.

**Enemigos** — host-autoritativo (ver sección Enemigos arriba).

**Flujo lobby:** Host → clientes se unen con la IP del host → host clickea Iniciar →
`change_scene_to_file("res://maps/map_01/pruebas.tscn")`. Todos los peers conectan antes de
cargar el mapa (no hay late-join).

**Probar en dos maquinas de la misma WiFi:** no hace falta ZeroTier, alcanza con la IP
local del host (`ipconfig` → adaptador Wi-Fi). ENet usa **UDP**: si el firewall de
Windows nunca pregunto, hay que abrir el 7777 UDP a mano en el host. Las dos maquinas
tienen que correr **la misma version de Godot**: si no, cada una reimporta los assets y
los `.import` rebotan en git de un lado al otro.

**Probar dos partidas en la MISMA maquina:** menu **Depurar -> multiples instancias**,
poner 2. En ese mismo dialogo cada instancia tiene su casilla de argumentos:

| Instancia | Argumentos |
|---|---|
| 1 | `--auto-host` |
| 2 | `--auto-join` |

Con eso F5 abre dos ventanas y **las dos entran solas a `pruebas.tscn`** — sin tocar
Hostear, Unirse ni Iniciar. Salen apiladas: arrastrar una al costado.

Flags de `ui/lobby/lobby.gd` (sin flags el lobby se comporta **exactamente** igual que
antes, así que no ensucian el build real):

| Flag | Qué hace |
|---|---|
| `--auto-host` | Hostea y arranca cuando hay suficientes jugadores |
| `--auto-join` | Se une a `127.0.0.1` |
| `--ip=192.168.0.5` | A dónde unirse (implica `--auto-join`) |
| `--jugadores=3` | Cuántos esperar antes de arrancar solo (default 2) |

Hay `AUTO_START_DELAY` de 0.4s antes del cambio de escena: le da margen al cliente
recién conectado para terminar de armarse. La carrera es rara pero real.

> **El hitstop se apaga solo con más de un peer** (cambiar `time_scale` en un cliente
> desincronizaría la simulación). Probando a dos ventanas vas a ver flash, viñeta y
> shake, pero **no** el micro-freeze. Ese solo se siente jugando solo.

Jugadores remotos en grupo `player_remote`, spawneados como `Player_{peer_id}`.

---

## Export web (2026-08-27) — **el portón está abierto**

**Existe build web y funciona.** Plantillas 4.7.2 instaladas, preset `Web` en
`export_presets.cfg`, single-thread (`variant/thread_support=false`) como pide
CrazyGames. El comando:

```
Godot_v4.7.2-stable_win64_console.exe --headless --export-release "Web" ../LotterWeb/index.html --path .
```

**Requisito no obvio:** el preset web exige
`rendering/textures/vram_compression/import_etc2_astc=true` en `project.godot`.
Sin eso el export aborta con *"configuration errors"* **y no dice cuál**. Ya está.

**Probado en Chrome, no solo exportado.** El lobby carga y renderiza. Al tocar
*Hostear* devuelve **"Error al crear servidor"**: ENet no puede abrir un socket UDP
en el navegador. Confirmado a mano, no deducido.

### Dos trampas del preset web, las dos pagadas a los golpes

**1. `exclude_filter="*.fbx"` te borra las MALLAS, no las fuentes.** Godot resuelve
`res://algo.fbx` **al recurso importado**, así que excluir el patrón excluye el `.scn`
que sí se usa. Síntoma: la escena no carga y la consola tira
`No loader found for resource: … .fbx (expected type: PackedScene)`. **El
`exclude_filter` va vacío**: Godot ya exporta solo lo importado, nunca los fuentes.
(Además falseaba el peso hacia abajo: el `.pck` medía 102 MB porque le faltaban los
personajes. Con las mallas adentro son 109 MB.)

**2. `vram_texture_compression/for_mobile=true` solo, deja el juego en blanco y negro
en escritorio.** Manda únicamente texturas **ETC2**, y **Chrome de escritorio (ANGLE)
no expone ETC2** — expone **S3TC**. Godot no puede subir ni una textura y todo queda
con el material gris por defecto. El síntoma es inconfundible: **todo monocromo menos
las barras de vida**, que son color plano sin textura y por eso sobreviven.

Hoy el preset va con `for_desktop=true` / `for_mobile=false` (S3TC). **Anda en
escritorio y NO andaría en un navegador de celular.**

> **La solución de verdad, pendiente: `compress/mode` = Basis Universal.** Manda **una
> sola copia** que se transcodifica en runtime a lo que soporte la GPU — S3TC, ETC2 o
> BC7. Arregla escritorio y móvil a la vez **y pesa menos que cualquiera de las dos
> variantes**, así que también empuja hacia los 50 MB. Es el próximo movimiento.

### El juego CORRE en el navegador — verificado, no deducido

Se probó en Chrome, no sólo exportado: **"Jugar solo" carga `pruebas.tscn` entero**
—pueblo, personaje, HUD, texturas y color correctos, cero errores en consola—.
Lo único que no anda es *Hostear*: ENet no abre sockets UDP en el browser (por eso
WebRTC, ver más abajo). **Tarda ~25 s en cargar el mapa** en la máquina de prueba
(Intel UHD, single-thread): a esta altura el peso ya no es un requisito de
CrazyGames, es experiencia de usuario.

### Dónde estamos contra CrazyGames

| Límite | Nosotros | |
|---|---|---|
| Menos de 1.500 archivos | **9** | ✅ |
| 250 MB totales | 142 MB crudos / **95 MB** transferidos | ✅ |
| **50 MB de carga inicial** | **95 MB** | ❌ **1,9× por encima** |

Se mide **comprimido**, que es lo que viaja por el cable (medido con `gzip -6`):

| | Crudo | gzip |
|---|---|---|
| `index.wasm` (el motor) | 37,7 MB | **9,7 MB** |
| `index.pck` (el juego) | 103,9 MB | **85,5 MB** |

El motor comprime 4×; **el `.pck` casi no comprime** porque las texturas ya vienen
comprimidas. O sea: **el problema es 100% texturas.** De los 101,8 MB de assets
importados que entran al `.pck`, **85,9 MB son texturas** y sólo 15,9 MB mallas.

### El techo real: 25 MB

Exportando **sólo lo que las escenas referencian**, el `.pck` da **22,6 MB crudos /
16,5 MB gzip**. O sea ~26 MB transferidos en total: **la mitad del límite.** El 78%
del `.pck` actual es contenido que no toca nadie.

> **PERO `export_filter="scenes"` NO se puede usar: rompe el juego.** Probado en
> Chrome — el lobby carga, y al entrar al mapa explota con `Preload file
> "longsword.tscn" does not exist`, `Cannot open file 'parche_tierra_2.tscn'`,
> `No loader found for T_WoodTrim_BaseColor.png` y `Identifier "BaseEnemy" not
> declared`. El escáner de dependencias de Godot se pierde **los `class_name`
> globales, las texturas que los `.gltf` referencian internamente, y hasta
> `preload` dentro de scripts**. El 25 MB sirve como número de referencia —cuánto
> margen hay— no como configuración.

### 28,6 MB del `.pck` son copias byte a byte

Verificado por MD5. **No es bajar calidad: es borrar repetido.**

| Dónde | Peso | Qué pasó |
|---|---|---|
| `PlayerCharacterLongsword` | **12,09 MB** | Mixamo extrajo las **mismas 3 texturas 5 veces**, una por FBX de animación |
| `medieval_village` | **15,00 MB** | `Textures/` y `glTF/` son el mismo set duplicado |
| `enemies/goblin/animations` | 1,18 MB | 3 copias |
| `nature_quaternius` | 0,33 MB | 2 copias |

De paso: de las **176 piezas del MegaKit sólo 6 estaban colocadas** antes de la
arena, pero **pesan 3,38 MB entre las 170 sin usar**. Las mallas no son el
problema; construir con el kit es gratis en peso.

### Lo que ya se sacó (rama `web-build`)

De **451 MB / 1.345 archivos** importados a **157 MB / 868**. Nada de esto era
contenido del juego:

| Qué | Peso | Por qué se fue |
|---|---|---|
| `Medieval Village MegaKit.zip` | 154 MB | El zip del pack, suelto en la raíz |
| `addons/terrain_3d` | 76 MB | GDExtension **sin binarios para web**: bloquea el export |
| `demo/` | 24 MB | Demo de Terrain3D |
| `Goblin.fbx` + sus 4 texturas | 44 MB | **Sin una sola referencia**: el goblin visible sale de los FBX de animación |
| `MapTerrain/` | 2,7 MB | Datos de Terrain3D |
| `world.tscn` | — | Usaba Terrain3D. `pruebas.tscn` usa `world.gd`, no el `.tscn` |

Está todo en `Desktop/lottergod_sacado/` — **movido, no borrado**.

**75 texturas capadas** por `process/size_limit` en el `.import`: el goblin estaba en
**4096×4096** (bajado a 512), personaje y pueblo en 2048 (a 1024). El importador solo
achica: si la textura ya es más chica, no la toca. **No se tocó el arte original**, así
que subir el techo de nuevo es cambiar un número.

### Lo que falta para entrar en los 50 MB, en orden de mejor relación

1. **Deduplicar las 28,6 MB de copias exactas.** Es la más grande y la única con
   **cero costo visual**. Empezar por el personaje (12 MB): los 5 FBX de animación
   extraen cada uno su propio set de texturas idénticas. Arreglo de fondo: `.glb`
   con texturas compartidas, o apuntar los materiales a un solo set.
2. **Bajar el pueblo de 1024 a 512.** Son texturas *tileadas*: aguantan mucho más
   recorte que un personaje. La aritmética es exacta —compresión por bloques, el
   peso escala con los píxeles—, así que media resolución es **un cuarto** del peso.
   Decisión visual.
3. **Basis Universal** (`compress/mode`). Manda una sola copia que se transcodifica
   en runtime a S3TC, ETC2 o BC7. Arregla escritorio y móvil a la vez y pesa menos
   que cualquiera de las dos variantes.
4. **Partir el `.pck`.** Godot carga packs adicionales en runtime: arrancás con el
   mínimo jugable y bajás el resto de fondo. La salida real para "50 MB iniciales"
   sin resignar contenido.

> `.godot/imported/` tiene basura de assets ya borrados (32 MB de texturas del
> goblin viejo en 4096). **No entra al `.pck`** —sin `.import` no se exporta— pero
> ensucia cualquier medición que se haga sobre esa carpeta. Medir siempre sobre los
> `dest_files` de los `.import` que existen, o directamente exportando.

> **`gl_compatibility` ya es el renderer** (`project.godot`), que es lo correcto para
> web. La mención a Forward+ al principio de este documento está vieja.

### Multijugador en web — WebRTC, no ENet

**ENet no corre en navegador** (verificado: *Hostear* devuelve "Error al crear
servidor"), y un browser **no puede aceptar conexiones entrantes**. Pero
`WebRTCPeerConnection` / `WebRTCDataChannel` / `WebRTCMultiplayerPeer` **vienen
incluidos en el export HTML5** — sin GDExtension, que en web no funciona (la consola
del propio build lo dice: *"single-threaded, no GDExtension support"*).

Dos navegadores **sí se hablan directo**. Hace falta un **servidor de señalización**:
un WebSocket mínimo que solo presenta a los peers e intercambia SDP/ICE. Mueve KB por
partida, no el tráfico del juego. Demo oficial: `networking/webrtc_signaling`.

**Lo que no se tira:** la API multijugador de Godot es **agnóstica del transporte**.
Se cambia `ENetMultiplayerPeer` por `WebRTCMultiplayerPeer` y **todo el código de RPC
queda igual** — enemigos host-autoritativos, `rpc_id`, sync a 20 Hz, todo.

Ver `DESIGN.md` §15.10 para el costo de STUN/TURN y las consecuencias de producto.

## Terreno — HTerrain (reemplazó a Terrain3D)

**Terrain3D quedó descartado y HTerrain lo reemplaza.** Es
`addons/zylann.hterrain` (Zylann, GDScript puro). **Verificado de punta a punta**:
compila en 4.7.2, renderiza en `gl_compatibility`, exporta a web y **corre en
WebGL 2.0 en Chrome sin un solo error de consola**. Cuesta +1,71 MB en el `.pck`.

> **El filtro para elegir addon es uno solo: que no traiga `.gdextension` ni
> binarios.** Terrain3D es GDExtension y en web no hay GDExtension (lo dice la
> propia consola del build: *"single-threaded, no GDExtension support"*). Eso es
> lo que lo mató, no el terreno en sí.

**Configuración actual** (nodo `Terreno` en la escena jugable): 513×513 vértices,
`map_scale (2,1,2)` = 1024 unidades de lado, `centered = true`, colisión activada,
shader `Classic4Lite`, `u_ground_uv_scale = 12`. Los datos pesan 1,2 MB.

**El terreno rodea al pueblo, no lo reemplaza.** Queda liso y a `y = -0.35` bajo
la arena (así el adoquín y las casas siguen apoyando igual) y sube en lomas hacia
afuera. `tools/generar_terreno.gd` lo genera; las perillas están arriba del
archivo.

**El perfil usa distancia al BORDE CUADRADO** (`max(|x|,|z|)`), no radial. Con
distancia al centro habría que dejar liso hasta 141 —la esquina del plano de
200×200— y las lomas quedaban tan lejos que el jugador, que ve unas 40 unidades,
no las veía nunca. Con el borde cuadrado arrancan a 104, justo pasado el adoquín.

### Cuatro cosas de HTerrain que no son obvias

1. **Carga su shader con `load()` por string** (`hterrain.gd:252`). Cualquier
   `export_filter` que no sea `all_resources` lo deja sin shaders y el terreno
   no aparece. Si tocás el preset, `addons/zylann.hterrain/shaders/*` va sí o sí
   en el `include_filter`.
2. **Las normales las hornea el editor** (`tools/normalmap_baker.gd`) cuando
   pintás con el pincel. Generando el heightmap por código hay que calcularlas a
   mano del gradiente — y **el paso horizontal no es 1, es `map_scale`**, o el
   relieve sale exagerado.
3. **Los PNG que escribe (`normal.png`, `splat.png`) necesitan una pasada de
   importación** antes de que carguen en runtime. Después de generar terreno hay
   que correr `--headless --editor --quit`, o tira *"Failed loading resource"*.
4. **El `doc/` del addon pesa 9,6 MB.** Excluirlo del export.

> Queda pendiente sacar Terrain3D de `world.tscn` y borrar el plugin (~50 MB de
> binarios). `base_enemy.gd` y `enemy_pit.gd` ya lo toleran: chequean
> `if _terrain and is_instance_valid(_terrain)` y caen a física normal si no está.

## Mesa de trabajo (rama `mesa-de-trabajo`, 2026-09-14)

Para **aprender** a hacer mapas, no para producir. Guido viene de Unreal (Modeling
Mode + Landscape) y en Godot no hay nada equivalente de fábrica.

**Camino elegido: Blender** (5.2.1, `winget install --id BlenderFoundation.Blender
--exact`). Se probaron y descartaron Cyclops (abajo) y GridMap con kit modular.
**La regla de reparto:** Blender hace la **geometría** (pisos, muros, cuevas);
Godot hace **todo lo que vive** (spawns, enemigos, luces, navmesh, triggers).

**La escena de práctica** sigue la separación de siempre:
- `maps/taller/taller_mapa.tscn` — se construye acá. Piso de 120×120 con un damero
  en coordenadas de mundo (shader propio, **cada cuadro = 1 u**, sirve de regla).
- `maps/taller/taller.tscn` — F6 acá. De día y sin niebla. Trae `cronometro.gd`:
  tiempo, distancia en línea recta y posición; **T** lo pone en cero y marca el
  origen. En grayboxing la planta se juzga con esos números.

### Cyclops Level Builder — probado y DESCARTADO

Addon de modelado dentro del editor (bloques, extrusión, booleanas). Pasaba el
filtro de web (GDScript puro) y sus bloques tenían colisión en el juego, pero
**la herramienta no se entendía**: interfaz rara, versión de desarrollo (1.5.0_dev)
y un solo autor. Veredicto de Guido: *"me parece horrible modelar directamente
adentro de Godot"*. Se sacó entero. Quedan dos lecciones que valen para
cualquier plugin:

- **`--headless --editor --quit` compila los scripts pero NO prueba el editor
  gráfico:** sin ventanas no hay menús nativos ni driver de video. Cyclops pasó
  limpio esa validación y después **cerraba Godot al abrir el proyecto**. Para un
  plugin nuevo, abrir el editor de verdad: `godot_console --editor --path .` con
  `timeout 60` — si sale por timeout (124) sobrevivió, si sale con 139 crasheó.
- **En esta PC (Intel UHD, OpenGL) destruir ventanas nativas tira el driver**
  (`igxelpicd64.dll`, segfault sin ningún error de GDScript antes). Cyclops
  destruía y recreaba sus menús desplegables en cada cambio de selección, y en
  Windows cada menú es una ventana. Se aisló por bisección. El arreglo, si otro
  plugin hace lo mismo: `Configuración del editor → Interfaz → Editor → Modo de
  ventana única` = ON. Es opción del editor, no del proyecto: no viaja por git.

## Input map
`shift_run` → Shift · `skill_q` → Q · `skill_w` → W · `skill_e` → E

---

## Pendiente (roadmap)

> **El orden lo manda `DESIGN.md` §15.7.** Esta lista es el inventario técnico; el
> plan de producción y qué está **estacionado a propósito** están allá (§15.6).

**Fase 0 — gamefeel + sonido** (en curso)
- [x] `CombatFeedback` cableado al jugador: flash, números y estallido en PvP
- [x] Viñeta roja de daño y shake de cámara
- [ ] **Sonido — hoy es cero.** Correr, atacar, recibir daño, morir + música de fondo.
      Packs libres: Kenney *Impact Sounds* y *RPG Audio* (CC0); música en Incompetech
      o FreePD. Van a `assets/audio/`.

**Fase 1 — sistema de habilidades** (siguiente)
- [ ] **Ulti con R en el Longsword** — *"Ejecución"*: cast ~0.6s inmóvil y
      telegrafiado, daño alto, ejecuta por debajo del 25% de HP y resetea su CD.
      Es el vehículo para construir la barra de casteo y la interrupción sin
      convertir al Longsword en caster (ver `DESIGN.md` §15.4)
- [ ] Cast time con barra, cancelable e interrumpible
- [ ] Skillshot lineal (proyectil) y skillshot al suelo con indicador
- [ ] Indicadores de apuntado en el piso
- [ ] Puntos de habilidad por nivel, rangos 1–3, R a nivel 6 (§15.3)

**Fase 2 — personaje 2**, opuesto al actual: caster a distancia, frágil
**Fase 3 — enemigos que telegrafíen** y obliguen a esquivar
**Fase 4 — loot** (solo el que cambia lo que hacés, no el que cambia cómo te ves)

**El mapa** (fuera de fase — es infraestructura para todo lo demás)
- [x] Terreno con relieve que sobrevive a la web (HTerrain, verificado en Chrome)
- [x] Arena 1v1: plaza del boss iluminada y expuesta, anillo oscuro, dos spawns
      opuestos, cuatro nidos, contención verificada (72/72 direcciones cerradas)
- [x] Noche: la iluminación como mecánica de visión (`DESIGN.md` §6)
- [ ] **NAVMESH — es el bloqueante, y ahora urge más.** Ni el jugador ni los
      enemigos saben rodear un obstáculo: `base_enemy.gd → _chase_and_attack()`
      persigue en línea recta y no tiene `NavigationAgent3D`; el jugador **sí**
      tiene el agente (`longsword.gd:276`) pero **no existe ningún
      `NavigationRegion3D` en el proyecto**, así que el path nunca es válido y cae
      al "va directo". Con la arena llena de muros, esto se nota en cada esquina.
      Verificar con UNA pared que el goblin la rodea antes de construir más mapa.
- [ ] Colisión para las piezas del kit: importan con **cero** colisión (0 de 198).
      `casa_01.tscn` tiene 14 `CollisionShape3D` puestos a mano. Automatizable.
- [ ] Variedad de casas: las 12 de la arena son todas `casa_01` y se nota. Quedan
      170 piezas del kit sin usar (voladizos, escaleras, balcones, cercas)

**Sin fase asignada**
- [ ] Animaciones de daño y muerte
- [ ] HP bar 3D sobre jugadores remotos
- [ ] **Peso web**: deduplicar 28,6 MB de copias exactas (ver §Export web). El
      export en sí ya está resuelto y verificado en Chrome
- [ ] Sacar Terrain3D de `world.tscn` y borrar el plugin (~50 MB)
- [ ] `systems/terrain_manager.gd` es **archivo muerto con referencias rotas**:
      hace `preload` de `res://demo/assets/models/Rock{A,B,C}.tscn` y `demo/` ya no
      existe. No lo usa nadie
- [ ] Catalogar los bugs del combate (`DESIGN.md` §12, pendiente hace tiempo)

**Estacionado** (ver `DESIGN.md` §15.6 para los motivos): equipo modular / cambiar el
look, progresión permanente entre partidas, idle + fantasmas, más mapa, personajes 3+.
