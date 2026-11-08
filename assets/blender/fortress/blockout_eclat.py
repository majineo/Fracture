# Maquette grise (blockout) de l'Éclat de forteresse, carte agrandie 7 × 7 (v0.11.0).
# Usage (Blender) : runpy.run_path(".../assets/blender/fortress/blockout_eclat.py",
#                                  init_globals={"LAYOUT": "build/layout_42.json"})
# Le plan vient du jeu : `lune run tools/export_layout 42` (EclatLayout + Districts). Ce script
# reproduit la logique de Server/Place/Lib/TileKit (mêmes cotes) en blocs gris colorés par rôle,
# et ajoute une couche « Points de jeu » (butin, Échoués, extraction, autels, apparitions, trône).
# Repère : 1 unité Blender = 1 stud ; Roblox (x, y, z) → Blender (x, -z, y).
import json
import math
import os

import bmesh
import bpy
from mathutils import Matrix, Vector

ROOT = r"C:\Users\neost\Documents\Fracture"
LAYOUT = globals().get("LAYOUT", "build/layout_42.json")
HALF = 48
ROW_END = 40

COLORS = {
    "rue": (0.48, 0.46, 0.43),
    "Slate": (0.64, 0.62, 0.58),
    "Cobblestone": (0.54, 0.51, 0.47),
    "Grass": (0.32, 0.42, 0.27),
    "Ground": (0.42, 0.36, 0.27),
    "Basalt": (0.29, 0.27, 0.28),
    "WoodPlanks": (0.47, 0.34, 0.22),
    "roche": (0.22, 0.21, 0.22),
    "mur": (0.45, 0.46, 0.5),
    "rempart": (0.42, 0.43, 0.47),
    "porte": (0.33, 0.33, 0.34),
    "tourelle": (0.36, 0.36, 0.38),
    "donjon": (0.4, 0.42, 0.48),
    "maison": (0.86, 0.8, 0.68),
    "corps": (0.36, 0.36, 0.37),
    "bois": (0.47, 0.34, 0.22),
    "laiton": (0.69, 0.5, 0.23),
    "cyan": (0.31, 0.9, 1.0),
    "violet": (0.59, 0.35, 0.94),
    "tissu": (0.55, 0.13, 0.14),
    "eau": (0.18, 0.38, 0.44),
    "escalier": (0.7, 0.67, 0.6),
    # Points de jeu
    "butin": (1.0, 0.82, 0.2),
    "poste": (0.9, 0.15, 0.12),
    "extraction": (0.2, 0.95, 1.0),
    "autel": (0.75, 0.4, 1.0),
    "apparition": (0.3, 0.95, 0.35),
    "trone": (1.0, 0.5, 0.1),
}

MODULE_COLOR = {
    "Fort_Donjon": "donjon", "Fort_TourGuet": "mur", "Fort_Maison": "maison",
    "Fort_GrandeMaison": "maison", "Fort_Corps": "corps", "Fort_Mur": "mur", "Fort_Porte": "porte",
    "Fort_Rempart": "rempart", "Fort_Tourelle": "tourelle", "Fort_Trebuchet": "bois",
    "Fort_Belier": "bois", "Fort_Barricade": "bois", "Fort_Chaudiere": "laiton",
    "Fort_Horloge": "laiton", "Fort_Cloche": "laiton", "Fort_Puits": "Slate",
    "Fort_Ratelier": "bois", "Fort_Sarcophage": "maison", "Fort_Cristal": "cyan",
    "Fort_Etendard": "tissu", "Kit_Caisse": "bois", "Kit_Coffre": "bois", "Fort_Eboulis": "porte",
}


