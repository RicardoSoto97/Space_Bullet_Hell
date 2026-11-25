# Bullet Hell Survivor

Juego bullet hell estilo survivor, con una nave modular, hecho en Godot 4.7.2 (GDScript, Forward+).

## Contexto del juego

@docs/CONTEXTO_JUEGO_IA.md

## Documentación de diseño

- `docs/GDD_Bullet_Hell_Survivor.docx` es la fuente de verdad del diseño. `docs/CONTEXTO_JUEGO_IA.md` es su versión para IA.
- Si cambia una decisión de diseño, actualiza los dos documentos o avisa al usuario de que uno quedó desactualizado.
- No inventes nada que esté marcado `[POR DEFINIR]`: pregunta. Lo marcado `[PENDIENTE DEL USUARIO]` lo explicará el usuario por chat: no lo diseñes por tu cuenta.

### Cómo actualizar el GDD

El usuario anota el `.docx` a mano: "ESTO VA!" significa que se aprueba; cualquier otro texto es contexto adicional; lo que va entre `*asteriscos*` es contexto para esa línea en particular.

1. Antes de regenerar, guarda una copia del `.docx` actual en `docs/historial/` (`GDD_vX.Y.docx`, o `GDD_vX.Y_anotado.docx` si el usuario lo anotó). Si los cambios llegan por chat, regístralos igual en el historial de versiones del GDD.
2. Lee el `.docx` con Word (COM) y expórtalo a texto.
3. Aplica los cambios en `docs/tools/build_gdd.js` y sube `VERSION` y el historial de versiones. El generador necesita el paquete npm `docx` (`npm install` en `docs/tools/`).
4. Genera el documento con `node docs/tools/build_gdd.js <salida.docx> docs/img/concepto_nave_modular.png`. Después ejecuta `docs/tools/word_export.ps1 -Docx <salida.docx> -Pdf <salida.pdf>` (abre una instancia propia de Word, compacta y actualiza el índice y exporta a PDF) y revisa las páginas con `docs/tools/pdf2png.ps1 -Pdf <pdf> -OutDir <carpeta> [-Pages "2,3"]`. Comprueba que el capítulo 1 empiece justo después del índice. Si el índice no cabe en una página, que siga en la siguiente aunque quede espacio en blanco: el usuario prefiere eso a achicar la letra (no bajes de 9,5 pt).
5. Actualiza `docs/CONTEXTO_JUEGO_IA.md` con los mismos cambios.

Si Word se cuelga al abrir el archivo, puede que el usuario lo tenga abierto: trabaja sobre una copia en el scratchpad y cópiala al proyecto al final.

## Convenciones

- Habla con el usuario en español. El código (nombres de clases, variables, funciones y archivos) va en inglés, con los identificadores del glosario.
- GDScript con tipos estáticos. Archivos y carpetas en `snake_case`; clases en `PascalCase`.
- Carpetas: `scenes/` (.tscn), `scripts/` (.gd), `assets/models/`, `assets/sprites/`, `assets/audio/`, `docs/`, `tools/`. Las carpetas `docs/` y `tools/` tienen `.gdignore` y Godot no las importa.
- La escena principal es `res://scenes/main.tscn`: pantalla de inicio con «Continuar» y «Nueva partida».

## Arquitectura del código

El plan por fases y las decisiones provisionales de implementación están en `docs/PLAN_DESARROLLO.md`. Mantenlo al día.

