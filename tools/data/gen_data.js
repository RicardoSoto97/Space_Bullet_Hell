// Genera los .tres de las piezas (data/parts), las armas (data/weapons), los edificios de la
// base (data/buildings) y los minerales puros (data/minerals).
// Uso: node tools/data/gen_data.js <carpeta_proyecto>
//
// Coordenadas de Godot: el frente de cada pieza es -Z, arriba es +Y, 1 cubo de pasillo = 1 m.
// Los valores de equilibrio son provisionales (GDD): se ajustan aquí y se vuelve a generar.

const fs = require("fs");
const path = require("path");

const PROJECT = process.argv[2] || process.cwd();
const CAT = { CORE: 0, STRUCTURE: 1, COMMAND_STATION: 2, CREW_STRUCTURE: 3, ENGINE: 4, ACCESSORY: 5 };
const SIDE = 0, FACE = 1;
const KIND = { BULLET: 0, ROCKET: 1, BEAM: 2 };

const v3 = (v) => `Vector3(${v.map(num).join(", ")})`;
const num = (x) => (Number.isInteger(x) ? String(x) : String(Math.round(x * 10000) / 10000));
const color = (c) => `Color(${c.map(num).join(", ")}, 1)`;

function slot(pos, normal, kind) { return { pos, normal, kind }; }

// Pasillo de n cubos a lo largo de Z: un acoplador en cada extremo, n en cada cara larga
// y n arriba y abajo (solo accesorios). Se une por el extremo trasero.
function corridorSlots(n) {
  const L = n, w = 0.46, h = 0.42;
  const s = [slot([0, 0, -L / 2], [0, 0, -1], SIDE), slot([0, 0, L / 2], [0, 0, 1], SIDE)];
  for (let k = 0; k < n; k++) {
    const z = -L / 2 + 0.5 + k;
    s.push(slot([-w, 0, z], [-1, 0, 0], SIDE), slot([w, 0, z], [1, 0, 0], SIDE));
  }
  for (let k = 0; k < n; k++) {
    const z = -L / 2 + 0.5 + k;
    s.push(slot([0, h, z], [0, 1, 0], FACE), slot([0, -h, z], [0, -1, 0], FACE));
  }
  return s;
}

