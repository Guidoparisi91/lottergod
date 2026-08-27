# LotterGod — ARPG Looter Extractor

## Stack
Godot **4.7.2** - GDScript - Forward+ - Jolt Physics - ENet multiplayer - puerto 7777
(LAN local por IP directa, o ZeroTier si las maquinas no comparten red)

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
  pueblo.tscn            EL MAPA — piso, casas, props, luces. Solo geometría.
  pruebas.tscn           ESCENA JUGABLE — instancia pueblo + player, cámara,
						 HUD, spawner, boss, PlayerSpawn. Es la que se corre.
  casa_01.tscn           casa de ejemplo armada con piezas del kit
  parche_tierra/pasto*   Decals para manchas y transiciones
  zona_tierra/pasto      Planos superpuestos para cubrir áreas grandes
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
addons/3DGallery/        visor de modelos 3D (parcheado, ver abajo)
```

**Separación de escenas:** `pueblo.tscn` es **solo el mapa** (geometría, sin lógica).
`pruebas.tscn` es la **escena jugable** que lo instancia y le suma el jugador, la
cámara, el HUD y los spawners. Se construye en una y se prueba con F6 en la otra.
Los enemigos y el spawn del jugador van en `pruebas`, nunca en `pueblo`.

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

## CombatFeedback (`systems/combat_feedback.gd`, autoload)

Flash de golpe, números de daño flotantes, hitstop y estallido de muerte. Puramente
visual, **sin sincronización de red**: cada cliente lo genera del daño que ya recibió.
Se dispara **antes** del redirect al host, para que quien pega vea el golpe sin
esperar el round-trip. Los enemigos lo modulan con `feedback_scale`.

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
- **GDScript no reduce el tipo dentro de un `and`.** `if n is Foo and n.prop` falla
  en parseo porque `n.prop` se evalúa contra el tipo declarado. Castear antes:
  `var f := n as Foo` y después chequear `f == null`.
- **`func _physics_process(delta)` sin tipo hace que `delta` sea Variant**, y ahí
  `var x := algo * delta` no puede inferir el tipo. Tipar el parámetro o la variable.

## Cámara (`shared/iso_camera.gd`)
Isométrica. Pitch −30° a −80° (default −60°), yaw libre con click medio. Zoom ARM 5–20 (arranca en 20).

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

Jugadores remotos en grupo `player_remote`, spawneados como `Player_{peer_id}`.

---

## Terreno — **en salida**
Plugin Terrain3D. `data_directory = "res://MapTerrain"`. No recibe sombras de objetos dinámicos (limitación del plugin). `DirectionalLight3D`: shadow_enabled, max_distance 256, blur 2.0.

> **Terrain3D no sobrevive a la web.** Su export HTML5 es experimental y exige hilos
> con `SharedArrayBuffer` más aislamiento cross-origin; los portales sirven builds de
> **un solo hilo** (el modo por defecto desde Godot 4.3 y el único que aceptan Poki y
> CrazyGames). Son incompatibles. `pueblo.tscn` ya se construye sin Terrain3D, y el
> código lo tolera: `base_enemy.gd` y `enemy_pit.gd` chequean
> `if _terrain and is_instance_valid(_terrain)` y caen a física normal si no está.
> Queda por sacarlo de `world.tscn` y borrar el plugin (~50 MB de binarios).

## Input map
`shift_run` → Shift · `skill_q` → Q · `skill_w` → W · `skill_e` → E

---

## Pendiente (roadmap)
- [ ] Sistema de loot (drop de items al morir enemigo)
- [ ] Inventario + pantalla de equipamiento
- [ ] Persistencia de CharacterStats a disco por cuenta
- [ ] Más enemigos (×10 objetivo) y bosses
- [ ] Animaciones de daño y muerte
- [ ] HP bar 3D sobre jugadores remotos
- [ ] Assets medievales (Kenney Castle Kit + Nature Kit)
- [ ] Múltiples personajes elegibles
- [ ] Múltiples mapas
