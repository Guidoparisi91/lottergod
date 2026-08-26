# LotterGod — Documento de producto

> **Estado: TODO ABIERTO.** No está definido de qué va el juego, cómo se gana,
> ni cuál es el final. Este documento existe para que el enfoque no se pierda
> entre sesiones — ya se perdió dos veces.
>
> Última actualización: 2026-08-25

---

## 0. Cómo leer este documento

Cada idea está marcada con su nivel de compromiso:

- **[DECIDIDO]** — acordado, no se re-discute sin motivo nuevo
- **[TENDENCIA]** — propuesto y sin objeción, pero no confirmado
- **[ABIERTO]** — sobre la mesa, sin resolver
- **[DESCARTADO]** — evaluado y dejado de lado, con el motivo

---

## 1. Qué estamos haciendo

Rescatar un prototipo de ARPG top-down que quedó abandonado por aburrimiento,
y convertirlo en **algo terminado, mostrable y jugable por gente real**.

Objetivo del ejercicio: recorrer el proceso completo de hacer un juego —
diseño, producción, publicación, marketing— y usarlo como experimento de
monetización.

**Referencias que nos gustan:** Helbreath (riesgo, equipo perdible, servidor
chico donde te conocés con todos), League of Legends (combate ajustado,
cooldowns, expresión de skill).

**[DECIDIDO]** Partimos de este prototipo, no de cero.

**[DECIDIDO]** Assets gratuitos/placeholder por ahora, pero el objetivo es que
se vea lindo: VFX, sonido, un mapa cuidado.

---

## 2. Qué tenemos (inventario honesto)

Esto es el 60% difícil de cualquier juego de acción, y ya está hecho.

| Sistema | Estado |
|---|---|
| Combate top-down click-to-move | Funciona, **tiene bugs sin catalogar** |
| 4 acciones (básico + Q/W/E) con cooldowns, cargas, dash, chain attack | Funciona |
| Netcode host-autoritativo (ENet) | Funciona |
| IA de enemigos: IDLE / PATROL / CHASE / APPROACH | Funciona |
| Jerarquía `BaseEnemy → AnimatedEnemy → MeleeEnemy` | Refactorizada 2026-08-25 |
| Boss con fases por umbral de HP (Goblin King) | Funciona |
| `wave_manager.gd` — oleadas por tiempo con escalado | Funciona |
| `CombatFeedback` — flash, hitstop, números de daño, partículas | Nuevo, 2026-08-25 |
| Cámara isométrica, cursor, HUD | Funciona |
| Terrain3D + mundo abierto | Funciona, **probablemente se descarta** |
| Loot | **No existe** |
| Sonido | **No existe** |
| Backend / cuentas / persistencia | **No existe** |

---

## 3. Diagnóstico: por qué se volvió aburrido

La frase de la charla original fue *"es el juego correcto en el envase incorrecto"*.
La evidencia está en el propio repo:

1. **`wave_manager.gd`** — oleadas por tiempo, `hp_mult = 1.0 + wave*0.15`, más
   enemigos por batch cada 5 waves.
2. **`enemy_pit`** estaba en `max_enemies = 100` / `spawn_interval = 2.0`.
   Se bajó a 12 / 4.0.
3. **La progresión**: `xp_to_next_level = level * 100`, y por nivel se gana
   **+10 HP y +0.25 de ataque**.

Los tres son el mismo intento: **arreglar el aburrimiento con volumen**. El
walk-back de 100 → 12 enemigos es el dato más honesto — se probó llenar la
pantalla y no funcionó.

El tercero es el peor: **nivel 10 se juega idéntico a nivel 1.** Mismas skills,
mismos cooldowns, mismas decisiones. Eso no es progresión, es una barra de carga.

Y el remate: el proyecto se llama *ARPG Looter Extractor* y **no tiene loot ni
extracción**.

### La tesis

Lo que está bien es el **momento a momento**. Nadie abandona un juego porque el
espadazo se siente mal — esa pelea ya está ganada.

Lo que está mal es el **envase**: un ARPG de mundo abierto infinito es un género
hambriento de contenido. Diablo y PoE no son divertidos por el combate, son
divertidos por 60 horas de actos y miles de items. Ese envase un dev solo no lo
llena nunca.

Y lo que nos gustaba de Helbreath **no era el género, era la apuesta**: salías de
la ciudad, podías perder tus cosas, alguien te podía cazar, y el servidor era
chico. Riesgo + reputación + población baja.

