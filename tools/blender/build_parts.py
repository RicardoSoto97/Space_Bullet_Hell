# Genera las piezas de la nave en Blender y las exporta a .glb para Godot.
#
# Uso (Blender en segundo plano):
#   blender --background --factory-startup --python tools/blender/build_parts.py -- <carpeta_proyecto> [carpeta_renders]
#
# Estilo: low-poly, formas redondeadas tipo vehículo actual, colores planos sin texturas.
# Ejes: Blender Z arriba, +Y = frente de la nave (en Godot queda como -Z, el "adelante" estándar).
# Unidad: 1 cubo de pasillo = 1 metro.

import bpy
import bmesh
import math
import os
import sys
from mathutils import Matrix, Vector

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
PROJECT = argv[0] if argv else os.getcwd()
RENDER_DIR = argv[1] if len(argv) > 1 else None
PARTS_DIR = os.path.join(PROJECT, "assets", "models", "parts")
os.makedirs(PARTS_DIR, exist_ok=True)

# ---------- paleta (colores planos) ----------
# Índices de material: se usan igual en todas las piezas.
HULL, DARK, ORANGE, CYAN, GLASS, MID, E_HULL, E_RED, E_LIGHT, G_ORANGE, VIOLET, GREEN = range(12)
PALETTE = [
    # nombre, color base (lineal), metálico, rugosidad, emisión
    ("hull_white", (0.78, 0.80, 0.83), 0.1, 0.55, 0.0),
    ("dark_grey", (0.045, 0.05, 0.06), 0.3, 0.6, 0.0),
    ("accent_orange", (0.95, 0.30, 0.03), 0.0, 0.5, 0.0),
    ("light_cyan", (0.10, 0.75, 1.00), 0.0, 0.3, 6.0),
    ("glass_dark", (0.02, 0.05, 0.08), 0.4, 0.12, 0.0),
    ("metal_grey", (0.30, 0.32, 0.35), 0.5, 0.45, 0.0),
    # enemigos: casco oscuro y luces rojas, para distinguirlos de la nave del jugador
    ("enemy_hull", (0.07, 0.06, 0.09), 0.3, 0.5, 0.0),
    ("enemy_red", (0.75, 0.04, 0.08), 0.1, 0.45, 0.0),
    ("enemy_light", (1.0, 0.06, 0.08), 0.0, 0.3, 3.0),
    # fase 4: horno de la refinería, cañón de partículas y detalles verdes
    ("glow_orange", (1.0, 0.32, 0.04), 0.0, 0.4, 4.0),
    ("glow_violet", (0.6, 0.25, 1.0), 0.0, 0.3, 5.0),
    ("accent_green", (0.15, 0.7, 0.3), 0.0, 0.5, 0.0),
]


def build_materials():
    mats = []
    for name, color, metal, rough, emit in PALETTE:
        m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
        m.use_nodes = True
        bsdf = m.node_tree.nodes.get("Principled BSDF")
        bsdf.inputs["Base Color"].default_value = (*color, 1.0)
        bsdf.inputs["Metallic"].default_value = metal
        bsdf.inputs["Roughness"].default_value = rough
        if emit > 0:
            bsdf.inputs["Emission Color"].default_value = (*color, 1.0)
            bsdf.inputs["Emission Strength"].default_value = emit
        m.diffuse_color = (*color, 1.0)
        mats.append(m)
    return mats


# ---------- primitivas con bmesh ----------
def _bevel_sharp(bm, width, segments, angle_deg=30):
    if width <= 0:
        return
    edges = [e for e in bm.edges if e.is_manifold and e.calc_face_angle(0) > math.radians(angle_deg)]
    if edges:
        bmesh.ops.bevel(bm, geom=edges, offset=width, offset_type='OFFSET', segments=segments,
                        profile=0.5, affect='EDGES', clamp_overlap=True)


