# Contexto del juego para IA: Bullet Hell Survivor

> Este es el contexto del juego pensado para asistentes de IA. La fuente de verdad del diseño es `docs/GDD_Bullet_Hell_Survivor.docx` (v0.32, 20/11/2026). Si este archivo y el GDD no coinciden, gana el GDD: avisa al usuario de la diferencia.

## Cómo usar este archivo

- Cada regla lleva una etiqueta de estado:
  - `[DEFINIDO]`: decidido por el usuario. Respétalo.
  - `[PROPUESTA]`: sugerencia que aún no está validada. Puedes usarla como valor por defecto, pero dilo al usuario.
  - `[POR DEFINIR]`: no hay decisión. **No inventes una respuesta.** Pregunta al usuario o deja el valor configurable.
  - `[PENDIENTE DEL USUARIO]`: el usuario dijo que lo explicará por chat. No lo diseñes por tu cuenta; espera su explicación.
- Escribe al usuario en español. En el código, usa los identificadores en inglés de la sección «Glosario».
- **Ojo con la palabra «nivel»:** un *nivel* es una etapa o zona del juego (`stage`). Las armas también tienen *niveles* de mejora (`weapon level`). **No existe «subir de nivel» con experiencia**: no hay XP ni lista de opciones al subir de nivel.

## Resumen

- `[DEFINIDO]` Género: bullet hell estilo survivor (hordas y disparo automático). Referente: Vampire Survivors (hordas, disparo automático y evolución de armas).
- `[DEFINIDO]` Temática: ciencia ficción espacial. Un jugador. Cámara cenital.
- `[DEFINIDO]` El jugador es **una nave modular** que viaja por un **mapa estelar** con saltos de su **motor interestelar**. Sobrevive en zonas de enemigos mientras se recarga el **combustible interestelar**, junta chatarra, la vende en **estaciones espaciales** y con el dinero mejora la nave. A largo plazo compra terreno para una **base** con edificios.
- `[DEFINIDO]` Gráficos: **naves en 3D** (jugador y enemigos) sobre **fondos en 2D**.
- `[DEFINIDO]` Motor: **Godot 4.7.2**, GDScript, renderizador Forward+.
- `[DEFINIDO]` Plataforma: PC (Windows). `[POR DEFINIR]` Android queda para **mucho más adelante**: no investigues todavía cómo adaptarlo, pero evita decisiones que lo impidan sin necesidad.

## Economía `[DEFINIDO]`

Hay dos recursos distintos; no los mezcles:
- **Chatarra** (`scrap`): la sueltan los enemigos y la nave la recoge en el nivel. **No se gasta directamente.**
- **Dinero** (`money`): se obtiene **vendiendo la chatarra en la estación**. Es la moneda con la que se paga todo: reparaciones, piezas, la base, los edificios y reconstruir la nave.

- `[DEFINIDO]` La chatarra sin vender se pierde si destruyen la nave. Esto obliga a decidir cuándo volver a la estación.
- `[DEFINIDO]` La chatarra se convierte en dinero de tres formas: venderla en la estación, **refinarla** en la refinería de la base en **minerales puros** (valen más; los mismos que extraen las minas) y venderlos en el **puerto comercial**, o vender la chatarra directamente en el puerto comercial (sin viajar a la estación, pero a peor precio). Ver «Minerales puros».
- `[DEFINIDO]` Hay **distintos tipos de chatarra**, cada uno con su precio. El valor de la chatarra es la referencia de todos los demás precios (piezas, terrenos, edificios), así que se fija primero.
- `[DEFINIDO]` Tipos y precios base, con el dinero en **créditos**. **Son provisionales**: se ajustarán en las pruebas de juego. Ponlos en datos configurables (`Resource`), no en el código.

| Tipo | Identificador | Quién la suelta | Precio base | Rareza |
|---|---|---|---|---|
| Metal común | `scrap_metal` | Todos los enemigos | 1 | Muy común |
| Componentes electrónicos | `electronics` | `gunner` | 3 | Común |
| Blindaje pesado | `heavy_plating` | `tank` | 5 | Común |
| Núcleo de energía | `energy_core` | `elite` | 25 | Rara |
| Tecnología alienígena | `alien_tech` | `boss` | 100 | Muy rara |

- `[PROPUESTA]` Cada estación paga un poco más o menos por cada tipo. Un nivel cercano (5 min) da unos 300 créditos; uno lejano (30 min) da varias veces más.
## Bucle principal `[DEFINIDO]`

1. En el **mapa estelar** (tecla M), el jugador elige una zona de enemigos (un nivel, `stage`) y salta hasta ella con el **motor interestelar** (`interstellar_drive`).
2. El salto gasta el **combustible interestelar** (`interstellar_fuel`). **Mientras se recarga**, la nave combate: se mueve, sus armas **disparan solas** (el jugador solo se mueve y esquiva) y los enemigos destruidos sueltan chatarra.
3. Cuando el combustible se recarga, puede saltar a una **estación espacial** (`station`).
4. En la estación **vende la chatarra** y obtiene dinero.
5. Con el dinero, el **mecánico** y sus **ingenieros** reparan la nave y le instalan piezas, y en el **bar** se reclutan tripulantes.
6. Vuelve a saltar hacia otra zona de enemigos. El ciclo se repite.

- `[DEFINIDO]` **No hay XP ni subida de nivel.** La nave solo mejora en la estación.
- `[DEFINIDO]` La partida empieza con **1.000 créditos** (`GameState.STARTING_MONEY`).
- `[DEFINIDO]` **Un jugador que juega con cuidado no debería perder la nave.** Perderla ya castiga mucho (se pierde la chatarra sin vender): la dificultad tiene que dejar ganar a quien esquiva bien.
- `[DEFINIDO]` **Ritmo de la partida** (objetivos del equilibrio): pasar el primer nivel con la nave inicial perdiendo entre el 30 y el 60 % del casco; primera arma extra en 2 o 3 niveles; Depósito I en unos 30 min; primera base útil en unas 2 h; primera evolución en 4 o 5 h; zonas de 30 min y el último jefe en 10 a 15 h.
- `[DEFINIDO]` **La duración de un nivel es el tiempo de recarga del combustible interestelar** tras el salto. La nave no puede irse hasta que se recargue. Así la duración encaja con la historia del universo.
- `[PROPUESTA]` Con el combustible ya recargado, el jugador decide cuándo saltar: quedarse más da más chatarra, pero es más peligroso.
- `[DEFINIDO]` La recarga **depende de la distancia** hasta la zona. Ver «El motor y el combustible interestelar».

### El motor y el combustible interestelar `[DEFINIDO]`
- El **motor interestelar** (`interstellar_drive`) viene con la nave y **no se cambia ni se mejora**. Gasta **combustible interestelar**, que se vuelve a llenar solo con el tiempo (de forma «mágica»).
- Lo que se mejora es el **depósito de combustible interestelar** (`interstellar_fuel_tank`): una pieza que se acopla en **cualquier ranura libre**. Un depósito más grande permite saltar a zonas más lejanas.
- Ejemplo: si el salto vacía un depósito de 10 minutos, hay que sobrevivir 10 minutos hasta que se recargue.
- **Cuanto más lejos está la zona, más difícil es el nivel:** más tipos de enemigos distintos, balas con más cadencia, etc.
- `[DEFINIDO]` **Mientras no exista la base (fase 4), los depósitos se compran en las estaciones**, de forma temporal, a los precios de fabricación de la tabla (1.500, 4.000, 10.000, 25.000 y 60.000 créditos). Cada uno reemplaza al anterior. **Con la base, las estaciones los seguirán vendiendo por ahora** (el usuario sigue probando los depósitos).
- `[DEFINIDO]` **Los depósitos solo se consiguen investigándolos** en el centro de investigación, con **puntos de investigación** (`research_points`). Son **caros a propósito**: dan acceso a zonas lejanas para farmear más y mejor chatarra.

| Depósito | Nivel | Recarga = duración del nivel `[DEFINIDO]` | Investigación `[PROPUESTA]` | Fabricación en el hangar `[PROPUESTA]` |
|---|---|---|---|---|
| Básico | 1 | 5 min | Viene con la nave | — |
| Depósito I | 2 | 10 min | 400 puntos (~40 min) | 1.500 créditos |
| Depósito II | 3 | 15 min | 1.200 puntos (~2 h) | 4.000 créditos |
| Depósito III | 4 | 20 min | 3.000 puntos (~5 h) | 10.000 créditos |
| Depósito IV | 5 | 25 min | 6.000 puntos (~10 h) | 25.000 créditos |
| Depósito V | 6 | 30 min | 12.000 puntos (~20 h) | 60.000 créditos |