---

## 4. Principios acordados

Estas son reglas, no features. Sobreviven a cualquier concepto que elijamos.

**[DECIDIDO] Divertido con 1 jugador, mejor —no distinto— con 4.**
Un multijugador sin jugadores está muerto. El día 1 vas a estar solo.

**[DECIDIDO] El PvP es una capa, nunca el core.**
Cualquier diseño donde el PvP es obligatorio muere el día 1.

**[DECIDIDO] La pérdida es parcial, nunca total.**
Se pierde lo no asegurado de la corrida. Nunca los desbloqueos permanentes.
Conserva la codicia sin el churn.

**[DECIDIDO] La progresión tiene que cambiar decisiones, no números.**
+10 HP por nivel es el error a no repetir. Mejoras que cambian lo que hacés.

**[TENDENCIA] El gancho de retorno tiene que ser asincrónico.**
Es la jugada que se le roba a Clash of Clans: competencia que no exige que dos
personas estén online al mismo tiempo.

---

## 5. La decisión de distribución

> **Actualizado 2026-08-25 con datos de mercado.** Ver §13 para la investigación
> completa. Resumen: web-first se confirma, **pero itch.io no es el canal**.

**[DECIDIDO] Web primero. El canal es CrazyGames, no itch.io.**

Los números que lo deciden:

| Canal | Alcance | Ingreso realista | Veredicto |
|---|---|---|---|
| CrazyGames | 50 M jugadores/mes, 300 M partidas/mes | USD 500–3.000/mes | **Canal principal** |
| itch.io | ~4.800 partidas en el percentil 70, sin cola larga | ≈ USD 0 | Vidriera y devlogs |
| Steam (indie) | 500–2.000 copias de mediana | USD 5.000–15.000 | Mediana brutal |
| Steam (roguelite) | 8.000–20.000 copias | USD 100.000–300.000 | Destino, no arranque |

CrazyGames acepta Godot oficialmente, tiene SDK, paga **60% de la publicidad** y 70%
de las compras, y su *Basic Launch* mide dos semanas de retención y tiempo de juego
reales **antes** de que exista monetización — o sea que **la señal que buscábamos
sale gratis**.

**Límites técnicos duros:** 50 MB de carga inicial, 250 MB totales, menos de 1.500
archivos. Un proyecto **vacío** de Unreal pesa 300–321 MB, y UE no exporta a HTML5
desde la 4.24 — por eso migrar de motor está descartado (§13.4).

**[DESCARTADO] itch.io como canal.** El razonamiento original —sin audiencia, lo que
manda es la fricción— era correcto; la plataforma estaba mal elegida. itch cicla
novedades rápido y no empuja tráfico sostenido. Queda como vidriera y para devlogs.

**[RESUELTO] Terrain3D no exporta a web.** Confirmado: su export HTML5 es experimental
y exige `SharedArrayBuffer` más aislamiento cross-origin, mientras que los portales
sirven builds de un solo hilo. Son incompatibles. **Ya se está trabajando sin él.**

<details>
<summary>Razonamiento original (histórico)</summary>

**[TENDENCIA] Web primero (itch.io + export HTML5).**

Razón: el problema número uno no es el diseño, es que **no hay a quién
mostrárselo**. La única variable que se mueve de verdad es la **fricción**.
Un link que abre y en 8 segundos estás jugando convierte muchísimo mejor que
una descarga. TikTok/IG → link en bio → jugando.

**Costo de esta decisión:**

- ENet/UDP no corre en browser → hay que migrar a WebSocket o WebRTC
- **RIESGO A VERIFICAR:** Terrain3D es un GDExtension pesado y puede no exportar
  a web. Es el único riesgo técnico serio del plan.

**Efecto secundario positivo:** si Terrain3D se cae, obliga a un mapa chico hecho
a mano en lugar de un terreno abierto y vacío — que es una de las razones por las
que el juego se sentía muerto. La restricción técnica y el buen diseño apuntan al
mismo lado.

**[ABIERTO] Play Store.** Descartado como primer paso (descubrimiento peor que
Steam para un desconocido). Pero si el juego va hacia idle + asincrónico, **es el
destino natural, no el plan B** — click-to-move ya es tap-to-move. Consecuencia
práctica: pensar resolución, UI y tamaño de botones para touch **desde ahora**.