def prim(kind, mat, size=(1, 1, 1), loc=(0, 0, 0), rot=(0, 0, 0), bevel=0.0, segs=2,
         radius=0.5, radius2=None, depth=1.0, verts=12):
    """Crea una primitiva y devuelve su bmesh.
    kind: 'box' (size), 'cyl' (radius, radius2, depth, verts; eje Z), 'sphere' (radius, verts)."""
    bm = bmesh.new()
    if kind == "box":
        bmesh.ops.create_cube(bm, size=1.0)
        bmesh.ops.scale(bm, vec=Vector(size), verts=bm.verts)
    elif kind == "cyl":
        bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=verts, radius1=radius,
                              radius2=radius if radius2 is None else radius2, depth=depth)
    elif kind == "sphere":
        bmesh.ops.create_uvsphere(bm, u_segments=verts, v_segments=max(4, verts // 2), radius=radius)
        bmesh.ops.scale(bm, vec=Vector(size), verts=bm.verts)
    _bevel_sharp(bm, bevel, segs)
    for f in bm.faces:
        f.material_index = mat
    m = (Matrix.Translation(loc)
         @ Matrix.Rotation(math.radians(rot[2]), 4, 'Z')
         @ Matrix.Rotation(math.radians(rot[1]), 4, 'Y')
         @ Matrix.Rotation(math.radians(rot[0]), 4, 'X'))
    bmesh.ops.transform(bm, matrix=m, verts=bm.verts)
    return bm


def merge(dst, src):
    vmap = {v: dst.verts.new(v.co) for v in src.verts}
    for f in src.faces:
        nf = dst.faces.new([vmap[v] for v in f.verts])
        nf.material_index = f.material_index
        nf.smooth = False
    src.free()


def make_part(name, pieces, mats):
    bm = bmesh.new()
    for p in pieces:
        merge(bm, p)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.0001)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    for m in mats:
        me.materials.append(m)
    obj = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(obj)
    return obj


# Acoplador: disco oscuro con luz cian. axis = dirección hacia afuera de la cara.
def coupler(loc, axis):
    rot = {"x": (0, 90, 0), "y": (90, 0, 0), "z": (0, 0, 0)}[axis]
    return [
        prim("cyl", DARK, loc=loc, rot=rot, radius=0.15, depth=0.05, verts=12),
        prim("cyl", CYAN, loc=loc, rot=rot, radius=0.085, depth=0.065, verts=12),
    ]


# ---------- piezas ----------
def corridor(n):
    """Pasillo de n cubos a lo largo de Y. Acopladores en todas sus caras."""
    L = float(n)
    w, h = 0.92, 0.84
    p = [prim("box", HULL, size=(w, L - 0.06, h), bevel=0.17, segs=2)]
    # aros oscuros en los extremos y en las uniones entre cubos
    rings = [-L / 2 + 0.12, L / 2 - 0.12] + [-L / 2 + k for k in range(1, n)]
    for y in rings:
        p.append(prim("box", DARK, size=(w + 0.04, 0.07, h + 0.04), loc=(0, y, 0), bevel=0.05, segs=1))
    # franjas naranjas en la parte de arriba
    for x in (-0.27, 0.27):
        p.append(prim("box", ORANGE, size=(0.07, L - 0.5, 0.03), loc=(x, 0, h / 2 - 0.005)))
    # acopladores
    for k in range(n):
        y = -L / 2 + 0.5 + k
        for sx in (-1, 1):
            p += coupler((sx * w / 2, y, 0), "x")
        p += coupler((0, y, h / 2), "z")
        p += coupler((0, y, -h / 2), "z")
    for sy in (-1, 1):
        p += coupler((0, sy * (L / 2 - 0.03), 0), "y")
    return p


def core():
    """Núcleo: cápsula achatada a lo largo de Y, con acoplador central arriba."""
    p = [prim("cyl", HULL, rot=(90, 0, 0), radius=0.75, depth=1.5, verts=14, bevel=0.22, segs=2)]
    # achatar en Z
    bmesh.ops.scale(p[0], vec=Vector((1, 1, 0.68)), verts=p[0].verts)
    p.append(prim("box", DARK, size=(0.62, 0.95, 0.06), loc=(0, 0, 0.5), bevel=0.03, segs=1))
    p += coupler((0, 0, 0.53), "z")  # acoplador central
    for sx in (-1, 1):
        p.append(prim("box", ORANGE, size=(0.05, 1.1, 0.09), loc=(sx * 0.7, 0, 0.24)))
        p += coupler((sx * 0.76, 0, -0.02), "x")  # puntos de acople laterales
    for sy in (-1, 1):
        p += coupler((0, sy * 0.76, 0), "y")
    # luz de posición
    p.append(prim("sphere", CYAN, size=(1, 1, 1), loc=(0, 0.55, 0.42), radius=0.05, verts=8))
    return p


def command_station():
    """Estación de mando: módulo redondeado con cabina de cristal para el artillero."""
    p = [prim("box", HULL, size=(0.9, 0.9, 0.72), bevel=0.24, segs=2)]
    p.append(prim("sphere", GLASS, size=(1.0, 1.25, 0.7), loc=(0, -0.08, 0.3), radius=0.3, verts=10))
    p.append(prim("box", DARK, size=(0.66, 0.08, 0.2), loc=(0, 0.3, 0.3), bevel=0.03, segs=1))
    for sx in (-1, 1):
        p.append(prim("box", ORANGE, size=(0.06, 0.55, 0.03), loc=(sx * 0.33, -0.05, 0.36)))
    # montura del arma (ranura frontal)
    p.append(prim("cyl", DARK, rot=(90, 0, 0), loc=(0, 0.45, 0.02), radius=0.17, depth=0.1, verts=12))
    p.append(prim("cyl", CYAN, rot=(90, 0, 0), loc=(0, 0.47, 0.02), radius=0.19, radius2=0.19, depth=0.03, verts=12))
    p += coupler((0, -0.46, 0), "y")  # unión con la nave
    return p


def machine_gun():
    """Metralleta simple. Origen = punto de montaje (atrás); dispara hacia +Y."""
    p = [prim("box", DARK, size=(0.26, 0.38, 0.24), loc=(0, 0.19, 0), bevel=0.05, segs=1)]
    p.append(prim("box", MID, size=(0.14, 0.2, 0.14), loc=(0.19, 0.16, -0.02), bevel=0.02, segs=1))
    p.append(prim("cyl", DARK, rot=(90, 0, 0), loc=(0, 0.47, 0.02), radius=0.085, depth=0.22, verts=10))
    p.append(prim("cyl", MID, rot=(90, 0, 0), loc=(0, 0.75, 0.02), radius=0.045, depth=0.5, verts=8))
    p.append(prim("cyl", ORANGE, rot=(90, 0, 0), loc=(0, 1.0, 0.02), radius=0.06, depth=0.06, verts=8))
    return p


def thruster_small():
    """Propulsor pequeño. Se acopla por delante (+Y) y empuja hacia -Y."""
    p = [prim("cyl", HULL, rot=(90, 0, 0), radius=0.36, depth=0.42, verts=12, bevel=0.08, segs=1)]
    p.append(prim("cyl", ORANGE, rot=(90, 0, 0), loc=(0, 0.06, 0), radius=0.375, depth=0.06, verts=12))
    p.append(prim("cyl", DARK, rot=(90, 0, 0), loc=(0, -0.36, 0), radius=0.24, radius2=0.33, depth=0.32, verts=12))
    p.append(prim("cyl", CYAN, rot=(90, 0, 0), loc=(0, -0.535, 0), radius=0.27, depth=0.03, verts=12))
    p += coupler((0, 0.21, 0), "y")
    return p


def armor_plate():
    """Placa de blindaje: losa que tapa un acoplador libre."""
    p = [prim("box", MID, size=(0.86, 0.86, 0.1), bevel=0.04, segs=1)]
    for y in (-0.2, 0.2):
        p.append(prim("box", ORANGE, size=(0.55, 0.08, 0.02), loc=(0, y, 0.055)))
    for x in (-0.33, 0.33):
        for y in (-0.33, 0.33):
            p.append(prim("cyl", DARK, loc=(x, y, 0.06), radius=0.04, depth=0.03, verts=6))
    return p


def crew_quarters(n):
    """Habitación de tripulantes de n cubos: módulo habitable con ventanas. Se une por detrás."""
    L = float(n)
    w, h = 0.92, 0.84
    p = [prim("box", HULL, size=(w, L - 0.04, h), bevel=0.3, segs=3)]
    for k in range(n):
        y = -L / 2 + 0.5 + k
        for sx in (-1, 1):
            for dy in (-0.22, 0.0, 0.22):
                p.append(prim("box", GLASS, size=(0.05, 0.14, 0.18), loc=(sx * (w / 2 - 0.01), y + dy, 0.05),
                              bevel=0.02, segs=1))
    p.append(prim("box", GLASS, size=(0.34, L - 0.42, 0.05), loc=(0, 0.05, h / 2 - 0.01), bevel=0.02, segs=1))
    p.append(prim("box", ORANGE, size=(w + 0.03, 0.08, h - 0.1), loc=(0, L / 2 - 0.22, 0), bevel=0.03, segs=1))
    p.append(prim("box", DARK, size=(w - 0.1, 0.06, h - 0.16), loc=(0, -L / 2 + 0.02, 0), bevel=0.03, segs=1))
    p.append(prim("sphere", CYAN, size=(1, 1, 1), loc=(0, L / 2 - 0.32, h / 2 - 0.02), radius=0.045, verts=8))
    p += coupler((0, -(L / 2 - 0.01), 0), "y")
    return p


def thruster_medium():
    """Propulsor mediano: más grande que el pequeño, con doble aro. Se acopla por delante (+Y)."""
    p = [prim("cyl", HULL, rot=(90, 0, 0), radius=0.46, depth=0.5, verts=14, bevel=0.1, segs=1)]
    p.append(prim("cyl", ORANGE, rot=(90, 0, 0), loc=(0, 0.1, 0), radius=0.475, depth=0.07, verts=14))
    p.append(prim("cyl", DARK, rot=(90, 0, 0), loc=(0, -0.1, 0), radius=0.47, depth=0.05, verts=14))
    p.append(prim("cyl", DARK, rot=(90, 0, 0), loc=(0, -0.42, 0), radius=0.3, radius2=0.43, depth=0.36, verts=14))
    p.append(prim("cyl", CYAN, rot=(90, 0, 0), loc=(0, -0.615, 0), radius=0.36, depth=0.03, verts=14))
    p += coupler((0, 0.25, 0), "y")
    return p


def scrap_magnet():
    """Recolector magnético: antena parabólica con bobina naranja. Centrado; se apoya por abajo (-Z)."""
    p = [prim("cyl", DARK, loc=(0, 0, -0.17), radius=0.3, depth=0.06, verts=12, bevel=0.02, segs=1)]
    p.append(prim("cyl", MID, loc=(0, 0, -0.05), radius=0.07, depth=0.2, verts=8))
    p.append(prim("cyl", ORANGE, loc=(0, 0, -0.06), radius=0.17, depth=0.05, verts=12))
    p.append(prim("cyl", HULL, loc=(0, 0, 0.1), radius=0.12, radius2=0.3, depth=0.14, verts=12))
    p.append(prim("cyl", MID, loc=(0, 0, 0.11), radius=0.04, depth=0.16, verts=6))
    p.append(prim("sphere", CYAN, size=(1, 1, 1), loc=(0, 0, 0.19), radius=0.06, verts=8))
    return p


def interstellar_fuel_tank():
    """Depósito de combustible interestelar: tanque cilíndrico tumbado. Se apoya por abajo (-Z)."""
    p = [prim("cyl", HULL, rot=(0, 90, 0), loc=(0, 0, 0.02), radius=0.22, depth=0.46, verts=12)]
    for sx in (-1, 1):
        p.append(prim("sphere", HULL, size=(1, 1, 1), loc=(sx * 0.23, 0, 0.02), radius=0.22, verts=12))
        p.append(prim("cyl", ORANGE, rot=(0, 90, 0), loc=(sx * 0.14, 0, 0.02), radius=0.232, depth=0.05, verts=12))
    p.append(prim("box", DARK, size=(0.5, 0.3, 0.06), loc=(0, 0, -0.22), bevel=0.02, segs=1))
    p.append(prim("box", CYAN, size=(0.18, 0.05, 0.03), loc=(0, 0, 0.245)))
    return p


def rocket_launcher():
    """Lanzacohetes: cápsula con cuatro tubos. Origen = punto de montaje (atrás); dispara hacia +Y."""
    p = [prim("box", MID, size=(0.2, 0.14, 0.16), loc=(0, 0.06, 0), bevel=0.03, segs=1)]
    p.append(prim("box", HULL, size=(0.46, 0.55, 0.32), loc=(0, 0.38, 0.03), bevel=0.08, segs=2))
    p.append(prim("box", ORANGE, size=(0.48, 0.07, 0.34), loc=(0, 0.22, 0.03), bevel=0.02, segs=1))
    for x in (-0.11, 0.11):
        for z in (-0.04, 0.1):
            p.append(prim("cyl", DARK, rot=(90, 0, 0), loc=(x, 0.64, z), radius=0.075, depth=0.08, verts=8))
            p.append(prim("cyl", ORANGE, rot=(90, 0, 0), loc=(x, 0.655, z), radius=0.04, depth=0.06, verts=6))
    return p


def laser():
    """Láser: cañón largo con aros luminosos. Origen = punto de montaje (atrás); dispara hacia +Y."""
    p = [prim("box", DARK, size=(0.26, 0.32, 0.22), loc=(0, 0.16, 0), bevel=0.05, segs=1)]
    for sx in (-1, 1):
        p.append(prim("box", HULL, size=(0.05, 0.22, 0.18), loc=(sx * 0.16, 0.16, 0), bevel=0.015, segs=1))
    p.append(prim("cyl", MID, rot=(90, 0, 0), loc=(0, 0.62, 0.02), radius=0.06, depth=0.66, verts=10))
    for y in (0.42, 0.62, 0.82):
        p.append(prim("cyl", CYAN, rot=(90, 0, 0), loc=(0, y, 0.02), radius=0.085, depth=0.035, verts=10))
    p.append(prim("cyl", CYAN, rot=(90, 0, 0), loc=(0, 0.97, 0.02), radius=0.07, depth=0.04, verts=10))
    return p


# ---------- evoluciones de armas (fase 3) ----------
def twin_machine_gun():
    """Metralleta doble (evolución): dos cañones paralelos sobre una base ancha."""
    p = [prim("box", DARK, size=(0.42, 0.4, 0.26), loc=(0, 0.2, 0), bevel=0.05, segs=1)]
    p.append(prim("box", ORANGE, size=(0.44, 0.06, 0.28), loc=(0, 0.08, 0)))
    p.append(prim("box", MID, size=(0.12, 0.2, 0.12), loc=(0.28, 0.16, -0.02), bevel=0.02, segs=1))
    for x in (-0.12, 0.12):
        p.append(prim("cyl", DARK, rot=(90, 0, 0), loc=(x, 0.5, 0.03), radius=0.075, depth=0.22, verts=10))
        p.append(prim("cyl", MID, rot=(90, 0, 0), loc=(x, 0.8, 0.03), radius=0.042, depth=0.52, verts=8))
        p.append(prim("cyl", ORANGE, rot=(90, 0, 0), loc=(x, 1.06, 0.03), radius=0.058, depth=0.06, verts=8))
    return p


def tsar_launcher():
    """Lanzador Tsar (evolución): un tubo enorme con una ojiva naranja asomando."""
    p = [prim("box", MID, size=(0.24, 0.16, 0.18), loc=(0, 0.07, 0), bevel=0.03, segs=1)]
    p.append(prim("cyl", HULL, rot=(90, 0, 0), loc=(0, 0.5, 0.06), radius=0.26, depth=0.74, verts=14, bevel=0.03))
    p.append(prim("cyl", ORANGE, rot=(90, 0, 0), loc=(0, 0.3, 0.06), radius=0.275, depth=0.08, verts=14))
    p.append(prim("cyl", DARK, rot=(90, 0, 0), loc=(0, 0.88, 0.06), radius=0.22, depth=0.06, verts=14))
    p.append(prim("sphere", ORANGE, size=(1, 1.4, 1), loc=(0, 0.88, 0.06), radius=0.17, verts=10))
    for sx in (-1, 1):
        p.append(prim("box", DARK, size=(0.06, 0.42, 0.2), loc=(sx * 0.29, 0.46, 0.06), bevel=0.02, segs=1))
    return p


def positron_cannon():
    """Cañón de positrones (evolución): cañón grueso con bobinas cian."""
    p = [prim("box", DARK, size=(0.4, 0.36, 0.26), loc=(0, 0.18, 0), bevel=0.06, segs=1)]
    for sx in (-1, 1):
        p.append(prim("box", HULL, size=(0.06, 0.3, 0.22), loc=(sx * 0.23, 0.18, 0), bevel=0.02, segs=1))
    p.append(prim("cyl", MID, rot=(90, 0, 0), loc=(0, 0.66, 0.02), radius=0.12, depth=0.7, verts=12))
    for y in (0.42, 0.58, 0.74, 0.9):
        p.append(prim("cyl", CYAN, rot=(90, 0, 0), loc=(0, y, 0.02), radius=0.16, depth=0.05, verts=12))
    p.append(prim("cyl", CYAN, rot=(90, 0, 0), loc=(0, 1.03, 0.02), radius=0.14, depth=0.05, verts=12))
    p.append(prim("sphere", CYAN, loc=(0, 0.18, 0.15), radius=0.09, verts=8))
    return p


# ---------- enemigos (frente = +Y) ----------
def enemy_swarm():
    """Dron de enjambre: pequeño, con alas rojas y un ojo luminoso."""
    p = [prim("sphere", E_HULL, size=(1.0, 1.35, 0.7), radius=0.28, verts=8)]
    for sx in (-1, 1):
        p.append(prim("box", E_RED, size=(0.42, 0.24, 0.06), loc=(sx * 0.33, -0.05, 0), rot=(0, 0, sx * 25),
                      bevel=0.03, segs=1))
    p.append(prim("sphere", E_LIGHT, size=(1, 1, 1), loc=(0, 0.3, 0.05), radius=0.09, verts=8))
    return p


def enemy_gunner():
    """Artillero: disco con tres cañones alrededor; dispara ráfagas en círculo."""
    p = [prim("cyl", E_HULL, radius=0.6, depth=0.3, verts=10, bevel=0.08, segs=1)]
    p.append(prim("sphere", E_RED, size=(1, 1, 0.6), loc=(0, 0, 0.14), radius=0.32, verts=10))
    p.append(prim("cyl", E_LIGHT, loc=(0, 0, 0), radius=0.615, depth=0.07, verts=10))
    for a in (90, 210, 330):
        r = math.radians(a)
        d = Vector((math.cos(r), math.sin(r), 0))
        p.append(prim("box", DARK, size=(0.16, 0.42, 0.16), loc=tuple(d * 0.68), rot=(0, 0, a - 90), bevel=0.03, segs=1))
        p.append(prim("sphere", E_LIGHT, size=(1, 1, 1), loc=tuple(d * 0.92), radius=0.07, verts=6))
    return p


def enemy_tank():
    """Tanque: casco grueso con placa frontal de choque."""
    p = [prim("box", E_HULL, size=(1.7, 1.9, 0.85), bevel=0.3, segs=2)]
    p.append(prim("box", E_RED, size=(1.85, 0.32, 0.65), loc=(0, 0.95, -0.05), bevel=0.08, segs=1))
    for sx in (-1, 1):
        p.append(prim("box", MID, size=(0.26, 1.5, 0.6), loc=(sx * 0.92, -0.1, -0.05), bevel=0.06, segs=1))
        p.append(prim("sphere", E_LIGHT, size=(1, 1, 1), loc=(sx * 0.5, 1.12, 0.12), radius=0.09, verts=6))
    p.append(prim("cyl", E_HULL, loc=(0, -0.15, 0.5), radius=0.42, depth=0.3, verts=10, bevel=0.06, segs=1))
    p.append(prim("box", E_RED, size=(0.5, 0.08, 0.04), loc=(0, -0.15, 0.66)))
    return p


def enemy_lancer():
    """Lancero: flecha estrecha con una lanza roja; se detiene, apunta y embiste en línea recta."""
    p = [prim("box", E_HULL, size=(0.5, 1.3, 0.35), loc=(0, -0.1, 0), bevel=0.12, segs=2)]
    p.append(prim("cyl", E_RED, rot=(-90, 0, 0), loc=(0, 0.9, 0), radius=0.15, radius2=0.0, depth=0.9, verts=8))
    for sx in (-1, 1):
        p.append(prim("box", E_RED, size=(0.6, 0.34, 0.05), loc=(sx * 0.42, -0.45, 0), rot=(0, 0, -sx * 30),
                      bevel=0.02, segs=1))
        p.append(prim("sphere", E_LIGHT, loc=(sx * 0.66, -0.62, 0), radius=0.06, verts=6))
    p.append(prim("sphere", E_LIGHT, size=(1, 1.6, 0.6), loc=(0, 0.25, 0.17), radius=0.1, verts=8))
    p.append(prim("cyl", E_LIGHT, rot=(90, 0, 0), loc=(0, -0.78, 0), radius=0.12, depth=0.08, verts=8))
    return p


def enemy_splitter():
    """Divisor: tres lóbulos unidos; al destruirlo se separa en drones de enjambre."""
    p = [prim("cyl", DARK, radius=0.5, depth=0.14, verts=10)]
    for a in (90, 210, 330):
        r = math.radians(a)
        d = Vector((math.cos(r), math.sin(r), 0))
        p.append(prim("sphere", E_HULL, loc=tuple(d * 0.4), radius=0.42, verts=10))
        p.append(prim("sphere", E_RED, size=(1, 1, 0.5), loc=tuple(d * 0.42 + Vector((0, 0, 0.26))), radius=0.22, verts=8))
    p.append(prim("sphere", E_LIGHT, loc=(0, 0, 0.12), radius=0.2, verts=8))
    return p


def enemy_mine_layer():
    """Sembrador: nave ancha con forma de manta que deja minas detrás y dispara en abanico."""
    p = [prim("sphere", E_HULL, size=(2.2, 1.2, 0.45), radius=0.5, verts=12)]
    p.append(prim("box", E_RED, size=(1.5, 0.16, 0.1), loc=(0, 0.25, 0.17), bevel=0.04, segs=1))
    for sx in (-1, 1):
        p.append(prim("box", E_HULL, size=(0.5, 0.7, 0.12), loc=(sx * 1.05, -0.15, 0), rot=(0, 0, sx * 20),
                      bevel=0.05, segs=1))
        p.append(prim("sphere", E_LIGHT, loc=(sx * 1.22, -0.42, 0.06), radius=0.07, verts=6))
    for x in (-0.3, 0.0, 0.3):
        p.append(prim("sphere", E_RED, loc=(x, -0.55, -0.04), radius=0.14, verts=8))
    p.append(prim("sphere", E_LIGHT, size=(1.5, 1, 0.6), loc=(0, 0.42, 0.14), radius=0.1, verts=8))
    return p


def boss_dreadnought():
    """Acorazado (jefe): anillo grande con seis torretas, núcleo con un ojo rojo y dos tenazas
    al frente. Mide unos 7 m."""
    p = [prim("cyl", DARK, radius=2.35, depth=0.16, verts=24)]
    p.append(prim("sphere", E_HULL, size=(1, 1, 0.6), radius=1.4, verts=16))
    p.append(prim("sphere", E_RED, size=(1, 1, 0.5), loc=(0, 0, 0.32), radius=0.95, verts=14))
    p.append(prim("sphere", E_LIGHT, size=(1, 1, 0.7), loc=(0, 0.15, 0.68), radius=0.36, verts=10))
    for i in range(16):
        a = i * 360.0 / 16
        d = Vector((math.cos(math.radians(a)), math.sin(math.radians(a)), 0))
        p.append(prim("box", E_HULL, size=(0.55, 1.12, 0.5), loc=tuple(d * 2.6), rot=(0, 0, a), bevel=0.12, segs=1))
    for a in (30, 150, 270):
        d = Vector((math.cos(math.radians(a)), math.sin(math.radians(a)), 0))
        p.append(prim("box", E_HULL, size=(1.3, 0.36, 0.3), loc=tuple(d * 1.85), rot=(0, 0, a), bevel=0.06, segs=1))
    for a in (0, 60, 120, 180, 240, 300):
        d = Vector((math.cos(math.radians(a)), math.sin(math.radians(a)), 0))
        p.append(prim("sphere", E_RED, size=(1, 1, 0.8), loc=tuple(d * 2.6 + Vector((0, 0, 0.3))), radius=0.42, verts=10))
        p.append(prim("box", DARK, size=(0.6, 0.18, 0.18), loc=tuple(d * 3.1 + Vector((0, 0, 0.32))), rot=(0, 0, a)))
        p.append(prim("sphere", E_LIGHT, loc=tuple(d * 3.42 + Vector((0, 0, 0.32))), radius=0.1, verts=6))
    for sx in (-1, 1):
        p.append(prim("box", E_HULL, size=(0.55, 2.0, 0.45), loc=(sx * 1.25, 3.3, 0), rot=(0, 0, sx * 12),
                      bevel=0.12, segs=1))
        p.append(prim("cyl", E_RED, rot=(-90, 0, 0), loc=(sx * 1.05, 4.6, 0), radius=0.2, radius2=0.0, depth=0.8, verts=8))
        p.append(prim("sphere", E_LIGHT, loc=(sx * 1.4, 2.6, 0.26), radius=0.1, verts=6))
    for x in (-0.9, 0.0, 0.9):
        p.append(prim("cyl", E_HULL, rot=(90, 0, 0), loc=(x, -3.25, 0), radius=0.36, depth=0.6, verts=10, bevel=0.04))
        p.append(prim("cyl", E_LIGHT, rot=(90, 0, 0), loc=(x, -3.58, 0), radius=0.26, depth=0.08, verts=10))
    return p


# ---------- piezas que se investigan (fase 4) ----------
def crew_room(feature):
    """Estructura de tripulación de un cubo: la habitación con un detalle que dice qué es."""
    p = crew_quarters(1)
    if feature == "library":
        # estanterías naranjas a la vista bajo un techo de cristal
        for x in (-0.18, 0.0, 0.18):
            p.append(prim("box", ORANGE, size=(0.08, 0.5, 0.06), loc=(x, 0.0, 0.44)))
    elif feature == "mess_hall":
        # mesa redonda con una cúpula de cristal
        p.append(prim("sphere", GLASS, size=(1, 1, 0.55), loc=(0, 0.02, 0.42), radius=0.3, verts=12))
        p.append(prim("cyl", ORANGE, loc=(0, 0.02, 0.45), radius=0.14, depth=0.04, verts=10))
    elif feature == "kitchen":
        # chimenea de ventilación con luz naranja
        p.append(prim("cyl", DARK, loc=(0.2, 0.15, 0.55), radius=0.09, depth=0.3, verts=8))
        p.append(prim("cyl", G_ORANGE, loc=(0.2, 0.15, 0.71), radius=0.07, depth=0.03, verts=8))
        p.append(prim("box", MID, size=(0.3, 0.3, 0.06), loc=(-0.15, -0.1, 0.44), bevel=0.02, segs=1))
    elif feature == "recreation_room":
        # cúpula de cristal grande con plantas verdes
        p.append(prim("sphere", GLASS, size=(1, 1, 0.7), loc=(0, 0.0, 0.42), radius=0.36, verts=12))
        for x, y in ((-0.12, -0.08), (0.1, 0.1), (0.12, -0.12)):
            p.append(prim("sphere", GREEN, loc=(x, y, 0.5), radius=0.08, verts=8))
    return p


def armor_plate_heavy():
    """Placa de blindaje pesada: losa doble, más gruesa, con remaches."""
    p = [prim("box", DARK, size=(0.88, 0.88, 0.1), loc=(0, 0, -0.04), bevel=0.03, segs=1)]
    p.append(prim("box", MID, size=(0.8, 0.8, 0.1), loc=(0, 0, 0.05), bevel=0.04, segs=1))
    for y in (-0.22, 0.0, 0.22):
        p.append(prim("box", ORANGE, size=(0.6, 0.06, 0.02), loc=(0, y, 0.105)))
    for x in (-0.34, 0.34):
        for y in (-0.34, 0.34):
            p.append(prim("cyl", DARK, loc=(x, y, 0.11), radius=0.05, depth=0.04, verts=6))
    return p


def scrap_magnet_large():
    """Recolector magnético grande: antena más ancha con dos bobinas."""
    p = [prim("cyl", DARK, loc=(0, 0, -0.22), radius=0.38, depth=0.06, verts=14, bevel=0.02, segs=1)]
    p.append(prim("cyl", MID, loc=(0, 0, -0.08), radius=0.09, depth=0.26, verts=8))
    for z in (-0.12, -0.04):
        p.append(prim("cyl", ORANGE, loc=(0, 0, z), radius=0.2, depth=0.04, verts=12))
    p.append(prim("cyl", HULL, loc=(0, 0, 0.12), radius=0.15, radius2=0.4, depth=0.18, verts=14))
    p.append(prim("cyl", MID, loc=(0, 0, 0.14), radius=0.05, depth=0.2, verts=6))
    p.append(prim("sphere", CYAN, loc=(0, 0, 0.25), radius=0.08, verts=8))
    return p


def shield_generator():
    """Generador de escudo (fase 6): base oscura, emisor blanco con un anillo cian y tres aletas
    naranjas. Centrado; se apoya por abajo (-Z)."""
    p = [prim("cyl", DARK, loc=(0, 0, -0.14), radius=0.33, depth=0.06, verts=14, bevel=0.02, segs=1)]
    p.append(prim("cyl", HULL, loc=(0, 0, -0.07), radius=0.27, radius2=0.22, depth=0.09, verts=14, bevel=0.015, segs=1))
    p.append(prim("cyl", CYAN, loc=(0, 0, -0.01), radius=0.235, depth=0.035, verts=16))
    p.append(prim("sphere", HULL, size=(1, 1, 0.75), loc=(0, 0, 0.03), radius=0.18, verts=12))
    p.append(prim("cyl", MID, loc=(0, 0, 0.12), radius=0.035, depth=0.1, verts=6))
    p.append(prim("sphere", CYAN, loc=(0, 0, 0.18), radius=0.055, verts=8))
    for k in range(3):
        a = math.radians(90 + k * 120)
        p.append(prim("box", ORANGE, size=(0.05, 0.13, 0.08), loc=(math.cos(a) * 0.29, math.sin(a) * 0.29, -0.08),
                      rot=(0, 0, math.degrees(a) + 90), bevel=0.01, segs=1))
    return p


def thruster_large():
    """Propulsor grande: tobera ancha con tres aros. Se acopla por delante (+Y)."""
    p = [prim("cyl", HULL, rot=(90, 0, 0), radius=0.56, depth=0.62, verts=16, bevel=0.12, segs=1)]
    for y, mat in ((0.16, ORANGE), (0.0, DARK), (-0.16, ORANGE)):
        p.append(prim("cyl", mat, rot=(90, 0, 0), loc=(0, y, 0), radius=0.575, depth=0.06, verts=16))
    p.append(prim("cyl", DARK, rot=(90, 0, 0), loc=(0, -0.52, 0), radius=0.38, radius2=0.53, depth=0.44, verts=16))
    p.append(prim("cyl", CYAN, rot=(90, 0, 0), loc=(0, -0.75, 0), radius=0.45, depth=0.03, verts=16))
    p += coupler((0, 0.31, 0), "y")
    return p


def particle_cannon():
    """Cañón de partículas: cañón largo con bobinas violetas. Dispara hacia +Y."""
    p = [prim("box", DARK, size=(0.3, 0.42, 0.26), loc=(0, 0.21, 0), bevel=0.06, segs=1)]
    p.append(prim("cyl", MID, rot=(90, 0, 0), loc=(0, 0.75, 0.02), radius=0.07, depth=0.8, verts=10))
    for y in (0.5, 0.7, 0.9):
        p.append(prim("cyl", VIOLET, rot=(90, 0, 0), loc=(0, y, 0.02), radius=0.11, depth=0.05, verts=10))
    p.append(prim("cyl", DARK, rot=(90, 0, 0), loc=(0, 1.18, 0.02), radius=0.1, radius2=0.06, depth=0.08, verts=10))
    return p


def flak_cannon():
    """Escopeta de fragmentos: bloque ancho con cinco cañones cortos en abanico."""
    p = [prim("box", DARK, size=(0.44, 0.36, 0.26), loc=(0, 0.18, 0), bevel=0.06, segs=1)]
    p.append(prim("box", ORANGE, size=(0.46, 0.06, 0.04), loc=(0, 0.1, 0.13)))
    for i, a in enumerate((-20, -10, 0, 10, 20)):
        d = Vector((math.sin(math.radians(a)), math.cos(math.radians(a)), 0))
        p.append(prim("cyl", MID, rot=(90, 0, -a), loc=tuple(Vector((0, 0.36, 0.02)) + d * 0.2), radius=0.045,
                      depth=0.36, verts=8))
    return p


# ---------- edificios de la base (fase 4) ----------
# Origen = centro del suelo; el frente (+Y) mira a la plataforma de aterrizaje. Caben en una
# parcela de unos 4 m de diámetro.
def hangar():
    """Hangar: nave medio cilíndrica con un gran portón y una plataforma delante."""
    p = [prim("cyl", HULL, rot=(90, 0, 0), loc=(0, -0.35, 0), radius=1.45, depth=2.9, verts=18, bevel=0.06, segs=1)]
    for y in (-1.75, -0.8, 0.15, 1.05):
        p.append(prim("cyl", DARK, rot=(90, 0, 0), loc=(0, y, 0), radius=1.5, depth=0.1, verts=18))
    p.append(prim("box", DARK, size=(1.9, 0.06, 1.15), loc=(0, 1.13, 0.58), bevel=0.04, segs=1))
    for z in (0.4, 0.8):
        p.append(prim("box", ORANGE, size=(1.95, 0.08, 0.06), loc=(0, 1.15, z)))
    p.append(prim("box", MID, size=(0.5, 0.8, 0.5), loc=(1.25, 0.4, 0.25), bevel=0.08, segs=1))
    p.append(prim("cyl", DARK, loc=(0, 1.75, 0.02), radius=0.75, depth=0.05, verts=16))
    p.append(prim("cyl", CYAN, loc=(0, 1.75, 0.03), radius=0.12, depth=0.05, verts=10))
    for a in range(0, 360, 60):
        d = Vector((math.cos(math.radians(a)), math.sin(math.radians(a)), 0))
        p.append(prim("sphere", CYAN, loc=tuple(Vector((0, 1.75, 0.06)) + d * 0.62), radius=0.05, verts=6))
    p.append(prim("sphere", CYAN, loc=(0, -0.35, 1.5), radius=0.08, verts=8))
    return p


def research_center():
    """Centro de investigación: cúpula de laboratorio con antena y paneles."""
    p = [prim("cyl", HULL, loc=(0, 0, 0.35), radius=1.25, depth=0.7, verts=18, bevel=0.08, segs=1)]
    p.append(prim("sphere", HULL, size=(1, 1, 0.72), loc=(0, 0, 0.7), radius=1.1, verts=18))
    p.append(prim("cyl", GLASS, loc=(0, 0, 0.62), radius=1.27, depth=0.16, verts=18))
    p.append(prim("cyl", ORANGE, loc=(0, 0, 0.08), radius=1.28, depth=0.08, verts=18))
    p.append(prim("box", GLASS, size=(0.7, 0.06, 0.45), loc=(0, 1.24, 0.35), bevel=0.03, segs=1))
    # antena con plato
    p.append(prim("cyl", MID, loc=(-0.95, -0.75, 1.0), radius=0.05, depth=1.4, verts=6))
    p.append(prim("cyl", HULL, loc=(-0.95, -0.75, 1.75), rot=(25, 0, 0), radius=0.05, radius2=0.4, depth=0.18, verts=12))
    p.append(prim("sphere", CYAN, loc=(-0.95, -0.75, 1.85), radius=0.06, verts=6))
    # paneles de datos
    for x in (0.9, 1.25):
        p.append(prim("box", DARK, size=(0.28, 0.06, 0.5), loc=(x, 0.95, 0.3), rot=(0, 0, -35)))
        p.append(prim("box", CYAN, size=(0.2, 0.07, 0.3), loc=(x, 0.95, 0.35), rot=(0, 0, -35)))
    return p


def telescope():
    """Telescopio que lleva el centro de investigación en un satélite (GDD 7.3)."""
    p = [prim("cyl", MID, loc=(0, 0, 0.1), radius=0.32, depth=0.2, verts=12)]
    p.append(prim("box", DARK, size=(0.12, 0.3, 0.45), loc=(0, 0, 0.4)))
    p.append(prim("cyl", HULL, rot=(-50, 0, 0), loc=(0, 0.25, 0.75), radius=0.2, depth=1.3, verts=12, bevel=0.03, segs=1))
    p.append(prim("cyl", ORANGE, rot=(-50, 0, 0), loc=(0, 0.1, 0.62), radius=0.215, depth=0.08, verts=12))
    p.append(prim("cyl", GLASS, rot=(-50, 0, 0), loc=(0, 0.75, 1.17), radius=0.17, depth=0.04, verts=12))
    return p


def refinery():
    """Refinería: tanques, chimeneas y tuberías, con un horno que brilla en naranja."""
    p = [prim("box", MID, size=(1.5, 1.0, 1.0), loc=(0, 0.55, 0.5), bevel=0.1, segs=1)]
    p.append(prim("box", G_ORANGE, size=(0.8, 0.05, 0.35), loc=(0, 1.06, 0.45), bevel=0.02, segs=1))
    for x, y, r, h in ((-0.85, -0.6, 0.55, 1.7), (0.55, -0.75, 0.48, 1.4)):
        p.append(prim("cyl", HULL, loc=(x, y, h / 2), radius=r, depth=h, verts=14, bevel=0.06, segs=1))
        p.append(prim("sphere", HULL, size=(1, 1, 0.5), loc=(x, y, h), radius=r, verts=14))
        for z in (h * 0.3, h * 0.7):
            p.append(prim("cyl", ORANGE, loc=(x, y, z), radius=r + 0.02, depth=0.08, verts=14))
    for x, h in ((1.15, 2.4), (1.15 - 0.42, 2.0)):
        p.append(prim("cyl", DARK, loc=(x, 0.45, h / 2), radius=0.16, depth=h, verts=10))
        p.append(prim("cyl", G_ORANGE, loc=(x, 0.45, h + 0.02), radius=0.13, depth=0.05, verts=10))
    p.append(prim("cyl", DARK, rot=(0, 90, 0), loc=(-0.15, -0.2, 1.1), radius=0.08, depth=1.4, verts=8))
    p.append(prim("cyl", DARK, rot=(90, 0, 0), loc=(-0.85, 0.0, 0.9), radius=0.08, depth=1.0, verts=8))
    return p


def mine():
    """Mina: torre de perforación con un taladro y una cinta transportadora."""
    p = []
    for sx in (-1, 1):
        for sy in (-1, 1):
            p.append(prim("box", MID, size=(0.12, 0.12, 2.9), loc=(sx * 0.42, sy * 0.42 - 0.3, 1.35),
                          rot=(sy * 9, -sx * 9, 0)))
    for z in (0.7, 1.4, 2.1):
        w = 1.0 - z * 0.22
        p.append(prim("box", ORANGE, size=(w, w, 0.07), loc=(0, -0.3, z)))
    p.append(prim("box", DARK, size=(0.4, 0.4, 0.3), loc=(0, -0.3, 2.85), bevel=0.04, segs=1))
    p.append(prim("sphere", CYAN, loc=(0, -0.3, 3.05), radius=0.08, verts=8))
    p.append(prim("cyl", DARK, loc=(0, -0.3, 0.9), radius=0.12, depth=1.8, verts=10))
    p.append(prim("cyl", G_ORANGE, loc=(0, -0.3, 0.12), radius=0.22, radius2=0.04, depth=0.3, verts=10))
    p.append(prim("cyl", DARK, loc=(0, -0.3, 0.03), radius=0.75, depth=0.06, verts=14))
    p.append(prim("box", DARK, size=(0.35, 1.6, 0.08), loc=(0.9, 0.55, 0.45), rot=(-22, 0, 0)))
    p.append(prim("sphere", MID, size=(1.2, 1.0, 0.55), loc=(0.9, 1.35, 0.1), radius=0.45, verts=8))
    return p


def academy():
    """Academia: edificio con aulas y un patio con un circuito de entrenamiento."""
    p = [prim("box", HULL, size=(2.1, 1.1, 1.3), loc=(-0.2, -0.6, 0.65), bevel=0.22, segs=2)]
    for x in (-0.9, -0.45, 0.0, 0.45):
        p.append(prim("box", GLASS, size=(0.28, 0.05, 0.4), loc=(x, -0.04, 0.8), bevel=0.02, segs=1))
    p.append(prim("box", ORANGE, size=(2.15, 0.06, 0.1), loc=(-0.2, -0.03, 0.35)))
    p.append(prim("sphere", GLASS, size=(1, 1, 0.6), loc=(-0.7, -0.6, 1.3), radius=0.45, verts=12))
    # patio: pista de entrenamiento y bandera
    p.append(prim("cyl", DARK, loc=(0.55, 0.85, 0.02), radius=0.85, depth=0.04, verts=18))
    p.append(prim("cyl", ORANGE, loc=(0.55, 0.85, 0.03), radius=0.65, depth=0.045, verts=18))
    p.append(prim("cyl", DARK, loc=(0.55, 0.85, 0.04), radius=0.55, depth=0.05, verts=18))
    for x, y in ((0.35, 0.75), (0.75, 1.0)):
        p.append(prim("box", MID, size=(0.12, 0.12, 0.35), loc=(x, y, 0.2)))
    p.append(prim("cyl", MID, loc=(1.15, -0.4, 0.9), radius=0.03, depth=1.8, verts=6))
    p.append(prim("box", ORANGE, size=(0.04, 0.45, 0.28), loc=(1.15, -0.18, 1.6)))
    return p


def infirmary():
    """Enfermería: módulo blanco con una cruz cian y camillas a la vista bajo un techo de cristal."""
    p = [prim("box", HULL, size=(1.9, 1.3, 1.1), loc=(0, -0.45, 0.55), bevel=0.3, segs=2)]
    for z, size in ((1.12, (0.75, 0.22, 0.06)), (1.12, (0.22, 0.75, 0.06))):
        p.append(prim("box", CYAN, size=size, loc=(0, -0.45, z)))
    p.append(prim("box", CYAN, size=(0.45, 0.06, 0.13), loc=(0, 0.21, 0.75)))
    p.append(prim("box", CYAN, size=(0.13, 0.06, 0.45), loc=(0, 0.21, 0.75)))
    # anexo con camillas
    p.append(prim("box", HULL, size=(1.6, 0.9, 0.1), loc=(0, 0.75, 0.05), bevel=0.03, segs=1))
    p.append(prim("box", GLASS, size=(1.6, 0.9, 0.06), loc=(0, 0.75, 0.75), bevel=0.03, segs=1))
    for x in (-0.55, 0.55):
        p.append(prim("box", MID, size=(0.06, 0.06, 0.7), loc=(x, 1.15, 0.4)))
    for x in (-0.4, 0.4):
        p.append(prim("box", HULL, size=(0.35, 0.7, 0.12), loc=(x, 0.75, 0.3), bevel=0.04, segs=1))
        p.append(prim("box", CYAN, size=(0.3, 0.2, 0.05), loc=(x, 0.5, 0.38)))
    return p


def trade_port():
    """Puerto comercial: plataforma con contenedores apilados y una grúa."""
    p = [prim("cyl", DARK, loc=(0, 0, 0.04), radius=1.6, depth=0.08, verts=18)]
    p.append(prim("cyl", ORANGE, loc=(0, 0, 0.05), radius=1.62, depth=0.07, verts=18))
    p.append(prim("cyl", DARK, loc=(0, 0, 0.06), radius=1.5, depth=0.08, verts=18))
    boxes = [((-0.7, -0.5, 0.33), ORANGE), ((-0.7, 0.25, 0.33), MID), ((-0.7, -0.12, 0.88), HULL),
             ((0.1, -0.85, 0.33), HULL), ((0.6, 0.6, 0.33), ORANGE)]
    for (x, y, z), mat in boxes:
        p.append(prim("box", mat, size=(0.55, 0.7, 0.55), loc=(x, y, z), bevel=0.03, segs=1))
        p.append(prim("box", DARK, size=(0.57, 0.04, 0.5), loc=(x, y, z)))
    p.append(prim("box", MID, size=(0.18, 0.18, 2.6), loc=(0.95, -0.55, 1.3)))
    p.append(prim("box", ORANGE, size=(0.12, 1.9, 0.14), loc=(0.95, 0.1, 2.55)))
    p.append(prim("cyl", DARK, loc=(0.95, 0.85, 2.05), radius=0.015, depth=0.95, verts=4))
    p.append(prim("box", DARK, size=(0.3, 0.3, 0.08), loc=(0.95, 0.85, 1.55)))
    p.append(prim("sphere", CYAN, loc=(0.95, -0.55, 2.66), radius=0.07, verts=6))
    return p


def fuel_charger():
    """Cargador de combustible: tres torres con anillos de energía cian alrededor de un tanque."""
    p = [prim("cyl", MID, loc=(0, 0, 0.1), radius=1.2, depth=0.2, verts=18, bevel=0.04, segs=1)]
    p.append(prim("sphere", HULL, size=(1, 1, 0.85), loc=(0, 0, 0.6), radius=0.55, verts=14))
    p.append(prim("cyl", ORANGE, loc=(0, 0, 0.55), radius=0.57, depth=0.08, verts=14))
    p.append(prim("sphere", CYAN, loc=(0, 0, 1.12), radius=0.16, verts=8))
    for a in (90, 210, 330):
        d = Vector((math.cos(math.radians(a)), math.sin(math.radians(a)), 0)) * 0.95
        p.append(prim("cyl", DARK, loc=tuple(d + Vector((0, 0, 1.1))), radius=0.11, depth=2.2, verts=8))
        for z in (0.8, 1.35, 1.9):
            p.append(prim("cyl", CYAN, loc=tuple(d + Vector((0, 0, z))), radius=0.24, depth=0.06, verts=12))
        p.append(prim("sphere", CYAN, loc=tuple(d + Vector((0, 0, 2.25))), radius=0.1, verts=6))
    return p


def landing_pad():
    """Plataforma de aterrizaje del centro de la base, donde se posa la nave."""
    p = [prim("cyl", DARK, loc=(0, 0, 0.06), radius=2.3, depth=0.12, verts=24, bevel=0.03, segs=1)]
    p.append(prim("cyl", MID, loc=(0, 0, 0.07), radius=2.0, depth=0.13, verts=24))
    for x in (-0.55, 0.55):
        p.append(prim("box", ORANGE, size=(0.16, 1.4, 0.02), loc=(x, 0, 0.14)))
    p.append(prim("box", ORANGE, size=(1.1, 0.16, 0.02), loc=(0, 0, 0.14)))
    for i in range(16):
        a = math.radians(i * 360.0 / 16)
        p.append(prim("box", CYAN, size=(0.18, 0.08, 0.05), loc=(math.cos(a) * 2.15, math.sin(a) * 2.15, 0.13),
                      rot=(0, 0, math.degrees(a) + 90)))
    return p


BUILDINGS = {
    "hangar": hangar,
    "research_center": research_center,
    "telescope": telescope,
    "refinery": refinery,
    "mine": mine,
    "academy": academy,
    "infirmary": infirmary,
    "trade_port": trade_port,
    "fuel_charger": fuel_charger,
    "landing_pad": landing_pad,
}


ENEMIES = {
    "enemy_swarm": enemy_swarm,
    "enemy_gunner": enemy_gunner,
    "enemy_tank": enemy_tank,
    "enemy_lancer": enemy_lancer,
    "enemy_splitter": enemy_splitter,
    "enemy_mine_layer": enemy_mine_layer,
    "boss_dreadnought": boss_dreadnought,
}


PARTS = {
    "core": core,
    "command_station": command_station,
    "machine_gun": machine_gun,
    "thruster_small": thruster_small,
    "corridor_1x1": lambda: corridor(1),
    "corridor_1x2": lambda: corridor(2),
    "corridor_1x3": lambda: corridor(3),
    "armor_plate": armor_plate,
    "crew_quarters_small": lambda: crew_quarters(1),
    "crew_quarters_medium": lambda: crew_quarters(2),
    "thruster_medium": thruster_medium,
    "scrap_magnet": scrap_magnet,
    "interstellar_fuel_tank": interstellar_fuel_tank,
    "rocket_launcher": rocket_launcher,
    "laser": laser,
    "twin_machine_gun": twin_machine_gun,
    "tsar_launcher": tsar_launcher,
    "positron_cannon": positron_cannon,
    "library": lambda: crew_room("library"),
    "mess_hall": lambda: crew_room("mess_hall"),
    "kitchen": lambda: crew_room("kitchen"),
    "recreation_room": lambda: crew_room("recreation_room"),
    "crew_quarters_large": lambda: crew_quarters(3),
    "armor_plate_heavy": armor_plate_heavy,
    "scrap_magnet_large": scrap_magnet_large,
    "thruster_large": thruster_large,
    "particle_cannon": particle_cannon,
    "flak_cannon": flak_cannon,
    "shield_generator": shield_generator,
}


def export_glb(obj, path):
    for o in bpy.context.scene.objects:
        o.select_set(False)
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.export_scene.gltf(filepath=path, export_format='GLB', use_selection=True,
                              export_apply=True, export_yup=True)


# ---------- render de vista previa ----------
def setup_render():
    scene = bpy.context.scene
    engines = [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items]
    scene.render.engine = next((e for e in ("BLENDER_EEVEE", "BLENDER_EEVEE_NEXT") if e in engines), "BLENDER_WORKBENCH")
    scene.render.resolution_x, scene.render.resolution_y = 1280, 720
    scene.view_settings.view_transform = "Standard"
    world = bpy.data.worlds.new("space")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.015, 0.02, 0.035, 1)
    world.node_tree.nodes["Background"].inputs["Strength"].default_value = 1.0
    scene.world = world
    sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
    sun.data.energy = 3.5
    sun.rotation_euler = (math.radians(40), math.radians(-25), math.radians(30))
    scene.collection.objects.link(sun)
    fill = bpy.data.objects.new("fill", bpy.data.lights.new("fill", "SUN"))
    fill.data.energy = 0.8
    fill.rotation_euler = (math.radians(-60), math.radians(30), math.radians(200))
    scene.collection.objects.link(fill)
    return scene


