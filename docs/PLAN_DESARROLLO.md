# Plan de desarrollo

Plan por fases para construir el juego a partir del GDD. Cada fase deja algo jugable.

## Fase 1: base jugable (hecha, 15/11/2026)

Objetivo: el bucle principal funcionando de punta a punta, con lo mínimo de cada sistema.

| # | Tarea | Estado |
|---|---|---|
| 1 | Datos como `Resource`: piezas, armas, enemigos y tipos de chatarra (`data/`) | Hecho |
| 2 | Modelos de enemigos en Blender (mismo estilo que las piezas); la chatarra usa formas simples de Godot | Hecho |
| 3 | Nave modular: se monta desde un plano (`ship_blueprint`), vida por pieza, pérdida de piezas desconectadas | Hecho |
| 4 | Movimiento en el plano con maniobrabilidad, cámara cenital ortográfica y fondo 2D de estrellas | Hecho |
| 5 | Armas automáticas (metralleta) y proyectiles reutilizables (pool) | Hecho |
| 6 | Enemigos (enjambre, tanque, artillero) con aparición que se intensifica con el tiempo | Hecho |
| 7 | Chatarra por tipo, recolección con radio de recogida, HUD y fin del nivel | Hecho |
| 8 | Estación: vender chatarra, reparar, mejorar el arma y saltar a otro nivel | Hecho |
| 9 | Pruebas en Godot y corrección de errores | Hecho |

### Arquitectura

- `GameState` (autoload, `scripts/autoload/game_state.gd`): dinero, chatarra sin vender, plano de la nave, vida de cada pieza, tripulantes y nivel de cada arma. Pasa los datos entre el nivel y la estación.
- `Catalog` (autoload, `scripts/autoload/catalog.gd`): carga los `Resource` de `data/` y los entrega por identificador.
- `scenes/main.tscn`: arranque; lleva a la estación.
- `scenes/stage/stage.tscn`: un nivel (zona de enemigos). Dura lo que tarda en recargarse el combustible interestelar.
- `scenes/station/station.tscn`: la estación espacial (interfaz 2D).
- Física: todo ocurre en el plano XZ de Godot (Y = 0). Colisiones con `Area3D` y capas:

| Capa | Uso |
|---|---|
| 1 | Piezas de la nave del jugador |
| 2 | Enemigos |
| 3 | Proyectiles del jugador |
| 4 | Proyectiles enemigos |

### Decisiones del prototipo

Confirmadas por el usuario tras probar la fase 1 (están como DEFINIDO en el GDD v0.19):

- La **integridad del casco** es la vida del núcleo; los pasillos le suman casco. Si el núcleo llega a 0, se pierde la nave.
- Las armas disparan **en un cono hacia el frente** de su estación de mando: para disparar hay que apuntar la nave.
- La nave se mueve en todas direcciones y **apunta hacia el puntero del ratón**, girando con una velocidad limitada (v0.21; antes giraba hacia donde se movía). La maniobrabilidad define cuánto acelera y gira.
- Para **saltar** hay que **mantener Espacio unos segundos** cuando el combustible está recargado (2 s, propuesta).
- Reparar cuesta 2 créditos por punto de vida.
- Si la nave se queda sin armas útiles, en la estación se puede **volver a la nave inicial gratis**.

Siguen siendo propuestas (valores fáciles de cambiar en datos o constantes):

- Dificultad dentro del nivel: 1,1 enemigos por segundo al empezar, +0,4 por minuto; la vida de los enemigos sube un 12 % por minuto. Oleadas de enjambre cada vez más espaciadas (decidido por el usuario): la primera a los 50 s y cada una 15 s más tarde que la anterior (0:50, 1:55, 3:15 y 4:50). Élites desde el minuto 1 (4 %).
- Calendario (decidido por el usuario): solo enjambres hasta 1:30, artilleros de a poco desde 1:30 (completos en el minuto 4) y tanques desde el minuto 4 (`min_stage_time` y `spawn_ramp_seconds` en `data/enemies/`).
- Cada enemigo suelta metal común; el artillero puede soltar componentes electrónicos, el tanque blindaje pesado y los élites un núcleo de energía.

### Cómo probar

- Jugar: abrir el proyecto en Godot y pulsar F5 (empieza en la estación). Mover con WASD o flechas y apuntar con el ratón; mantener Espacio 2 segundos para saltar cuando el combustible está recargado; Esc para pausar. En la estación, clic en una ranura (círculo) o en una pieza.
- Prueba automática del bucle completo (nivel de 90 s con piloto automático, salto, estación y captura):
  `Godot --path . -- --start-stage --autopilot --stage-seconds=90 --screenshot=<png> --screenshot-at=85 --auto-jump --auto-station --station-screenshot=<png> --quit-after-station`
- Prueba del editor de la nave (construye una nave más grande, contrata tripulantes y guarda capturas de la estación y del bar):
  `Godot --path . -- --build-test --money=20000 --station-screenshot=<png> --quit-after-station`
- `--spawn-log` imprime cuántos enemigos de cada tipo aparecen cada 30 s, e `--invulnerable` hace que la nave no reciba daño (solo pruebas).
  Sin `--quit-after-station` salta después a un nivel (añade `--autopilot --screenshot=<png> --screenshot-at=<s> --quit-after-screenshot`).

## Fase 2: construcción de la nave (hecha, 15/11/2026)

Editor de la nave en la estación: comprar piezas y acoplarlas en ranuras libres, con las reglas de acopladores del GDD. Bar con candidatos al azar y asignación de tripulantes a cada estación de mando. Lanzacohetes y láser funcionando. Modelos que faltan: habitaciones, recolector magnético, propulsor mediano, depósito de combustible, lanzacohetes y láser.

### Enfoque técnico

