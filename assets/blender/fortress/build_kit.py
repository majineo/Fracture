# Kit de forteresse (v0.5.1) : modules de décor modélisés pour remplacer la greybox des tuiles.
# Usage (Blender) : runpy.run_path(".../assets/blender/fortress/build_kit.py")
# Conventions : 1 unité = 1 stud ; origine en bas au centre ; longueur des murs selon X,
# épaisseur selon Y, hauteur selon Z. Une pièce exportée par matériau (suffixe du nom).
# Sorties : assets/blender/fortress/<Module>.fbx et fortress_kit.blend (copie).
import math
import os
import random
import runpy

import bpy

HERE = os.path.dirname(os.path.abspath(__file__))
LIB = runpy.run_path(os.path.join(HERE, "..", "lib", "fracture_shapes.py"))
Shapes = LIB["Shapes"]
MATERIALS = LIB["MATERIALS"]
export_by_material = LIB["export_by_material"]

# Matériaux propres au kit (couleurs de base ; le vrai rendu est réglé dans Studio).
NEW = {
    "Pierre": ("Fracture_Pierre", (0.50, 0.48, 0.44)),
    "PierreSombre": ("Fracture_PierreSombre", (0.24, 0.23, 0.22)),
    "Toit": ("Fracture_Toit", (0.42, 0.14, 0.10)),
    "Toile": ("Fracture_Toile", (0.62, 0.54, 0.40)),
}
for key, (name, rgb) in NEW.items():
    MATERIALS[key] = name
    mat = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs[0].default_value = (*rgb, 1)
    bsdf.inputs["Roughness"].default_value = 0.9
for key in ("Bois", "Fer", "Laiton", "Tissu", "Cuir"):
    if bpy.data.materials.get(MATERIALS[key]) is None:
        bpy.data.materials.new(MATERIALS[key])

rng = random.Random(1307)


def fresh(name):
    old = bpy.data.collections.get(name)
    if old:
        for o in list(old.objects):
            bpy.data.objects.remove(o, do_unlink=True)
        bpy.data.collections.remove(old)
    return Shapes(name)


def stone_face(S, prefix, length, height, y, z0, rows, sign, axis="x"):
    """Pierres de taille en saillie sur une face (y = plan de la face, sign = côté).
    axis = "y" : la face longe Y (plan x = y), pour les piliers."""
    course = height / rows
    for r in range(rows):
        x = -length / 2
        offset = (r % 2) * 0.6
        widths = []
        remaining = length + offset
        while remaining > 0.3:
            w = min(remaining, rng.uniform(1.6, 2.4))
            widths.append(w)
            remaining -= w
        x -= offset
        for i, w in enumerate(widths):
            x0 = max(x, -length / 2)
            x1 = min(x + w, length / 2)
            if x1 - x0 > 0.35:
                depth = rng.uniform(0.10, 0.20)
                size = (x1 - x0 - 0.12, depth, course - 0.12)
                loc = ((x0 + x1) / 2, y + sign * depth / 2, z0 + course * (r + 0.5))
                if axis == "y":
                    size = (size[1], size[0], size[2])
                    loc = (loc[1], loc[0], loc[2])
                S.box(f"{prefix}_{r}_{i}", "Pierre", size, loc, bevel=0)
            x += w


def build_wall():
    S = fresh("Kit_Mur")
    L, T, H = 8.0, 4.0, 14.0
    S.box("Coeur", "PierreSombre", (L, T - 0.4, H - 0.6), (0, 0, (H - 0.6) / 2), bevel=0)
    S.box("Socle", "PierreSombre", (L, T + 0.5, 1.2), (0, 0, 0.6), bevel=0.05)
    S.box("Chaperon", "Pierre", (L, T + 0.2, 0.6), (0, 0, H - 0.3), bevel=0.04)
    for sign in (-1, 1):
        stone_face(S, f"P{'a' if sign < 0 else 'b'}", L, H - 1.8, sign * (T - 0.4) / 2, 1.2, 9, sign)
    return "Kit_Mur"


def build_merlon():
    S = fresh("Kit_Creneau")
    S.box("Bloc", "Pierre", (3.0, 1.5, 2.1), (0, 0, 1.05), bevel=0.06)
    S.box("Chapeau", "PierreSombre", (3.2, 1.7, 0.4), (0, 0, 2.3), bevel=0.05)
    return "Kit_Creneau"


def build_pillar():
    S = fresh("Kit_Pilier")
    W, H = 7.0, 18.0
    S.box("Coeur", "PierreSombre", (W - 0.6, W - 0.6, H), (0, 0, H / 2), bevel=0)
    S.box("Socle", "PierreSombre", (W + 0.6, W + 0.6, 1.4), (0, 0, 0.7), bevel=0.05)
    face = W - 0.6
    for sign in (-1, 1):
        stone_face(S, f"Py{sign}", face, H - 2.6, sign * face / 2, 1.4, 11, sign)
        stone_face(S, f"Px{sign}", face, H - 2.6, sign * face / 2, 1.4, 11, sign, axis="y")
    S.box("Corniche", "Pierre", (W + 0.8, W + 0.8, 0.7), (0, 0, H - 0.35), bevel=0.05)
    # Petit toit en pyramide (quatre pans effilés).
    S.box("Toit", "Toit", (W + 0.4, W + 0.4, 2.6), (0, 0, H + 1.3), taper=None, bevel=0)
    roof = bpy.data.objects["Toit"]
    for v in roof.data.vertices:
        if v.co.z > 0:
            v.co.x *= 0.08
            v.co.y *= 0.08
    return "Kit_Pilier"