- **Autoloads:** `Settings` (opciones del jugador y teclas, en `user://settings.cfg`), `Sfx` (efectos de sonido: `Sfx.play(&"id")`, tabla `SOUNDS`) y `GamepadCursor` (mando en las interfaces) cargan después de `GameState`. `Catalog` (`scripts/autoload/catalog.gd`) carga los `Resource` de `data/` por id; `Bases` (`scripts/autoload/bases.gd`) lleva las bases, lo guardado en ellas, sus tripulantes, la investigación, los planos y la producción (solo con el juego abierto); `GameState` (`scripts/autoload/game_state.gd`) guarda dinero, chatarra, el plano de la nave (`blueprint`), la vida de cada pieza y los tripulantes, y cambia entre nivel y estación. También define las acciones de entrada.
- **Datos** (`data/*.tres`, clases en `scripts/data/`): `PartData`, `WeaponData`, `EnemyData`, `ScrapTypeData`, `BuildingData`, `MineralData`. Los números de equilibrio van ahí, no en el código. Los .tres de **piezas, armas, edificios y minerales** se generan con `node tools/data/gen_data.js .`: cambia el script y vuelve a generarlos, no los edites a mano.
- **Nave** (`scripts/ship/`): `Ship` se monta desde `GameState.blueprint`; cada `ShipPart` es un `Area3D` con su vida; `ShipWeapon` dispara solo al enemigo más cercano **dentro de su cono** (hacia el frente de su estación de mando): balas, cohetes (`Rocket`) o rayo.
- **Plano y ranuras:** cada pieza del plano se une a una ranura de su padre (`attached_to`, `parent_slot`, `mount_slot`), y su `transform` se calcula con `GameState.attach_transform`. Usa `GameState.check_placement`, `buy_part` y `sell_part`; no escribas posiciones a mano.
- **Nivel** (`scenes/stage/stage.tscn`, `scripts/stage/`): `Stage` crea entorno, nave, cámara, `EnemySpawner`, `ProjectilePool` y `StageHud`.
- **Guardado:** `GameState.save_game` / `load_game` (JSON en `user://save.json`). Se guarda al llegar a una estación. Las pruebas con argumentos usan `user://save_test.json` o `--save-path=`. Si añades estado a `GameState`, guárdalo y cárgalo también.
- **Universo** (`data/universe/<sistema>.tres`, clases `StarSystemData`, `CelestialBodyData`, `StationData`, `ZoneData`): se genera con `node tools/data/gen_universe.js .`; no lo edites a mano. `Catalog` los indexa (`site`, `zone`, `body`, `system_of`). `GameState.location` es la estación o la zona actual y `travel_to` salta a ella.
- **Mapa estelar** (`scripts/star_map/star_map.gd`, `StarMap`): `CanvasLayer` con su propio mundo 3D en un `SubViewport`; se abre encima de la estación o del nivel (en pausa) y emite `destination_chosen`.
- **Enemigos:** `EnemyData.behavior` (perseguir, distancia, embestida), minas, división y `min_difficulty`. El jefe es `Boss` (`scripts/enemies/boss.gd`), con patrones por fases; lo hace aparecer `Stage` al recargarse el combustible en su zona.
- **Base** (`scenes/base/base.tscn`, `BaseScreen` en `scripts/base/`): hereda de `Station` (`class_name Station`) y reutiliza su taller para el hangar. `BaseView` es la vista 3D con las parcelas y los edificios (`assets/models/buildings/`). `GameState.go_to_station()` abre la base si `location` es el cuerpo de una base; `travel_to` acepta ese id.
- **Estación** (`scenes/station/station.tscn`, `scripts/station/station.gd`): interfaz construida por código, con pestañas Mecánico, Bar y Chatarra. `ShipEditorView` es la vista 3D de la nave con cámara orbital (arrastrar, rueda) y las ranuras libres que no tapa otra pieza.
- **Menús y mando:** `OptionsMenu` (`scripts/ui/`) se abre encima de cualquier pantalla. La pausa y la pantalla de nave destruida están en `StageHud`. Una pantalla que se usa con el puntero entra en el grupo `gamepad_pointer` (el mando mueve el puntero); un menú o diálogo encima entra en `gamepad_menu` (el mando usa el foco: dale el foco a un botón al abrirlo). Los textos de ayuda usan `Settings.control_name(acción)`, no teclas escritas a mano.
- **Sonido:** los efectos son de Kenney (CC0) en `assets/audio/Effects/` (carpetas con espacios: `Audio Digital`, `Audio interface`, `Audio sci-fi`). Para un sonido nuevo, añádelo a `Sfx.SOUNDS` con su límite de repeticiones. La música llegará más adelante (bus `Music`).
- **Efectos:** no crees un material nuevo por cada efecto. Un material recién creado se dibuja roto en su primer fotograma (eso causaba los «destellos rojos» de las explosiones). Usa los materiales compartidos de `Effects` y anima la transparencia de la instancia (`GeometryInstance3D.transparency`).
- La **interpolación física** está activada: lo que se mueve en `_process` o con tweens lleva `physics_interpolation_mode = OFF`, y lo que se teletransporta (proyectiles reutilizados, enemigos nuevos) llama a `reset_physics_interpolation()`.
- Todo se mueve en el plano XZ (Y = 0). La cámara del nivel es ortográfica pero inclinada (`Stage.CAMERA_TILT_DEG`): para pasar del ratón al plano, intersecta el rayo con Y = 0. Las inclinaciones y piruetas de las naves son solo visuales: la nave inclina `ShipPart.visual` (modelo y arma) y los enemigos su `_model`; las colisiones no se inclinan. Capas de colisión: 1 piezas del jugador, 2 enemigos, 3 balas del jugador, 4 balas enemigas.