| # | Tarea | Estado |
|---|---|---|
| 1 | **Ranuras en los datos:** añadir a `PartData` una lista de ranuras (posición, dirección hacia afuera y tipo: `structure`, `accessory` o `weapon`). Pasillos según el GDD (1, 2 o 3 acopladores por cara larga y 1 por extremo; arriba y abajo solo accesorios). Núcleo: frente, atrás, izquierda, derecha y acoplador central arriba. Estación de mando: unión atrás y ranura frontal de arma. Propulsor: unión delante. | Hecho |
| 2 | **Plano de la nave:** cada entrada guarda, además de `attached_to`, la ranura del padre (`parent_slot`). La posición y el giro se calculan a partir de la ranura (ya no se escriben a mano). Comprobar que dos piezas no se solapen en el plano. | Hecho |
| 3 | **Editor en la estación:** vista 3D cenital de la nave (SubViewport) con las ranuras libres resaltadas. Clic en una ranura: lista de piezas compatibles con su precio. Comprar la coloca; también se puede quitar o vender una pieza (y lo que cuelga de ella). | Hecho |
| 4 | **Bar:** candidatos al azar con las cifras propuestas en el GDD (estadísticas 1–100, precio = mejor estadística² ÷ 2, de 3 a 5 candidatos que cambian en cada visita) y asignación de tripulantes a estaciones de mando. Las habitaciones limitan cuántos caben. | Hecho |
| 5 | **Armas nuevas:** lanzacohetes (proyectil lento que explota con daño en área) y láser (rayo continuo que atraviesa enemigos en línea, con un `RayCast3D` o una forma alargada). | Hecho |
| 6 | **Modelos que faltan** en `tools/blender/build_parts.py` (sigue siendo la fuente de los modelos; el MCP de Blender sirve para probar y revisar) y sus `.tres` en `data/`. | Hecho |
| 7 | Probar en Godot con las pruebas automáticas y actualizar la documentación. | Hecho |

Además, con los comentarios de la prueba de la fase 1:

- **Temblor de la nave al avanzar:** la cámara se movía en `_process` y la nave en `_physics_process`. Se activó la interpolación física (`physics/common/physics_interpolation`) y la cámara sigue la posición interpolada de la nave.
- **Disparo en cono** (`WeaponData.aim_cone_degrees`, 35° a cada lado) y **salto manteniendo Espacio** (`Stage.JUMP_HOLD_SECONDS`, 2 s).

### Cómo está hecho

- `PartData` guarda las ranuras: `slot_positions`, `slot_normals` (hacia afuera), `slot_kinds` (`SIDE` admite cualquier pieza; `FACE`, arriba o abajo, solo accesorios) y `mount_slot`. Los .tres de piezas y armas se generan con `node tools/data/gen_data.js .`
- Cada entrada del plano (`GameState.blueprint`) guarda `attached_to`, `parent_slot` y `mount_slot`; `transform` se calcula con `GameState.attach_transform` (las dos ranuras quedan enfrentadas). `check_placement` comprueba el tipo de ranura y que la pieza no se solape con otras (la estación de mando reserva el hueco de su arma).
- `GameState` también tiene la compra, el giro y la venta de piezas (`buy_part`, `rotate_part`, `sell_part`), las armas (`buy_weapon`, `sell_weapon`), las mejoras de estructuras, las plazas de tripulantes, el bono de calidad de vida y el bar (`refresh_bar`, `hire_candidate`).
- Estación: `ShipEditorView` (`scripts/station/ship_editor_view.gd`) es la vista 3D de la nave con cámara orbital (desde la v0.25; antes era cenital), con las ranuras y la selección. Una ranura se muestra y se puede elegir si ninguna pieza la tapa desde la cámara; las piezas se eligen con un rayo contra sus cajas. `station.gd` arma las pestañas Mecánico, Bar y Chatarra.
- Armas: `ShipWeapon` dispara balas, cohetes (`Rocket`, daño en área) o un rayo continuo, según `WeaponData.kind`.
- El piloto automático de las pruebas apunta al enemigo más cercano y se mueve para mantener la distancia (se aparta si se acerca y lo rodea si no).

### Pendiente de revisar jugando

- Con el cono a 50° y el nuevo calendario de enemigos, el piloto automático con la nave inicial aguanta unos 2:50 de un nivel de 5 minutos (lo derriban los enjambres). Hay que ver jugando a mano si los enjambres son demasiados.

## Fase 3: mapa estelar y progresión

Decisiones del usuario (15/11/2026, en el GDD v0.23):

- **Mapa estelar 3D** con **8 sistemas** (estrella, planetas, satélites, asteroides, estaciones y zonas), nombres inventados y fijos. Se abre con M o con Back en el mando.
  - Vista de galaxia: rueda para el zoom, arrastrar para girar.
  - Al elegir un sistema, la cámara viaja a él. Al elegir un planeta, satélite, estación o la estrella, se acerca a verlo.
  - La partida empieza en una estación del primer sistema.
- **Fichas al pasar el ratón:**
  - Cuerpo celeste: imagen 2D, nombre, descripción, habitable, temperatura y costo del terreno, con el botón de compra desactivado hasta la fase 4. El usuario quiere ver cómo queda.
  - Zona: nombre, duración, dificultad y tipos de enemigos; calavera, nombre del jefe y advertencia si tiene jefe.
- **Viajes:**
  - Cada zona tiene una distancia fija (5–30 min) que marca su dificultad y su costo de combustible.
  - Al recargarse el combustible, el jugador **abre el mapa y elige a dónde saltar**: estación o zona al alcance.
  - Se pueden encadenar zonas.
- **Jefes:**
  - Solo en algunas zonas. Aparecen **5 s después** de recargarse el combustible, tras una **alerta de «peligro inminente»** en el centro de la pantalla.
  - Hay que derrotarlo para saltar, o huir manteniendo el salto el doble de tiempo y perder la recompensa.
  - No reaparece.
  - Modelo en Blender: grande y con muchos proyectiles (diseño libre).
  - Recompensa propuesta: 5 `alien_tech` y 1 `energy_core`.