Los tiempos suponen un investigador medio (10 puntos/min). Todos los costos son provisionales: ponlos en datos configurables.

- `[DEFINIDO]` **La nave lleva un solo depósito.** Cada depósito nuevo reemplaza al anterior y es **más grande** (guarda más combustible).
- `[DEFINIDO]` **Saltar a una estación también gasta combustible**, pero las estaciones tienen **cargadores** (`fuel_charger`) que lo rellenan automáticamente: en la práctica es como si no se hubiera gastado.
- `[PROPUESTA]` Las zonas lejanas sueltan más chatarra rara. El salto solo gasta el combustible que necesita según la distancia.

## El universo y el mapa estelar `[DEFINIDO]`

- Se abre con la tecla **M** o con el botón **Back** del mando. Muestra puntos que representan lugares: **sistemas planetarios**, **estaciones espaciales** y **zonas de enemigos** (niveles).
- `[DEFINIDO]` **El mapa es en 3D**, con **8 sistemas planetarios** por ahora, cada uno con su estrella, planetas, satélites, asteroides, estaciones y zonas. Nombres inventados y fijos (no al azar).
  - Vista de la galaxia con los 8 sistemas. Rueda del ratón para acercar o alejar; arrastrar para girar la cámara.
  - Al elegir un sistema, la cámara viaja hasta él y se ven todos sus cuerpos, estaciones y zonas.
  - Al elegir un planeta, un satélite, una estación o la estrella, la cámara se acerca para verlo de cerca.
  - La partida empieza en una estación del primer sistema.
  - `[DEFINIDO]` Los nombres de sistemas, planetas, satélites, asteroides, estaciones y zonas de enemigos **solo se muestran al pasar el ratón por encima** (o con el lugar elegido).
- `[DEFINIDO]` **Fichas al pasar el ratón:**
  - Cuerpo celeste: imagen 2D, nombre, descripción, si es habitable, temperatura y costo del terreno. **Hasta la fase 4 la ficha se ve, pero el botón de compra está desactivado.**
  - Zona de enemigos: nombre, duración del nivel, dificultad y tipos de enemigos. Si tiene jefe, una **calavera** con el nombre del jefe y una advertencia de peligro; si ya fue derrotado, lo indica.
- `[DEFINIDO]` **Viajar:**
  - Cada zona está a una distancia fija (5, 10, 15, 20, 25 o 30 min) que marca su dificultad; saltar a ella gasta ese combustible.
  - **Cuando el combustible se recarga, el jugador abre el mapa y elige a dónde saltar** (cualquier estación o zona al alcance de su depósito).
  - Se puede encadenar zona tras zona sin pasar por una estación (se arriesga la chatarra sin vender y no se repara).
- `[PROPUESTA]` Así está implementado:
  - En el nivel, con el combustible recargado, se pulsa M (o se mantiene ESPACIO) para abrir el mapa (el nivel queda en pausa), se fija el destino y después se mantiene ESPACIO para saltar.
  - Las estaciones siempre están al alcance. Si destruyen la nave, se reaparece en la estación más cercana (la del sistema donde estaba la zona).
  - `[DEFINIDO]` Los sistemas están **muy separados** y, de lejos, **solo se ven las estrellas**: al alejarse de un sistema, sus planetas desaparecen. La galaxia se abre centrada en el sistema actual; rueda para alejar hasta verla entera y botón derecho arrastrando para desplazarla.
  - El depósito comprado es un valor de la partida (`GameState.fuel_tank_level`), no una pieza montada.
  - Los 8 sistemas (generados con `tools/data/gen_universe.js`): 1 Velora (inicial, zonas de 5 min), 2 Kessar (5–10), 3 Thalune (10–15, jefe Acorazado Kraal), 4 Ombrion (15–20), 5 Drevan (15–20), 6 Isk-Maren (20–25, jefe Acorazado Morvath), 7 Coralis (25), 8 Nyxar (30, jefe Acorazado Nyx). Cada uno con una estación.
- **Sistemas planetarios** (`star_system`): una estrella y hasta **6 planetas** (límite por ahora), **gaseosos** o **rocosos**. Planetas, satélites y asteroides tienen características; la principal es si son **habitables**.
  - Habitable (planeta, satélite o asteroide): se puede comprar un **terreno** para la base.
  - No habitable (por ejemplo, una órbita muy cercana a su estrella): por ahora solo forma parte del paisaje.
- `[DEFINIDO]` Los planetas gaseosos no son habitables, pero algunos de sus satélites sí.
- `[DEFINIDO]` Cada cuerpo celeste tiene nombre, descripción, si es habitable, **temperatura** y otros datos (ver la ficha en «Bucle a largo plazo»).
- `[POR DEFINIR]` Qué otras características tienen.
- Las estaciones espaciales y las zonas de enemigos están **dentro** de los sistemas planetarios.

## Bucle a largo plazo: la base `[DEFINIDO]`

1. Con dinero, el jugador compra un **terreno** en un planeta, satélite o asteroide **habitable** del mapa estelar para tener su **base** (`base`).
2. En la base construye **edificios** (`building`).
3. En el **hangar** construye naves y **guarda sus planos** (`ship_blueprint`) para usarlas o reconstruirlas más adelante.
- `[DEFINIDO]` La base se conserva aunque destruyan la nave. Es la progresión a largo plazo; sustituye a las «mejoras permanentes» de versiones anteriores.
- `[DEFINIDO]` Precio del terreno (provisional, se ajustará jugando): **asteroide 3.000, satélite 6.000 y planeta 12.000 créditos**.
- `[DEFINIDO]` **El terreno se compra desde el mapa estelar.** Al pasar el ratón sobre un cuerpo celeste aparece una **ficha** (`body_info_card`) con: una imagen 2D del cuerpo, su nombre y descripción, si es habitable, su temperatura y otros datos, y el costo del terreno.
- `[DEFINIDO]` Se compra haciendo **clic en la misma ficha**. La base se funda cuando la nave llega a ese cuerpo celeste.
- `[DEFINIDO]` **Se pueden tener varias bases** (una por cuerpo celeste), para sumar la producción de sus edificios (investigación, refinerías, minas…).
- `[DEFINIDO]` **Ir a la base:** clic en el cuerpo celeste del mapa; si el terreno ya es del jugador, la ficha muestra el botón **«Aterrizar»** (en vez de «Comprar terreno»).
- `[DEFINIDO]` **La base también sirve de estación**, pero solo con los edificios adecuados (repostar, reparar, vender, reclutar: cada cosa necesita su edificio).
- `[DEFINIDO]` **Por ahora la base no puede ser atacada.** Mucho más adelante habrá defensas (torretas con lanzamisiles o metralletas) y entonces podrá ser atacada: no lo implementes todavía.
- `[PROPUESTA]` Una base es un destino del mapa como una estación: siempre al alcance; al aterrizar se guarda la partida. En el mapa, los cuerpos con base llevan una marca y su ficha dice «Tu base». Una sola base por cuerpo (hay 17 cuerpos habitables).

### Interfaz de la base
- `[DEFINIDO]` **Pendiente de rediseño:** al usuario no le gusta la base del prototipo y se rediseñará por completo **en la versión 0.2.0** (con los modelos de Blockbench). En la 0.1.0 queda como está: no la amplíes ni la pulas.
- `[DEFINIDO]` La base se ve **en 3D**, con los edificios encima del cuerpo celeste. **Los edificios son modelos 3D hechos en Blender** (`tools/blender/build_parts.py`), en el estilo de las naves, y su forma cuenta lo que hacen.
- `[DEFINIDO]` **Tripulantes en los edificios:** al hacer clic en un edificio se abre una ventana con lo que hace y un botón para **asignar o quitar tripulantes**.
- `[PROPUESTA]` Cómo se usa:
  - Un trozo del suelo del cuerpo (con sus colores) y cámara orbital como `ShipEditorView` (arrastrar, rueda). Plataforma de aterrizaje en el centro con la nave del jugador.
  - Parcelas libres marcadas en el suelo: clic en una para elegir el edificio que se construye. Clic en un edificio: su ventana (función, nivel y botón de mejorar, tripulantes, acciones).
  - Arriba: nombre de la base, dinero y lo guardado en las bases (chatarra y minerales); botones Mapa (M) y Guardar y salir al menú.
  - Los tripulantes pasan de la nave a la base (o al revés) solo con la nave aterrizada en esa base. Los que no trabajan quedan en reserva; la base no tiene límite de tripulantes.
  - Sin cargador de combustible, al aterrizar el depósito queda vacío y se recarga solo con el tiempo: hay que esperar en la base antes de volver a saltar.