const PARTS = [
  // El núcleo sube de nivel (decisión del usuario, 20/11/2026): nivel 2 = 500 créditos y +25 % por
  // nivel; +25 % de su casco base y +1 plaza de tripulante por nivel.
  { id: "core", name: "Núcleo", cat: CAT.CORE, price: 0, for_sale: false, hp: 160, crew: 1,
    levels: true, up_base: 500, up_growth: 1.25, hp_per: 0.25, crew_per: 1,
    size: [1.5, 1, 1.7],
    slots: [slot([0, 0, -0.75], [0, 0, -1], SIDE), slot([0, 0, 0.75], [0, 0, 1], SIDE),
            slot([-0.75, 0, 0], [-1, 0, 0], SIDE), slot([0.75, 0, 0], [1, 0, 0], SIDE),
            slot([0, 0.5, 0], [0, 1, 0], FACE), slot([0, -0.5, 0], [0, -1, 0], FACE)],
    mount: -1 },
  { id: "command_station", name: "Estación de mando", cat: CAT.COMMAND_STATION, price: 300, hp: 150,
    levels: true, size: [0.9, 0.72, 0.9], weapon_offset: [0, 0.02, -0.44],
    slots: [slot([0, 0, 0.46], [0, 0, 1], SIDE)], mount: 0 },
  { id: "corridor_1x1", name: "Pasillo cuadrado", cat: CAT.STRUCTURE, price: 80, hp: 40, hull: 20,
    size: [0.92, 0.84, 1], slots: corridorSlots(1), mount: 1 },
  { id: "corridor_1x2", name: "Pasillo doble", cat: CAT.STRUCTURE, price: 150, hp: 70, hull: 40,
    size: [0.92, 0.84, 2], slots: corridorSlots(2), mount: 1 },
  { id: "corridor_1x3", name: "Pasillo triple", cat: CAT.STRUCTURE, price: 210, hp: 100, hull: 60,
    size: [0.92, 0.84, 3], slots: corridorSlots(3), mount: 1 },
  { id: "crew_quarters_small", name: "Habitación de tripulantes pequeña", cat: CAT.CREW_STRUCTURE,
    price: 250, hp: 60, crew: 2, crew_bonus: 0.01, levels: true, size: [0.92, 0.84, 1],
    slots: [slot([0, 0, 0.5], [0, 0, 1], SIDE)], mount: 0 },
  { id: "crew_quarters_medium", name: "Habitación de tripulantes mediana", cat: CAT.CREW_STRUCTURE,
    price: 450, hp: 100, crew: 4, crew_bonus: 0.01, levels: true, size: [0.92, 0.84, 2],
    slots: [slot([0, 0, 1], [0, 0, 1], SIDE)], mount: 0 },
  { id: "thruster_small", name: "Propulsor pequeño", cat: CAT.ENGINE, price: 250, hp: 70,
    handling: 2, speed: 1.5, size: [0.75, 0.75, 0.78], offset: [0, 0, 0.17],
    slots: [slot([0, 0, -0.21], [0, 0, -1], SIDE)], mount: 0 },
  { id: "thruster_medium", name: "Propulsor mediano", cat: CAT.ENGINE, price: 450, hp: 100,
    handling: 3, speed: 2.5, size: [0.95, 0.95, 0.92], offset: [0, 0, 0.2],
    slots: [slot([0, 0, -0.26], [0, 0, -1], SIDE)], mount: 0 },
  { id: "armor_plate", name: "Placa de blindaje", cat: CAT.ACCESSORY, price: 120, hp: 60, armor: 3,
    size: [0.86, 0.1, 0.86], slots: [slot([0, -0.05, 0], [0, -1, 0], FACE)], mount: 0 },
  { id: "scrap_magnet", name: "Recolector magnético", cat: CAT.ACCESSORY, price: 200, hp: 30,
    pickup: 2.5, size: [0.62, 0.4, 0.62], slots: [slot([0, -0.2, 0], [0, -1, 0], FACE)], mount: 0 },
  { id: "interstellar_fuel_tank", name: "Depósito de combustible interestelar I", cat: CAT.ACCESSORY,
    price: 1500, for_sale: false, hp: 50, size: [0.9, 0.5, 0.5],
    slots: [slot([0, -0.25, 0], [0, -1, 0], FACE)], mount: 0 },
  // Fase 4: piezas que se investigan en la base (GDD 7.6). No las vende la estación; una vez
  // investigadas se fabrican en el hangar.
  ...[["library", "Biblioteca"], ["mess_hall", "Comedor"], ["kitchen", "Cocina"],
      ["recreation_room", "Sala de recreación"]].map(([id, name]) => (
    { id, name, cat: CAT.CREW_STRUCTURE, price: 350, for_sale: false, research: 300, hp: 60,
      crew_bonus: 0.01, levels: true, size: [0.92, 0.84, 1], slots: [slot([0, 0, 0.5], [0, 0, 1], SIDE)], mount: 0 })),
  { id: "crew_quarters_large", name: "Habitación de tripulantes grande", cat: CAT.CREW_STRUCTURE,
    price: 650, for_sale: false, research: 150, hp: 140, crew: 6, crew_bonus: 0.01, levels: true,
    size: [0.92, 0.84, 3], slots: [slot([0, 0, 1.5], [0, 0, 1], SIDE)], mount: 0 },
  { id: "armor_plate_heavy", name: "Placa de blindaje pesada", cat: CAT.ACCESSORY, price: 260, for_sale: false,
    research: 150, hp: 110, armor: 6, size: [0.88, 0.18, 0.88], slots: [slot([0, -0.09, 0], [0, -1, 0], FACE)], mount: 0 },
  { id: "scrap_magnet_large", name: "Recolector magnético grande", cat: CAT.ACCESSORY, price: 380, for_sale: false,
    research: 150, hp: 45, pickup: 4.5, size: [0.8, 0.5, 0.8], slots: [slot([0, -0.25, 0], [0, -1, 0], FACE)], mount: 0 },
  // Fase 6: generador de escudo (pieza avanzada, GDD 7.6). Accesorio, solo arriba o abajo y uno
  // por nave (decisión del usuario, 20/11/2026). Los números son propuestas.
  { id: "shield_generator", name: "Generador de escudo", cat: CAT.ACCESSORY, price: 1800, for_sale: false,
    research: 1000, hp: 50, levels: true, unique: true, face_only: true, shield: 60, shield_per: 0.15,
    shield_recharge: 10, shield_delay: 3, shield_break: 6, size: [0.7, 0.34, 0.7],
    slots: [slot([0, -0.17, 0], [0, -1, 0], FACE)], mount: 0 },
  { id: "thruster_large", name: "Propulsor grande", cat: CAT.ENGINE, price: 700, for_sale: false, research: 500,
    hp: 130, handling: 4.5, speed: 3.5, size: [1.15, 1.15, 1.1], offset: [0, 0, 0.24],
    slots: [slot([0, 0, -0.31], [0, 0, -1], SIDE)], mount: 0 },
];