- **Enemigos nuevos para zonas lejanas:** diseño libre, con modelos en Blender.
- **Depósitos de combustible:** por ahora se compran en las estaciones (1.500 / 4.000 / 10.000 / 25.000 / 60.000 créditos); cada uno reemplaza al anterior.
- **Estaciones:** todas iguales por ahora.
- **Guardado:** una sola partida, automático al llegar a una estación, con «Continuar» al abrir el juego.
- **Evoluciones:** 12.000 créditos, solo con el arma al nivel 10.

### Tareas

| # | Tarea | Estado |
|---|---|---|
| 1 | **Guardado y pantalla de inicio** | Hecho |
| 2 | **Evoluciones de armas** | Hecho |
| 3 | **Datos del universo** (8 sistemas) | Hecho |
| 4 | **Mapa estelar 3D** con fichas | Hecho |
| 5 | **Viajes, dificultad por distancia y depósitos** | Hecho |
| 6 | **Enemigos nuevos** de zonas lejanas | Hecho |
| 7 | **Jefe** | Hecho |
| 8 | Pruebas automáticas y documentación | Hecho |

### Cómo está hecho

- **Guardado** (`GameState.save_game` / `load_game`): JSON en `user://save.json` con dinero, chatarra, plano (sin las posiciones: se recalculan con las ranuras), tripulantes, candidatos del bar, depósito, lugar del mapa y jefes derrotados. Se guarda al llegar a una estación, al saltar desde ella y con «Guardar y salir al menú». Las pruebas con argumentos usan `user://save_test.json` (o `--save-path=`) para no pisar la partida del jugador.
- **Pantalla de inicio** (`scenes/main.tscn`, `scripts/main.gd`): «Continuar» (si hay partida), «Nueva partida» (pide confirmación si ya hay una) y «Salir».
- **Evoluciones:** `GameState.evolve_weapon` cambia el arma al nivel 10 por su `evolves_into` (nivel 1) por 12.000 créditos; la estación de mando se conserva. Las evoluciones tienen `for_sale = false`. `WeaponData.barrels` (cañones paralelos) y `projectile_scale` (tamaño del cohete). Modelos en `build_parts.py`.
- **Universo:** `node tools/data/gen_universe.js .` genera `data/universe/<sistema>.tres` (`StarSystemData` con sus `CelestialBodyData`, `StationData` y `ZoneData` como subrecursos). `Catalog` los indexa (`site`, `zone`, `body`, `system_of`, `start_station`, `enemies_for_difficulty`).
- **Mapa estelar** (`scripts/star_map/star_map.gd`, clase `StarMap`): `CanvasLayer` con un `SubViewport` 3D propio que se abre encima de la estación o del nivel (en pausa). Galaxia → sistema → cuerpo, con la cámara que viaja interpolando. Selección por cercanía en pantalla (sin física). Las fichas usan otro `SubViewport` que renderiza una copia del cuerpo. Superficie de los planetas: `planet.gdshader` (ruido o bandas, colores planos). Calavera en pixel art generada por código. Los sistemas están separados (`GALAXY_SCALE` = 14 en `gen_universe.js`; la galaxia se abre centrada en el sistema actual y se desplaza arrastrando con el botón derecho); de lejos solo se ven las estrellas: los planetas, estaciones y zonas se ocultan (`CONTENT_HIDE_DIST`) y, si se sigue alejando, se pasa a la vista de la galaxia.
- **Viajes:** `GameState.location` es una estación o una zona; `travel_to` empieza el nivel (duración = distancia de la zona) o va a la estación. `can_reach`: zona con distancia ≤ depósito; las estaciones siempre. En el nivel, con el combustible recargado se pulsa M (o se mantiene ESPACIO) para abrir el mapa y fijar el destino; después se mantiene ESPACIO para saltar.
- **Dificultad por zona** (1 a 6 = distancia ÷ 5): vida de los enemigos ×(1 + 0,45 por punto), aparición ×(1 + 0,15), cadencia de sus balas ×(1 + 0,12), élites +1 %. En los niveles de más de 5 min la presión sigue subiendo, pero al 35 %.
- **Enemigos nuevos** (`data/enemies/`, `EnemyData.min_difficulty`): lancero (`lancer`, dificultad 2: apunta y embiste), divisor (`splitter`, 3: se divide en 4 drones) y sembrador (`mine_layer`, 4: deja minas y dispara en abanico).
- **Jefe** (`scripts/enemies/boss.gd`, `data/enemies/boss_dreadnought.tres`): el Acorazado, en 3 zonas (dificultad 2, 4 y 6) con nombres distintos. 3 fases según su vida (espiral + abanicos; anillos + torretas + escoltas; doble espiral). Vida ×(1 + 0,5 por punto de dificultad). Su recompensa vuela sola hacia la nave.

### Propuestas de la fase 3 (sin confirmar)

- Saltar a una estación no tiene límite de alcance (sus cargadores rellenan el combustible).
- Al destruirse la nave se reaparece en la estación del sistema donde estaba la zona.
- El depósito comprado es un valor de la partida (`GameState.fuel_tank_level`), no una pieza montada en la nave.
- Precio de las evoluciones para vender y reconstruir: arma base + 12.000.
- Diseño y números de los enemigos nuevos y del jefe; los multiplicadores de dificultad.
- El mapa se maneja con el ratón; con mando solo se abre y se cierra.

## Fase 4: la base (hecha, 15/11/2026)

Compra de terreno, bases en 3D con edificios, minerales, investigación, hangar y planos, tripulantes en los edificios. Estructuras de calidad de vida con su +1 % por nivel. El diseño está en el GDD v0.29, capítulo 7.

### Decidido por el usuario (15/11/2026)