## Modelos 3D

**Hasta la versión 0.1.0 (fases 5, 6… hasta terminar el juego base), los modelos se siguen haciendo en Blender** (ver «Blender» más abajo). **En la versión 0.2.0** se reemplazarán todos por modelos nuevos hechos en Blockbench, con otro diseño (nave, enemigos, edificios): no se copiarán los de Blender. No empieces los modelos de Blockbench hasta que el usuario lo pida. El estilo nuevo está `[POR DEFINIR]`.

### Blockbench (para la versión 0.2.0; ya configurado y probado)

- Blockbench 5.2 está en `D:/1.Documentos/1. Apps/Blockbench/Blockbench.exe`. El servidor MCP `blockbench` (en `.mcp.json`, HTTP en `http://localhost:3000/bb-mcp`) lo controla con el plugin `jasonjgardner/blockbench-mcp-plugin`.
- Blockbench tiene que estar **abierto** con el plugin cargado. Si el MCP no conecta, ábrelo (tarda unos 10 s en escuchar el puerto 3000) y pide al usuario que lo reconecte con `/mcp`.
- Proyectos en formato `free` (Generic Model). Las herramientas de modelado (`place_cube`, `create_cylinder`, `place_mesh`, texturas…) solo se activan con un proyecto abierto.
- **Fuentes:** `tools/blockbench/<parts|enemies|buildings>/<id>.bbmodel` (`export_model` con el codec `project`).
- **Para el juego:** `export_model` con el codec `gltf` y `options: {encoding: "binary", embed_textures: true}` a `assets/models/<parts|enemies|buildings>/<id>.glb`. Mismo nombre que el modelo que reemplaza: el código y los `.tres` no cambian.
- Escala y ejes: 16 unidades de Blockbench = 1 m = 1 cubo de pasillo. Y hacia arriba. El frente de la pieza es el norte (-Z), que en Godot también es -Z.
- Después de exportar, importa con `Godot --headless --path . --import` y revisa con `scenes/tests/parts_preview.tscn` (acepta `-- --view=top|angled --screenshot=<ruta.png>`). En Blockbench, revisa con `capture_screenshot`.

### Blender (el flujo actual, hasta la versión 0.1.0)

- Blender 5.3 está en `D:/1.Documentos/1. Apps/Blender/blender.exe`.
- Las piezas se generan por script: `tools/blender/build_parts.py` crea cada pieza con primitivas y biseles, la exporta a `assets/models/parts/<id>.glb` y guarda `tools/blender/parts.blend`. Para añadir o cambiar una pieza, edita el script y vuelve a ejecutarlo:
  `blender --background --factory-startup --python tools/blender/build_parts.py -- <carpeta_proyecto> [carpeta_renders]`
  Con `carpeta_renders`, además renderiza vistas previas (PNG) para revisarlas.