def render_view(scene, path, loc, target, ortho=None, lens=50):
    cam_data = bpy.data.cameras.new("cam")
    if ortho:
        cam_data.type = "ORTHO"
        cam_data.ortho_scale = ortho
    else:
        cam_data.lens = lens
    cam = bpy.data.objects.new("cam", cam_data)
    scene.collection.objects.link(cam)
    cam.location = loc
    direction = Vector(target) - Vector(loc)
    cam.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    scene.camera = cam
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    bpy.data.objects.remove(cam)


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    mats = build_materials()
    objs = {}
    for name, fn in PARTS.items():
        obj = make_part(name, fn(), mats)
        export_glb(obj, os.path.join(PARTS_DIR, name + ".glb"))
        objs[name] = obj
        print("exported", name)
    enemy_dir = os.path.join(PROJECT, "assets", "models", "enemies")
    os.makedirs(enemy_dir, exist_ok=True)
    enemies = {}
    for name, fn in ENEMIES.items():
        obj = make_part(name, fn(), mats)
        export_glb(obj, os.path.join(enemy_dir, name + ".glb"))
        enemies[name] = obj
        print("exported", name)
    building_dir = os.path.join(PROJECT, "assets", "models", "buildings")
    os.makedirs(building_dir, exist_ok=True)
    buildings = {}
    for name, fn in BUILDINGS.items():
        obj = make_part(name, fn(), mats)
        export_glb(obj, os.path.join(building_dir, name + ".glb"))
        buildings[name] = obj
        print("exported", name)

    if not RENDER_DIR:
        return
    os.makedirs(RENDER_DIR, exist_ok=True)
    scene = setup_render()

    # 1) Nave inicial montada: núcleo + estación de mando con metralleta + propulsor pequeño
    for o in list(objs.values()) + list(enemies.values()) + list(buildings.values()):
        o.hide_render = True
    ship =["core", "command_station", "machine_gun", "thruster_small"]
    objs["core"].location = (0, 0, 0)
    objs["command_station"].location = (0, 1.22, 0)
    objs["machine_gun"].location = (0, 1.66, 0.02)
    objs["thruster_small"].location = (0, -0.98, 0)
    for n in ship:
        objs[n].hide_render = False
    render_view(scene, os.path.join(RENDER_DIR, "ship_top.png"), (0, 0.4, 12), (0, 0.4, 0), ortho=8.5)
    render_view(scene, os.path.join(RENDER_DIR, "ship_34.png"), (4.2, -3.6, 3.6), (0, 0.3, 0), lens=55)

    # 2) Todas las piezas en fila
    x = -6.0
    for n in ["corridor_1x1", "corridor_1x2", "corridor_1x3", "armor_plate", "core", "command_station", "machine_gun", "thruster_small"]:
        objs[n].hide_render = False
        objs[n].location = (x, 0, 0)
        x += 1.75
    objs["machine_gun"].location.y -= 0.5
    render_view(scene, os.path.join(RENDER_DIR, "parts_lineup.png"), (0.1, -10.5, 6.5), (0.1, 0, 0), lens=30)

    # 2b) Piezas de la fase 2
    for o in objs.values():
        o.hide_render = True
    x = -6.0
    for n in ["crew_quarters_small", "crew_quarters_medium", "thruster_medium", "scrap_magnet",
              "interstellar_fuel_tank", "rocket_launcher", "laser"]:
        objs[n].hide_render = False
        objs[n].location = (x, 0, 0)
        x += 2.0
    render_view(scene, os.path.join(RENDER_DIR, "parts_lineup2.png"), (0.0, -10.5, 6.5), (0.0, 0, 0), lens=30)

    # 2c) Evoluciones de armas (fase 3)
    for o in objs.values():
        o.hide_render = True
    for i, n in enumerate(["machine_gun", "twin_machine_gun", "rocket_launcher", "tsar_launcher", "laser",
                           "positron_cannon"]):
        objs[n].hide_render = False
        objs[n].location = (-2.5 + i * 1.0, 0, 0)
    render_view(scene, os.path.join(RENDER_DIR, "weapons_evolutions.png"), (0.0, -3.6, 2.6), (0.0, 0.4, 0), lens=35)

    # 3) Enemigos
    for o in objs.values():
        o.hide_render = True
    for o in enemies.values():
        o.hide_render = True
    for i, n in enumerate(["enemy_swarm", "enemy_gunner", "enemy_tank"]):
        enemies[n].hide_render = False
        enemies[n].location = (-3.0 + i * 3.0, 0, 0)
    render_view(scene, os.path.join(RENDER_DIR, "enemies_lineup.png"), (0, -7.5, 5.0), (0, 0, 0), lens=40)

    # 3b) Enemigos de zonas lejanas y jefe (fase 3)
    for o in enemies.values():
        o.hide_render = True
    for i, n in enumerate(["enemy_lancer", "enemy_splitter", "enemy_mine_layer"]):
        enemies[n].hide_render = False
        enemies[n].location = (-3.2 + i * 3.2, 0, 0)
    render_view(scene, os.path.join(RENDER_DIR, "enemies_far.png"), (0, -7.0, 5.5), (0, 0, 0), lens=40)
    for o in enemies.values():
        o.hide_render = True
    enemies["boss_dreadnought"].hide_render = False
    enemies["boss_dreadnought"].location = (0, 0, 0)
    render_view(scene, os.path.join(RENDER_DIR, "boss_34.png"), (7.0, -9.0, 8.0), (0, 0.3, 0), lens=40)
    render_view(scene, os.path.join(RENDER_DIR, "boss_top.png"), (0, 0.4, 20), (0, 0.4, 0), ortho=10.0)

    # 4) Fase 4: edificios de la base y piezas que se investigan
    for o in enemies.values():
        o.hide_render = True
    names = ["hangar", "research_center", "refinery", "mine", "academy", "infirmary", "trade_port", "fuel_charger"]
    for i, n in enumerate(names):
        buildings[n].hide_render = False
        buildings[n].location = ((i % 4) * 4.4 - 6.6, (i // 4) * -4.6 + 2.3, 0)
    buildings["telescope"].hide_render = False
    buildings["telescope"].location = buildings["research_center"].location + Vector((0, 0, 1.45))
    render_view(scene, os.path.join(RENDER_DIR, "buildings.png"), (0, -17, 13), (0, 0, 0.6), lens=32)
    for o in buildings.values():
        o.hide_render = True
    new_parts = ["library", "mess_hall", "kitchen", "recreation_room", "crew_quarters_large", "armor_plate_heavy",
                 "scrap_magnet_large", "thruster_large", "particle_cannon", "flak_cannon"]
    for i, n in enumerate(new_parts):
        objs[n].hide_render = False
        objs[n].location = ((i % 5) * 1.9 - 3.8, (i // 5) * -2.6 + 1.3, 0)
    render_view(scene, os.path.join(RENDER_DIR, "parts_phase4.png"), (0, -9.5, 7.5), (0, 0, 0), lens=32)

    # 5) Fase 6: generador de escudo sobre el núcleo
    for o in objs.values():
        o.hide_render = True
    objs["core"].hide_render = False
    objs["core"].location = (0, 0, 0)
    objs["shield_generator"].hide_render = False
    objs["shield_generator"].location = (0, 0, 0.5 + 0.17)
    render_view(scene, os.path.join(RENDER_DIR, "shield_generator.png"), (2.6, -2.8, 2.4), (0, 0, 0.4), lens=50)

    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(PROJECT, "tools", "blender", "parts.blend"))


main()