- Base en 3D; edificios en 3D hechos en Blender, que se reconozcan por su función. La interfaz, la colocación, los costos y los niveles los propone el asistente.
- Varias bases, para sumar su producción. Ir a la base: clic en el cuerpo del mapa y botón «Aterrizar» si el terreno es del jugador.
- La base hace de estación solo con los edificios adecuados (repostar, reparar, vender, reclutar).
- La mina solo produce con el juego abierto. La refinería convierte la chatarra en minerales puros (los mismos que extraen las minas, más caros que la chatarra) y el puerto comercial vende todo.
- Reconstruir desde el plano sale un poco más barato que comprar las piezas; construir, reconstruir o reparar necesita al menos un ingeniero en el hangar.
- Tripulantes: en la ventana de cada edificio, un botón para asignar o quitar.
- Árbol de investigación: más adelante; por ahora, unas piezas inventadas para investigar.
- Las estaciones siguen vendiendo depósitos por ahora.
- La base no puede ser atacada; las defensas (torretas) quedan para mucho más adelante.
- Confirmado después (v0.29): cargador de combustible como edificio; una sola nave con varios planos; un edificio de cada tipo por base y parcelas 4/6/9; la refinería y la mina sin tripulantes; las estaciones no compran minerales (hace falta el puerto comercial); la chatarra se descarga al aterrizar (por ahora).

### Propuestas del asistente (en el GDD, sin confirmar)

Costos y niveles de los edificios, los cinco minerales y sus precios, tasas de refinería, mina y puerto, el 80 % de reconstrucción, cuántos planos se guardan, reaparecer en la base con hangar, evacuación de heridos, piezas para investigar e interfaz de la base. Se ajustarán jugando.

### Tareas

1. Datos: `BuildingData` y `MineralData` (.tres generados por script), minerales en `data/minerals/`, edificios en `data/buildings/`.
2. `GameState`: bases (cuerpo, edificios con nivel, tripulantes asignados), lo guardado en las bases, investigación en curso y desbloqueos, planos, ubicación de los tripulantes y heridos. Guardar y cargar todo.
3. Mapa estelar: botón «Comprar terreno» activo, marca de base y botón «Aterrizar»; la base como destino de salto.
4. Escena de la base: suelo del cuerpo en 3D, parcelas, cámara orbital, construir y mejorar edificios, ventana de cada edificio con asignar/quitar tripulantes.
5. Producción con el juego abierto (también en los niveles): investigación, refinería, mina, curación y entrenamiento.
6. Hangar: funciones del mecánico, planos, reconstrucción y reaparecer en la base. Puerto comercial, academia, enfermería y cargador.
7. Investigación: estructuras de tripulación (biblioteca, comedor, cocina, sala de recreación) y algunas piezas nuevas; depósitos investigables.
8. Modelos en Blender: los 8 edificios, la plataforma de aterrizaje y las piezas nuevas.
9. Pruebas automáticas con argumentos (`--base-test`) y capturas.

### Cómo está hecho

- **`Bases`** (`scripts/autoload/bases.gd`, autoload que carga antes de `GameState`): las bases ({body, founded, buildings [{type, lot, level}], mine_acc, mine_next}), lo guardado en ellas (`storage`, chatarra y minerales, común a todas), los tripulantes de las bases (`Bases.crew`, aparte de `GameState.crew`, que son los de la nave), la investigación, los planos y la producción en `_process` (solo con el juego abierto). Se guarda dentro de la partida (`SAVE_VERSION` 2).
- **Datos:** `BuildingData` (`data/buildings/`) y `MineralData` (`data/minerals/`), generados por `tools/data/gen_data.js`, igual que las piezas nuevas (`research_points`) y las armas nuevas (`pierce`, `pellets`).
- **Escena de la base** (`scenes/base/base.tscn`, `BaseScreen` hereda de `Station`): vista 3D (`BaseView`) con el suelo del cuerpo, las parcelas en anillo alrededor de la plataforma de aterrizaje y la nave. Pestañas Base (la ventana del edificio o de la parcela elegida), Hangar (el taller de la estación, solo con hangar e ingeniero) y Tripulación (bajar y subir tripulantes). `GameState.go_to_station()` abre la base si la nave está en una.
- **Mapa:** el botón «Comprar terreno» funciona; los cuerpos con base llevan un aro verde y su ficha tiene «Aterrizar». `GameState.travel_to` acepta el id de un cuerpo con base.
- **Modelos:** los 8 edificios, el telescopio y la plataforma están en `assets/models/buildings/` (`tools/blender/build_parts.py`). Las piezas nuevas, en `assets/models/parts/`.

Decisiones del prototipo (no están en el GDD; propuestas):
- Cambiar de investigación pierde lo avanzado en la anterior.
- Asignar a un edificio a un tripulante de la nave lo baja a la base. Para entrenar en la academia, el tripulante tiene que estar en esa base.
- Sin cargador, al aterrizar hay que esperar lo que tarda en recargarse el depósito entero (`tank_minutes`).
- Los heridos van a la enfermería de la base actual o, si no tiene, a la primera base con enfermería.
- Al perder la nave, se reaparece en la base con hangar que tenga ingeniero (o en la primera con hangar). La reconstrucción usa el plano guardado solo al despegar.
- La refinería procesa primero la chatarra que da el mineral más caro. Sin chatarra, no acumula trabajo.
- Cañón de partículas: 30 de daño cada 0,9 s y atraviesa 4 enemigos (900 créditos). Escopeta de fragmentos: 6 perdigones de 7 de daño en 32° cada 0,7 s (800 créditos). Piezas: estructuras de tripulación 350, habitación grande 650 (6 plazas), placa pesada 260 (blindaje 6), recolector grande 380 (+4,5 m) y propulsor grande 700 (+3,5 velocidad, +4,5 maniobrabilidad).
- **Falta:** el generador de escudo (está en la lista del GDD, pero no se implementó).

Pruebas: `--base-test --money=60000 --base-speed=200 [--base-body=<id>]`, `--continue --base-jump=<zona> --destroy-at=3 --rebuild-test`, `--start-stage --starter-weapon=<id>`.

