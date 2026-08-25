# LotterGod — ARPG Looter Extractor

## Stack
Godot 4.6 · GDScript · Forward+ · Jolt Physics · ENet multiplayer · ZeroTier (VPN LAN, puerto 7777)

## Concepto
ARPG top-down estilo Helbreath/LoL. Click-to-move, PvP + PvE, loot del equipamiento de enemigos/jugadores muertos. Progresión por nivel y stats.

---

## Estructura del proyecto
```
characters/longsword/    longsword.tscn + longsword.gd
enemies/
  base_enemy.gd          clase base BaseEnemy (class_name)
  enemy_pit.gd           EnemyPit — spawner/zona de patrulla reutilizable (@tool)
  goblin/                enemy.tscn + enemy.gd (extends BaseEnemy)
systems/
  network/               network_manager.gd  ← Autoload "NetworkManager"
  stats/                 character_stats.gd  ← Resource "CharacterStats"
maps/map_01/             world.tscn + world.gd
ui/
  hud/                   hud.tscn + hud.gd
  lobby/                 lobby.tscn + lobby.gd
shared/                  iso_camera.gd
assets/characters/PlayerCharacterLongsword/   FBX Mixamo
assets/Textures/         texturas terreno
MapTerrain/              datos Terrain3D (data_directory del plugin)
demo/                    demo Terrain3D — solo referencia, no tocar
```

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
**BaseEnemy** (`enemies/base_enemy.gd`): estados `IDLE / PATROL / CHASE`, HP bar 3D billboard, knockback.

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

**Flujo lobby:** Host → clientes se unen con ZeroTier IP → host clickea Iniciar → `change_scene_to_file("res://maps/map_01/world.tscn")`. Todos los peers conectan antes de cargar el mapa (no hay late-join).

Jugadores remotos en grupo `player_remote`, spawneados como `Player_{peer_id}`.

---

## Terreno
Plugin Terrain3D. `data_directory = "res://MapTerrain"`. No recibe sombras de objetos dinámicos (limitación del plugin). `DirectionalLight3D`: shadow_enabled, max_distance 256, blur 2.0.

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