**[DESCARTADO] Steam como primer lanzamiento.** La fricción de descarga mata un
lanzamiento sin audiencia. Sigue siendo válido más adelante.

**[DESCARTADO] ZeroTier.** Sirve para probar entre nosotros, pero es un muro
absoluto para cualquier desconocido.

</details>

---

## 6. El mapa

**[DECIDIDO] Pueblo abandonado, semioscuro, con escondites. Hecho a mano.**

No es decorado, es mecánica. Dos razones:

1. **Con visión limitada, dos jugadores alcanzan para que un mapa se sienta
   lleno.** En un mapa abierto e iluminado necesitás 10 personas para generar
   tensión. En un pueblo oscuro con esquinas, un solo desconocido moviéndose
   ahí adentro te tiene el pulso arriba. **La oscuridad es lo que hace que la
   baja población se sienta densa en vez de vacía.**

2. **La oscuridad es el director de arte más barato que existe.** Assets
   gratuitos a plena luz gritan "placeholder". Los mismos assets en un pueblo
   semioscuro con luces cálidas puntuales, niebla y contraste fuerte **se ven
   intencionales**.

Nota técnica: viniendo de UE la diferencia es menor de lo temido. No hay Nanite
ni Lumen. Se arma instanciando escenas (o GridMap si se quiere modular), y para
un pueblo oscuro van luces realtime + oclusión.

**[ABIERTO]** Qué pack de assets usar. Pendiente: buscar opciones
medieval-oscuro-abandonado que sean livianas para web.

---

## 7. Los cuatro ejes abiertos

El concepto no cerraba porque veníamos discutiendo géneros como paquetes
cerrados. Son cuatro decisiones **independientes y combinables**:

1. **¿Qué es una sesión?** — qué pasa en 10 minutos y cómo termina
2. **¿Qué está en juego?** — qué ganás y qué podés perder
3. **¿Por qué volvés mañana?** — el gancho de retorno
4. **¿Cuál es el contrato de PvP?** — cuándo y cómo se pelean los jugadores

| Concepto | Sesión | Stake | Retorno | PvP |
|---|---|---|---|---|
| Extracción pura | Incursión | Todo | Acumular | Siempre |
| Clash of Clans | Ataque corto | Poco | Base + ladder | Asincrónico |
| Roguelite | Corrida | La corrida | Desbloqueos | Ninguno |
| Arena libre | Continua | ? | ? | Si hay gente |

---

## 8. Ideas sobre la mesa

### 8.1 Extracción por rondas — **[DESCARTADO como forma pura]**

Rondas de 12-15 min, entrás, farmeás, salís por una puerta con el botín. Morís
y perdés todo.

**Por qué se descartó:** pide tres cosas que no tenemos. Población (si nadie te
puede robar, no hay tensión), un jugador hardcore que tolere perder todo (el
público de Tarkov, no el de un link de itch.io), y tiempo invertido para que la
pérdida duela. Alguien que llega de TikTok y pierde todo a los 6 minutos cierra
la pestaña.

**Qué se rescata:** la mecánica de la puerta —el multiplicador que sube mientras
te quedás— es una fuente de tensión que **no necesita otros jugadores**. Sirve
como pieza suelta.

### 8.2 Arena libre — **[ABIERTO, buena base]**

*"Si hay gente entra en esa arena, y si no la hay, pelea solo contra bichos."*

Idea de Guido, y ataca el problema que mata al 99% de los multiplayer indies.
Es la forma concreta del principio "divertido con 1, mejor con 4".

### 8.3 Roguelite con draft — **[ABIERTO]**

Entre oleada y oleada elegís 1 de 3 mejoras. No "+10 HP": cosas que cambian lo
que hacés — que el dash deje fuego, que la Q golpee en cono, que matar cure, que
el escudo al romperse explote. Diez corridas, diez personajes distintos.

**A favor:** resuelve el eje de progresión (decisiones, no números), y el
contenido más viral del género son clips de *"mirá la build rota que me salió"* —
así crecieron Vampire Survivors, Brotato y Risk of Rain. **Los jugadores generan
el marketing.**

### 8.4 Tablas / ladder competitivo — **[ABIERTO]**

Mencionado en la charla original junto con Clash of Clans. Competir por posición
en tablas en vez de por matar a alguien en tiempo real. Requiere el eje
asincrónico.