- `[PROPUESTA]` Modelos: centro de investigación (cúpula con antenas; telescopio en un satélite), hangar (medio cilindro con portón y plataforma), refinería (tanques, chimeneas, horno naranja), mina (torre de perforación con cinta), academia (aulas y circuito de entrenamiento), enfermería (módulo blanco con cruz cian), puerto comercial (contenedores y grúa), cargador (torres con anillos de energía cian).

### Espacio, costos y niveles
- `[DEFINIDO]` Cada base tiene **parcelas** y cada edificio ocupa una: asteroide 4, satélite 6, planeta 9. **Un edificio de cada tipo por base** (para dos minas, dos bases).
- `[DEFINIDO]` **La refinería y la mina no necesitan tripulantes.**
- `[PROPUESTA]` Todos los edificios llegan al nivel 10 (salvo el cargador). Subir al nivel 2 cuesta la mitad del precio del edificio y cada nivel un 40 % más (del 1 al 10 ≈ 25 veces el precio).

| Edificio | Precio | Cada nivel | Tripulantes |
|---|---|---|---|
| Hangar | 5.000 | −2 % al costo de reconstruir; +1 plano en los niveles 4, 7 y 10 | 1 ingeniero |
| Centro de investigación | 4.000 | +10 % de puntos; +1 plaza en los niveles 4 y 7 | 1 a 3 investigadores |
| Refinería | 3.000 | +20 % de chatarra procesada por minuto | No necesita |
| Mina | 2.500 | +25 % de minerales por minuto | No necesita |
| Academia | 2.000 | +1 candidato y +1 plaza de entrenamiento en los niveles 4 y 7 | No necesita |
| Enfermería | 2.000 | +10 % de velocidad de curación; +1 tripulante en los niveles 4 y 7 | 1 a 3 (primeros auxilios) |
| Puerto comercial | 1.500 | +2 % al precio de la chatarra (70 % → 88 %) | No necesita |
| Cargador de combustible | 2.000 | Sin niveles | No necesita |

- `[PROPUESTA]` Referencia: primera base útil (asteroide + cargador + refinería + puerto) ≈ 9.500; base completa en un planeta ≈ 34.000 sin mejoras.
- `[PROPUESTA]` La academia muestra 3–5 candidatos (más con los niveles), que cambian cada vez que la nave aterriza.

### Minerales puros
- `[DEFINIDO]` La **refinería** convierte la chatarra traída de los niveles en **minerales puros**, que valen más que la chatarra. Son los **mismos minerales que extraen las minas**. El **puerto comercial** vende todo: la chatarra (a peor precio que la estación) y los minerales.
- `[DEFINIDO]` La mina **solo produce con el juego abierto**.
- `[DEFINIDO]` **Las estaciones no compran minerales:** hace falta sí o sí un puerto comercial en alguna base.
- `[DEFINIDO]` **Por ahora, la chatarra de la nave se descarga al aterrizar en la base** y queda a salvo.
- `[PROPUESTA]` Cada tipo de chatarra se refina en un mineral que vale un 50 % más:

| Mineral | Identificador | Se refina de | Precio | En las minas |
|---|---|---|---|---|
| Titanio | `titanium` | 10 de metal común | 15 | 60 % |
| Oro | `gold` | 5 componentes electrónicos | 22 | 25 % |
| Tungsteno | `tungsten` | 5 de blindaje pesado | 37 | 12 % |
| Iridio | `iridium` | 1 núcleo de energía | 37 | 3 % |
| Xenita | `xenite` | 1 de tecnología alienígena | 150 | No se extrae |

- `[PROPUESTA]` Cómo funciona:
  - La chatarra se descarga si alguna base tiene refinería o puerto comercial; si no, sigue en la nave.
  - Lo guardado es común a todas las bases (no es un almacén: sin edificio ni límite). Cualquier refinería procesa y cualquier puerto vende.
  - Refinería: 30 créditos de chatarra por minuto en el nivel 1 (84 en el 10). Mina: 10 créditos de minerales por minuto (33 en el 10), +50 % en asteroide.
  - Puerto comercial: chatarra al 70 % (88 % en el nivel 10), minerales al 100 %. Refinar + puerto = 1,5× la estación.
  - Todo lo de la base (minas, refinerías, investigación, curación, entrenamiento) avanza solo con el juego abierto, también durante los niveles.

### Investigación en la base
- `[POR DEFINIR]` El árbol de investigación: se definirá más adelante.
- `[PROPUESTA]` Mientras tanto, piezas para investigar: biblioteca, comedor, cocina y sala de recreación (300 cada una); habitación de tripulantes grande (6 plazas, 150); placa de blindaje pesada (150); recolector magnético grande (150); propulsor grande (500); cañón de partículas (arma, disparos lentos que atraviesan, 500); escopeta de fragmentos (arma, abanico de perdigones de corto alcance, 500); generador de escudo (pieza avanzada, 1.000; hecho en la fase 6, ver «Estructuras de la nave»); depósitos I–V (400 a 12.000).
- `[PROPUESTA]` Se investiga una cosa a la vez; se suman los puntos de los centros de todas las bases. Las piezas investigadas se fabrican en el hangar.

### Perder la nave `[DEFINIDO]`
Si el casco llega a 0, la nave se destruye **por completo**:

| Qué | Resultado |
|---|---|
| Dinero | Se mantiene. |
| Chatarra sin vender | Se pierde. |
| Tripulantes | Quedan heridos. Con **enfermería** en la base se recuperan allí; sin enfermería, **mueren**. |
| Nave | **Con hangar:** se reconstruye desde su plano pagando dinero. **Sin hangar:** se vuelve a la **nave inicial** y el bucle empieza de nuevo. |

- `[DEFINIDO]` **Una sola nave a la vez:** el hangar guarda **varios planos**, pero el jugador tiene una sola nave.
- `[DEFINIDO]` **Reconstruir desde el plano sale un poco más barato que comprar todas las piezas de nuevo.** Para construir una nave nueva, reconstruirla o repararla hace falta **al menos un tripulante ingeniero en el hangar**.
- `[PROPUESTA]` Reconstruir = 80 % del valor de la nave (piezas, armas y mejoras; el plano guarda los niveles), −2 % por nivel del hangar (62 % en el 10). Al despegar de una base con hangar se guarda solo el plano; además, planos con nombre (2, +1 en los niveles 4, 7 y 10). Si destruyen la nave, se reaparece en la estación más cercana; con hangar, se va a la base a reconstruirla. Construir otro plano reemplaza la nave actual (se desarma y devuelve el 50 %). El hangar repara (2 créditos/punto de vida), vende, mejora y evoluciona piezas a precios del mecánico; las piezas investigadas solo se fabrican allí.
- `[PROPUESTA]` Los heridos se evacúan solos a la enfermería de cualquier base. Cada tripulante de la enfermería cura a un herido a la vez. Sin tripulante en la enfermería, esperan sin curarse pero no mueren; solo mueren si no hay ninguna enfermería.
- `[DEFINIDO]` Cuánto tarda en curarse un herido depende de la estadística **primeros auxilios** (`first_aid`) del tripulante que trabaja en la enfermería.
- `[PROPUESTA]` Tiempo de curación = 1.000 ÷ `first_aid` minutos de juego (50 → 20 min; 100 → 10 min).

### Tipos de base

| Tipo | Características | Estado |
|---|---|---|
| Asteroide | Espacio limitado para edificios. Bono de minería. | `[DEFINIDO]` |
| Planeta | Más espacio para edificios. | `[DEFINIDO]` |
| Satélite | Espacio intermedio para edificios. Bono de investigación: los puntos se generan un **30 % más rápido**, como en un observatorio sin atmósfera. | `[DEFINIDO]` |

### Edificios de la base