const WEAPONS = [
  { id: "machine_gun", name: "Metralleta", kind: KIND.BULLET, price: 250, damage: 6, interval: 0.15,
    speed: 32, range: 13, color: [1, 0.8, 0.35], spread: 3, evolves: "twin_machine_gun" },
  { id: "rocket_launcher", name: "Lanzacohetes", kind: KIND.ROCKET, price: 600, damage: 26, interval: 1.5,
    speed: 12, range: 14, color: [1, 0.5, 0.15], spread: 2, area: 2.2, area_per_level: 0.05,
    evolves: "tsar_launcher" },
  { id: "laser", name: "Láser", kind: KIND.BEAM, price: 700, damage: 24, interval: 0, speed: 0, range: 11,
    color: [0.3, 0.9, 1], spread: 0, beam: 0.35, evolves: "positron_cannon" },
  // Evoluciones (GDD 8.3): no se venden; el mecánico las crea desde un arma al nivel 10
  // por 12.000 créditos. Su precio (arma base + evolución) cuenta para vender y reconstruir.
  { id: "twin_machine_gun", name: "Metralleta doble", kind: KIND.BULLET, price: 12250, for_sale: false,
    damage: 10, interval: 0.12, speed: 34, range: 14, color: [1, 0.85, 0.4], spread: 2.5, barrels: 2 },
  { id: "tsar_launcher", name: "Lanzador Tsar", kind: KIND.ROCKET, price: 12600, for_sale: false,
    damage: 130, interval: 2.4, speed: 9, range: 15, color: [1, 0.45, 0.1], spread: 0, area: 5.5,
    area_per_level: 0.05, projectile_scale: 2.4 },
  { id: "positron_cannon", name: "Cañón de positrones", kind: KIND.BEAM, price: 12700, for_sale: false,
    damage: 62, interval: 0, speed: 0, range: 13, color: [0.55, 0.75, 1], spread: 0, beam: 1.5 },
  // Fase 4: armas que se investigan (GDD 7.6) y se fabrican en el hangar.
  { id: "particle_cannon", name: "Cañón de partículas", kind: KIND.BULLET, price: 900, for_sale: false,
    research: 500, damage: 30, interval: 0.9, speed: 40, range: 16, color: [0.75, 0.45, 1], spread: 1, pierce: 4 },
  { id: "flak_cannon", name: "Escopeta de fragmentos", kind: KIND.BULLET, price: 800, for_sale: false,
    research: 500, damage: 7, interval: 0.7, speed: 26, range: 8, color: [1, 0.65, 0.3], spread: 2,
    pellets: 6, pellet_spread: 32 },
];