### 8.5 Idle + fantasmas — **[ABIERTO, es la idea más avanzada]**

Ver sección 9. Es hasta donde llegamos antes de parar.

---

## 9. Idle + fantasmas (desarrollado)

Idea de Guido: cuando estás conectado manejás el personaje; cuando te vas, queda
farmeando solo, menos eficiente, pero seguís mejorando.

### La observación clave: son el mismo sistema

- **PvP asincrónico** necesita: una IA que maneje tu personaje con tu build y equipo.
- **Idle farming** necesita: una IA que maneje tu personaje con tu build y equipo.

**Es una sola pieza de tecnología que paga cuatro veces:**

1. Tu personaje farmeando mientras no estás
2. Fantasmas para PvP asincrónico
3. **Relleno del mundo cuando no hay nadie conectado**
4. Un defensor de tu botín, estilo CoC

El punto 3 liquida el peor problema del proyecto: el pueblo nunca está vacío,
está lleno de personajes de otros jugadores farmeando dormidos. Y no es un truco
sucio — **son otros jugadores reales**, con su equipo y build, en piloto
automático. Es la jugada de Dark Souls y Death Stranding.

Se pasa de *"necesito población para que esto funcione"* a **"cada jugador que
entra una vez deja algo vivo en mi mundo para siempre"**.

### El ciclo diario que sale de ahí

1. Abrís el juego. Tu personaje estuvo 8 horas farmeando. Tiene la bolsa
   cargada... **o no, porque alguien lo cazó mientras dormías.**
2. Asegurás lo que sobrevivió, lo convertís en mejoras permanentes.
3. Jugás activo 15-20 min: farmeás mucho más rápido que el idle, cazás a los que
   están dormidos, vas por el boss.
4. Te vas. Dejás tu personaje ahí con todo lo que no aseguraste.

Gancho de retorno, apuesta y PvP — **los tres del mismo mecanismo**, sin
necesidad de que haya nadie conectado.

### La regla que le da dientes

Hace falta una razón para no asegurar todo y quedarte tranquilo. Si el
movimiento óptimo es "guardo todo y me voy", el PvP muere en una semana.

> **Para farmear tenés que estar presente. Y estar presente es estar expuesto.**

No podés idlear con el personaje desnudo. El equipo que tenés puesto es lo que te
hace farmear rápido, y es exactamente lo que está en riesgo. **Mejor equipo =
mejor idle = blanco más apetecible.** El que más gana es el que más tiene para
perder, automáticamente. Es Helbreath exacto, y encaja con el nombre del juego.

### Cómo se construye barato

**No hace falta simular el idle, hace falta contabilizarlo.** No se corren 500
personajes en un servidor. Se guarda cuándo se fue cada uno y con qué build;
cuando vuelve, se calcula lo que habría ganado. Su fantasma **se instancia bajo
demanda**, solo cuando otro jugador entra a esa zona. Es lo que hace casi todo
idle del mercado: 95% de la sensación por 10% del costo.

**El fantasma no debería ser un enemigo nuevo, sino el personaje con las manos
atadas.** En vez de escribir una IA que imite al jugador, se le enchufa a
`longsword.gd` una fuente de input falsa. Así usa las mismas skills, cooldowns,
dash y cadencia que un humano — pelea como un jugador porque *es* el jugador, y
cualquier balanceo aplica a ambos lados sin trabajo extra.

La jerarquía `BaseEnemy → AnimatedEnemy → MeleeEnemy` refactorizada el 25/08 es
el cimiento correcto para esto.

### Riesgos conocidos

1. **El idle se puede comer al juego.** Si farmear dormido da el 70% de lo que da
   jugar, no jugás. Disciplina: el idle **sostiene**, el juego activo
   **progresa**. El idle tiene techo (la bolsa se llena en ~8h y para). Rangos,
   desbloqueos y el boss solo se consiguen jugando.

2. **Esto sí necesita backend.** Cuentas, persistencia, servidor autoritativo. No
   es opcional: si el progreso vive en el cliente, el primer tipo con un editor
   de memoria queda primero en la tabla para siempre. **Hay que presupuestarlo
   desde el día 1.**

3. **Que te farmeen dormido puede ser espantoso.** Si entrás cinco días seguidos
   y te vaciaron, te vas. Hace falta el kit de CoC: pérdida parcial, techo a lo
   que te pueden sacar, y escudo después de que te cazan.

