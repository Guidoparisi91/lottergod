# LotterGod — Documento de producto

> **Estado: TODO ABIERTO.** No está definido de qué va el juego, cómo se gana,
> ni cuál es el final. Este documento existe para que el enfoque no se pierda
> entre sesiones — ya se perdió dos veces.
>
> Última actualización: 2026-08-27

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

---

## 15. Cierre del 2026-08-27 — la sesión y las habilidades

### 15.1 Qué es una sesión — **[ABIERTO]**

> Entrás a la arena. Subís de nivel matando. Tenés **3 vidas**. **Ganás si matás
> al boss.**

**Es una posibilidad, no una decisión.** Salió como respuesta tentativa de Guido
—*"tal vez hasta que se muera X veces o hasta que maten al boss"*— y quedó
anotado acá como `[DECIDIDO]` por error del PO. Corregido el 27/08. Sigue siendo
la forma más concreta que apareció hasta ahora, pero **el eje 1 de §7 sigue
abierto**.

Lo que sí vale de esta forma, gane o no: la duración **no se mediría en minutos,
se mediría contra el boss**, y el techo de nivel se tunearía contra el encuentro
final en vez de contra un reloj.

> **De qué depende esto.** §15.2 (*"lo que da poder se resetea"*) y §15.3 (puntos
> de habilidad por partida) dan por sentado que existe **una corrida que termina**.
> Si el envase termina siendo continuo en vez de por partidas, esas dos secciones
> hay que reescribirlas, no solo retocarlas.
>
> El plan de producción de §15.7 **no** depende de esto: la R, el sonido, el
> personaje 2 y los enemigos que telegrafían valen igual en cualquier envase.

### 15.2 La regla de la progresión — **[DECIDIDO]**

> **Lo que da poder se resetea. Lo que da variedad se acumula.**

- **Rangos de habilidad = poder** → viven dentro de la partida y se van con ella.
- **Personajes desbloqueados = variedad** → se guardan.

Tres razones duras, no estéticas:

1. La progresión permanente exige backend (§9, riesgo 2). Si el progreso vive en
   el cliente, el primero con un editor de memoria queda arriba para siempre.
2. En CrazyGames el jugador llega de una miniatura y sin cuenta. Un meta
   permanente que da poder hace que **la primera partida sea la peor del juego**.
   Con PvP encima, es letal.
3. Desbloquear personajes **sí** se puede guardar local y gratis: si alguien lo
   hackea, se auto-regala contenido y no le arruina la partida a nadie.

Es la aplicación directa del `[DECIDIDO]` de §4: *"nunca los desbloqueos
permanentes"*.

**El lobby es selección de personaje, no gestión de build.** La meta permanente
se rediscute cuando exista backend.

### 15.3 El sistema de habilidades — **[TENDENCIA]**

Cuatro slots: **Q, W, E, R**. La R es la ulti y se desbloquea a **nivel 6**
(igual que LoL, y por el mismo motivo: es el mejor momento de la partida
temprana, cuando aparece una herramienta que antes no existía).

| | Rangos | Puntos para maxear |
|---|---|---|
| Q / W / E | 3 | 9 |
| R | 2 | 2 |
| **Total necesario** | | **11** |
| **Disponibles a nivel 10** | | **10** |

**El desfasaje de 1 punto es a propósito: nunca podés maxear todo.** En LoL a
nivel 18 tenés todo y la decisión es solo el *orden*. Si el techo alcanza, no hay
decisión, hay secuencia.

**El rango no puede ser "+10 de daño"** (§4):
- **Rango 1 → 2:** sube números. Es la recompensa de relleno, barata.
- **Rango 3:** **muta la habilidad** — cambia qué hace, no cuánto hace.

Ejemplos con lo que ya existe: E rango 3 pasa a 3 cargas *y* el dash deja fuego;
Q rango 3 pega en cono en vez de a un solo objetivo. Una sola variante por
habilidad: barato de construir, y es el momento de *"mirá lo que me salió"*.

**Paso siguiente natural, no construir todavía:** que en rango 3 **elijas entre
dos mutaciones**. Ahí el draft de §8.3 queda metido *adentro* del sistema en vez
de pegado por afuera.