def build_arch():
    S = fresh("Kit_Linteau")
    span, T = 10.0, 4.0
    S.box("Poutre", "Pierre", (span + 1.0, T, 2.0), (0, 0, 2.0), bevel=0.05)
    S.box("Assise", "PierreSombre", (span + 1.4, T + 0.3, 0.6), (0, 0, 3.3), bevel=0.04)
    S.box("Clef", "Pierre", (1.3, T + 0.5, 2.4), (0, 0, 1.9), taper=None, bevel=0.05)
    for x in (-1, 1):
        S.box(f"Console_{x}", "PierreSombre", (1.2, T + 0.3, 1.0), (x * (span / 2 - 0.2), 0, 0.5), bevel=0.04)
    return "Kit_Linteau"


def build_crate():
    S = fresh("Kit_Caisse")
    X, Y, Z = 3.0, 2.4, 2.4
    S.box("Corps", "Bois", (X - 0.2, Y - 0.2, Z - 0.2), (0, 0, Z / 2), bevel=0)
    # Planches en relief sur les grandes faces.
    for sign in (-1, 1):
        for i in range(4):
            S.box(f"Planche_{sign}_{i}", "Bois", (X - 0.5, 0.08, Z / 4 - 0.1),
                  (0, sign * (Y - 0.2) / 2 + sign * 0.04, Z / 8 + i * Z / 4), bevel=0)
        # Croisillon.
        S.box(f"Croix_{sign}", "Bois", (math.hypot(X, Z) - 0.8, 0.12, 0.32),
              (0, sign * (Y / 2 + 0.02), Z / 2), rot=(0, math.degrees(math.atan2(Z, X)), 0), bevel=0)
    # Arêtes et coins en fer.
    for cx in (-1, 1):
        for cy in (-1, 1):
            S.box(f"Montant_{cx}_{cy}", "Fer", (0.22, 0.22, Z), (cx * (X / 2 - 0.1), cy * (Y / 2 - 0.1), Z / 2), bevel=0)
    for z in (0.12, Z - 0.12):
        S.box(f"Cerclage_{z:.1f}", "Fer", (X + 0.04, Y + 0.04, 0.16), (0, 0, z), bevel=0)
    return "Kit_Caisse"


def build_chest():
    S = fresh("Kit_Coffre")
    X, Y, Z = 3.6, 2.4, 1.6
    S.box("Cuve", "Bois", (X, Y, Z), (0, 0, Z / 2), bevel=0.03)
    # Couvercle bombé : demi-cylindre couché selon X.
    # Les cylindres de la bibliothèque sont orientés selon Y : 90° autour de Z = couchés selon X.
    S.cyl("Couvercle", "Bois", Y / 2, X, (0, 0, Z), rot=(0, 0, 90), verts=12)
    for x in (-X / 2 + 0.3, 0, X / 2 - 0.3):
        S.box(f"Bande_{x:.1f}", "Laiton", (0.22, Y + 0.06, Z + 0.02), (x, 0, Z / 2), bevel=0)
        S.cyl(f"BandeHaut_{x:.1f}", "Laiton", Y / 2 + 0.03, 0.22, (x, 0, Z), rot=(0, 0, 90), verts=12)
    # Moitié basse des demi-cylindres écrasée dans la cuve (couvercle bombé).
    for o in bpy.data.collections["Kit_Coffre"].objects:
        if o.name.startswith("Couvercle") or o.name.startswith("BandeHaut"):
            for v in o.data.vertices:
                if v.co.z < 0:
                    v.co.z = 0
    S.box("Serrure", "Laiton", (0.7, 0.14, 0.8), (0, -Y / 2 - 0.07, Z - 0.1), bevel=0.02)
    S.box("Moraillon", "Fer", (0.24, 0.1, 0.5), (0, -Y / 2 - 0.16, Z - 0.15), bevel=0)
    return "Kit_Coffre"


def build_sack():
    S = fresh("Kit_Sac")
    S.sphere("Panse", "Toile", 1.0, (0, 0, 0.85), scale=(1.0, 0.9, 0.85), detail=2)
    S.box("Col", "Toile", (0.55, 0.5, 0.55), (0, 0, 1.85), taper=None, bevel=0.05)
    S.ring("Lien", "Cuir", 0.36, 0.07, (0, 0, 1.62), seg=12, sides=5)
    S.box("Rabat", "Cuir", (0.9, 0.08, 0.6), (0.2, -0.86, 0.9), rot=(0, 0, 8), bevel=0)
    return "Kit_Sac"


BUILDERS = [build_wall, build_merlon, build_pillar, build_arch, build_crate, build_chest, build_sack]


def main():
    report = {}
    x = 0.0
    for build in BUILDERS:
        name = build()
        coll = bpy.data.collections[name]
        for o in coll.objects:
            o.location.x += x  # rangés côte à côte pour l'aperçu
        parts, tris = export_by_material(name, name, os.path.join(HERE, f"{name}.fbx"),
                                         origin=(x, 0, 0))
        report[name] = (tris, sorted(parts))
        x += 14.0
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(HERE, "fortress_kit.blend"), copy=True)
    return report


RESULT = main()
