// Genera los 8 sistemas planetarios del mapa estelar (data/universe/<id>.tres).
// Uso: node tools/data/gen_universe.js <carpeta_proyecto>
//
// Nombres inventados y fijos (GDD 5.1). Cada zona tiene una distancia fija de 5 a 30 minutos
// de combustible: es la duración del nivel y marca su dificultad. Los sistemas más lejanos del
// inicial tienen las zonas más lejanas. Los valores son provisionales.

const fs = require("fs");
const path = require("path");

const PROJECT = process.argv[2] || process.cwd();
// Separación entre sistemas: las posiciones de la tabla se multiplican por este factor.
// Un sistema mide unos 45 de diámetro; con 14, los vecinos quedan a cientos de unidades.
const GALAXY_SCALE = 14;
const OUT = path.join(PROJECT, "data", "universe");
fs.mkdirSync(OUT, { recursive: true });

const K = { STAR: 0, ROCKY: 1, GAS: 2, MOON: 3, ASTEROID: 4 };
// Precio del terreno por tipo de cuerpo habitable (GDD 7.3, provisional).
const LAND = { [K.ROCKY]: 12000, [K.GAS]: 0, [K.MOON]: 6000, [K.ASTEROID]: 3000, [K.STAR]: 0 };

const num = (x) => (Number.isInteger(x) ? String(x) : String(Math.round(x * 10000) / 10000));
const v3 = (v) => `Vector3(${v.map(num).join(", ")})`;
const col = (hex) => {
  const n = parseInt(hex.slice(1), 16);
  return `Color(${num(((n >> 16) & 255) / 255)}, ${num(((n >> 8) & 255) / 255)}, ${num((n & 255) / 255)}, 1)`;
};
const str = (s) => `"${s.replace(/\\/g, "\\\\").replace(/"/g, '\\"')}"`;

// ---------- descripciones por defecto ----------
function defaultDescription(b) {
  const t = b.temp;
  switch (b.kind) {
    case K.ROCKY:
      if (b.hab) return "Mundo rocoso con atmósfera respirable, agua líquida y suelo firme. Un buen lugar para echar raíces.";
      if (t > 120) return "Roca desnuda tan cerca de su estrella que la superficie brilla de calor. Nada sobrevive aquí.";
      if (t < -60) return "Planeta helado y silencioso. Bajo el hielo hay minerales, pero el frío es letal.";
      return "Planeta de aire tóxico y tormentas de polvo. Se puede orbitar, pero no vivir en él.";
    case K.GAS:
      return "Gigante gaseoso de tormentas eternas. No tiene superficie donde construir, aunque alguna de sus lunas sí.";
    case K.MOON:
      if (b.hab) return "Luna templada por las mareas de su planeta. Cielos tranquilos y una vista privilegiada de las estrellas: ideal para investigar.";
      return "Luna estéril cubierta de cráteres y polvo fino.";
    case K.ASTEROID:
      if (b.hab) return "Asteroide grande y estable, rico en metales. Se puede excavar una base minera en su interior.";
      return "Roca errante que gira sin control. Imposible construir aquí.";
  }
  return "";
}

