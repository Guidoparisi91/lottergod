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
2. **Armar el pueblo a mano.** Se necesita en todos los escenarios. Guido tiene
   experiencia de mapas en UE.
3. **Buscar assets** medieval-oscuro-abandonado, livianos para web.

Pendiente de mantenimiento: `CLAUDE.md` todavía no refleja la jerarquía nueva de
enemigos, `CombatFeedback` ni el sistema de bosses. Además `project.godot` pasó a
`config/features = "4.7"` — el proyecto se abrió con Godot 4.7, pero `CLAUDE.md`
dice 4.6.