- Estilo (ver GDD 10.2): low-poly, formas redondeadas y medio cilíndricas, colores planos sin texturas, poco detalle. Paleta y materiales definidos en `PALETTE` del script.
- Ejes y escala: 1 cubo de pasillo = 1 m; el frente de cada pieza es +Y en Blender, que en Godot queda como -Z.
- Después de exportar, importa con `Godot --headless --path . --import` y revisa con `scenes/tests/parts_preview.tscn`.
- El servidor MCP `blender` (en `.mcp.json`, con la telemetría desactivada) controla un Blender abierto: el add-on «MCP for Blender» ya está instalado y arranca solo al abrir Blender.
- Cuando empiecen los modelos de Blockbench (v0.2.0): `build_parts.py` **sobrescribe** los `.glb`, así que hay que sacarle los ids ya rehechos antes de ejecutarlo.

## Ejecutar

El servidor MCP `godot` (configurado en `.mcp.json`) permite ejecutar el proyecto (`run_project`), leer los errores (`get_debug_output`) y abrir el editor. Después de cada cambio, ejecuta el proyecto y revisa que no haya errores.

Godot está en `D:/1.Documentos/2. Development/Godot/Godot_v4.7.2-stable_win64.exe`. Para probar sin jugar a mano, pasa argumentos después de `--`:

- `--start-stage`: empieza en un nivel. `--autopilot`: la nave se mueve sola. `--stage-seconds=N`: duración del nivel.
- `--screenshot=<png> --screenshot-at=<s>`: captura del nivel (imprime enemigos, bajas, chatarra y casco). `--quit-after-screenshot`.
- `--auto-jump`: salta al recargarse el combustible. `--auto-station`: en la estación vende, repara y mejora. `--station-screenshot=<png>`, `--quit-after-station`.
- `--zone=<id>`: zona del nivel (con `--start-stage`, o destino del salto automático desde la estación). `--auto-dest=<id>`: destino de `--auto-jump` (por defecto, la estación del sistema; con un jefe vivo espera a derrotarlo).
- `--continue`: carga la partida guardada. `--save-path=user://x.json`: archivo de guardado. `--menu-screenshot=<png>`: captura de la pantalla de inicio.
- `--map-test=<carpeta>`: en la estación abre el mapa estelar y guarda capturas (galaxia, sistema, planeta y fichas).
- `--evolve-test` (con `--build-test`): sube las armas al nivel 10 y las evoluciona.
- `--base-test --money=60000 [--base-body=<id>] [--base-speed=N]`: compra un terreno (por defecto `velora_odo`), aterriza, construye con clics en las parcelas, asigna tripulantes, investiga y guarda capturas (con `--station-screenshot`). `--base-speed=N` acelera la producción de las bases.
- `--continue --base-jump=<zona> --destroy-at=3 --rebuild-test`: despega de la base, destruye la nave a los 3 s y la reconstruye en el hangar. `--starter-weapon=<id>`: arma de la nave inicial (para probar armas en un nivel).
- `--build-test --money=20000`: en la estación construye una nave más grande con el editor (pasillo, estaciones con lanzacohetes y láser, habitación y accesorios), contrata tripulantes y guarda capturas (`<png>` y `<png>-bar`).
- `--ui-test=<carpeta>` (con `--start-stage`): capturas del menú de pausa y de las opciones. `--pad-test`: prueba el mando en la estación (RB, A sobre una pestaña, Start y cruceta en las opciones). `--perf-log`: FPS, enemigos y balas cada 10 s. `--game-over-screenshot=<png>`: captura de la pantalla de nave destruida (con `--destroy-at` o `--autopilot` se reaparece sola).
- Equilibrio (fase 6): `--balance-run` imprime una línea `balance …` (sobrevivió, casco, daño por origen, chatarra) al recargarse el combustible o al perder la nave, y se cierra. `--time-scale=N` acelera el tiempo (prueba típica: `--headless -- --start-stage --autopilot --balance-run --time-scale=6`, unos 30 s). `--starter-shield` monta un generador de escudo en la nave inicial.
- Al destruirse la nave se imprime `ship destroyed at t=...`. `--spawn-log`: cuántos enemigos de cada tipo aparecen cada 30 s. `--invulnerable`: la nave no recibe daño (para revisar un nivel entero). `--burst=N` con `--screenshot`: guarda N fotogramas seguidos en una cuadrícula, para revisar efectos que duran un fotograma.

Los mensajes «Unreferenced static string» o «RID allocations leaked» al cortar Godot con `timeout` son del cierre forzado, no del código.