// Edificios de la base (GDD 7.3, propuestas de la v0.29). extra: niveles que dan una plaza más
// (tripulantes, entrenamiento y candidatos, o planos en el hangar).
const BUILDINGS = [
  { id: "hangar", name: "Hangar", price: 5000, stat: "engineering", slots: 1, extra: [4, 7, 10], rate: 0.8, per: -0.02,
    desc: "Construye naves y fabrica sus piezas, también las investigadas. Guarda los planos de tus naves. Con un ingeniero asignado repara, mejora y reconstruye la nave como el mecánico de una estación." },
  { id: "research_center", name: "Centro de investigación", price: 4000, stat: "research", slots: 1, extra: [4, 7],
    rate: 1, per: 0.1,
    desc: "Investiga piezas, armas y depósitos nuevos, que quedan desbloqueados para siempre. Cada investigador genera (investigador ÷ 5) puntos por minuto; en un satélite, un 30 % más." },
  { id: "refinery", name: "Refinería", price: 3000, rate: 30, per: 0.2,
    desc: "Convierte la chatarra guardada en la base en minerales puros, que valen un 50 % más. No necesita tripulantes." },
  { id: "mine", name: "Mina", price: 2500, rate: 10, per: 0.25,
    desc: "Extrae minerales puros del suelo mientras el juego está abierto. Rinde un 50 % más en un asteroide. No necesita tripulantes." },
  { id: "academy", name: "Academia", price: 2000, extra: [4, 7],
    desc: "Recluta tripulantes (los candidatos cambian cada vez que aterrizas) y los entrena: +5 a una estadística en 10 minutos." },
  { id: "infirmary", name: "Enfermería", price: 2000, stat: "first_aid", slots: 1, extra: [4, 7], rate: 1, per: 0.1,
    desc: "Cura a los tripulantes heridos. Cada tripulante asignado cura a un herido a la vez: tarda 1.000 ÷ primeros auxilios minutos." },
  { id: "trade_port", name: "Puerto comercial", price: 1500, rate: 0.7, per: 0.02,
    desc: "Vende lo guardado en las bases: la chatarra, a peor precio que la estación, y los minerales puros, a su precio completo." },
  { id: "fuel_charger", name: "Cargador de combustible", price: 2000, levels: false,
    desc: "Rellena el depósito de combustible interestelar al aterrizar, como los cargadores de las estaciones." },
];

// Minerales puros (GDD 7.5): cada tipo de chatarra se refina en un mineral que vale un 50 % más.
const MINERALS = [
  { id: "titanium", name: "Titanio", price: 15, color: [0.72, 0.78, 0.86], src: "scrap_metal", n: 10, mine: 60 },
  { id: "gold", name: "Oro", price: 22, color: [1, 0.78, 0.25], src: "electronics", n: 5, mine: 25 },
  { id: "tungsten", name: "Tungsteno", price: 37, color: [0.45, 0.5, 0.58], src: "heavy_plating", n: 5, mine: 12 },
  { id: "iridium", name: "Iridio", price: 37, color: [0.85, 0.9, 1], src: "energy_core", n: 1, mine: 3 },
  { id: "xenite", name: "Xenita", price: 150, color: [0.45, 1, 0.6], src: "alien_tech", n: 1, mine: 0 },
];

function header(script, model) {
  return `[gd_resource type="Resource" script_class="${script.cls}" load_steps=3 format=3]\n\n` +
    `[ext_resource type="Script" path="res://scripts/data/${script.file}" id="1"]\n` +
    `[ext_resource type="PackedScene" path="res://assets/models/parts/${model}.glb" id="2"]\n\n[resource]\nscript = ExtResource("1")\n`;
}

function partTres(p) {
  const lines = [
    `id = &"${p.id}"`, `display_name = "${p.name}"`, `category = ${p.cat}`, `model = ExtResource("2")`,
    `price = ${p.price}`, `for_sale = ${p.for_sale === false ? "false" : "true"}`,
    `has_levels = ${p.levels ? "true" : "false"}`, `max_hp = ${num(p.hp)}`,
    `hull_bonus = ${num(p.hull || 0)}`, `armor = ${num(p.armor || 0)}`, `handling = ${num(p.handling || 0)}`,
    `speed = ${num(p.speed || 0)}`, `pickup_radius = ${num(p.pickup || 0)}`, `crew_capacity = ${p.crew || 0}`,
    `crew_bonus_per_level = ${num(p.crew_bonus || 0)}`, `collision_size = ${v3(p.size)}`,
    `collision_offset = ${v3(p.offset || [0, 0, 0])}`, `weapon_offset = ${v3(p.weapon_offset || [0, 0, 0])}`,
    `slot_positions = PackedVector3Array(${p.slots.flatMap((s) => s.pos).map(num).join(", ")})`,
    `slot_normals = PackedVector3Array(${p.slots.flatMap((s) => s.normal).map(num).join(", ")})`,
    `slot_kinds = PackedInt32Array(${p.slots.map((s) => s.kind).join(", ")})`,
    `mount_slot = ${p.mount}`, `research_points = ${p.research || 0}`,
    `upgrade_base_cost = ${p.up_base || 0}`, `upgrade_growth = ${num(p.up_growth || 0)}`,
    `hp_per_level = ${num(p.hp_per || 0)}`, `crew_per_level = ${p.crew_per || 0}`,
    `shield_capacity = ${num(p.shield || 0)}`, `shield_per_level = ${num(p.shield_per || 0)}`,
    `shield_recharge = ${num(p.shield_recharge || 0)}`, `shield_delay = ${num(p.shield_delay || 0)}`,
    `shield_break_delay = ${num(p.shield_break || 0)}`, `unique = ${p.unique ? "true" : "false"}`,
    `face_only = ${p.face_only ? "true" : "false"}`,
  ];
  return header({ cls: "PartData", file: "part_data.gd" }, p.id) + lines.join("\n") + "\n";
}