| Edificio | Identificador | Función | Estado |
|---|---|---|---|
| Centro de investigación | `research_center` | Investiga piezas nuevas, que quedan **desbloqueadas para siempre**. Necesita un tripulante investigador. **Solo existe en la base**, no en la nave. En un satélite, su modelo lleva un telescopio arriba. | `[DEFINIDO]` |
| Hangar | `hangar` | Construye naves, fabrica sus piezas (siempre disponibles allí) y guarda los planos para usarlas o reconstruirlas. Los tripulantes ingenieros trabajan aquí y permiten mejorar la nave: sin al menos un ingeniero no se puede construir, reconstruir ni reparar. | `[DEFINIDO]` |
| Refinería | `refinery` | Convierte la chatarra en **minerales puros**, que valen más (más dinero que venderla en la estación). | `[DEFINIDO]` |
| Mina | `mine` | Extrae minerales puros de forma pasiva, **solo con el juego abierto**; rinde más en asteroides. | `[DEFINIDO]` |
| Academia | `academy` | Recluta y entrena tripulantes. | `[DEFINIDO]` |
| Enfermería | `infirmary` | Recupera a los tripulantes heridos. Necesita un tripulante; cuanto mejor su `first_aid`, más rápido cura. Sin enfermería, los heridos mueren. | `[DEFINIDO]` |
| Puerto comercial | `trade_port` | Vende lo que hay en la base: chatarra (sin ir a la estación, pero a peor precio) y minerales puros. | `[DEFINIDO]` |
| Cargador de combustible | `fuel_charger` | Rellena el depósito al aterrizar en la base, como en una estación. Es lo que permite repostar en la base. | `[DEFINIDO]` |

- El **mapa estelar no es un edificio**: es una pantalla que se abre con la tecla M. `[DEFINIDO]` Por ahora **no hay edificio de centro de mando**; no lo añadas.
- **Descartados:** fábrica (las piezas se fabrican en el hangar), almacén y naves base distintas en el hangar (en su lugar, el hangar guarda planos). No los propongas de nuevo.
- `[POR DEFINIR]` Qué otros edificios habrá.

## La estación espacial `[DEFINIDO]`

- Las estaciones están dentro de los sistemas planetarios del mapa estelar. Allí el jugador vende la chatarra, paga al mecánico y a los ingenieros para **reparar** la nave (no hay regeneración pasiva) y **compra piezas**, que los ingenieros instalan o cambian.
- **Cargadores de combustible interestelar:** rellenan el depósito automáticamente al llegar.
- **Bar:** hay candidatos con estadísticas al azar; se reclutan **pagando**, y los mejores cuestan más (ver «Tripulantes»). Pueden trabajar en la nave o en los edificios de la base (el personal de la base **son** tripulantes).
- Origen de las piezas:
  - `[DEFINIDO]` Al principio el mecánico vende **piezas básicas**: los tres **pasillos** (`corridor_1x1`, `corridor_1x2`, `corridor_1x3`), la **estación de mando** (`command_station`) y las **armas** (metralleta, lanzacohetes, láser…).
  - `[DEFINIDO]` También vende: placa de blindaje (`armor_plate`), propulsores pequeño (`thruster_small`) y mediano (`thruster_medium`), recolector magnético (`scrap_magnet`) y habitaciones de tripulantes pequeña (`crew_quarters_small`, 2 plazas) y mediana (`crew_quarters_medium`, 4 plazas).
  - `[DEFINIDO]` Más adelante, con un **centro de investigación** en la base y un tripulante **investigador**, se investigan piezas nuevas.
  - `[DEFINIDO]` Las piezas se fabrican en el **hangar** de la base, donde siempre están disponibles.
  - `[DEFINIDO]` Las piezas investigadas quedan **desbloqueadas para siempre**.
  - `[DEFINIDO]` Investigar cuesta **puntos de investigación**. Las investigaciones avanzadas, como los depósitos de combustible interestelar, cuestan más.
  - `[DEFINIDO]` Los puntos de investigación se generan **de forma pasiva, todo el tiempo**. Más rápido cuanto más alta sea la estadística `research` del tripulante del centro de investigación, y más rápido aún si la base está en un **satélite**.
  - `[DEFINIDO]` En un **satélite**, los puntos se generan un **30 % más rápido**.
  - `[PROPUESTA]` El centro genera (estadística `research` ÷ 5) puntos por minuto: investigador medio (50) = 10/min, excelente (100) = 20/min; en un satélite, 13 y 26.
  - `[PROPUESTA]` Costos: estructura nueva 150 puntos; estructura de tripulación 300; arma o motor de propulsión nuevo 500; pieza avanzada 1.000; depósitos de combustible 400 a 12.000 (ver «El motor y el combustible interestelar»).
  - `[DEFINIDO]` Los puntos **solo se generan con el juego abierto**. No hay progreso con el juego cerrado: no lo implementes.
- `[DEFINIDO]` **Reparar cuesta 2 créditos por punto de vida.** Reconstruir una pieza perdida cuesta el 50 % de su precio; una destruida, el 100 % (con su arma si era una estación de mando).
- `[DEFINIDO]` **Si la nave se queda sin armas útiles**, en la estación se vuelve gratis a la nave inicial (nunca queda atascado sin dinero ni armas).
- `[DEFINIDO]` **El mecánico también mejora piezas:** sube de nivel armas y estructuras con función, y evoluciona las armas al nivel 10. Ver «Mejoras y evoluciones».
- `[DEFINIDO]` **Por ahora, todas las estaciones son iguales** (mismos servicios y precios).
- `[PROPUESTA]` Ideas para más adelante: cada estación con servicios y precios distintos; precios que suben con cada nivel.
- `[PROPUESTA]` Vender una pieza (o un arma) devuelve el 50 % de su precio, junto con todo lo que cuelga de ella.
- `[DEFINIDO]` En la estación la nave se ve **en 3D, con una cámara que gira a su alrededor** (como en el mapa estelar), para ver y usar también las ranuras de abajo.
- `[PROPUESTA]` Interfaz de la estación (así está implementada): vista 3D de la nave con una cámara que gira a su alrededor (arrastrar para girar, rueda para acercar; botones «Ver desde abajo» y «Centrar»). Se ven todas las ranuras libres que no tapa otra pieza (azul = lateral, naranja = arriba/abajo), también las de la cara de abajo al girar la nave. Clic en una ranura para comprar la pieza; clic en una pieza para mejorarla, girarla, venderla y, si es estación de mando, comprar su arma y elegir su tripulante. Pestañas: Mecánico, Bar y Chatarra.

## La nave modular `[DEFINIDO]`

Referencia visual: `docs/img/concepto_nave_modular.png`. La nave apunta hacia arriba.

| Parte | Identificador | Ubicación | Qué admite |
|---|---|---|---|
| Núcleo / cuerpo principal | `core` | Centro | La base de la nave. Organiza la estructura y en él se conectan los módulos. Sube de nivel (ver «Mejoras por nivel»). |
| Estación de mando con metralleta | `command_station` | Arriba | **No es un arma principal aparte:** es una estación de mando típica con una metralleta simple incluida. Necesita tripulante, como toda estación de mando. La metralleta se mejora y puede evolucionar. |
| Puntos de acople laterales | `side_slot_left`, `side_slot_right` | A los lados del núcleo | Armas secundarias o estructuras especiales. |
| Acoplador central | `central_coupler` | Centro del núcleo | Une estructuras arriba y abajo del núcleo. |
| Propulsor | `engine` | Abajo | Propulsión. Define la maniobrabilidad. La nave inicial trae el **propulsor pequeño**; se pueden añadir más. |

### Crecimiento y ranuras
- `[DEFINIDO]` **Cada estructura tiene su propio número y posición de ranuras** (`slot`). Las estructuras se encadenan: al acoplar una, sus ranuras libres quedan disponibles para nuevas piezas.
  - Pasillos: acopladores en todas sus caras (tres tamaños, ver «Estructuras de la nave»).
  - Estación de mando: solo dos ranuras, la de unión a la nave y una frontal para el arma.