def material(key):
    name = "Maquette_" + key
    mat = bpy.data.materials.get(name)
    if mat is None:
        mat = bpy.data.materials.new(name)
        # Couleurs notées en sRGB : Blender travaille en linéaire.
        color = tuple(c ** 2.2 for c in COLORS[key])
        mat.diffuse_color = (*color, 1)
        mat.use_nodes = True
        bsdf = next((n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
        if bsdf:
            bsdf.inputs["Base Color"].default_value = (*color, 1)
            bsdf.inputs["Roughness"].default_value = 0.85
            if key in ("cyan", "violet", "extraction", "autel"):
                for socket in ("Emission Color", "Emission"):
                    if socket in bsdf.inputs:
                        bsdf.inputs[socket].default_value = (*color, 1)
                if "Emission Strength" in bsdf.inputs:
                    bsdf.inputs["Emission Strength"].default_value = 2.0
    return mat


def collection(name, parent=None):
    coll = bpy.data.collections.get(name)
    if coll is None:
        coll = bpy.data.collections.new(name)
        (parent or bpy.context.scene.collection).children.link(coll)
    return coll


def clear(name):
    coll = bpy.data.collections.get(name)
    if coll is None:
        return
    for child in list(coll.children):
        clear(child.name)
    for obj in list(coll.objects):
        bpy.data.objects.remove(obj, do_unlink=True)
    bpy.data.collections.remove(coll)


# Repères (comme les CFrame Roblox, limités aux rotations autour de Y) -------------------------
class Frame:
    def __init__(self, x=0.0, z=0.0, yaw=0.0, y=0.0):
        self.x, self.y, self.z, self.yaw = x, y, z, yaw

    def point(self, lx, ly, lz):
        # CFrame.Angles(0, yaw, 0) appliqué à (lx, 0, lz)
        c, s = math.cos(self.yaw), math.sin(self.yaw)
        return (self.x + lx * c + lz * s, self.y + ly, self.z - lx * s + lz * c)

    def child(self, lx, lz, yaw=0.0, ly=0.0):
        x, y, z = self.point(lx, ly, lz)
        return Frame(x, z, self.yaw + yaw, y)


def to_blender(x, y, z):
    return Vector((x, -z, y))


def box(coll, name, size, frame, x, y, z, color, yaw=0.0):
    """Bloc de taille (w, h, d), base au sol en (x, y, z) du repère `frame` (comme TileKit.block)."""
    w, h, d = size
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=(w, d, h), verts=bm.verts)
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    obj.data.materials.append(material(color))
    px, py, pz = frame.point(x, y + h / 2, z)
    obj.matrix_world = Matrix.Translation(to_blender(px, py, pz)) @ Matrix.Rotation(frame.yaw + yaw, 4, "Z")
    coll.objects.link(obj)
    return obj


def wedge(coll, name, frame, x, z, yaw, rise, run, width, y=0.0):
    """Escalier de maquette : rampe pleine qui monte de `rise` sur `run`, vers -Z local."""
    bm = bmesh.new()
    w, r = width / 2, run / 2
    v = [bm.verts.new(c) for c in (
        (-w, r, 0), (w, r, 0), (w, -r, 0), (-w, -r, 0), (-w, -r, rise), (w, -r, rise))]
    # Blender local : Y = -Z Roblox ; monter vers -Z Roblox = vers +Y Blender
    for f in ((0, 1, 2, 3), (3, 2, 5, 4), (0, 4, 5, 1), (0, 3, 4), (1, 5, 2)):
        bm.faces.new([v[i] for i in f])
    for vert in bm.verts:
        vert.co.y = -vert.co.y
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    obj.data.materials.append(material("escalier"))
    px, py, pz = frame.point(x, y, z)
    obj.matrix_world = Matrix.Translation(to_blender(px, py, pz)) @ Matrix.Rotation(frame.yaw + yaw, 4, "Z")
    coll.objects.link(obj)
    return obj


def marker(coll, name, frame, spot, key, radius=1.2, height=0.0):
    px, py, pz = frame.point(spot["x"], spot["y"], spot["z"])
    bpy.ops.mesh.primitive_uv_sphere_add(segments=12, ring_count=6, radius=radius,
                                         location=to_blender(px, py + radius + height, pz))
    obj = bpy.context.active_object
    obj.name = name
    obj.data.materials.append(material(key))
    for c in obj.users_collection:
        c.objects.unlink(obj)
    coll.objects.link(obj)
    return obj


# Construction ------------------------------------------------------------------------------
def module(coll, data, frame, name, x, y, z, yaw, sx=1.0, solid=True):
    m = data["modules"][name]
    color = MODULE_COLOR.get(name, "mur")
    if name == "Fort_Porte":
        box(coll, name, (m["w"] * sx, 3, m["d"] + 0.4), frame, x, y + m["h"] - 3, z, color, yaw)
        return
    if name == "Fort_Etendard":
        box(coll, name + "_Mat", (0.4, m["h"], 0.4), frame, x, y, z, "bois", yaw)
        box(coll, name, (0.1, 4, 2.4), frame, x, y + m["h"] - 5, z + 1.3, color, yaw)
        return
    height = m.get("roof") or m["h"]
    box(coll, name, (m["w"] * sx, height, m["d"]), frame, x, y, z, color, yaw)
    tower = m.get("tower")
    if tower:
        box(coll, name + "_Tour", (tower["w"], tower["h"] - height, tower["d"]), frame, x, y + height, z, color, yaw)


def curtain(coll, data, frame, x0, x1, name):
    length = x1 - x0
    m = data["modules"][name]
    count = max(1, math.floor(length / m["w"] + 0.5))
    width = length / count
    for i in range(count):
        module(coll, data, frame, name, x0 + width * (i + 0.5), 0, 0, 0, width / m["w"])


EDGE_YAW = {"N": 0.0, "W": math.pi / 2, "S": math.pi, "E": -math.pi / 2}


def build_edge(coll, data, center, direction, kind, rng):
    frame = center.child(0, 0, EDGE_YAW[direction]).child(0, -HALF)
    if kind == "Gates":
        curtain(coll, data, frame, -ROW_END, -22, "Fort_Mur")
        curtain(coll, data, frame, -12, 12, "Fort_Mur")
        curtain(coll, data, frame, 22, ROW_END, "Fort_Mur")
        for x in (-17, 17):
            module(coll, data, frame, "Fort_Porte", x, 0, 0, 0)
    elif kind == "Rampart":
        top = data["modules"]["Fort_Rempart"]["h"]
        curtain(coll, data, frame, -ROW_END, -5, "Fort_Rempart")
        curtain(coll, data, frame, 5, ROW_END, "Fort_Rempart")
        module(coll, data, frame, "Fort_Porte", 0, 0, 0, 0)
        wedge(coll, "Escalier_Rempart", frame, -30, 11, 0, top, 16, 6)
        wedge(coll, "Escalier_Rempart", frame, 30, -11, math.pi, top, 16, 6)
    elif kind == "Open":
        for x in (-34, 34):
            box(coll, "Eboulis", (10, 3, 5), frame, x, 0, 0, "porte", x * 0.004)
            box(coll, "Eboulis", (5, 2, 4), frame, x * 0.8, 0, 2, "porte", 0.4)
    else:
        for i in range(8):
            x = -HALF + 6 + i * 12 + (rng.random() - 0.5) * 4
            box(coll, "Bord_Roche", (3 + rng.random() * 4, 0.8 + rng.random() * 1.8, 3), frame, x, 0, 1.5, "roche", rng.random())
        for _ in range(4):
            s = 1.5 + rng.random() * 3.5
            box(coll, "Eclat_Flottant", (s * 1.3, s, s), frame, (rng.random() - 0.5) * 84,
                -6 + rng.random() * 14, -8 - rng.random() * 18, "roche", rng.random() * 6)


def build_tile(root, points, data, tile, rng):
    cx, cz = tile["center"]
    name = f"Tuile_{tile['x']}_{tile['z']}_{tile['kind']}"
    coll = collection(name, root)
    center = Frame(cx, cz)
    inner = Frame(cx, cz, tile["rotation"] * math.pi / 2)
    d = data["districts"][tile["kind"]]
    T = data["tile"]
    # Sol, îlot, roche suspendue
    if d.get("canal"):
        bank = (T - 12) / 2
        box(coll, "Berge", (T, 4, bank), inner, 0, -4, -6 - bank / 2, "rue")
        box(coll, "Berge", (T, 4, bank), inner, 0, -4, 6 + bank / 2, "rue")
        box(coll, "Douve_Fond", (T, 2, 12), inner, 0, -10, 0, "roche")
        box(coll, "Douve_Eau", (T, 4, 12), inner, 0, -8, 0, "eau")
        for side in (-1, 1):
            box(coll, "Douve_Quai", (T, 8, 0.8), inner, 0, -8, side * 6.4, "porte")
        wedge(coll, "Escalier_Douve", inner, -36, 0, 0, 8, 11, 4, -8)
        wedge(coll, "Escalier_Douve", inner, 36, 0, math.pi, 8, 11, 4, -8)
    else:
        box(coll, "Sol", (T, 4, T), center, 0, -4, 0, "rue")
        box(coll, "Ilot", (data["block"] * 2, 0.2, data["block"] * 2), inner, 0, 0, 0, d["ground"] if d["ground"] in COLORS else "Slate")
    box(coll, "Roche", (T - 6, 14, T - 6), center, 0, -18, 0, "roche")
    box(coll, "Roche", (T - 26, 18, T - 26), center, 0, -36, 0, "roche")
    box(coll, "Roche", (T - 50, 14, T - 50), center, 0, -50, 0, "roche")
    for direction in ("N", "E", "S", "W"):
        kind = tile["edges"][direction]
        if direction in ("N", "W") or kind == "Void":
            build_edge(coll, data, center, direction, kind, rng)
    if tile["x"] > 0 and tile["z"] > 0:
        module(coll, data, center, "Fort_Tourelle", -HALF, 0, -HALF, 0)
    for p in d["buildings"]:
        module(coll, data, inner, p["module"], p["x"], p.get("y", 0), p["z"], p.get("turns", 0) * math.pi / 2)
    for p in d["props"]:
        module(coll, data, inner, p["module"], p["x"], p.get("y", 0), p["z"], p.get("turns", 0) * math.pi / 2)
    for s in d["stairs"]:
        wedge(coll, "Escalier", inner, s["x"], s["z"], s["turns"] * math.pi / 2, s["rise"], s["run"], s["width"])
    for s in d["solids"]:
        bottom = s.get("bottom", 0)
        key = s["material"] if s["material"] in COLORS else "Slate"
        if s["top"] > 0:
            box(coll, "Plateforme", (s["w"], s["top"] - bottom, s["d"]), inner, s["x"], bottom, s["z"], key)
        else:
            box(coll, "Pont", (s["w"], 1, s["d"]), inner, s["x"], -1, s["z"], key)
    # Points de jeu
    pc = collection(f"Points_{tile['x']}_{tile['z']}", points)
    for p in d["loot"]:
        marker(pc, "Butin_" + p["table"], inner, p, "butin", 0.9)
    for p in d["posts"]:
        marker(pc, "Poste_" + p["id"], inner, p, "poste", 0.9, 1.5)
    marker(pc, "Extraction", inner, d["extract"], "extraction", 1.6)
    if d.get("altar"):
        marker(pc, "Autel", inner, d["altar"], "autel", 1.2)
    if d.get("spawn"):
        marker(pc, "Apparition", inner, d["spawn"], "apparition", 2.0)
    if d.get("throne"):
        marker(pc, "Trone_Gardien", inner, d["throne"], "trone", 2.0)


def build(path):
    import random
    with open(os.path.join(ROOT, path), encoding="utf-8") as f:
        data = json.load(f)
    clear("Maquette_Eclat")
    root = collection("Maquette_Eclat")
    points = collection("Maquette_Points_de_jeu", root)
    rng = random.Random(data["seed"])
    for tile in data["tiles"]:
        build_tile(root, points, data, tile, rng)
    count = sum(1 for o in bpy.data.collections["Maquette_Eclat"].all_objects)
    return {"seed": data["seed"], "objects": count}


RESULT = build(LAYOUT)