function weaponTres(w) {
  const lines = [
    `id = &"${w.id}"`, `display_name = "${w.name}"`, `model = ExtResource("2")`, `kind = ${w.kind}`,
    `price = ${w.price}`, `damage = ${num(w.damage)}`, `fire_interval = ${num(w.interval)}`,
    `projectile_speed = ${num(w.speed)}`, `weapon_range = ${num(w.range)}`,
    `projectile_color = ${color(w.color)}`, `spread_degrees = ${num(w.spread)}`,
    `aim_cone_degrees = ${num(w.cone || 50)}`, `area_radius = ${num(w.area || 0)}`,
    `area_per_level = ${num(w.area_per_level || 0)}`, `beam_width = ${num(w.beam || 0.3)}`,
    `evolves_into = &"${w.evolves || ""}"`, `for_sale = ${w.for_sale === false ? "false" : "true"}`,
    `barrels = ${w.barrels || 1}`, `projectile_scale = ${num(w.projectile_scale || 1)}`,
    `research_points = ${w.research || 0}`, `pierce = ${w.pierce || 0}`, `pellets = ${w.pellets || 1}`,
    `pellet_spread_degrees = ${num(w.pellet_spread || 0)}`,
  ];
  return header({ cls: "WeaponData", file: "weapon_data.gd" }, w.id) + lines.join("\n") + "\n";
}

function buildingTres(b) {
  const lines = [
    `id = &"${b.id}"`, `display_name = "${b.name}"`, `description = "${b.desc}"`, `model = ExtResource("2")`,
    `price = ${b.price}`, `has_levels = ${b.levels === false ? "false" : "true"}`,
    `crew_stat = "${b.stat || ""}"`, `crew_slots = ${b.slots || 0}`,
    `extra_slot_levels = PackedInt32Array(${(b.extra || []).join(", ")})`,
    `base_rate = ${num(b.rate || 0)}`, `rate_per_level = ${num(b.per || 0)}`,
  ];
  return `[gd_resource type="Resource" script_class="BuildingData" load_steps=3 format=3]\n\n` +
    `[ext_resource type="Script" path="res://scripts/data/building_data.gd" id="1"]\n` +
    `[ext_resource type="PackedScene" path="res://assets/models/buildings/${b.id}.glb" id="2"]\n\n[resource]\nscript = ExtResource("1")\n` +
    lines.join("\n") + "\n";
}

function mineralTres(m) {
  const lines = [
    `id = &"${m.id}"`, `display_name = "${m.name}"`, `price = ${m.price}`, `color = ${color(m.color)}`,
    `source_scrap = &"${m.src}"`, `source_amount = ${m.n}`, `mine_weight = ${num(m.mine)}`,
  ];
  return `[gd_resource type="Resource" script_class="MineralData" load_steps=2 format=3]\n\n` +
    `[ext_resource type="Script" path="res://scripts/data/mineral_data.gd" id="1"]\n\n[resource]\nscript = ExtResource("1")\n` +
    lines.join("\n") + "\n";
}

for (const dir of ["buildings", "minerals"]) fs.mkdirSync(path.join(PROJECT, "data", dir), { recursive: true });
for (const b of BUILDINGS) fs.writeFileSync(path.join(PROJECT, "data", "buildings", b.id + ".tres"), buildingTres(b));
for (const m of MINERALS) fs.writeFileSync(path.join(PROJECT, "data", "minerals", m.id + ".tres"), mineralTres(m));
for (const p of PARTS) fs.writeFileSync(path.join(PROJECT, "data", "parts", p.id + ".tres"), partTres(p));
for (const w of WEAPONS) fs.writeFileSync(path.join(PROJECT, "data", "weapons", w.id + ".tres"), weaponTres(w));
console.log(`ok: ${PARTS.length} piezas, ${WEAPONS.length} armas, ${BUILDINGS.length} edificios, ${MINERALS.length} minerales`);