### Pendiente de la fase 3 (que el usuario lo pruebe y opine)

- Mapa estelar, fichas, viajes, jefe y dificultad de las zonas lejanas (la dificultad 4 es muy dura con la nave inicial).
- Propuestas sin confirmar: estaciones siempre al alcance, reaparecer en la estación del sistema, el depósito no es una pieza montada, precio de las evoluciones, números de enemigos, jefe y dificultad, nombres de los sistemas, el mapa no se navega con mando.

## Fase 5: pulido (hecha, 16/11/2026)

- **Menús:** menú principal (nueva partida, continuar, opciones, salir), pausa con opciones y pantalla de fin de partida.
- **Opciones:** resolución detectada al iniciar con opciones típicas para cambiarla (GDD 12), pantalla completa, volumen y controles.
- **Sonido y música:** disparos, explosiones, impactos, recogida de chatarra, interfaz y música para el nivel, la estación y el mapa.
- **Efectos visuales:** partículas de explosión, estelas de propulsores, sacudida de cámara y avisos de daño.
- **Mando:** navegación completa de menús e interfaces con mando.
- **Rendimiento:** pruebas con cientos de enemigos y balas; enemigos reutilizables (pool) si hace falta.
- **Android:** investigar la adaptación (controles táctiles, rendimiento, resolución), como pide el GDD.

### Cómo está hecho

- **`Settings`** (`scripts/autoload/settings.gd`): pantalla (pantalla completa por defecto, resolución de la ventana, VSync), volumen por bus (`Master`, `SFX`, `UI`; `Music` ya existe para más adelante), sacudida de cámara y teclas. Se guarda en `user://settings.cfg`, aparte de la partida. Reasignar quita esa tecla a la otra acción que la usara. `Settings.control_name(acción)` da el nombre de la tecla o del botón (según el último control usado) para los textos de ayuda. Las pruebas con argumentos no cambian la ventana.
- **`Sfx`** (`scripts/autoload/sfx.gd`): tabla `SOUNDS` con los archivos de Kenney elegidos para cada situación, su bus, volumen, tono al azar, intervalo mínimo y copias a la vez. Pone sonido a todos los botones y pestañas (`node_added`). El láser usa un sonido en bucle mientras el rayo esté encendido (`Sfx.beam_on()`); la chatarra sube de tono en racha (`play_scrap`).
- **`GamepadCursor`** (`scripts/autoload/gamepad_cursor.gd`): en las pantallas del grupo `gamepad_pointer` (estación, base y mapa) el mando mueve el puntero del ratón y A / X hacen clic; si hay un nodo visible del grupo `gamepad_menu` (pausa, opciones, fin de partida, diálogos, menú principal), el mando navega con el foco. Acciones nuevas `tab_prev` / `tab_next` (LB / RB).
- **Menús:** `OptionsMenu` (`scripts/ui/options_menu.gd`) se abre desde el menú principal, la pausa y la estación (botón «Opciones» o Start). La pausa y la pantalla de nave destruida están en `StageHud`. Al perder la nave, `Stage.respawn()` llama a `GameState.on_ship_destroyed()`, que ahora siempre lleva a la estación del sistema.
- **Efectos:** `Effects.sparks` (chispas al morir enemigos y en las explosiones de cohetes), `Effects.thruster_trail` (estela de los propulsores, `Ship`), `Stage.shake` (sacudida por «trauma»), borde rojo (`scripts/stage/damage_vignette.gdshader`) y destello al saltar (`StageHud.jump_flash`).
- **Rendimiento:** en la zona más difícil (`zone_velo_nyxar`), a los 4 minutos hay 160 enemigos y unas 930 balas a 135–144 FPS (`--perf-log`). No hace falta reutilizar enemigos por ahora.

Pruebas nuevas: `--ui-test=<carpeta>` (capturas de la pausa y las opciones), `--pad-test` (mando en la estación), `--perf-log`, `--game-over-screenshot=<png>`.

Decisiones del prototipo (propuestas, en el GDD v0.31): salir al menú desde un nivel no guarda; Start en la estación abre las opciones; las chispas son de color claro para no confundirlas con las minas naranjas.

### Decisiones del usuario para la fase 5 (16/11/2026, GDD v0.30)

- **Teclas configurables:** teclado y mando, desde las opciones.
- **Mando:** todos los menús e interfaces (inicio, pausa, opciones, estación, mapa, base) se usan con mando.
- **Fin de partida:** al perder la nave, un menú simple para reaparecer en la estación más cercana; se conserva el dinero.
- **Efectos visuales:** sutiles, pero con personalidad.
- **Sonido:** los packs de Kenney que puso en `assets/audio/Effects/` (Interface, Sci-Fi y Digital). **Música:** en una fase posterior.
- **Android:** mucho más adelante. No investigarlo todavía (sale de la fase 5).
- **Equilibrio:** hay que cambiar muchas cosas, pero más adelante.
- **Generador de escudo:** pendiente.
- **La base:** no le gusta; se rediseñará por completo. Pendiente de que explique el diseño nuevo: no ampliar ni pulir la base actual.
- **Cámara del nivel:** inclinada 10° (antes 22°).

### Antes de empezar la fase 5 (estado al 15/11/2026, ya respondido arriba)