// ---------- sistemas ----------
// Cuerpo: [id, nombre, tipo, órbita, ángulo, radio, color, temperatura, habitable, extra]
// extra: { c2: color de bandas, rings, desc, parent }
const SYSTEMS = [
  {
    id: "velora", name: "Velora", order: 1, pos: [0, 0, 0],
    desc: "El sistema donde empieza todo. Tranquilo, con una estación bien surtida y enemigos poco organizados.",
    star: { name: "Velora", radius: 2.2, color: "#fff2c4", c2: "#ffcf6a", temp: 5600,
      desc: "Estrella amarilla y estable. Su luz es cálida y constante: las rutas comerciales nacieron aquí." },
    bodies: [
      ["velora_cendra", "Cendra", K.ROCKY, 5, 40, 0.55, "#b8654a", 310, false],
      ["velora_aurel", "Aurel", K.ROCKY, 8.5, 160, 0.9, "#4f8f6a", 18, true,
        { desc: "Mundo verde de mares someros y llanuras templadas. La mayoría de los pilotos de Velora nacieron aquí." }],
      ["velora_lisse", "Lisse", K.MOON, 1.7, 30, 0.28, "#b9b4aa", -35, false, { parent: "velora_aurel" }],
      ["velora_mareth", "Mareth", K.GAS, 13.5, 280, 1.7, "#d9a066", -130, false, { c2: "#a8643a", rings: true }],
      ["velora_odo", "Odo", K.MOON, 2.9, 90, 0.36, "#9fb7c9", -12, true, { parent: "velora_mareth" }],
      ["velora_pell", "Pell", K.MOON, 3.8, 250, 0.25, "#8a7f74", -140, false, { parent: "velora_mareth" }],
      ["velora_tarn", "Roca de Tarn", K.ASTEROID, 18, 20, 0.3, "#7d7369", -170, true],
    ],
    stations: [["station_puerto_velora", "Puerto Velora", "velora_aurel", 1.25, 300]],
    zones: [
      ["zone_cinturon_chatarra", "Cinturón de Chatarra", "", 11, 60, 5,
        "Restos de viejas batallas a la deriva. Drones salvajes rondan los cascos abandonados."],
      ["zone_nube_cendra", "Nube de Cendra", "velora_cendra", 1.4, 200, 5,
        "Una nube de polvo caliente donde se esconden enjambres que atacan a las naves de paso."],
      ["zone_paso_mareth", "Paso de Mareth", "velora_mareth", 5.2, 170, 5,
        "El paso entre los anillos de Mareth. Estrecho, oscuro y lleno de emboscadas."],
    ],
  },
  {
    id: "kessar", name: "Kessar", order: 2, pos: [42, 6, -18],
    desc: "Sistema minero de luz anaranjada. Las rutas hacia el interior de la galaxia empiezan aquí.",
    star: { name: "Kessar", radius: 2.0, color: "#ffc58a", c2: "#ff8a3c", temp: 4300,
      desc: "Estrella naranja, más fría y más vieja que Velora. Sus llamaradas desordenan los sensores." },
    bodies: [
      ["kessar_brask", "Brask", K.ROCKY, 4.5, 300, 0.6, "#8c4a3c", 260, false],
      ["kessar_tovin", "Tovin", K.ROCKY, 8, 100, 0.8, "#8a7a52", 9, true,
        { desc: "Planeta árido de cañones profundos. En el fondo de los cañones el aire es respirable y templado." }],
      ["kessar_ulmar", "Ulmar", K.GAS, 13, 220, 1.5, "#9fb4c9", -180, false, { c2: "#6d86a3" }],
      ["kessar_fen", "Fen", K.MOON, 2.6, 330, 0.33, "#c2b48f", -5, true, { parent: "kessar_ulmar" }],
    ],
    stations: [["station_anillo_kessar", "Anillo Kessar", "kessar_tovin", 1.2, 60]],
    zones: [
      ["zone_restos_brask", "Restos de Brask", "kessar_brask", 1.6, 120, 5,
        "Una flota minera destruida orbita Brask. Sus drones automáticos siguen atacando."],
      ["zone_garganta_kessar", "Garganta de Kessar", "", 16, 160, 10,
        "Un corredor de asteroides donde los artilleros esperan a los cargueros."],
    ],
  },
  {
    id: "thalune", name: "Thalune", order: 3, pos: [-38, -5, -40],
    desc: "Sistema de luz azul y fría. Una fortaleza enemiga vigila el paso hacia los sistemas lejanos.",
    star: { name: "Thalune", radius: 2.6, color: "#d6e6ff", c2: "#7fb0ff", temp: 9200,
      desc: "Estrella blanca azulada, joven y muy brillante. Su radiación quema los cascos sin blindaje." },
    bodies: [
      ["thalune_ixo", "Ixo", K.ROCKY, 5, 220, 0.5, "#c9c0b5", 420, false],
      ["thalune_nere", "Neré", K.ROCKY, 9.5, 20, 1.0, "#3f78a8", 24, true,
        { desc: "Planeta oceánico con archipiélagos de roca negra. El agua es potable y las tormentas, cortas." }],
      ["thalune_gorm", "Gorm", K.GAS, 15, 130, 2.0, "#b7a3d6", -150, false, { c2: "#7a64a8", rings: true }],
      ["thalune_tali", "Tali", K.MOON, 3.2, 60, 0.38, "#a7c7b0", 4, true, { parent: "thalune_gorm" }],
      ["thalune_sorn", "Sorn", K.MOON, 4.2, 200, 0.26, "#8d8d93", -170, false, { parent: "thalune_gorm" }],
      ["thalune_vespa", "Vespa", K.ROCKY, 20, 300, 0.6, "#e3eef5", -210, false],
    ],
    stations: [["station_mirador_thalune", "Mirador Thalune", "thalune_nere", 1.4, 200]],
    zones: [
      ["zone_vortice_ixo", "Vórtice de Ixo", "thalune_ixo", 1.5, 40, 10,
        "Corrientes de plasma alrededor de Ixo. Los enemigos usan el brillo para esconderse."],
      ["zone_fortaleza_thalune", "Fortaleza de Thalune", "", 12.5, 260, 10,
        "Una estación de guerra enemiga orbita la estrella. La defiende un acorazado.",
        "boss_dreadnought", "Acorazado Kraal"],
      ["zone_fosa_gorm", "Fosa de Gorm", "thalune_gorm", 6, 330, 15,
        "Las capas altas de Gorm, donde la gravedad arrastra a los incautos hacia abajo."],
    ],
  },
  {
    id: "ombrion", name: "Ombrion", order: 4, pos: [70, -8, 30],
    desc: "Una enana roja apagada y un cementerio de naves. Pocos pilotos vuelven con la bodega vacía.",
    star: { name: "Ombrion", radius: 1.5, color: "#ff8a6a", c2: "#c23a2a", temp: 3100,
      desc: "Enana roja tenue y antigua. Su luz rojiza apenas calienta a sus planetas." },
    bodies: [
      ["ombrion_dusk", "Dusk", K.ROCKY, 4, 80, 0.7, "#6e4b4b", -20, true,
        { desc: "Mundo en penumbra eterna, con un lado siempre mirando a su estrella. En la franja del crepúsculo se puede vivir." }],
      ["ombrion_hollo", "Hollo", K.GAS, 9, 200, 1.3, "#8f6b7d", -190, false, { c2: "#5c3f52" }],
      ["ombrion_quiebra", "Quiebra", K.ASTEROID, 13, 320, 0.4, "#6f6560", -200, true],
    ],
    stations: [["station_refugio_ombrion", "Refugio Ombrion", "ombrion_dusk", 1.3, 140]],
    zones: [
      ["zone_sombra_ombrion", "Sombra de Ombrion", "", 6.5, 260, 15,
        "La cara oscura del sistema. Los lanceros embisten desde la oscuridad."],
      ["zone_grieta_hollo", "Grieta de Hollo", "ombrion_hollo", 2.4, 60, 15,
        "Una grieta en las nubes de Hollo, llena de restos y de enemigos."],
      ["zone_cementerio_naves", "Cementerio de Naves", "", 16, 120, 20,
        "Miles de cascos muertos a la deriva. Algo los mantiene vigilados."],
    ],
  },
  {
    id: "drevan", name: "Drevan", order: 5, pos: [-75, 10, 15],
    desc: "Sistema amarillo con un gigante anillado. Sus rutas están infestadas de divisores.",
    star: { name: "Drevan", radius: 2.1, color: "#fff0b0", c2: "#ffc94a", temp: 5900,
      desc: "Estrella amarilla algo más caliente que Velora. Un sistema rico y muy disputado." },
    bodies: [
      ["drevan_sel", "Sel", K.ROCKY, 4.5, 140, 0.5, "#d18b5a", 350, false],
      ["drevan_arvo", "Arvo", K.ROCKY, 8, 260, 0.95, "#5f9a5a", 21, true,
        { desc: "Selvas de hojas oscuras y lluvias tibias. El planeta más fértil de esta región." }],
      ["drevan_kethra", "Kethra", K.GAS, 13.5, 30, 1.9, "#d6c18a", -160, false, { c2: "#9a7f4a", rings: true }],
      ["drevan_ime", "Ime", K.MOON, 3, 150, 0.35, "#a9b8c4", -8, true, { parent: "drevan_kethra" }],
      ["drevan_rax", "Rax", K.MOON, 4, 300, 0.24, "#7b6f6a", -150, false, { parent: "drevan_kethra" }],
      ["drevan_pallu", "Pallu", K.ROCKY, 19, 200, 0.55, "#cfe0ea", -220, false],
    ],
    stations: [["station_bastion_drevan", "Bastión Drevan", "drevan_arvo", 1.3, 20]],
    zones: [
      ["zone_corredor_arvo", "Corredor de Arvo", "", 10.5, 330, 15,
        "La ruta comercial más transitada de Drevan, y por eso la más asaltada."],
      ["zone_mar_kethra", "Mar de Kethra", "drevan_kethra", 5.4, 220, 20,
        "Entre los anillos de Kethra flotan nidos de enemigos que se dividen al morir."],
    ],
  },
  {
    id: "isk_maren", name: "Isk-Maren", order: 6, pos: [20, 12, -85],
    desc: "Un gigante gaseoso enorme domina el sistema. En su órbita se alza el trono de un acorazado.",
    star: { name: "Maren", radius: 2.3, color: "#f4f6ff", c2: "#b6c4ff", temp: 7400,
      desc: "Estrella blanca y potente. El gigante Isk le roba protagonismo en el cielo de sus lunas." },
    bodies: [
      ["isk_maren_morr", "Morr", K.ROCKY, 5, 10, 0.6, "#9a6a55", 230, false],
      ["isk_maren_isk", "Isk", K.GAS, 11, 140, 2.6, "#c98f6a", -120, false, { c2: "#8a4f3a" }],
      ["isk_maren_vaal", "Vaal", K.MOON, 3.8, 20, 0.42, "#9ec2a2", 12, true, { parent: "isk_maren_isk" }],
      ["isk_maren_ennu", "Ennu", K.MOON, 5, 210, 0.3, "#b0a090", -90, false, { parent: "isk_maren_isk" }],
      ["isk_maren_maren", "Maren", K.ROCKY, 18, 270, 0.85, "#7b98b0", -10, true,
        { desc: "Planeta frío de tundras azuladas. Duro, pero habitable para quien sepa abrigarse." }],
    ],
    stations: [["station_ancla_maren", "Ancla Maren", "isk_maren_maren", 1.3, 100]],
    zones: [
      ["zone_tormenta_isk", "Tormenta de Isk", "isk_maren_isk", 6.5, 300, 20,
        "Una tormenta del tamaño de un planeta. Los sembradores llenan de minas sus corrientes."],
      ["zone_trono_morvath", "Trono de Morvath", "", 14, 40, 20,
        "La guarida de un acorazado famoso por no haber perdido nunca una batalla.",
        "boss_dreadnought", "Acorazado Morvath"],
      ["zone_abismo_maren", "Abismo de Maren", "", 22, 200, 25,
        "El borde exterior del sistema, donde se reúnen las flotas enemigas."],
    ],
  },
  {
    id: "coralis", name: "Coralis", order: 7, pos: [-60, -10, -95],
    desc: "Sistema de estrella azul rodeado de arrecifes de roca. Rico en chatarra rara y en enemigos.",
    star: { name: "Coralis", radius: 2.4, color: "#bfefff", c2: "#5ad0ff", temp: 11000,
      desc: "Estrella azul intensa. Sus vientos estelares esculpen los asteroides en formas de coral." },
    bodies: [
      ["coralis_opal", "Opal", K.ROCKY, 7, 50, 0.85, "#5aa8a0", 30, true,
        { desc: "Planeta de mares turquesa y costas de cristal. Caluroso, pero habitable." }],
      ["coralis_lume", "Lume", K.GAS, 13, 190, 1.6, "#8fd0e0", -170, false, { c2: "#4a90a8" }],
      ["coralis_seri", "Seri", K.MOON, 2.8, 100, 0.32, "#c9d6c0", -25, true, { parent: "coralis_lume" }],
      ["coralis_coral9", "Coral-9", K.ASTEROID, 18, 320, 0.45, "#a07f8f", -160, true],
    ],
    stations: [["station_arrecife_coralis", "Arrecife Coralis", "coralis_opal", 1.3, 240]],
    zones: [
      ["zone_arrecife_roto", "Arrecife Roto", "", 10, 280, 25,
        "Un campo de asteroides afilados donde cada enemigo puede salir de cualquier parte."],
      ["zone_ojo_coralis", "Ojo de Coralis", "", 4.2, 120, 25,
        "Tan cerca de la estrella que los escudos se resienten. Solo los mejores vuelven."],
    ],
  },
  {
    id: "nyxar", name: "Nyxar", order: 8, pos: [110, 4, -60],
    desc: "El sistema más lejano conocido. Su estrella violeta es la sede del acorazado más temido.",
    star: { name: "Nyxar", radius: 2.0, color: "#e6c8ff", c2: "#a45cff", temp: 6800,
      desc: "Estrella de luz violeta, extraña e inestable. Los instrumentos fallan cerca de ella." },
    bodies: [
      ["nyxar_vel", "Vel", K.ROCKY, 4.5, 250, 0.55, "#c46a8a", 380, false],
      ["nyxar_nox", "Nox", K.GAS, 10, 70, 2.1, "#6f5aa8", -140, false, { c2: "#3d2f6e", rings: true }],
      ["nyxar_umbra", "Umbra", K.MOON, 3.4, 140, 0.4, "#8f8fb0", 2, true, { parent: "nyxar_nox" }],
      ["nyxar_ash", "Ash", K.MOON, 4.5, 330, 0.28, "#5f5a5a", -100, false, { parent: "nyxar_nox" }],
      ["nyxar_tyr", "Tyr", K.ROCKY, 16, 180, 0.7, "#7a8fa0", -70, false],
    ],
    stations: [["station_ultimo_faro", "Último Faro", "nyxar_umbra", 0.9, 30]],
    zones: [
      ["zone_velo_nyxar", "Velo de Nyxar", "", 7.5, 320, 30,
        "Una cortina de radiación violeta. Detrás, todo lo que el enemigo tiene."],
      ["zone_ciudadela_nyx", "Ciudadela Nyx", "", 13.5, 220, 30,
        "La fortaleza final. Su acorazado manda sobre todas las flotas enemigas.",
        "boss_dreadnought", "Acorazado Nyx"],
    ],
  },
];