- `[DEFINIDO]` A medida que se avanza de nivel, **la nave se hace más grande y los enemigos también**.
- `[PROPUESTA]` El jugador elige la ranura de cada pieza en la estación. La cámara se aleja poco a poco. La hitbox crece con la nave.
- `[POR DEFINIR]` Cuántas ranuras tienen las demás estructuras (se irá definiendo con el tiempo).
- `[PROPUESTA]` Mientras tanto, en el código: las habitaciones de tripulantes y los propulsores solo tienen la ranura con la que se unen; los accesorios se apoyan por su cara de abajo; los pasillos se pueden unir por cualquiera de sus caras laterales (botón «Girar»). Las ranuras están en `PartData` (`slot_positions`, `slot_normals`, `slot_kinds`, `mount_slot`) y se generan con `tools/data/gen_data.js`.
- `[DEFINIDO]` **La nave crece hacia los lados y el juego se mueve en un plano 2D**, aunque las naves sean 3D: la silueta vista desde arriba es la zona de impacto. Las **caras de arriba y de abajo** de las piezas solo admiten **accesorios** (placas de blindaje, recolectores magnéticos, depósito de combustible), nunca estructuras.
- `[PROPUESTA]` La nave inicial empieza con un tripulante artillero para su estación de mando.
- `[DEFINIDO]` **Las secciones de la nave pueden destruirse por separado** durante un nivel. La interfaz muestra el daño de cada pieza.
- `[DEFINIDO]` **Al destruirse una sección se pierde todo lo que tenía acoplado.** Si destruyen una estación de mando, se pierden la estación y su arma, y su tripulante queda herido (ver «Perder la nave»). Si destruyen un pasillo, también se pierde lo que estaba acoplado **solo** a ese pasillo (por ejemplo, una estación de mando con su arma y su tripulante).
- `[PROPUESTA]` Regla general para implementarlo: toda pieza que queda desconectada del núcleo se pierde; la que sigue unida al núcleo por otro camino se conserva.
- `[DEFINIDO]` Las piezas perdidas **se reconstruyen** en la estación, más barato que comprarlas nuevas. Si una pieza queda **totalmente destruida**, hay que comprarla de nuevo.
- `[DEFINIDO]` Una pieza está **totalmente destruida cuando su vida llega a 0**, aunque siga viéndose en la nave. Las perdidas por quedar desconectadas se reconstruyen por el **50 %** del precio.

## Estadísticas de la nave `[DEFINIDO]`

| Estadística | Identificador | Nota |
|---|---|---|
| Integridad del casco | `hull` | Vida. Si llega a 0, la nave se pierde. |
| Blindaje | `armor` | Reduce el daño recibido. |
| Velocidad | `speed` | |
| Maniobrabilidad | `handling` | Depende del motor o motores. |
| Daño | `damage` | Multiplicador global. |
| Cadencia | `fire_rate` | |
| Radio de recogida | `pickup_radius` | Para atraer la chatarra. |

- `[DEFINIDO]` **La integridad del casco es la vida del núcleo**, y cada pasillo le suma casco. Si el núcleo llega a 0, la nave se pierde.
- `[DEFINIDO]` **La nave se mueve en todas direcciones y apunta hacia el puntero del ratón**, girando con una velocidad limitada (no instantánea). La maniobrabilidad define lo rápido que acelera y gira. (Antes giraba hacia donde se movía; el usuario lo cambió en la v0.21 para hacer el juego más fácil.)
- `[PROPUESTA]` Velocidad de giro: 1,2 + 0,45 × maniobrabilidad rad/s (`Ship.turn_speed()`). Con mando se apunta con el stick derecho. Cursor en forma de mira durante el nivel.
- `[PROPUESTA]` Una placa de blindaje suma su blindaje a la pieza en la que está acoplada.
- La reparación no es una estadística: se paga en la estación.
- **La suerte se eliminó del juego.** No la implementes.

## Piezas

### Reglas generales `[DEFINIDO]`
- Tipos: **estructuras de la nave**, **estructuras de tripulación**, **armas**, **motores** y el **depósito de combustible interestelar** (se acopla en cualquier ranura libre).
- Todas se compran e instalan en la estación.
- `[DEFINIDO]` Las estructuras **con función** (estación de mando, comedor…) tienen niveles hasta el 10. **Los pasillos no tienen niveles.** Ver «Mejoras y evoluciones».

### Estructuras de la nave

| Estructura | Identificador | Función | Estado |
|---|---|---|---|
| Pasillo cuadrado | `corridor_1x1` | Un cubo; la pieza más básica. Un acoplador en cada una de sus 6 caras. + Integridad del casco. | `[DEFINIDO]` |
| Pasillo doble | `corridor_1x2` | Paralelepípedo de 2 cubos. 2 acopladores en cada cara larga y 1 en cada extremo. + Integridad del casco. | `[DEFINIDO]` |
| Pasillo triple | `corridor_1x3` | Paralelepípedo de 3 cubos. 3 acopladores en cada cara larga y 1 en cada extremo. + Integridad del casco. | `[DEFINIDO]` |
| Habitación de tripulantes pequeña (= dormitorio) | `crew_quarters_small` | +2 plazas de tripulantes. | `[DEFINIDO]` |
| Habitación de tripulantes mediana | `crew_quarters_medium` | +4 plazas de tripulantes. | `[DEFINIDO]` |
| Placa de blindaje | `armor_plate` | Se acopla en un acoplador libre de cualquier pieza (por ejemplo, una cara de un pasillo) y protege esa pieza. La idea es cubrir con placas todos los acopladores sin otra pieza. | `[DEFINIDO]` |
| Recolector magnético | `scrap_magnet` | + Radio de recogida de chatarra. | `[DEFINIDO]` |
| Generador de escudo | `shield_generator` | Accesorio **solo arriba o abajo** y **uno por nave**. Burbuja que recibe el daño antes que las piezas y se recarga. Se investiga (1.000 puntos) y se fabrica en el hangar. | `[DEFINIDO]` |
| Estación de mando (antes «cápsula de mando») | `command_station` | Aloja un arma en su ranura frontal y da + cadencia. Un tripulante artillero se sube y controla el arma automáticamente. Requisito de `twin_machine_gun`. **No confundir con la estación espacial** (`station`). | `[DEFINIDO]` |

### Estructuras de tripulación `[DEFINIDO]`
Estructuras de **calidad de vida**: mejoran las estadísticas de los tripulantes de la nave. `[DEFINIDO]` Cada una da solo **+1 %** por nivel, para que juntar muchas no rompa el equilibrio al principio.

| Estructura | Identificador | Efecto | Estado |
|---|---|---|---|
| Biblioteca | `library` | +1 % a las estadísticas de los tripulantes por nivel | `[DEFINIDO]` |
| Comedor | `mess_hall` | +1 % por nivel | `[DEFINIDO]` |
| Cocina | `kitchen` | +1 % por nivel | `[DEFINIDO]` |
| Sala de recreación | `recreation_room` | +1 % por nivel | `[DEFINIDO]` |
| Habitaciones de tripulantes | `crew_quarters_small` / `crew_quarters_medium` | Plazas, y además +1 % por nivel | `[DEFINIDO]` |

- `[DEFINIDO]` El +1 % es **por nivel** (10 % en el nivel 10) y los bonos de varias estructuras **se suman** (cinco al nivel 10 = +50 %).

- `[DEFINIDO]` Los dormitorios **son** las habitaciones de tripulantes; no es una sala aparte.
- `[POR DEFINIR]` Qué otras salas habrá.

### Armas `[DEFINIDO]`
Armas de ciencia ficción: metralletas, lanzacohetes, láseres y otras. Tienen niveles de mejora hasta el **nivel 10**; el mecánico las sube pagando dinero, con un costo exponencial.

- `[DEFINIDO]` **Cada arma se acopla a una estación de mando operada por un tripulante.** No hay un límite fijo de armas: la nave puede llevar tantas como estaciones de mando con tripulante tenga.

| Arma | Identificador | Nivel máx. | Comportamiento | Al subir de nivel `[DEFINIDO]` |
|---|---|---|---|---|
| Metralleta | `machine_gun` | 10 `[DEFINIDO]` | Ráfaga rápida de proyectiles hacia el frente | Más daño |
| Lanzacohetes | `rocket_launcher` | 10 `[DEFINIDO]` | Cohetes lentos que explotan con daño en área | Más potencia: más daño de área o área más grande |
| Láser | `laser` | 10 `[DEFINIDO]` | **Rayo continuo:** poco daño pero sin parar; atraviesa enemigos en línea | Más daño |