- **Pendiente de la fase 4:** el generador de escudo (pieza avanzada de la lista de investigación) no está implementado. El usuario está probando la base a mano: esperar su opinión.
- **Dinero inicial:** `GameState.STARTING_MONEY` = 1.000 créditos (decisión del usuario, 20/11/2026; antes 100.000 para sus pruebas).
- **Preguntas para el usuario** (no decidir por él):
  1. Sonido y música: ¿de dónde salen (bancos libres, generados, compuestos)? ¿Qué estilo de música?
  2. Opciones: ¿qué ajustes quiere además de resolución, pantalla completa y volumen? ¿Reasignar teclas?
  3. Menú de pausa y pantalla de fin de partida: ¿qué muestran? (El juego no tiene un «fin»: ¿se refiere a perder la nave?)
  4. Efectos visuales: ¿cuánto? (sacudida de cámara, estelas, partículas).
  5. ¿Se hace ya el mando en todas las interfaces y la investigación de Android, o se deja para después?
  6. Si hay cambios de equilibrio tras sus pruebas de las fases 3 y 4 (dificultad, precios, tiempos de la base).

## Fase 6: equilibrio, generador de escudo y cierre de la 0.1.0 (hecha, 25/11/2026)

### Respuestas del usuario (20/11/2026, GDD v0.32)

1. **Equilibrio:** el primer nivel con la nave inicial es muy difícil (para ganar dinero hay que sobrevivirlo sí o sí, y sin mejoras se muere mucho). Los 1.000 iniciales ayudan, pero pidió bajarlo «un poquito».
2. **Hitos de tiempo:** le sirven (ver la tabla de abajo; ahora son `[DEFINIDO]`).
3. **Castigo:** si el jugador juega con cuidado, no debería perder la nave. Perderla y perder lo farmeado ya castiga bastante.
4. **Escudo:** accesorio arriba y abajo, y solo uno por nave.
5. **Dinero inicial:** 1.000 créditos.
6. **Git:** sí. El usuario pasará el repositorio en la siguiente petición.
7. **Idea nueva: el núcleo sube de nivel** (como las demás estructuras): más casco y más plazas. Elegido: nivel 2 = 500 créditos y +25 % por nivel; +25 % del casco base y +1 plaza por nivel.

### Hecho (20/11/2026)

- **Mejora del núcleo:** `PartData` tiene `upgrade_base_cost` / `upgrade_growth` (curva propia; 0 = la general), `hp_per_level` y `crew_per_level`, con `hp_at`, `crew_at`. `GameState.level_cost(data, level)` es la curva de cualquier estructura (también la usa `Bases.blueprint_value`). Al mejorar, la pieza gana la vida extra aunque esté dañada. En la estación, el botón dice lo que gana («+40 casco, +1 plaza»).
- **Generador de escudo** (`shield_generator`, modelo en `build_parts.py`): `PartData.shield_*`, `unique` (uno por nave, lo comprueba `check_placement`) y `face_only` (solo arriba o abajo). `Ship.absorb_shield` recibe el daño antes que la pieza (`ShipPart.take_damage`; `through_shield` solo para `--destroy-at`) y `_tick_shield` lo recarga. Burbuja: `Effects.shield_mesh` / `shield_material` (`scripts/combat/shield.gdshader`, parámetros de instancia `glow` y `strength`). Sonidos `shield_hit`, `shield_break`, `shield_up`. Barra «Escudo» en el HUD. Se investiga (1.000 puntos) y se fabrica en el hangar.
- **Dinero inicial:** 1.000.
- **Herramientas de medición:** `--time-scale=N` (tiempo acelerado, con más ticks de física), `--balance-run` (al recargarse el combustible o al perder la nave imprime `balance zone=… survived=… hull_left=… damage=… shield_absorbed=… kills=… scrap_value=…` y `balance damage_by …`, y se cierra), `--starter-shield`. El piloto automático ahora esquiva las balas que se le acercan y a los enemigos pegados. `Ship.damage_log` cuenta el daño por origen (`Ship.damage_source` lo fija quien hace el daño).

### Primera medición: primer nivel con la nave inicial (zona Cinturón de Chatarra, piloto automático, `--time-scale=6`)

| Prueba | Resultado (6 o 7 partidas) |
|---|---|
| Piloto sin esquivar, números originales | Muere siempre, entre 2:12 y 3:15 (mediana 2:45) |
| Piloto que esquiva, números originales | Muere entre 2:42 y 3:22 (mediana 3:15) |
| Piloto que esquiva, cambios de abajo | Muere entre 3:15 y 3:43 (mediana 3:25) |

- **De dónde viene el daño:** unos 200 de los ~280 son choques de drones de enjambre; el resto, balas de artilleros. Muere cerca de la oleada de las 3:15.
- **Cambios (pedidos por el usuario, «un poquito»):** choque de dron 8 → 6; oleadas de 12 + 4 por minuto a 10 + 3 (`EnemySpawner.wave_size` y `wave_size_per_minute`).
- **Ojo:** el piloto automático sigue siendo peor que una persona (no sabe usar el cono de disparo y los drones lo rodean). Sirve para comparar cambios; la prueba del usuario manda.
- **Chatarra:** al morir a los 3 minutos ya lleva 300–480 créditos de chatarra. Un nivel completo de 5 minutos da bastante más que los ~300 del GDD: revisarlo en las rondas de equilibrio.

### Prueba del usuario (antes de las rondas)

El primer nivel con la nave inicial «es desafiante pero es pasable completamente», y el sonido se escucha bien. Se mantiene así.

### Simulación de partida entera (`--balance-career`, `scripts/tests/balance_career.gd`)

- Un «jugador cuidadoso» con el piloto automático juega niveles; en cada estación vende, repara (o repara lo que alcance), contrata artilleros para las estaciones sin tripulante, aparta una reserva para reparar y compra según una lista fija: núcleo 2, metralleta extra, armas a 3, Depósito I, placas de blindaje en pasillos y núcleo, núcleo 4, láser, armas a 5, primera base (12.500 apartados, no se construye), Depósito II, evolución, Depósito III, núcleo 6, lanzacohetes, armas a 7, Depósito IV, armas a 10, Depósito V, núcleo 10.
- Va más lejos tras dos niveles limpios con al menos el 50 % del casco, solo si ya compró lo que pide esa distancia (`TIER_STEPS`), y vuelve a 5 min si casi muere. Al jefe va solo con la nave de la distancia siguiente; si no cae en 4 min, huye.
- **Calibración:** recibe el 8 % del daño del piloto (`--player-damage=0.08`). Con eso el primer nivel con la nave inicial pierde el 30–50 % del casco, como pide el GDD 2.4. Con el 12 % perdía el 60–90 %.
- Sin hangar, si se queda sin un arma con artillero vuelve a la nave inicial (`abandon_ship`) y empieza la lista de nuevo. Es lo que más frena la partida simulada.