4. **El riesgo más serio: el público del idle y el del combate con skill no son
   el mismo.** Uno quiere que los números suban solos, el otro quiere ejecutar.
   Existe la chance de no contentar a ninguno.

   > **La regla que resuelve esto: no estamos haciendo un idle. Estamos haciendo
   > un juego de acción, y el idle es lo que pasa entre sesiones.** El combate es
   > el motivo para entrar, el idle es el motivo para volver. En el momento en
   > que el idle sea la parte divertida, nos equivocamos.

---

## 10. Presupuesto y marketing

**Presupuesto total: USD 500. Audiencia actual: cero seguidores.**

**[DECIDIDO]** Cubrir el 100% de los canales gratuitos: itch.io, Reddit
(r/godot, r/IndieDev), devlogs.

**[DECIDIDO]** Armar cuenta profesional de X.

**[ABIERTO]** Plata en TikTok / Instagram para conseguir views.

**Posición del PO sobre lo pago: no boostear en frío.** Un clip empujado con
plata que nadie compartiría gratis compra números que no significan nada. La
regla propuesta: subir ~20 clips gratis, mirar cuál despega **solo**, y recién a
ese meterle plata. Se paga para amplificar una señal ya validada, no para
inventarla. Hasta que exista ese clip, la plata no se toca.

**El experimento de monetización real** no es vender: es comprar información
barata. Una página con tráfico y ver cuánta gente quiere esto, antes de invertir
seis meses más.

---

## 11. Preguntas abiertas

- [ ] **¿De qué va el juego?** Sigue sin definirse el concepto, el final, ni la
      condición de victoria.
- [ ] **¿Qué se pierde exactamente cuando te cazan dormido?** Es la perilla que
      define si el juego es tenso o cruel.
- [ ] **¿El idle es tu personaje, o es una tropa?** Guido dijo tu personaje, y
      unifica todo. Pero la versión CoC —dejás algo *defendiendo* y salís a
      atacar con otra cosa— separa el riesgo de la ofensiva y es más amable.
      Cambia bastante el juego.
- [ ] ¿Cómo se combinan tablas/ladder con el idle?
- [ ] ¿Hay progresión de personaje único, o múltiples clases? (hoy solo existe
      Longsword)
- [ ] ¿Terrain3D exporta a web? — **verificar antes de comprometerse**

---

## 12. Próximos pasos (independientes de la decisión)

Estas tres cosas valen la pena en **cualquiera** de los caminos, así que no hay
tiempo perdido en arrancarlas antes de cerrar el concepto:

1. **Catalogar los bugs del combate.** Pendiente de Guido. Es el activo que
   estamos rescatando, y con el diseño de fantasmas el combate pasa a ser también
   el motor del idle y del PvP asincrónico — **cada bug ahí ahora vale triple.**
2. ~~**Armar el pueblo a mano.**~~ **EN CURSO desde 2026-08-25.** Ver §14.
3. ~~**Buscar assets**~~ **HECHO.** Quaternius Medieval Village MegaKit (CC0).

Pendiente de mantenimiento: ~~`CLAUDE.md` desactualizado~~ **actualizado 2026-08-25.**

---

## 13. Investigación de mercado (2026-08-25)