- `[DEFINIDO]` **Las armas disparan en un cono hacia el frente** de su estación de mando: apuntan solas al enemigo más cercano dentro del cono. Para disparar con un arma hay que **apuntar la nave con el ratón** hacia los enemigos. Las armas montadas en los lados disparan hacia los lados. **No** implementes puntería en 360°.
- `[PROPUESTA]` Cono de 50° a cada lado (`aim_cone_degrees`; se amplió desde 35° para que sea más disfrutable). Precios: metralleta 250, lanzacohetes 600, láser 700 créditos. Lanzacohetes: 26 de daño en 2,2 m cada 1,5 s (+15 % de daño y +5 % de área por nivel). Láser: 24 de daño por segundo con 11 m de alcance.

### Motores `[DEFINIDO]`
- La maniobrabilidad depende de los propulsores que tenga la nave. Se pueden instalar más en la estación.
- **Propulsor pequeño** (`thruster_small`): viene con la nave inicial y también se vende. **Propulsor mediano** (`thruster_medium`): un poco más de maniobrabilidad.
- `[POR DEFINIR]` Dónde se acoplan, si también aumentan la velocidad y si tienen niveles.
- `[PROPUESTA]` Mientras tanto, en el código: se acoplan en cualquier ranura lateral, suman velocidad (pequeño +1,5; mediano +2,5) y no tienen niveles.
- `[DEFINIDO]` El **motor interestelar** (`interstellar_drive`) no es un motor de propulsión (`engine`) y no se cambia: lo que se acopla y se mejora es el depósito de combustible interestelar. Ver «El motor y el combustible interestelar».

### Tripulantes
- `[DEFINIDO]` Los tripulantes (`crew`) operan estructuras y edificios: la estación de mando necesita uno para operar su arma, y el centro de investigación de la base necesita un investigador. Las habitaciones de tripulantes aumentan la capacidad de la nave.
- `[DEFINIDO]` **El personal de la nave y el de la base son lo mismo: tripulantes.** Se reclutan en el bar de la estación o en la **academia** de la base. Las estructuras de tripulación mejoran sus estadísticas.
- `[DEFINIDO]` **Pueden morir:** si se destruye su sección o la nave entera, quedan heridos; con enfermería se recuperan en la base, sin enfermería mueren.
- `[DEFINIDO]` **Estadísticas de profesión:** todos los tripulantes tienen las mismas cinco estadísticas, una por profesión. Sus valores indican para qué trabajo es más adecuado cada uno. **No hay clases fijas**: la «profesión» de un tripulante es la estadística en la que destaca.

| Estadística | Identificador | Para qué sirve `[DEFINIDO]` |
|---|---|---|
| Artillero | `gunnery` | Sube el daño y la cadencia del arma de la estación de mando que opera |
| Ingeniero | `engineering` | Por ahora, trabaja en el hangar de la base y permite mejorar la nave (hace falta al menos uno para construir, reconstruir o reparar). `[POR DEFINIR]` Se seguirá definiendo con el tiempo: no le inventes más funciones |
| Investigador | `research` | Acelera la investigación en el centro de investigación |
| Reparador | `repair` | Repara el casco y las secciones dañadas durante el nivel |
| Primeros auxilios | `first_aid` | Profesión nueva. En la enfermería de la base, cura más rápido a los tripulantes heridos |

  Ojo: el enemigo «artillero» es `gunner`; la estadística de tripulante es `gunnery`. No los confundas.
- `[DEFINIDO]` El empleado en general se llama **tripulante** (`crew`), trabaje en la nave o en la base.
- `[DEFINIDO]` **Ingeniero y reparador van juntos:** quien tiene mucho de `engineering` también tiene mucho de `repair`, y al revés.
- `[DEFINIDO]` **Reclutar en el bar:** hay varios candidatos, cada uno con su personalidad y estadísticas **al azar** (hay artilleros mucho mejores que otros, y lo mismo con las demás profesiones). Reclutar a alguien **cuesta dinero**, y cuanto mejores son sus estadísticas, más caro o más difícil es.
- `[DEFINIDO]` La **academia** recluta y además **entrena**: sube las estadísticas.
- `[PROPUESTA]` Números:
  - Estadísticas de 1 a 100. Candidato normal: 20–50 en su mejor estadística; excepcional (raro): 70–100.
  - `engineering` y `repair` se generan con como mucho 15 puntos de diferencia.
  - Precio de reclutamiento = (mejor estadística)² ÷ 2 créditos (40 → 800; 80 → 3.200; 100 → 5.000).
  - El bar muestra 3–5 candidatos y cambia cada vez que la nave vuelve a la estación.
  - Cada candidato tiene una personalidad (por ahora solo descriptiva). Se puede despedir a un tripulante. La nave lleva tantos tripulantes como plazas: el núcleo da 1 y las habitaciones 2 o 4.
  - Entrenar: +5 a una estadística (máx. 100), 10 minutos, 10 créditos por cada punto que ya tiene (de 40 a 45 cuesta 400).
- `[PROPUESTA]` También se podrían rescatar cápsulas de escape durante los niveles. Una estructura sin tripulante queda inactiva.

## Mejoras y evoluciones

### Mejoras por nivel `[DEFINIDO]`
- El **mecánico** de la estación mejora las piezas: cada mejora sube un nivel, cuesta dinero y cada nivel cuesta más que el anterior (**exponencial**) hasta el **nivel 10**.
- **Armas:** ganan potencia al subir (ver la tabla de «Armas»).
- **Estructuras con función** también suben de nivel; **los pasillos no**. Ejemplos: la **estación de mando** aumenta el % de daño de su arma por nivel; las estructuras de calidad de vida dan +1 % por nivel.
- **Estructuras con niveles:** estaciones de mando, biblioteca, sala de recreación, comedor, cocina, habitaciones de tripulantes y otras. **Todas las armas** llegan al nivel 10, evolucionan y vuelven al nivel 1.
- `[PROPUESTA]` Costo: nivel 2 = 200 créditos y cada nivel +60 % (nivel 5 = 820; nivel 10 = 8.590; total 1→10 ≈ 22.600). Las estructuras usan la misma curva. Estación de mando: +5 % de daño por nivel.
- `[DEFINIDO]` **El núcleo sube de nivel** hasta el 10: nivel 2 = 500 créditos y cada nivel +25 % (nivel 10 ≈ 3.000; total ≈ 13.000). Cada nivel: +25 % de su casco base (160 → 520) y +1 plaza de tripulante (1 → 10). En datos: `PartData.upgrade_base_cost`, `upgrade_growth`, `hp_per_level` y `crew_per_level`.
- `[PROPUESTA]` Generador de escudo: 60 de escudo en el nivel 1, +15 % por nivel (141 en el 10); recarga 10/s tras 3 s sin daño; si se rompe, 6 s para volver; la pieza tiene 50 de vida; 1.800 créditos en el hangar; curva de las estructuras. Burbuja cian con brillo en el borde y barra en el HUD.
- `[POR DEFINIR]` La lista completa de estructuras con niveles.

### Evoluciones `[DEFINIDO]`
```
SI arma.nivel == 10
ENTONCES el mecánico puede evolucionarla
AL EVOLUCIONAR: el arma evolucionada reemplaza a la original y vuelve al nivel 1 (máximo 10)
                la estación de mando donde está acoplada SE CONSERVA
```
- La regla original pedía además una estructura requerida, pero como toda arma va en una estación de mando, se cumple siempre. `[POR DEFINIR]` Si alguna evolución futura necesitará una estructura especial.
- `[DEFINIDO]` Evolucionar cuesta 12.000 créditos (provisional, se ajustará jugando).
- `[PROPUESTA]` Nivel 1 de cada evolución: metralleta doble, dos balas paralelas de 10 de daño cada 0,12 s; Lanzador Tsar, cohete grande de 130 de daño en 5,5 m cada 2,4 s; cañón de positrones, rayo de 1,5 m de grosor y 62 de daño por segundo. Para vender o reconstruir, una evolución vale el arma base + 12.000.

| Arma (nivel 10) | Evolución | Qué cambia | Estado |
|---|---|---|---|
| `machine_gun` | `twin_machine_gun` (Metralleta doble) | Dos cañones: dos proyectiles a la vez | `[DEFINIDO]` |
| `rocket_launcher` | `tsar_launcher` (Lanzador Tsar) | Un cohete con muchísimo daño en un área gigante | `[DEFINIDO]` |
| `laser` | `positron_cannon` (Cañón de positrones) | Rayo muy grueso que alcanza a muchos más enemigos | `[DEFINIDO]` |