### Rondas de equilibrio (hasta el 25/11/2026)

| Ronda | Cambio | Qué pasó |
|---|---|---|
| 0 | Números de la v0.32, daño 12 % | En 16 h no salió de la nave inicial. El propulsor pequeño (30 de vida, 250 créditos) se destruía casi siempre y la estación de mando muchas veces: reparar costaba 600–1.100 por nivel, más de lo que se ganaba (550–900). |
| 1 | Propulsores 30/45/60 → 70/100/130 de vida; simulación al 8 %; no va lejos sin mejorar | Primer nivel 0:06, primera arma extra 0:12–0:24, Depósito I 0:36–0:42. Atasco en las zonas de 10 min: casi muere siempre. |
| 2 | Comparar +45/+15 % por dificultad contra +30/+10 % | Poca diferencia. El daño por origen muestra al **lancero** como el que más pega (14 cada 0,4 s pegado a la nave): de 180 a 1.000 por nivel. |
| 3 | Lancero 14 cada 0,4 s → 10 cada 0,8 s; «reparar lo que alcance» | Mejor, pero en cada zona de 10 min se rompen los pasillos (40 de vida) con las estaciones de mando que cuelgan de ellos: 2.000 de reparación. |
| 4 | El simulador pone placas de blindaje | El núcleo queda al 90 %, pero las tres estaciones de mando se destruyen en cada zona de 10 min. |
| 5 | Estación de mando 90 → 150 de vida; +30/+10 % por dificultad | **Con +30/+10 % la zona de 10 min se vuelve rentable** (3.500 de chatarra, 500–1.000 de reparación). Primera base a las 3:05 y primera evolución a las 5:50. Con +45/+15 % sigue atascada. |

**Hitos medidos (ronda 5, números de la 0.1.0) contra los objetivos del GDD 2.4:**

| Hito | Objetivo | Medido |
|---|---|---|
| Primer nivel con la nave inicial | Perder 30–60 % del casco | 30–40 % (0:06) |
| Primera arma extra | 2 o 3 niveles | 2 niveles (0:12) |
| Depósito I | ~30 min | 0:42 |
| Primera base útil | ~2 h | 3:05 |
| Primera evolución | 4–5 h | 5:50 |
| Zonas de 30 min y último jefe | 10–15 h | No llegó: atasco en las zonas de 15 min |

**Números que quedan en la 0.1.0** (todos `[PROPUESTA]`, en datos): propulsores 70/100/130 de vida, estación de mando 150, lancero 10 de daño cada 0,8 s, `hp_per_difficulty` 0,3, `rate_per_difficulty` 0,1. Se quitó `scrap_per_difficulty` (no se usaba). Los ingresos se dejaron como están: con ellos los primeros hitos caen donde pide el GDD. El «unos 300 créditos por nivel» del GDD pasa a «unos 800» (lo medido).

### Pendiente para la 0.2.0 (o para otra ronda de equilibrio)

1. **Zonas de 15 min:** al llegar con un arma evolucionada, una estación de mando destruida cuesta 12.000–15.000 en reparación (el arma evolucionada vale el arma base + 12.000 y se compra entera). Una mala partida borra horas de progreso. Hay que decidir con el usuario: ¿reconstruir una evolución más barato, o que el arma no se pierda al destruirse su estación?
2. **El lancero** sigue siendo el que más daño hace en todas las zonas lejanas.
3. **Lo que más frena la partida es volver a la nave inicial:** sin hangar se pierden las mejoras del núcleo y de las armas. La simulación no construye bases (solo aparta el dinero), así que no usa el hangar ni la enfermería. Simular la base de verdad haría más fiable la parte de 3 h en adelante.
4. Las piezas que sobresalen (pasillos de 40 de vida con estaciones de mando) son lo primero que se rompe; las placas de blindaje solo protegen el pasillo.

### Cierre técnico de la 0.1.0

- Versión `0.1.0` en `project.godot` (`application/config/version`); el menú principal la muestra abajo a la derecha.
- `export_presets.cfg`: preset «Windows Desktop» → `builds/windows/BulletHellSurvivor.exe` (un solo .exe con el .pck dentro; sin `docs/` ni `tools/`). Faltan las plantillas de exportación de Godot 4.7.2 en este equipo (solo están las de 4.4.1).
- Git: `https://github.com/RicardoSoto97/Space_Bullet_Hell`, ramas `main` y `v0.1.0`. No se creó una etiqueta `v0.1.0`, porque tendría el mismo nombre que la rama.
- Pruebas sin pantalla: `Settings.input_name` ya no pide la distribución del teclado con `--headless` (daba «Not supported by this display server»).

## Diseño de la fase 6 (19/11/2026)

### Decidido por el usuario (19/11/2026)

- **La base se rediseña en la versión 0.2.0** (junto con los modelos de Blockbench). En la 0.1.0 queda como está: no se amplía ni se pule.
- **Fase 6:** probar el bucle jugable y tocar los números del equilibrio («hay que cambiar muchas cosas»), y hacer el generador de escudo.
- Después de la fase 6 se cierra la versión 0.1.0.

### 1. Generador de escudo (propuesta; el usuario eligió accesorio arriba o abajo, uno por nave)

En el GDD solo dice: «pieza avanzada: un escudo que absorbe daño y se recarga», 1.000 puntos de investigación.