**Nivel 10 es un número, no una estructura.** Lo caro es que exista un punto por
nivel, que exista el rango 3 que muta y que la R llegue a nivel 6. Eso funciona
igual con techo 10, 18 o 25. **Las estructuras se discuten, los números se
prueban.**

### 15.4 La R del Longsword — **[TENDENCIA]**

El Longsword se queda como el bruiser instantáneo (nada que errar, a propósito),
pero su ulti es el vehículo para construir el **cast time** sin convertirlo en
caster:

> **R — Ejecución.** Cast de ~0,6 s inmóvil y telegrafiado (esquivable,
> interrumpible). Si conecta: daño masivo, y si el objetivo queda por debajo del
> 25 % de HP, **lo ejecuta** y la R vuelve a estar lista.

Se lee en tres segundos, encaja con el "compromiso al golpe" que ya es la firma
del combate, castiga la avaricia, y **obliga a construir barra de casteo,
interrupción y telegrafiado** — la mitad de la Fase 1. El skillshot puro queda
para el personaje 2, que es donde corresponde.

### 15.5 Loot: dos cosas que parecen una — **[DECIDIDO]**

- **Loot que cambia lo que podés hacer** — es *data*, no arte. Barato. Cae
  durante la corrida y se va con la corrida (§15.2).
- **Loot que cambia cómo te ves** — es *equipo modular*: cuerpo partido en piezas
  intercambiables, todas riggeadas al mismo esqueleto, y cada variante suma malla
  y texturas contra **50 MB**. Es un proyecto en sí mismo. **Estacionado.**

**El atajo:** cambiar **solo el arma**. Es una malla suelta pegada a un hueso de
la mano — un punto de anclaje, no un sistema. Da el 80 % de la sensación de
"conseguí algo" al 5 % del costo.

### 15.6 La lista de lo que NO estamos haciendo

El *"faltan demasiadas cosas"* no viene de la cantidad de trabajo: viene de que
**la lista no tiene borde**. Nada de acá está cancelado; está **estacionado**.

| Estacionado | Motivo | Vuelve cuando |
|---|---|---|
| Equipo modular / cambiar el look | Carísimo, y pega contra los 50 MB | Haya jugadores reales |
| Progresión permanente entre partidas | Exige backend y plata | Haya backend |
| Idle + fantasmas (§9) | Depende de lo anterior | Ídem |
| Robar habilidades (§14.1) | **[DESCARTADO]** por Guido: el goblin no tiene nada distintivo que robar | — |
| Terrain3D | No exporta a web | Nunca |
| Personajes 3, 4, 5… | El 2 todavía no existe | El 2 esté andando |
| Más mapa | No sabemos para qué formato | Fase 3 |

### 15.7 El plan de producción — cuatro fases

Ninguna depende de decisiones pendientes.

| Fase | Qué | Estado |
|---|---|---|
| **0** | Gamefeel del jugador + sonido | Feedback **hecho**, falta sonido |
| **1** | Sistema de habilidades: skillshot, cast time, indicadores, R | Siguiente |
| **2** | Personaje 2, **opuesto** al actual: caster a distancia, frágil | — |
| **3** | Enemigos que telegrafíen y obliguen a esquivar | — |
| **4** | Loot (solo el que cambia lo que hacés) | — |

**Fase 0, detalle.** Hallazgo verificado el 27/08: **`CombatFeedback` no se usaba
ni una vez en `longsword.gd`** — estaba enchufado solo del lado de los enemigos.
El PvE tenía todo el feedback y **el PvP estaba mudo**. Hecho:

- `CombatFeedback.screen_flash()` — viñeta roja difuminada en los bordes, con
  shader. Vive en el autoload y no en el HUD: es feedback de combate, no
  información, y tiene que andar con cualquier personaje.
- `CombatFeedback.camera_shake()` → `iso_camera.shake()`. La vertical va a la
  mitad: en isométrica el temblor en Y se lee como que salta el piso.