- Nombres de reserva para futuras armas: Daisy Cutter, Grand Slam, Nova, Lanza de taquiones, Haz de antimateria, Cañón de partículas.

`[POR DEFINIR]` (se verá con el tiempo): si las armas evolucionadas pueden volver a evolucionar y si las estructuras pueden evolucionar.

## Enemigos `[DEFINIDO]`
Tipos: `swarm` (drones en masa que persiguen), `tank` (lentos y resistentes), `gunner` (disparan patrones de balas; son el núcleo del bullet hell), `elite` (sueltan más chatarra o una recompensa especial) y `boss`.

### Jefes `[DEFINIDO]`
- Solo en **algunas zonas** de los sistemas; en el mapa llevan una calavera.
- Nave **grande**, con diseño llamativo y **muchos proyectiles**. Se diseña y modela en Blender (`tools/blender/build_parts.py`), en el mismo estilo que los demás enemigos.
- **Aparece cuando el combustible se recarga**, unos **5 segundos** después, tras una **alerta de peligro inminente** en el centro de la pantalla.
- Para saltar hay que derrotarlo; también se puede huir manteniendo la tecla de salto el doble de tiempo, perdiendo la recompensa.
- **No vuelve a aparecer:** la zona queda como «jefe derrotado».
- `[PROPUESTA]` Recompensa: 5 de tecnología alienígena (`alien_tech`), 1 núcleo de energía y 20 de metal común; vuela sola hacia la nave.
- `[PROPUESTA]` **El Acorazado** (`boss_dreadnought`): anillo de unos 7 m con seis torretas, núcleo con ojo rojo y dos tenazas. Está en 3 zonas con comandantes distintos (Kraal, Morvath y Nyx). Fases según su vida: 1) espiral de tres brazos y abanicos; 2) anillos de 28 balas, torretas y escoltas de enjambre; 3) doble espiral y abanicos anchos. Vida ×(1 + 0,5 por punto de dificultad). Barra de vida arriba; si la nave se aleja mucho, reaparece cerca.

### Enemigos de zonas lejanas `[DEFINIDO]`
- Hay que inventar **tipos nuevos** para las zonas lejanas y modelarlos en Blender (lo decide el asistente y se los propone al usuario).
- `[PROPUESTA]` Los tres de la fase 3 (`EnemyData.min_difficulty`): **lancero** (`lancer`, desde zonas de 10 min: se detiene a apuntar y embiste), **divisor** (`splitter`, desde 15 min: se divide en 4 drones al morir) y **sembrador** (`mine_layer`, desde 20 min: deja minas y dispara abanicos de 5 balas).
- `[PROPUESTA]` Dificultad de la zona (1 a 6 = distancia ÷ 5). Por cada punto: +45 % de vida, +15 % de enemigos y +12 % de cadencia de sus balas. En los niveles de más de 5 minutos la presión sigue subiendo al 35 %.
La dificultad sube **con cada nivel y con el tiempo dentro del nivel**: más enemigos, más resistentes, **más grandes** y con patrones de balas más densos.
`[DEFINIDO]` **Las zonas más lejanas del mapa son más difíciles:** más tipos de enemigos distintos y balas con más cadencia.

`[DEFINIDO]` **Calendario de un nivel cercano (5 min):** hasta el minuto 1:30 solo enjambres (`swarm`), cada vez más; desde el 1:30, artilleros (`gunner`) de a poco y cada vez más; desde el minuto 4, tanques (`tank`). **Las oleadas de enjambre van cada vez más espaciadas**, sobre todo al final.
`[PROPUESTA]` En datos: `EnemyData.min_stage_time` (cuándo puede aparecer) y `spawn_ramp_seconds` (empieza con el 10 % de su peso y llega al 100 % en ese tiempo). Artillero: 90 s y 150 s (completo en el minuto 4). Tanque: 240 s y 60 s. Oleadas: la primera a los 50 s y cada una 15 s más tarde que la anterior (`EnemySpawner.wave_interval` y `wave_interval_growth`): 0:50, 1:55, 3:15 y 4:50; cada una con 10 drones + 3 por minuto (`wave_size`, `wave_size_per_minute`; antes 12 + 4). Choque de un dron de enjambre: 6 de daño (antes 8). `[DEFINIDO]` El primer nivel se bajó «un poquito» (el usuario lo encontraba muy difícil con la nave inicial).

## Estilo visual e interfaz
- `[DEFINIDO]` Naves 3D sobre fondos 2D con parallax.
- `[DEFINIDO]` **Estilo de modelado:** low-poly, formas redondeadas y medio cilíndricas como los vehículos actuales, **colores planos sin texturas**, con carácter pero poco detalle.
- `[PROPUESTA]` Paleta provisional (la de los primeros modelos): casco blanco grisáceo, gris oscuro, acentos naranjas y luces cian emisivas. Silueta: domo arriba, cuerpo rectangular y motor triangular abajo.
- `[DEFINIDO]` Interfaz del nivel: **miniatura de la nave con cada pieza coloreada según el daño recibido**, y el nivel actual. **No hay barra de experiencia.**
- `[DEFINIDO]` El centro de investigación construido en un satélite lleva un **telescopio** en la parte superior de su modelo.
- `[PROPUESTA]` Contador de chatarra y carga del combustible interestelar (cuánto falta para poder saltar).
- `[DEFINIDO]` En el mapa estelar, al pasar el ratón sobre un cuerpo celeste, aparece su ficha: imagen 2D, nombre, descripción, si es habitable, temperatura y costo del terreno.
- `[DEFINIDO]` La base se ve en 3D, con los edificios sobre el cuerpo celeste (ver «Interfaz de la base»).
- `[POR DEFINIR]` El resto de las interfaces de la estación y del mapa estelar.
- `[DEFINIDO]` **Efectos visuales:** sutiles, pero con personalidad (explosiones, estelas de propulsores, sacudida de cámara, avisos de daño), sin tapar las balas.
- `[DEFINIDO]` **Efectos de sonido:** los packs de Kenney (CC0) que el usuario puso en `assets/audio/Effects/` (Interface, Sci-Fi y Digital). Elige el más adecuado a cada situación.
- `[POR DEFINIR]` **Música:** de dónde sale y su estilo; llegará en una fase posterior. No la elijas por el usuario.
- `[PROPUESTA]` Así está hecho: `Sfx` (autoload) con un sonido por arma, explosiones, golpes, chatarra (más aguda en racha), combustible, salto, jefe e interfaz; cada sonido limita sus repeticiones. Efectos visuales: chispas, estela de propulsores, sacudida de cámara (se puede apagar), borde rojo al recibir daño y destello al saltar.
- `[DEFINIDO]` **Fin de partida:** al perder la nave aparece un menú simple para reaparecer en la estación más cercana; se conserva el dinero.
- `[PROPUESTA]` **Pausa:** continuar, opciones y salir al menú (desde un nivel no guarda: la partida queda como en la última estación).
- `[DEFINIDO]` **Opciones:** resolución, pantalla completa, volumen y teclas configurables.

## Controles `[DEFINIDO]`
Moverse con WASD / flechas / stick izquierdo. **Apuntar la nave con el ratón** (`[PROPUESTA]` stick derecho en mando). Disparo automático. Pausa con Esc / Start. **Mapa estelar: M.**
`[DEFINIDO]` **Saltar: mantener Espacio unos segundos** cuando el combustible está recargado (así no se salta por accidente). `[PROPUESTA]` 2 segundos (`Stage.JUMP_HOLD_SECONDS`); en mando, mantener A.
`[DEFINIDO]` Mapa estelar en mando: botón **Back**. `[PROPUESTA]` En la estación se usa el ratón.
`[DEFINIDO]` **Teclas configurables:** en las opciones se cambian las teclas del teclado y los botones del mando.
`[DEFINIDO]` **Mando en todo:** todos los menús e interfaces (estación, mapa, base, opciones) se pueden usar con mando.
`[PROPUESTA]` Así está hecho (`GamepadCursor`): en los menús, foco con cruceta o stick, A acepta y B vuelve; en la estación, la base y el mapa, el stick izquierdo mueve el puntero, A hace clic (mantener A arrastra), X es el clic derecho, el stick derecho hace zoom, LB / RB cambian de pestaña y Start abre las opciones.