- **Pieza:** `shield_generator`, un **accesorio** que va en las caras de arriba o de abajo, como la placa de blindaje. Así no ocupa las ranuras laterales con las que crece la nave.
- **Cómo funciona:** crea una burbuja alrededor de toda la nave que recibe el daño (balas y choques) antes que las piezas. Cuando la burbuja llega a 0 se rompe y las piezas vuelven a recibir el daño.
- **Números:**
  - Escudo de 60 puntos en el nivel 1, +15 % por nivel (141 en el nivel 10). Como referencia, el casco de la nave inicial tiene 160.
  - Se recarga 10 puntos por segundo después de 3 s sin recibir daño. Si se rompe, tarda 6 s en volver a encenderse.
  - La pieza tiene 50 de vida; si la destruyen, el escudo se apaga.
  - Fabricarlo en el hangar cuesta 1.800 créditos. Tiene niveles hasta el 10, con la curva de las estructuras.
- **Varios generadores:** suman la capacidad, pero no la velocidad de recarga (pregunta 4).
- **Cómo se ve y suena:**
  - Una burbuja cian translúcida que se ilumina al recibir un golpe, con material compartido (ver «Efectos» en CLAUDE.md).
  - Un destello al romperse y otro al volver a encenderse.
  - Sonidos de Kenney: `forceField` para el golpe y `glitch` o `zap` para la rotura.
- **Interfaz:**
  - En el HUD, una barra de escudo cian bajo la del casco.
  - En la estación, la ficha de la pieza.
- **Pruebas:** `--starter-shield` monta uno en la nave inicial.

### 2. Equilibrio: cómo se va a probar

**Herramientas nuevas (simulación con el piloto automático y el tiempo acelerado)**
- `--balance-run`: juega niveles solo y escribe una línea por nivel en `user://balance.csv`. Cada línea tiene la zona, la dificultad, el valor de la nave, si sobrevivió, el casco perdido, las bajas, la chatarra, los créditos ganados y el daño por segundo.
- `--balance-career`: simula una partida entera como un «jugador razonable».
  - Juega un nivel y en la estación vende, repara y compra según una lista de compras fija.
  - Pasa a una zona más lejana cuando sobrevive con margen.
  - Anota cuántos minutos de juego tarda en llegar a cada hito.
- **Límite:** el piloto automático esquiva peor que una persona. Las simulaciones sirven para comparar cambios; tus pruebas a mano tienen la última palabra.

**Hitos objetivo (`[DEFINIDO]`: el usuario los aceptó el 20/11/2026)**

| Hito | Objetivo |
|---|---|
| Primer nivel de 5 min con la nave inicial | Sobrevive perdiendo entre el 30 y el 60 % del casco; gana unos 300 créditos (GDD; medido en la 0.1.0: unos 800) |
| Primera arma extra (estación de mando, arma y tripulante) | 2 o 3 niveles |
| Depósito I (1.500 créditos), zonas de 10 min | Unos 30 min |
| Primera base útil (terreno de asteroide, cargador, refinería y puerto, unos 12.500) | Unas 2 h |
| Primera evolución (arma al nivel 10 + 12.000, unos 35.000) | Unas 4 o 5 h |
| Zonas de 30 min y el último jefe (Acorazado Nyx) | Unas 10 a 15 h |

**Dónde están los números**
- **Enemigos:** `data/enemies/*.tres`.
- **Multiplicadores de dificultad y de presión por minuto:** están en `EnemySpawner` (+45 % de vida, +15 % de enemigos por punto, 0,35 de presión después del minuto 5). Se pasarán a datos, porque CLAUDE.md pide que los números de equilibrio no estén en el código.
- **Precios de la chatarra:** `data/scrap_types`.
- **Piezas, armas y edificios:** `tools/data/gen_data.js`.
- **Constantes de `GameState`:** reparar, mejorar, evolucionar, vender y depósitos.
- **Reclutamiento, investigación y producción de la base:** `BuildingData` y `Bases`.

**Ya se nota en la prueba de rendimiento**
- En la zona más difícil, la nave inicial llega al tope de 160 enemigos a los 4 minutos.
- Es lo esperado, pero muestra que hay que medir qué nave hace falta para cada distancia.

**Cómo se trabaja: por rondas**
1. Medir.
2. Informe al usuario con tablas.
3. Cambiar unos pocos números.
4. Volver a simular.
5. El usuario prueba.

No se cambian números sin mostrar antes el informe.

### 3. Cierre de la 0.1.0

- **Dinero inicial:** 1.000 (hecho).
- **Versión:** `config/version="0.1.0"` en `project.godot`, visible en una esquina del menú principal.
- **Ejecutable:** preset para exportar a Windows, a una carpeta `builds/`. Necesita las plantillas de exportación de Godot 4.7.2.
- **Control de versiones:** poner el proyecto en git, con un `.gitignore` para `.godot/` y `builds/`, y marcar `v0.1.0` (pregunta 6).
- **Documentos:** GDD con la versión 0.1.0 en el historial.

### Orden propuesto

1. Generador de escudo.
2. Herramientas de simulación.
3. Primera medición e informe.
4. Rondas de ajustes.
5. Pruebas del usuario.
6. Cierre de la 0.1.0.

### Preguntas para el usuario (respondidas el 20/11/2026, ver arriba)

1. ¿Qué cosas del equilibrio notaste en tus pruebas? Una lista corta sirve para empezar por ahí.
2. ¿Cuánto debería tardar un jugador en llegar al final (el último jefe)? ¿Te sirven los hitos de la tabla?
3. ¿Cuánto debe castigar el juego? Por ejemplo, ¿perder la nave a menudo al principio, o casi nunca si se juega con cuidado?
4. Generador de escudo:
   - ¿Accesorio en las caras de arriba y abajo, o estructura en una ranura lateral?
   - ¿Se pueden poner varios?
5. ¿Con cuánto dinero se empieza en la 0.1.0?
6. ¿Puedo poner el proyecto en git para marcar la versión?