- Flash, número de daño y estallido de muerte en el jugador, **replicados a todos
  los peers**. Con enemigos cada cliente genera el suyo; con jugadores no se
  puede, porque el daño viaja por `rpc_id(dueño)` y **la víctima es el único peer
  que se entera** —y el único que conoce el daño real con defensa y escudo ya
  aplicados—, así que es ella la que dispara y replica.

Ajustado al probarlo: el shake bajó a menos de un tercio y ahora **escala por
zoom** (estaba en unidades de mundo, así que quedaba bien a una distancia y mal a
todas las demás). La franja roja se angostó. El detalle técnico está en `CLAUDE.md`.

Pendiente de Fase 0: **sonido** (hoy es cero). Packs libres: Kenney *Impact
Sounds* y *RPG Audio* (CC0) para golpe, impacto y muerte; Incompetech o FreePD
para la música. Van a `assets/audio/`.

**De yapa, no estaba planeado:** `ui/lobby/lobby.gd` acepta `--auto-host` /
`--auto-join` para levantar dos partidas en la misma máquina con F5 y cero clicks.
Ver `CLAUDE.md → Multijugador`. Acorta el ciclo de prueba de PvP a segundos.

### 15.8 El portón web — **ABIERTO, con número** (27/08)

Se probó. **Hay build web y funciona.** Los detalles técnicos están en `CLAUDE.md`;
lo que importa para el producto:

| Límite CrazyGames | Nosotros | |
|---|---|---|
| Menos de 1.500 archivos | 9 | ✅ |
| 250 MB totales | 92 MB transferidos | ✅ |
| **50 MB de carga inicial** | **92 MB** | ❌ 1,85× |

**El riesgo técnico grande de §5 ya no es una incógnita, es una cuenta.** Godot exporta,
el motor pesa 10 MB comprimido, y todo lo que sobra son texturas. Se limpiaron 300 MB
de cosas que **no eran contenido del juego** (el zip del pack, Terrain3D, la demo, un
FBX del goblin sin usar) y se capó la resolución de 75 texturas. Falta un factor ~2,
y hay dos caminos claros: bajar el pueblo a 512, o partir el `.pck` y cargar en
diferido. Ninguno de los dos pone en riesgo el plan.

**Lo que sigue sin resolverse es el multijugador en web:** ENet no corre en navegador
y un browser no puede aceptar conexiones entrantes, así que **ningún jugador puede ser
el host**. Ver §15.9.

### 15.9 Matchmaking — **[TENDENCIA]**

Propuesta de Guido: **partidas que arrancan cada 15 segundos.** Los que están en cola
entran a esa partida; lo que falta lo llenan **bots que simulan humanos**. Empezar de
2 jugadores, después 4.

Es el patrón `.io` y ya estaba anotado en §14.2 (*"los .io resuelven eso con bots"*).

**El costo escondido:** ese modelo pide un **servidor dedicado** — un build headless
de Godot en un VPS hablando WebSocket, porque el host no puede ser un navegador. Son
5-10 USD por mes, entran en los 500, pero es mudanza real: la lógica host-autoritativa
tiene que pasar de *"la máquina de un jugador"* a *"una máquina donde no juega nadie"*.

**La propiedad buena, que es la razón para bancar el diseño:** si los bots llenan la
partida igual, **la versión 1 no necesita servidor en absoluto.** Un jugador contra
bots es lo que va a ver el 100% de la gente el día uno de todas formas. Cero
infraestructura, cero latencia, y el *Basic Launch* de CrazyGames mide dos semanas de
retención real gratis. Si nadie vuelve, nos ahorramos el servidor entero; si vuelven,
le enchufamos jugadores reales a un diseño **que ya asumía bots**.

Un ajuste a la cadencia: los 15 segundos solo importan cuando hay cola. Con población
cero son invisibles. Mejor: *la partida arranca ya y los bots llenan; cuando haya gente
real, la ventana de 15 s los agrupa.* Mismo sistema, funciona desde el día uno.

### 15.10 Multijugador en web — **NO estamos obligados al single-player** (27/08)