Documento completo: **[Tres Rutas para LotterGod](https://claude.ai/code/artifact/e1649f71-ba39-4b5d-8a76-29c9b0afe0f3)**

### 13.1 La extracción PvE funciona sola — **[REABRE §8.1]**

*Escape from Duckov*: extraction shooter **top-down, un solo jugador**, cinco personas,
**3,8 millones de copias**, 96% positivo, 300 K jugadores simultáneos.

El descarte de §8.1 era correcto para la extracción **PvP**. La variante **PvE** es hoy
uno de los géneros más validados del mercado. Y el propio documento ya tenía la pieza:
*"la mecánica de la puerta es una fuente de tensión que no necesita otros jugadores"*.
La tensión no la genera otro jugador: la genera **la mochila llena y el camino de vuelta**.

### 13.2 Lo que el mercado pide

- Sesiones de **20–40 minutos**, onboarding rápido, algo **finito**
- **Fatiga declarada de live-service** — esto rema en contra del idle (§9)
- El roguelite es el género que mejor convierte en Steam, no por el género sino porque
  **la meta-progresión convierte al que abandona frustrado en alguien que vuelve**
- Distribución brutal en web: 80% de los juegos gana USD 0–50/mes, **menos del 1% pasa
  de 2.000**. El rango realista para nosotros es **USD 200–2.000/mes**

### 13.3 Lo que enseña EvoWars.io (top 1 de CrazyGames)

Hallazgo de Guido. Es .io, top-down, con evolución dentro de la partida. Tres lecciones:

1. **Se explica en un GIF de tres segundos.** No tiene extracción, loot, ni
   meta-progresión. Tiene **una idea legible al instante**.
2. **Salió en marzo de 2018.** El top 1 es inercia acumulada, no un lanzamiento.
3. Su tráfico es tier-3 (Vietnam): mucho volumen, eCPM de USD 1–3 contra 15–28 en EEUU.

**La consecuencia para nosotros:** en un portal donde se elige por miniatura,
**explicar es perder**. Cualquier concepto que necesite un párrafo está en desventaja.

### 13.4 Migrar a Unreal — **[DESCARTADO, con datos]**

- **UE no exporta a HTML5** desde la 4.24 y UE5 nunca lo repuso. La única vía a
  navegador es Pixel Streaming: un servidor con GPU por jugador simultáneo.
- Un proyecto **vacío** de UE5 pesa **300–321 MB** empaquetado. CrazyGames acepta
  50 MB iniciales. No entra ni estando vacío.
- Se tirarían los 17 scripts: combate, jerarquía de enemigos, netcode, CombatFeedback.

Migrar = renunciar al único canal con tráfico real que además paga.

**El contraargumento que sí es real:** si trabajar en Godot resulta insoportable, la
estrategia no importa — un dev que pelea con su herramienta no termina el juego, y
este proyecto ya se abandonó una vez. Ese riesgo es más grande que cualquier cálculo
de mercado. La mitigación acordada: Guido no toca código; su superficie de contacto
con Godot es el editor de escenas, y las tareas repetitivas se automatizan.

---

## 14. Estado real al cierre del 2026-08-25

### El concepto sigue sin cerrar

Frase textual de Guido: **"todavía no siento la razón del juego"**. Se propuso un
roguelite de extracción PvE (§13.1) y **no convenció**. Su objeción, que es correcta:
*"por ahí estamos muy encasillados en un extractor"*. Sumado a §13.3, el problema es
que ese concepto **necesita un párrafo para explicarse**.

**[ABIERTO] La pregunta que reemplaza a "qué género".** Dejamos de elegir paquetes
cerrados. La pregunta operativa pasó a ser: **¿cuál es nuestro GIF de tres segundos?**

### 14.1 Robar habilidades — **[ABIERTO, propuesta sin evaluar]**

> **Matás un enemigo y te quedás con su habilidad.**

El goblin te da su swipe, el Goblin King su embestida. Cuatro slots. La decisión no es
"¿subo ataque?" sino "¿cambio la que tengo por esta?".

**A favor:** se ve en tres segundos · progresión que cambia decisiones y no números
(§4) · genera los clips de *"mirá la combinación que me salió"* · **convierte la
jerarquía de enemigos en un sistema de contenido**: cada enemigo nuevo es una
habilidad nueva · es **agnóstico del envase** — funciona en arena, en oleadas o con
extracción encima, así que el envase se elige después.

**Sin evaluar todavía.** Se prueba en una tarde con lo que ya está en el repo.

### 14.2 Corrección: el .io con bots se descartó mal

Se descartó la arena .io (§8.2, idea de Guido) por servidores caros y falta de
población. **Los .io resuelven eso con bots** — por eso Agar.io y Slither.io nunca
están vacíos. Y nosotros ya tenemos IA de enemigos y **el fantasma diseñado en §9 es
exactamente ese bot**, sin necesidad de backend.

§8.2 vuelve a estar sobre la mesa, y era mejor idea que la extracción.

### 14.3 El camino elegido para hoy: construir en vez de decidir

Decisión de Guido, y es la correcta: **empezar por lo que mejora el juego en
cualquier escenario** — mapa, sonido, UI. Con el fundamento agregado de que
**prototipar con sensación revela el concepto**: es más probable que la razón del
juego aparezca jugando un pueblo con sonido que discutiéndola en abstracto.

**Avanzado hoy:** el pueblo (§6) pasó de idea a escena jugable — piso de 200 × 200,
kit modular importado, primeras casas, parches de tierra y pasto, iluminación y
paleta corregidas, spawner de oleadas funcionando. Ver `CLAUDE.md` para el detalle
técnico y **[Armar el Pueblo](https://claude.ai/code/artifact/9765642f-e4a4-4539-88d1-13b20263b739)**
para el flujo de trabajo.

**Pendiente inmediato:** sonido (**el proyecto sigue mudo** y es el arreglo más barato
y más grande disponible), colisión en las casas, y conectar `wave_manager` al HUD.

### 14.4 Presupuesto

**Sigue intacto: USD 0 gastados.** Todo lo usado hoy es CC0 o gratis — Quaternius,
Sonniss GDC, Kenney, ambientCG. La regla de §10 (no boostear en frío) sigue en pie y
ahora tiene respaldo: el *Basic Launch* de CrazyGames da la señal de retención gratis.

---

## 15. El concepto, tomando forma (2026-08-26)

Propuesta de Guido al cierre del segundo día, después de jugar el prototipo:

> *"limpiar enemigos pequeños, limpiar boss, y entre medio pelear contra otro
> jugador o contra un Jugador IA"*

**[TENDENCIA] Arena por rondas con tres tipos de encuentro.**

| Encuentro | Qué se siente | Qué pone a prueba | Estado hoy |
|---|---|---|---|
| Oleada de chicos | Multitud, presión constante | Posicionamiento, área | **Funciona** (wave_manager) |
| Boss gigante | Duelo pesado y legible | Lectura de patrones | **Funciona** (GoblinKing) |
| Duelo vs jugador/IA | Alguien que juega como vos | Skill puro | **No existe** |

**Por qué funciona:** los tres se sienten distintos. Los survivors se vuelven
monótonos porque todo es la misma multitud; acá el ritmo tiene picos y valles y
cada ronda cambia qué tenés que hacer bien. Y respeta los cuatro principios
[DECIDIDO] de §4 sin excepciones.

### 15.1 El "Jugador IA" es el fantasma de §9

Guido llegó a la misma pieza por otro camino, sin acordarse del diseño anterior.
Eso es buena señal: la idea aparece sola cuando se piensa el problema.

**Se construye en dos etapas, y la primera es barata:**

1. **Bot con input falso.** Se le enchufa a `longsword.gd` una fuente de input
   sintética. Pelea como un humano porque *es* el personaje del jugador con las
   manos atadas: mismas skills, cooldowns, dash y cadencia. **Sin backend.**
2. **Fantasma completo.** Ese mismo bot se alimenta de builds de jugadores reales,
   y ahí aparece el gancho asincrónico de §9. Es una actualización, no un rediseño.

### 15.2 El contenido dejó de ser el problema

Verificado el 26/08: Quaternius —mismo autor que el Medieval Village— publica en
CC0 packs de monstruos (Ultimate Monsters, Easy Enemy, Animated Monster, Zombie,
Dinosaur), de personajes jugables (Universal Base Characters, RPG Character Pack,
Animated Knight, Modular Outfits) y la **Universal Animation Library** con 120+
animaciones **compatibles con rigs Mixamo**, que es el del personaje actual.

Con la jerarquía `BaseEnemy → AnimatedEnemy → MeleeEnemy` ya hecha, cada enemigo
nuevo es configuración, no código. **"Más enemigos" y "más personajes" dejaron de
ser la parte cara.**

### 15.3 Dónde está el riesgo, entonces

En el **tercer encuentro**. Oleadas y bosses ya funcionan; el duelo es lo único que
no existe, y es exactamente lo que separaría a este juego de otros cien survivors.

**[PROPUESTO] Prototipar el duelo antes que el contenido.** Un bot que pelee de
igual a igual en un ring, aunque sea feo. Si se siente bien, hay un juego con
identidad. Si no, mejor saberlo antes de importar veinte monstruos.

### 15.4 Lo que sigue sin cerrar

- **¿Cuál es el GIF de tres segundos?** (§14) El boss gigante es visualmente muy
  fuerte y el duelo también, pero todavía no hay una frase que lo explique solo.
- ¿Qué pasa entre rondas? El draft de §8.3 o el robo de habilidades de §14.1
  encajan acá, pero no están decididos.
- ¿La corrida tiene final, o se juega hasta morir?