## Pautas técnicas
- `[DEFINIDO]` Resolución: al iniciar se detecta la resolución de la pantalla y se usa como resolución por defecto, con opciones típicas para cambiarla. Resolución de diseño: 1280×720 con stretch `canvas_items`.
- `[PROPUESTA]` Mundo en 3D con cámara ortográfica cenital, inclinada unos 10° (`Stage.CAMERA_TILT_DEG`; antes 22°, el usuario la bajó para probar); el fondo 2D se dibuja detrás.
- `[DEFINIDO]` **En combate tiene que notarse que la nave y los enemigos son modelos 3D.** `[PROPUESTA]` Así está hecho: cámara algo inclinada; la nave se inclina al girar o desplazarse de lado y cabecea al acelerar (solo el modelo, `ShipPart.visual`; la colisión sigue en el plano); cada enemigo tiene su movimiento de modelo (`EnemyData.motion`): pirueta de 360° al acercarse (enjambre), bamboleo de trompo (artillero), balanceo (tanque), alabeo al rodear (sembrador), tumbos (divisor), giro al embestir (lancero).
- `[DEFINIDO]` El movimiento y las colisiones ocurren en un plano (por ejemplo, el plano XZ con Y fija): las naves 3D no se mueven en altura.
- `[PROPUESTA]` Reutilizar balas y enemigos (pooling); habrá muchos a la vez.
- `[PROPUESTA]` Definir piezas, edificios y evoluciones como `Resource` de Godot (`.tres`), separando datos y lógica.
- `[PROPUESTA]` **Modelos 3D:** se generan con `tools/blender/build_parts.py` (Blender por script) y se exportan a `assets/models/parts/<id>.glb`. Escala: 1 cubo de pasillo = 1 m. Ejes: el frente de la pieza es -Z en Godot (+Y en Blender). Vista previa en Godot: `scenes/tests/parts_preview.tscn`.
- `[PROPUESTA]` Mapa estelar 3D como escena aparte con cámara orbital.
- `[DEFINIDO]` **Guardado:** una sola partida, que se guarda sola al llegar a una estación; al abrir el juego aparece «Continuar». Se guardan el dinero, la nave, los tripulantes, los niveles, lo desbloqueado, el mapa (jefes derrotados) y las bases. También se guarda al aterrizar en una base.
- **Estado del código:** fases 1 a 4 hechas: nivel con nave modular, chatarra y HUD; estación con editor de la nave por ranuras, bar, armas y evoluciones; guardado con pantalla de inicio; mapa estelar 3D con 8 sistemas y fichas; viajes y dificultad por distancia; tres enemigos de zonas lejanas y el jefe; bases en 3D con los 8 edificios, minerales, investigación, planos y reconstrucción, tripulantes en los edificios y enfermería. Fase 5 (pulido) hecha: menús (inicio, pausa, opciones, fin de partida), opciones con teclas configurables, sonidos, efectos visuales y mando en todas las interfaces. Fase 6 en curso: hechos el generador de escudo, la mejora del núcleo, el dinero inicial (1.000) y la primera bajada de dificultad del primer nivel; faltan las rondas de equilibrio y el cierre de la 0.1.0 (ver `docs/PLAN_DESARROLLO.md`). La base se rediseña en la 0.2.0. Las decisiones del prototipo que el GDD no fija están en `docs/PLAN_DESARROLLO.md` (fase 4, «Cómo está hecho»).
- `[PROPUESTA]` Movimiento suave: la interpolación física está activada (`physics/common/physics_interpolation`). Lo que se mueve fuera de los ticks de física (cámara, tweens, rayos) va con la interpolación desactivada, y lo que se teletransporta llama a `reset_physics_interpolation()`.
- Estructura de carpetas: `scenes/`, `scripts/`, `assets/sprites/`, `assets/audio/`, `docs/`. La carpeta `docs/` tiene `.gdignore` y Godot no la importa.

## Glosario

| Término (ES) | Identificador | Significado |
|---|---|---|
| Nave | `ship` | El jugador |
| Nave inicial | `starter_ship` | La nave con la que se empieza, y a la que se vuelve si se pierde la nave sin tener hangar |
| Nivel | `stage` | Zona de enemigos del mapa estelar; se sobrevive mientras se recarga el combustible interestelar. **No** es un nivel de experiencia. |
| Mapa estelar | `star_map` | Pantalla (tecla M) con sistemas planetarios, estaciones y zonas de enemigos |
| Sistema planetario | `star_system` | Una estrella con hasta 6 planetas (gaseosos o rocosos), sus satélites y asteroides |
| Motor interestelar | `interstellar_drive` | Motor de salto que viene con la nave; no se cambia ni se mejora. Gasta combustible interestelar |
| Combustible interestelar | `interstellar_fuel` | Se gasta al saltar y se recarga solo; su tiempo de recarga (5–30 min según la distancia) es la duración del nivel |
| Depósito de combustible interestelar | `interstellar_fuel_tank` | Pieza que se acopla en cualquier ranura libre; uno más grande permite saltar más lejos. Solo se consigue investigándolo |
| Terreno | `land_plot` | Parcela que se compra en un cuerpo celeste habitable para construir la base |
| Estación espacial | `station` | Lugar donde se vende la chatarra, el mecánico y los ingenieros reparan y modifican la nave, y el bar recluta personal |
| Chatarra | `scrap` | Lo que sueltan los enemigos. Hay varios tipos (`scrap_type`), cada uno con su precio. Se vende en la estación; no se gasta directamente. |
| Dinero | `money` | Moneda del juego. Se obtiene vendiendo chatarra. Unidad: créditos. |
| Base | `base` | Planeta, satélite o asteroide propio del jugador, con edificios. Se conserva al perder la nave. |
| Edificio | `building` | Construcción de la base (centro de investigación, hangar…) |
| Parcela | `building_lot` | Lugar de la base donde va un edificio |
| Mineral puro | `mineral` | Lo que produce la refinería (a partir de chatarra) y la mina; vale más que la chatarra y se vende en el puerto comercial |
| Puerto comercial | `trade_port` | Edificio de la base que vende chatarra y minerales |
| Hangar | `hangar` | Edificio que construye naves, fabrica piezas y guarda planos de naves; allí trabajan los ingenieros |
| Plano de nave | `ship_blueprint` | Diseño guardado de una nave, para construirla otra vez o reconstruirla si se pierde |
| Enfermería | `infirmary` | Edificio donde se recuperan los tripulantes heridos; sin ella, mueren |
| Pieza | `part` | Cualquier estructura, arma, motor o depósito de combustible interestelar que se instala en la nave |
| Estructura | `structure` | Pieza de metal que da estadísticas, abre ranuras o habilita evoluciones |
| Pasillo | `corridor_1x1` / `corridor_1x2` / `corridor_1x3` | Pieza más básica; cuadrado, doble o triple, con acopladores en todas sus caras |
| Estación de mando | `command_station` | Estructura donde un artillero opera un arma. No es la estación espacial (`station`) |
| Estructura de tripulación | `crew_structure` | Sala de la nave que mejora las estadísticas de los tripulantes |
| Arma | `weapon` | Pieza que ataca; va acoplada a una estación de mando. Tiene niveles de mejora. |
| Motor | `engine` | Pieza de propulsión; define la maniobrabilidad |
| Ranura / punto de acople | `slot` | Lugar donde se instala una pieza |
| Tripulante | `crew` | Persona que trabaja en la nave o en la base. Tiene estadísticas de profesión: `gunnery`, `engineering`, `research`, `repair` |
| Estadística de profesión | `profession_stat` | Valor de un tripulante en una profesión (artillero, ingeniero, investigador, reparador) |
| Puntos de investigación | `research_points` | Lo que cuesta investigar. Se generan pasivamente en el centro de investigación (más rápido con buen investigador y un 30 % más en un satélite) |
| Investigación | `research` | Desbloqueo de piezas nuevas con el centro de investigación y un tripulante investigador (también es el nombre de la estadística) |
| Evolución | `evolution` | Arma mejor que el mecánico crea a partir de un arma al nivel 10; empieza en nivel 1 |
| Primeros auxilios | `first_aid` | Estadística de tripulante que acelera la curación en la enfermería |
| Casco | `hull` | Vida de la nave |