Verificado en la documentación, no de memoria. **CrazyGames soporta multijugador como
categoría de primera**: tiene una página entera de *requisitos para juegos
multijugador*, botón de invitar en su propia UI, y un SDK con `inviteLink()`,
`getInviteParam()`, `updateRoom()` y un flag `isInstantMultiplayer` que mete al jugador
directo a una partida joinable.

**Y anticipan exactamente la idea de Guido.** Cita textual de su documentación:

> *"The room doesn't have to exist on the server, you could also consider a room a
> special case when some players are connected to each other directly, via WebRTC."*

#### El camino técnico: WebRTC

`WebRTCPeerConnection`, `WebRTCDataChannel` y `WebRTCMultiplayerPeer` **vienen
incluidos en el export HTML5 de Godot**, sin GDExtension — dato clave, porque en web
los GDExtension **no funcionan** (nuestro propio build lo dice: *"single-threaded, no
GDExtension support"*). Dos navegadores **sí pueden hablarse directo entre ellos**.

Eso es literalmente el *"algo local entre ellos automáticamente"*: después del apretón
de manos, los paquetes van **jugador ↔ jugador**, no por un servidor nuestro.

**Lo único que hace falta es un servidor de señalización (*signaling*)**: un WebSocket
mínimo cuyo único trabajo es presentar a los dos navegadores e intercambiar SDP e ICE.
Mueve unos pocos KB por partida, no el tráfico del juego. Entra en un plan gratuito.
Godot trae el demo oficial: `networking/webrtc_signaling`.

**Lo que sí cuesta, dicho sin maquillar:**
- **STUN** para descubrir la IP pública: gratis, hay servidores públicos.
- **TURN** para cuando el NAT no se puede atravesar (redes restrictivas, NAT
  simétrico). Ese **sí relaya el tráfico**, así que consume ancho de banda y cuesta.
  Afecta a una fracción de las conexiones, no a todas. Es el único costo variable real.

**[DESCARTADO] Epic (EOS).** Su P2P y su relay son **solo SDK nativo**; el SDK web de
Epic es de login y compras, no de red. No corre en navegador. El equivalente gratuito
para web es WebRTC + STUN público.

**CrazyGames no hostea servidores de juego.** No lo ofrecen. Con WebRTC eso deja de
importar, porque lo único que hosteamos es el signaling.

#### Lo mejor: no se tira el netcode que ya validamos

La API multijugador de Godot es **agnóstica del transporte**. Se cambia
`ENetMultiplayerPeer` por `WebRTCMultiplayerPeer` y **todo el código de RPC queda
igual** — el sistema host-autoritativo de enemigos, `_take_damage_rpc.rpc_id(1, …)`,
la sincronización a 20 Hz, todo. Un jugador hace de host, como ahora.

Costo del modelo: ventaja de host por latencia, y si el host se va se cae la partida.
Para 2-4 jugadores en una arena cooperativa es aceptable.

#### Qué significa para el concepto

**El concepto no está obligado a colapsar en un clon de Vampire Survivors.** La arena
de §15.1 —3 vidas, boss— funciona con 1 y funciona con 4, que es justo el principio
`[DECIDIDO]` de §4.

**El orden que propongo no cambia:** v1 solo contra bots (se publica rápido, se mide
gratis con el *Basic Launch*), pero **diseñando la partida con lugares que un jugador
real pueda ocupar**. Los bots no son un parche: son el relleno permanente, y el
multijugador se enchufa encima cuando haya a quién enchufarle.

### 15.11 UI y arte de interfaz — factibilidad (27/08)

Pregunta de Guido: ¿puede Claude buscar referencias y rehacer la UI solo?

**Sí, y bastante bien.** En Godot un `Theme` es un **recurso de texto** (`.tres`):
colores, tipografías, bordes y estados se escriben desde afuera sin tocar el editor. Y
desde que existe el build web hay **circuito de verificación visual**: exportar, abrir
en Chrome, capturar, iterar — sin depender de que Guido mire cada paso.

**Los límites, sin maquillar:**
1. **El gusto es de Guido, no de Claude.** Con una referencia visual se copia con
   fidelidad; sin referencia, se adivina.
2. **Licencias: el riesgo real.** Casi toda la UI linda de GitHub y ArtStation **no es
   libre para uso comercial**, y hay gente que sube packs que no le pertenecen con
   licencias inventadas. **Regla: CC0 y de fuentes conocidas, o nada.**
3. **Las capturas son JPEG a resolución media.** Sirven para layout, color y jerarquía;
   no para juzgar hinting de fuente, bordes de 1px o degradados sutiles.
4. **Los 50 MB.** Una UI con atlas de texturas suma peso; una hecha con `StyleBoxFlat`
   —bordes, radios y colores por código— **pesa casi cero**. Hoy eso no es un detalle.

**La advertencia de PO: la UI es el mejor lugar del mundo para procrastinar.** Se ve,
da satisfacción inmediata, no se termina nunca y no tiene punto natural de corte. Y el
HUD no es lo feo: lo que decide si alguien se queda es la vista del juego.

**El matiz a favor de adelantarla:** en un portal donde se elige por miniatura, **los
primeros diez segundos son la superficie de conversión** — carga, título, el botón que
apretás. Eso no es el HUD, es la entrada. Y si se van a grabar clips o devlogs, la UI
es lo que hace que las capturas se vean intencionales en vez de placeholder.

**El cómo, cuando toque:** no "rediseñar el HUD" sino **un `Theme` global, procedural,
de un solo archivo**, que hereden lobby, HUD, selección de personaje y fin de partida.
Misma jugada que la gramática de habilidades: construir el sistema una vez para que lo
que venga después salga barato.

**Tiempo recomendado:** después de la R y el sonido. Buscar referencias no cuesta nada
y no compromete a nada, así que eso se puede hacer cuando sea.

### 15.11b El duelo con boss — **[ABIERTO]** (27/08)

> **Todo 15.11b y 15.11c son IDEAS, no decisiones.** Están escritas con detalle porque
> el detalle es lo que se pierde entre sesiones, no porque estén cerradas. El loop
> todavía se está pensando. Nos estamos acercando, que no es lo mismo que llegar.

> **1v1. Gana el que mate al boss, o el que mate al otro jugador 3 veces.**

Propuesta de Guido. **Es una propuesta, no una decisión** — está acá para no perderse,
igual que §15.1.

**Por qué es la más fuerte que apareció:**
- **Es una carrera.** Dos condiciones de victoria en la misma partida = cada segundo
  estás eligiendo entre empujar al boss o ir a cazarlo. Bucle de decisión real, y la
  tensión la genera el reloj compartido, no la población.
- **El PvP queda como capa, no como core** (§4): podés ganar sin pelearte nunca, pero
  ignorarlo es peligroso.
- **Se explica en una frase y se ve en un GIF** — dos tipos, un boss, una carrera. Es
  la respuesta que §14 venía pidiendo.
- **Cierra el eje 1 de §7**: la sesión es finita y tiene condición de victoria.
- **1v1 es el multijugador más barato posible**: una conexión, cero matchmaking, y el
  bot necesario es **uno solo**.

**Los tres lugares donde se rompe:**

1. **El snowball, y es el grave.** La primera muerte da nivel al que mató y no al
   muerto, que ahora mata más fácil: **el primer kill decide la partida.** Es la
   espiral clásica del 1v1.

   > **Pero el propio diseño trae la solución: si vas perdiendo en kills, el boss es
   > tu comeback.** La condición que estás perdiendo te empuja hacia la otra, así que
   > **las dos condiciones se balancean entre sí**. No es un parche, es una propiedad
   > del diseño — y es la razón principal para bancarlo.

2. **Si una condición domina, la otra es decorado.** Kills muy fáciles = deathmatch
   con escenografía; boss muy fácil = carrera PvE donde el otro da igual. La perilla
   que las mantiene vivas: **pegarle al boss tiene que dejarte expuesto.** Si se puede
   farmear tranquilo, el PvP desaparece.

3. **El spawn camp.** Con 3 kills para ganar, el que va arriba cierra la partida
   campeando el respawn. Hace falta protección al reaparecer, sí o sí.

**Consecuencia:** el bot no es un goblin, es un oponente con skills, cooldowns y dash.
Eso es exactamente el **fantasma de §9** — no una IA nueva, sino `longsword.gd` con una
fuente de input falsa enchufada.

#### Cómo se prueba, y esto es lo importante

**NO hace falta WebRTC para probar el concepto.** Se prueba en LAN con la notebook, que
ya funciona. Lo que hace falta es:

- un contador de kills entre los dos jugadores,
- la condición de victoria (3 kills o boss muerto),
- una pantalla de "ganó X".

Es una tarde, y contesta la única pregunta que importa: **¿la carrera se siente?** Si
sí, ahí vale la pena el servidor de señalización. Si no, nos lo ahorramos entero.

**El "3" es un número; la carrera de dos condiciones es la estructura.** No gastar un
minuto discutiendo si son 3 o 5 (ver §15.3).

### 15.11c La economía de tiempo — **[ABIERTO]** (27/08)

Guido: *"los enemigos pequeños deberían seguir estando, entonces farmeás y subís de
nivel, y decidís si vas a pelearle o a pegarle al boss. Es un loop medio extraño."*

**No es extraño: es una línea de LoL.** Farmeás minions para subir de nivel y en todo
momento elegís entre pelear al otro o empujar hacia el objetivo grande. League
comprimido a una línea y un objetivo. Derivado desde cero, y encima con quince años de
ajuste fino público para copiar.

#### El triángulo

| | Riesgo | Velocidad | ¿Gana? |
|---|---|---|---|
| **Bichos chicos** | Bajo | Lento | **No** |
| **El otro jugador** | Alto | Rápido | Sí |
| **El boss** | Alto | Lento | Sí |

**La regla que lo mantiene honesto: farmear es lo único que NO gana.** Solo te hace
mejor en las dos cosas que sí. Tiene que ser **necesario temprano** (a nivel 1 no matás
ni al boss ni al otro) y **nunca suficiente** (podés farmear toda la partida y perder).

Si farmear fuera gratis, lo óptimo sería farmear para siempre. Lo que rompe eso en un
MOBA es que **el mapa es compartido y el farmeo del rival es presión visible**.

#### Dónde viven los bichos — acá se decide si el loop funciona

- **Repartidos y compartidos:** si él farmea ese nido, yo no. El conflicto aparece
  **solo**, sin regla que lo fuerce.
- **Uno por jugador cerca de su lado:** simétrico y justo, pero farmean en paralelo y
  no pasa nada hasta que alguien decide irse. Mucho más tibio.

**Propuesta: mezcla.** Goteo seguro cerca de cada spawn + **centro rico y disputado**.
Es lanes + jungla. La decisión deja de ser "farmeo o no" y pasa a ser *"¿me conformo
con lo seguro o voy a pelear por lo bueno?"*.

#### El boss va en el centro disputado

Esto resuelve **geométricamente** el problema 2 de §15.11b (*"pegarle al boss tiene que
dejarte expuesto"*). Con el boss en el medio no hace falta ninguna regla: ir por él
**es** meterse en territorio disputado, de espaldas, ocupado y con la vida bajando. Se
entiende mirando el mapa, sin explicar nada.

**Y le da al pueblo un motivo para tener la forma que tiene.** Hasta ahora el mapa era
decorado —por eso está congelado en §15.6—. Con esto pasa a ser mecánica: zonas seguras
en los extremos, centro rico y peligroso, boss en el medio, y las esquinas y líneas de
visión pasan a importar. **Esto es lo que contesta qué es la Fase 3.**

#### El riesgo real

**Tres actividades en 8 minutos es mucho.** Un MOBA tiene 35 minutos para que respire.
El peligro es hacer las tres a medias y que ninguna se sienta.

**La perilla: el farmeo tiene que ser rápido.** Segundos por nido, no minutos. Ritmo de
Vampire Survivors, no de LoL. Si limpiar un nido lleva un minuto, el juego es una tarea.

#### Lo que ya está conectado

Tres piezas que encajan: **la carrera de dos condiciones** (§15.11b), **la economía de
tiempo con tres destinos** (acá), y **un mapa que hace de árbitro**. Alcanza para
describir el juego sin pedir disculpas — aunque el loop siga en discusión.

### 15.11d El segundo eje de progresión — **[ABIERTO]** (27/08)

Guido: *"en LoL comprás items, en Helbreath farmeás ropa y armas. En LotterGod solo
tenemos habilidades. Hay que pensar qué otra vuelta de progreso le damos."*

#### El agujero concreto que hay detrás

**Con solo habilidades, el farmeo se muere a mitad de partida.** Techo nivel 10 (§15.3),
alcanzado tal vez en el minuto 5 de una partida de 8: a partir de ahí matar goblins **no
da nada**. Un tercio de la partida con una de las tres patas del triángulo (§15.11c)
muerta. Eso solo ya justifica un segundo eje.

#### Qué hacen los items en realidad

No hay que copiar el sistema, hay que cubrir los trabajos:

1. **Convierten farmeo en poder** — sin eso, farmear no tiene salida.
2. **Segundo eje de decisión** — el nivel es forzado, el item es elegido.
3. **Economía** con tensión de gastar o guardar.
4. **Palanca de contrajuego** — reaccionar a lo que hizo el otro.
5. **Power spikes** — *"ahora soy fuerte, ahora es mi ventana"*.

Para 8 minutos valen el **1**, el **4** y sobre todo el **5**. La **economía (3) queda
descartada**: pide un ciclo de volver a la base, y **no tenemos base**.

#### La trampa a esquivar

**Los rangos que mutan habilidades (§15.3) y los items que modifican habilidades son el
mismo sistema con dos sombreros.** Construir los dos sin distinguirlos = complejidad sin
profundidad. La separación propuesta:

> **Las habilidades son la build que elegiste. Los drops son la ventana en la que estás.**
> Planificado y tuyo, contra circunstancial y disputado.

#### La propuesta

**Los enemigos y el boss sueltan el objeto en el piso. Lo pisás y lo tenés. Sin tienda,
sin inventario, sin oro.**

- **Cero UI**, que es lo caro y lo estacionado (§15.11).
- **Se lee en tres segundos**: cae, brilla, lo pisás, sos más fuerte.
- **La recompensa está en el mundo, así que es disputable** — alimenta directo el mapa
  como árbitro (§15.11c). Cada drop es un punto de conflicto que aparece solo.
- **El spike es el propio pickup.** No hay que inventarlo.

**Pocos y temporales.** Tres o cuatro por partida, cada uno un evento. Y no
estadísticas permanentes sino **ventanas con reloj** — el boss suelta algo que dura 60
segundos. Eso lo convierte en **objeto de tempo**: una ventaja con fecha de vencimiento
**obliga a actuar**, que es lo que una partida corta necesita. Un item permanente te
deja sentarte a esperar; uno temporal te empuja.

**Lo de Helbreath** —equipo que farmeás y conservás entre partidas— sigue siendo el eje
largo correcto, pero es progresión permanente y **exige backend** (§15.2). Queda donde
está.

#### La advertencia

**Una partida de 8 minutos puede tener lugar para UN solo eje de progresión bien hecho.**
LoL tiene 35 minutos y le entran los dos.

**No construirlo todavía.** Primero las habilidades (Fase 1), jugar, y ver si la partida
se siente flaca. Si a los 6 minutos no hay nada que perseguir, los drops entran con un
problema real que resolver en vez de por analogía con LoL. **Es Fase 4.**

### 15.12 Próxima sesión

1. **La R del Longsword** (§15.4). Es la Fase 1 entrando por la puerta que menos
   riesgo tiene: construye cast time, interrupción y telegrafiado sobre el
   personaje que ya existe y ya se siente bien.
2. **Sonido**, para cerrar Fase 0 y ver cuánto levanta el conjunto.
3. **El bot que reemplaza al humano.**

#### Sobre el bot — pedido de Guido, con motivo de peso

*"No tengo con quién testear."* **El bot es herramienta antes que contenido.** Hoy
probar el duelo exige dos máquinas y jugar los dos lados mal; con bot, el loop se
prueba solo, en una ventana, las veces que haga falta. Acelera todo lo demás.

Paga cuatro veces: **compañero de pruebas**, **relleno cuando no hay matchmaking**,
**modo solo deliberado**, y es la misma tecnología que el fantasma de §9.

**Alcance de la v1 — el bot NO tiene que pelear bien, tiene que existir en el reloj.**
Para saber si la carrera de §15.11b se siente, alcanza con que farmee, suba de nivel y
empuje al boss. Lo que hay que medir es presión de **tempo**, no habilidad de duelo. Un
bot que pelea mal pero compite por el objetivo da la respuesta; uno que duelea perfecto
pero ignora el boss, no.

**El orden R → bot es el correcto, no arbitrario.** El bot no es una IA nueva sino
`longsword.gd` con una fuente de input falsa (§9), así que **hereda gratis todo lo que
se le construya al personaje**. Con la R hecha primero, el bot la tiene el mismo día.

> **Dependencia a resolver antes: la navmesh del pueblo NO está horneada.**
> `longsword.gd` tiene el `NavigationAgent3D` puesto pero esperando. Un humano esquiva
> las casas a ojo; **un bot sin navmesh se clava contra la primera pared.** Es una
> tarea chica, pero es un bloqueante real del bot.

**Lo que sigue sin definirse: de qué va el juego.** §15.1 puso sobre la mesa una
forma posible de sesión (arena, 3 vidas, boss) pero **no la cerró**, y los cuatro
ejes de §7 siguen abiertos, y con ellos la respuesta a *"¿cuál es nuestro GIF de tres
segundos?"* (§14). La apuesta de estas fases es que **el concepto se cierre desde
abajo** —por acumulación de decisiones jugables— y no en otra charla de género.
Si después de la R y el personaje 2 el juego sigue sin tener razón de ser, ahí sí
el problema es de concepto y no de contenido.

//agregado 2.54 am 27.8 como nota:
Si no quiere pelear:
→ farmea.

Si quiere hacerse fuerte:
→ busca mobs.

Si ve al rival débil:
→ lo persigue.

Si aparece una oportunidad:
→ va por el boss.

Si está perdiendo:
→ puede intentar escapar y farmear para volver.

Eso es mucho mejor que diseñar un PvP donde básicamente “encontrás al rival y peleás”.

Yo prestaría mucha atención a una sola cosa

El loot debería crear builds temporales.

No necesariamente:

Espada +1, espada +2, espada +3.

Sino cosas que hagan que esa partida se sienta distinta.

Por ejemplo, el mago podría encontrar:

🔥 Proyectil que atraviesa enemigos
⚡ Skillshot que rebota
❄️ Proyectil que ralentiza
💥 +1 carga de una habilidad
🌀 Dash adicional
🔮 reducción de cooldown
☠️ daño aumentado contra enemigos con poca vida

Y el guerrero podría terminar una partida siendo:

tanque + robo de vida

mientras que otra partida sea:

glass cannon + movilidad

Y todo eso desaparece cuando termina la partida.

Eso además te evita tener que construir inicialmente un sistema RPG permanente gigantesco.

Y esto tiene una consecuencia MUY buena para CrazyGames

El jugador puede pensar:

"Esta partida me salió una build de mierda."

Otra partida.

"A ver qué loot me toca ahora."

Otra partida.

"Ahora tengo una build increíble, voy a buscar al mago."

Otra partida.

Ese tipo de loop puede generar muchas partidas por jugador.

Así que sí: yo no agregaría contenido todavía por agregar contenido. Primero terminaría de definir exactamente:

Qué pueden dropear los mobs.
Cómo se recoge el loot.
Cuánto dura.
Cuántos objetos puede llevar un jugador.
Cómo se combinan.
Qué tan fuerte puede llegar a ser una build.
Cómo el loot modifica el PvP.

Cuando tengas esas reglas, probablemente tengas definido el 70% de lo que hace que LooterGod sea LooterGod, aunque inicialmente solo tenga Guerrero + Mago.

Y sí: el concepto ya tiene una dirección bastante clara. Lo que te falta ahora no es inventar más sistemas, sino terminar de encontrar el sistema de loot que haga que quieras jugar “una partida más”.