// ---------- escritura del .tres ----------
function bodyLines(b) {
  return [
    `id = &"${b.id}"`, `display_name = ${str(b.name)}`, `kind = ${b.kind}`, `description = ${str(b.desc)}`,
    `parent = &"${b.parent || ""}"`, `orbit_radius = ${num(b.orbit)}`, `orbit_angle = ${num(b.angle)}`,
    `orbit_speed = ${num(b.speed)}`, `radius = ${num(b.radius)}`, `color = ${col(b.color)}`,
    `color2 = ${col(b.c2 || b.color)}`, `has_rings = ${b.rings ? "true" : "false"}`,
    `habitable = ${b.hab ? "true" : "false"}`, `temperature = ${b.temp}`, `land_price = ${b.hab ? LAND[b.kind] : 0}`,
  ];
}

function systemTres(sys) {
  const bodies = [];
  bodies.push({ id: sys.id + "_star", name: sys.star.name, kind: K.STAR, desc: sys.star.desc, orbit: 0, angle: 0,
    speed: 0, radius: sys.star.radius, color: sys.star.color, c2: sys.star.c2, temp: sys.star.temp, hab: false });
  for (const [id, name, kind, orbit, angle, radius, color, temp, hab, extra = {}] of sys.bodies) {
    const b = { id, name, kind, orbit, angle, radius, color, temp, hab, parent: extra.parent, c2: extra.c2,
      rings: extra.rings };
    // Velocidad visual: los cuerpos cercanos giran más rápido; las lunas, más aún.
    b.speed = kind === K.MOON ? 9 / Math.sqrt(orbit) : 22 / Math.pow(orbit, 1.5);
    b.desc = extra.desc || defaultDescription(b);
    bodies.push(b);
  }
  const ids = new Set(bodies.map((b) => b.id));
  for (const b of bodies) if (b.parent && !ids.has(b.parent)) throw new Error("padre desconocido: " + b.parent);

  let out = `[gd_resource type="Resource" script_class="StarSystemData" format=3]\n\n`;
  out += `[ext_resource type="Script" path="res://scripts/data/star_system_data.gd" id="1"]\n`;
  out += `[ext_resource type="Script" path="res://scripts/data/celestial_body_data.gd" id="2"]\n`;
  out += `[ext_resource type="Script" path="res://scripts/data/station_data.gd" id="3"]\n`;
  out += `[ext_resource type="Script" path="res://scripts/data/zone_data.gd" id="4"]\n\n`;
  const bodyRefs = [], stationRefs = [], zoneRefs = [];
  bodies.forEach((b, i) => {
    out += `[sub_resource type="Resource" id="body_${i}"]\nscript = ExtResource("2")\n${bodyLines(b).join("\n")}\n\n`;
    bodyRefs.push(`SubResource("body_${i}")`);
  });
  sys.stations.forEach(([id, name, parent, orbit, angle], i) => {
    if (parent && !ids.has(parent)) throw new Error("padre desconocido: " + parent);
    out += `[sub_resource type="Resource" id="station_${i}"]\nscript = ExtResource("3")\n` +
      `id = &"${id}"\ndisplay_name = ${str(name)}\n` +
      `description = ${str("Estación espacial con mecánico, bar y compra de chatarra. Sus cargadores rellenan el combustible interestelar al llegar.")}\n` +
      `parent = &"${parent}"\norbit_radius = ${num(orbit)}\norbit_angle = ${num(angle)}\n\n`;
    stationRefs.push(`SubResource("station_${i}")`);
  });
  sys.zones.forEach(([id, name, parent, orbit, angle, minutes, desc, boss, bossName], i) => {
    if (parent && !ids.has(parent)) throw new Error("padre desconocido: " + parent);
    out += `[sub_resource type="Resource" id="zone_${i}"]\nscript = ExtResource("4")\n` +
      `id = &"${id}"\ndisplay_name = ${str(name)}\ndescription = ${str(desc)}\n` +
      `parent = &"${parent}"\norbit_radius = ${num(orbit)}\norbit_angle = ${num(angle)}\n` +
      `distance_minutes = ${minutes}\nboss = &"${boss || ""}"\nboss_name = ${str(bossName || "")}\n\n`;
    zoneRefs.push(`SubResource("zone_${i}")`);
  });
  out += `[resource]\nscript = ExtResource("1")\nid = &"${sys.id}"\ndisplay_name = ${str(sys.name)}\n` +
    `description = ${str(sys.desc)}\norder = ${sys.order}\ngalaxy_position = ${v3(sys.pos.map((x) => x * GALAXY_SCALE))}\n` +
    `bodies = Array[ExtResource("2")]([${bodyRefs.join(", ")}])\n` +
    `stations = Array[ExtResource("3")]([${stationRefs.join(", ")}])\n` +
    `zones = Array[ExtResource("4")]([${zoneRefs.join(", ")}])\n`;
  return out;
}

const allIds = new Set();
for (const sys of SYSTEMS) {
  for (const id of [...sys.bodies.map((b) => b[0]), ...sys.stations.map((s) => s[0]), ...sys.zones.map((z) => z[0])]) {
    if (allIds.has(id)) throw new Error("id repetido: " + id);
    allIds.add(id);
  }
  fs.writeFileSync(path.join(OUT, sys.id + ".tres"), systemTres(sys));
}
const zones = SYSTEMS.flatMap((s) => s.zones);
console.log(`ok: ${SYSTEMS.length} sistemas, ${SYSTEMS.reduce((n, s) => n + s.bodies.length + 1, 0)} cuerpos, ` +
  `${SYSTEMS.reduce((n, s) => n + s.stations.length, 0)} estaciones, ${zones.length} zonas ` +
  `(${zones.filter((z) => z[7]).length} con jefe)`);
