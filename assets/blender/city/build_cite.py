# Kit de la Cité d'Horlogerie (v0.11.0) — modules steampunk / arcanes de la ville de l'Éclat.
# Usage (Blender) : runpy.run_path(".../assets/blender/city/build_cite.py")
# Repère : 1 unité = 1 stud ; origine en bas au centre ; façade (côté rue) vers -Y (= -Z Roblox) ;
# +Z = haut. Une pièce par matériau à l'export, nommée « <Module>_<Matériau> » : le jeu applique
# couleur et matériau d'après le suffixe (Server/Place/Lib/Kit).
# Style : semi-stylisé, silhouettes lisibles — pierre claire, brique, enduit crème, ardoise bleutée,
# laiton, cuivre vert-de-gris, vitres sombres, touches de néon cyan (énergie des Éclats).
import math
import os
import runpy

import bmesh
import bpy
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__)) if "__file__" in globals() else r"C:\Users\neost\Documents\Fracture\assets\blender\city"
LIB = runpy.run_path(os.path.join(HERE, "..", "lib", "fracture_shapes.py"))
MATERIALS = LIB["MATERIALS"]
# Matériaux propres à la ville (ajoutés à la table commune pour cette session).
EXTRA = {
    "Pierre": ("Cite_Pierre", (0.72, 0.68, 0.6)),
    "Brique": ("Cite_Brique", (0.55, 0.3, 0.22)),
    "Enduit": ("Cite_Enduit", (0.88, 0.82, 0.68)),
    "Ardoise": ("Cite_Ardoise", (0.24, 0.27, 0.38)),
    "Cuivre": ("Cite_Cuivre", (0.35, 0.62, 0.55)),
    "Vitre": ("Cite_Vitre", (0.12, 0.2, 0.28)),
    "Toile": ("Cite_Toile", (0.75, 0.25, 0.2)),
}
for key, (name, color) in EXTRA.items():
    MATERIALS[key] = name
    mat = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1)
    mat.use_nodes = True
    bsdf = next((n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
    if bsdf:
        bsdf.inputs["Base Color"].default_value = (*color, 1)
for key in ("Bois", "Laiton", "Metal", "Noyau", "Fer", "Cristal", "Acier"):
    if bpy.data.materials.get(MATERIALS[key]) is None:
        bpy.data.materials.new(MATERIALS[key])


def fresh(name):
    old = bpy.data.collections.get(name)
    if old:
        for o in list(old.objects):
            bpy.data.objects.remove(o, do_unlink=True)
        bpy.data.collections.remove(old)
    return LIB["Shapes"](name)


def prism(S, name, mat, width, depth, height, loc, rot=(0, 0, 0)):
    """Toit à deux pans (prisme triangulaire) : faîtage le long de X."""
    bm = bmesh.new()
    w, d, h = width / 2, depth / 2, height
    v = [bm.verts.new(c) for c in (
        (-w, -d, 0), (w, -d, 0), (w, d, 0), (-w, d, 0), (-w, 0, h), (w, 0, h))]
    for f in ((0, 1, 5, 4), (2, 3, 4, 5), (0, 4, 3), (1, 2, 5), (0, 3, 2, 1)):
        bm.faces.new([v[i] for i in f])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return S._finish(name, bm, mat, loc, rot, 0)


def mansard(S, name, mat, width, depth, height, inset, loc):
    """Toit mansardé : tronc de pyramide (pente raide, dessus plat)."""
    bm = bmesh.new()
    w, d = width / 2, depth / 2
    bottom = [bm.verts.new(c) for c in ((-w, -d, 0), (w, -d, 0), (w, d, 0), (-w, d, 0))]
    top = [bm.verts.new(c) for c in ((-w + inset, -d + inset, height), (w - inset, -d + inset, height),
                                     (w - inset, d - inset, height), (-w + inset, d - inset, height))]
    for i in range(4):
        j = (i + 1) % 4
        bm.faces.new((bottom[i], bottom[j], top[j], top[i]))
    bm.faces.new(top)
    bm.faces.new(list(reversed(bottom)))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return S._finish(name, bm, mat, loc, (0, 0, 0), 0)


def arch_ring(S, name, mat, r_in, r_out, depth, base, n=14):
    """Demi-anneau vertical (plan XZ) extrudé en Y : arc de pont ou de porte, centré en x = 0."""
    bm = bmesh.new()
    h = depth / 2
    rings = []
    for k in range(n + 1):
        t = math.pi * k / n
        c, si = math.cos(t), math.sin(t)
        rings.append([bm.verts.new((c * r, y, base + si * r)) for r in (r_in, r_out) for y in (-h, h)])
    for k in range(n):
        a, b = rings[k], rings[k + 1]
        # a = [in-, in+, out-, out+]
        bm.faces.new((a[0], b[0], b[2], a[2]))  # face avant (-Y)
        bm.faces.new((a[3], b[3], b[1], a[1]))  # face arrière (+Y)
        bm.faces.new((a[1], b[1], b[0], a[0]))  # intrados
        bm.faces.new((a[2], b[2], b[3], a[3]))  # extrados
    for ring in (rings[0], rings[-1]):
        bm.faces.new((ring[0], ring[2], ring[3], ring[1]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return S._finish(name, bm, mat, (0, 0, 0), (0, 0, 0), 0)


def arched_window(S, prefix, x, y, z, w, h, frame="Laiton", glass="Vitre"):
    """Fenêtre haute à arc (vitre, encadrement, appui) sur une façade orientée -Y en `y`."""
    S.box(f"{prefix}Vitre", glass, (w, 0.12, h), (x, y - 0.02, z + h / 2), bevel=0)
    S.cyl(f"{prefix}VitreArc", glass, w / 2, 0.12, (x, y - 0.02, z + h), verts=10)
    S.box(f"{prefix}Cadre", frame, (w + 0.3, 0.2, 0.18), (x, y - 0.1, z), bevel=0)
    S.box(f"{prefix}Meneau", frame, (0.12, 0.16, h), (x, y - 0.08, z + h / 2), bevel=0)
    S.box(f"{prefix}Traverse", frame, (w, 0.16, 0.12), (x, y - 0.08, z + h * 0.6), bevel=0)


# --------------------------------------------------------------------------------------------
# Maison A : immeuble de ville 16 × 16, 34 de haut. Rez-de-chaussée en pierre (arcades),
# deux étages de brique, toit mansardé d'ardoise avec lucarnes et cheminées.
def maison_a():
    S = fresh("Cite_MaisonA")
    W, D = 16, 16
    S.box("Socle", "Pierre", (W, D, 9), (0, 0, 4.5), bevel=0.15)
    S.box("Bandeau", "Pierre", (W + 0.6, D + 0.6, 0.8), (0, 0, 9.2), bevel=0.1)
    S.box("Etages", "Brique", (W - 0.4, D - 0.4, 15), (0, 0, 17.1), bevel=0.1)
    S.box("Corniche", "Pierre", (W + 1, D + 1, 1), (0, 0, 24.9), bevel=0.15)
    mansard(S, "Toit", "Ardoise", W, D, 7, 2.2, (0, 0, 25.4))
    # Arcades du rez-de-chaussée (porte au centre, vitrines)
    for i, x in enumerate((-5, 0, 5)):
        S.box(f"Arcade{i}", "Vitre" if i != 1 else "Bois", (3.6, 0.3, 5.5), (x, -D / 2 - 0.05, 2.75), bevel=0)
        S.cyl(f"ArcadeArc{i}", "Vitre" if i != 1 else "Bois", 1.8, 0.3, (x, -D / 2 - 0.05, 5.5), verts=12)
        S.box(f"Pilastre{i}", "Pierre", (0.8, 0.6, 8), (x - 2.5, -D / 2 - 0.2, 4), bevel=0.05)
    S.box("PilastreFin", "Pierre", (0.8, 0.6, 8), (7.5, -D / 2 - 0.2, 4), bevel=0.05)
    S.box("Enseigne", "Laiton", (5, 0.3, 1.1), (0, -D / 2 - 0.35, 7.6), bevel=0.05)
    # Fenêtres des étages, façade avant et côtés
    for floor, z in enumerate((11, 18)):
        for i, x in enumerate((-5, 0, 5)):
            arched_window(S, f"F{floor}{i}", x, -D / 2 + 0.2, z, 2.2, 3.6)
        S.box(f"Balcon{floor}", "Fer", (13, 1.6, 0.25), (0, -D / 2 - 0.6, z - 0.4), bevel=0)
        for k in range(9):
            S.box(f"Barreau{floor}{k}", "Fer", (0.1, 0.1, 1.3), (-6 + k * 1.5, -D / 2 - 1.35, z + 0.25), bevel=0)
        S.box(f"Garde{floor}", "Fer", (13, 0.15, 0.15), (0, -D / 2 - 1.35, z + 0.95), bevel=0)
        for side in (-1, 1):
            for j, y in enumerate((-4, 4)):
                S.box(f"Lat{floor}{side}{j}", "Vitre", (0.12, 2.2, 3.4), (side * (W / 2 - 0.15), y, z + 1.7), bevel=0)
    # Lucarnes et cheminées
    for i, x in enumerate((-4.5, 4.5)):
        S.box(f"Lucarne{i}", "Enduit", (2.6, 2.5, 3), (x, -D / 2 + 2.6, 27.5), bevel=0.05)
        S.box(f"LucarneVitre{i}", "Vitre", (1.6, 0.1, 1.8), (x, -D / 2 + 1.3, 27.6), bevel=0)
        prism(S, f"LucarneToit{i}", "Ardoise", 3, 2.7, 1.4, (x, -D / 2 + 2.6, 29))
    for i, (x, y) in enumerate(((-6, 5), (5, 4))):
        S.box(f"Cheminee{i}", "Brique", (1.6, 1.6, 6), (x, y, 31), bevel=0.05)
        S.box(f"ChemineeChapeau{i}", "Pierre", (2, 2, 0.4), (x, y, 34.2), bevel=0)
        S.cyl(f"ChemineePot{i}", "Cuivre", 0.35, 0.8, (x, y, 34.8), rot=(90, 0, 0), verts=6)
    # Tuyau de laiton qui court sur l'angle (touche steampunk) et petite jauge cyan
    S.cyl("Tuyau", "Laiton", 0.25, 24, (W / 2 + 0.3, -D / 2 + 0.6, 12), rot=(90, 0, 0), verts=6)
    S.cyl("Jauge", "Laiton", 0.6, 0.2, (W / 2 + 0.4, -D / 2 + 1.4, 6), rot=(0, 0, 90), verts=12)
    S.cyl("JaugeCadran", "Noyau", 0.45, 0.22, (W / 2 + 0.42, -D / 2 + 1.4, 6), rot=(0, 0, 90), verts=12)
    return S


# Maison B : immeuble étroit 12 × 14, 44 de haut, oriel (bow-window) et tourelle à dôme de cuivre.
def maison_b():
    S = fresh("Cite_MaisonB")
    W, D = 12, 14
    S.box("Socle", "Pierre", (W, D, 8), (0, 0, 4), bevel=0.15)
    S.box("Etages", "Enduit", (W - 0.4, D - 0.4, 24), (0, 0, 20), bevel=0.1)
    for z in (8.2, 16, 24):
        S.box(f"Cordon{z}", "Pierre", (W + 0.3, D + 0.3, 0.5), (0, 0, z), bevel=0.05)
    S.box("Corniche", "Pierre", (W + 0.8, D + 0.8, 0.8), (0, 0, 32.2), bevel=0.1)
    prism(S, "Toit", "Ardoise", W + 0.6, D + 0.6, 7, (0, 0, 32.6), rot=(0, 0, 90))
    # Porte et vitrine
    S.box("Porte", "Bois", (2.6, 0.3, 5), (-2.5, -D / 2 - 0.05, 2.5), bevel=0)
    S.cyl("PorteArc", "Bois", 1.3, 0.3, (-2.5, -D / 2 - 0.05, 5), verts=10)
    S.box("Vitrine", "Vitre", (4, 0.3, 4), (2.6, -D / 2 - 0.05, 3), bevel=0)
    S.box("Auvent", "Toile", (5, 1.8, 0.2), (2.6, -D / 2 - 0.9, 5.6), rot=(-15, 0, 0), bevel=0)
    # Oriel sur deux étages (bloc en saillie vitré, laiton)
    S.box("Oriel", "Laiton", (6, 2.4, 10), (0, -D / 2 - 1.1, 15), bevel=0.15)
    for i, x in enumerate((-1.9, 0, 1.9)):
        S.box(f"OrielVitre{i}", "Vitre", (1.5, 0.1, 3.4), (x, -D / 2 - 2.35, 13), bevel=0)
        S.box(f"OrielVitreH{i}", "Vitre", (1.5, 0.1, 3.4), (x, -D / 2 - 2.35, 17.6), bevel=0)
    prism(S, "OrielToit", "Cuivre", 6.4, 2.8, 1.2, (0, -D / 2 - 1.1, 20))
    for floor, z in enumerate((25.5,)):
        for i, x in enumerate((-3, 3)):
            arched_window(S, f"F{floor}{i}", x, -D / 2 + 0.2, z, 2, 3.4)
    for z in (10, 18):
        for i, x in enumerate((-4.2, 4.2)):
            arched_window(S, f"G{z}{i}", x, -D / 2 + 0.2, z, 1.6, 3)
    # Tourelle d'angle à dôme
    S.cyl("Tourelle", "Enduit", 2.2, 14, (W / 2, -D / 2, 31), rot=(90, 0, 0), verts=12)
    S.sphere("Dome", "Cuivre", 2.5, (W / 2, -D / 2, 38.5), scale=(1, 1, 1.2), detail=2)
    S.cyl("Fleche", "Laiton", 0.12, 3, (W / 2, -D / 2, 42), rot=(90, 0, 0), verts=6)
    S.crystal("FlecheCristal", "Noyau", 0.35, 0.8, 0.3, (W / 2, -D / 2, 43.4), sides=5)
    for i, a in enumerate(range(0, 360, 90)):
        x = W / 2 + math.cos(math.radians(a)) * 2.25
        y = -D / 2 + math.sin(math.radians(a)) * 2.25
        S.box(f"TourelleVitre{i}", "Vitre", (0.9, 0.9, 2.6), (x, y, 30), bevel=0)
    S.box("Cheminee", "Brique", (1.4, 1.4, 6), (-3.5, 4, 37), bevel=0.05)
    return S


# Atelier : 24 × 20, 26 de haut, toit en dents de scie, rosace, haute cheminée d'usine.
def atelier():
    S = fresh("Cite_Atelier")
    W, D = 24, 20
    S.box("Murs", "Brique", (W, D, 16), (0, 0, 8), bevel=0.15)
    S.box("Socle", "Pierre", (W + 0.4, D + 0.4, 2), (0, 0, 1), bevel=0.1)
    for i in range(3):
        y = -D / 2 + (i + 0.5) * D / 3
        prism(S, f"Dent{i}", "Ardoise", W, D / 3, 5, (0, y, 16))
        S.box(f"DentVitre{i}", "Vitre", (W - 2, 0.15, 3.2), (0, y - D / 6 + 0.4, 17.8), rot=(-35, 0, 0), bevel=0)
    S.box("Portail", "Bois", (8, 0.4, 9), (0, -D / 2 - 0.1, 4.5), bevel=0)
    S.cyl("PortailArc", "Bois", 4, 0.4, (0, -D / 2 - 0.1, 9), verts=14)
    S.box("PortailCadre", "Fer", (9, 0.6, 0.5), (0, -D / 2 - 0.2, 9), bevel=0)
    S.ring("Rosace", "Laiton", 2.6, 0.25, (0, -D / 2 - 0.15, 13.5), seg=20, sides=4)
    S.cyl("RosaceVitre", "Vitre", 2.4, 0.2, (0, -D / 2 - 0.05, 13.5), verts=20)
    S.gear("RosaceRouage", "Laiton", 1.4, 0.3, 10, (0, -D / 2 - 0.3, 13.5), tooth=0.3)
    S.sphere("RosaceNoyau", "Noyau", 0.5, (0, -D / 2 - 0.4, 13.5))
    for i, x in enumerate((-8.5, 8.5)):
        S.box(f"Fenetre{i}", "Vitre", (4, 0.2, 6), (x, -D / 2 - 0.05, 7), bevel=0)
        S.box(f"FenetreLinteau{i}", "Pierre", (4.6, 0.5, 0.6), (x, -D / 2 - 0.15, 10.3), bevel=0)
    # Haute cheminée d'usine et tuyauterie
    S.cyl("Cheminee", "Brique", 1.6, 18, (W / 2 - 3, D / 2 - 3, 25), rot=(90, 0, 0), verts=12, radius2=1.3)
    for z in (19, 26, 33):
        S.ring(f"ChemineeBague{z}", "Fer", 1.5, 0.15, (W / 2 - 3, D / 2 - 3, z), rot=(90, 0, 0), seg=12, sides=4)
    S.cyl("Tuyau", "Cuivre", 0.45, W - 2, (0, -D / 2 - 0.6, 15.4), rot=(0, 0, 90), verts=8)
    for i, x in enumerate((-10, 10)):
        S.cyl(f"TuyauDescente{i}", "Cuivre", 0.35, 13, (x, -D / 2 - 0.6, 9), rot=(90, 0, 0), verts=8)
    # Cuve de cuivre sur le toit (dans l'empreinte du bâtiment, pour ne pas gêner la rue)
    S.cyl("Cuve", "Cuivre", 2.2, 4, (-W / 2 + 4, D / 2 - 4, 18), rot=(90, 0, 0), verts=12)
    S.sphere("CuveDome", "Cuivre", 2.2, (-W / 2 + 4, D / 2 - 4, 20), scale=(1, 1, 0.6), detail=2)
    S.cyl("CuveJauge", "Noyau", 0.5, 0.2, (-W / 2 + 1.7, D / 2 - 4, 17.5), rot=(0, 0, 90), verts=12)
    return S


# Tour de l'Horloge : 18 × 18, 86 de haut — repère visible de toute la ville (tuile centrale).
def tour_horloge():
    S = fresh("Cite_TourHorloge")
    W = 18
    S.box("Base", "Pierre", (W, W, 30), (0, 0, 15), bevel=0.2)
    for i, (x, y) in enumerate(((-1, -1), (1, -1), (1, 1), (-1, 1))):
        S.box(f"Contrefort{i}", "Pierre", (3, 3, 34), (x * (W / 2), y * (W / 2), 17), bevel=0.15)
    S.box("Portail", "Bois", (6, 0.4, 9), (0, -W / 2 - 0.1, 4.5), bevel=0)
    S.cyl("PortailArc", "Bois", 3, 0.4, (0, -W / 2 - 0.1, 9), verts=14)
    S.box("Fut", "Brique", (W - 3, W - 3, 30), (0, 0, 45), bevel=0.15)
    S.box("Galerie", "Pierre", (W + 1, W + 1, 1.2), (0, 0, 30.6), bevel=0.1)
    for side in range(4):
        a = side * math.pi / 2
        for k in range(3):
            z = 36 + k * 8
            dx, dy = math.sin(a), -math.cos(a)
            px, py = dx * (W / 2 - 1.4), dy * (W / 2 - 1.4)
            S.box(f"Meurtriere{side}{k}", "Vitre", (1.2 if dy != 0 else 0.2, 0.2 if dy != 0 else 1.2, 4),
                  (px + dy * 0, py, z), rot=(0, 0, 0), bevel=0)
    # Chambre de l'horloge : quatre cadrans lumineux, rouages
    S.box("Chambre", "Pierre", (W, W, 16), (0, 0, 68), bevel=0.2)
    for side in range(4):
        a = side * 90
        rad = math.radians(a)
        cx, cy = math.sin(rad) * (W / 2 + 0.1), -math.cos(rad) * (W / 2 + 0.1)
        S.cyl(f"Cadran{side}", "Noyau", 6, 0.3, (cx, cy, 68), rot=(0, 0, a), verts=24)
        S.ring(f"CadranBord{side}", "Laiton", 6.2, 0.45, (cx * 1.01, cy * 1.01, 68), rot=(0, 0, a), seg=24, sides=4)
        for h in range(12):
            t = h / 12 * math.tau
            ox, oz = math.cos(t) * 5, math.sin(t) * 5
            px = cx * 1.02 + math.cos(rad) * ox
            py = cy * 1.02 + math.sin(rad) * ox
            S.box(f"Repere{side}{h}", "Laiton", (0.4, 0.4, 1.2 if h % 3 == 0 else 0.7), (px, py, 68 + oz),
                  rot=(0, 0, a), bevel=0)
        S.box(f"AiguilleH{side}", "Metal", (0.5, 0.3, 4), (cx * 1.03, cy * 1.03, 70), rot=(0, 0, a), bevel=0)
        S.box(f"AiguilleM{side}", "Metal", (0.35, 0.3, 5.5), (cx * 1.03 + math.cos(rad) * 1.6, cy * 1.03 + math.sin(rad) * 1.6, 68.5),
              rot=(0, -60, a), bevel=0)
    S.box("Corniche", "Pierre", (W + 2, W + 2, 1.5), (0, 0, 76.7), bevel=0.15)
    # Flèche de cuivre et couronne de cristaux (le Temps brisé)
    mansard(S, "Fleche", "Cuivre", W, W, 14, 7.5, (0, 0, 77.4))
    S.cyl("Pointe", "Laiton", 0.4, 8, (0, 0, 95), rot=(90, 0, 0), verts=8)
    S.crystal("Cristal", "Cristal", 1.4, 4, 1.2, (0, 0, 100), sides=6)
    for i in range(6):
        t = i / 6 * math.tau
        S.crystal(f"Eclat{i}", "Noyau", 0.5, 1.8, 0.4, (math.cos(t) * 3, math.sin(t) * 3, 92), rot=(math.cos(t) * 25, math.sin(t) * 25, 0), sides=5)
    for i, (x, y) in enumerate(((-1, -1), (1, -1), (1, 1), (-1, 1))):
        S.cyl(f"Clocheton{i}", "Pierre", 1.4, 6, (x * (W / 2), y * (W / 2), 80), rot=(90, 0, 0), verts=8)
        S.sphere(f"ClochetonDome{i}", "Cuivre", 1.5, (x * (W / 2), y * (W / 2), 83.2), detail=1)
    return S


# Passerelle-arche : 24 de long, 18 de haut — aqueduc / pont à arche avec tablier praticable.
def arche():
    S = fresh("Cite_Arche")
    L, H, T = 24, 18, 8
    for side in (-1, 1):
        S.box(f"Pile{side}", "Pierre", (4, T, H), (side * (L / 2 - 2), 0, H / 2), bevel=0.15)
    S.box("Tablier", "Pierre", (L, T, 2.4), (0, 0, H - 1.2), bevel=0.1)
    # Arc d'une pièce : anneau en demi-cercle (intrados R, extrados R + 1,6), épaisseur T.
    R = L / 2 - 4
    base = H - 2.4 - R
    arch_ring(S, "Arc", "Pierre", R, R + 1.6, T - 0.4, base)
    S.box("Clef", "Laiton", (1.2, T, 1.8), (0, 0, H - 2.6), bevel=0.05)
    # Garde-corps de fer et lampadaires sur le tablier
    for side in (-1, 1):
        S.box(f"Garde{side}", "Fer", (L, 0.2, 0.2), (0, side * (T / 2 - 0.2), H + 1.2), bevel=0)
        for k in range(9):
            S.box(f"Barreau{side}{k}", "Fer", (0.15, 0.15, 1.2), (-L / 2 + 1.5 + k * 2.6, side * (T / 2 - 0.2), H + 0.6), bevel=0)
    S.cyl("Conduite", "Cuivre", 0.6, L, (0, T / 2 + 0.4, H - 3.5), rot=(0, 0, 90), verts=8)
    return S


# Lampadaire arcanique : 9 de haut, lanterne de laiton et cristal cyan.
def lampadaire():
    S = fresh("Cite_Lampadaire")
    S.cyl("Pied", "Fer", 0.45, 1, (0, 0, 0.5), rot=(90, 0, 0), verts=8)
    S.cyl("Fut", "Fer", 0.18, 7, (0, 0, 4.5), rot=(90, 0, 0), verts=8)
    S.ring("Volute", "Fer", 0.5, 0.08, (0, -0.5, 7.3), seg=10, sides=4)
    S.box("Potence", "Fer", (0.15, 1.4, 0.15), (0, -0.7, 8), bevel=0)
    # Lanterne ouverte : quatre montants de laiton autour du cristal lumineux
    for k, (dx, dy) in enumerate(((-0.4, -0.4), (0.4, -0.4), (0.4, 0.4), (-0.4, 0.4))):
        S.box(f"LanterneMontant{k}", "Laiton", (0.08, 0.08, 1.3), (dx, -1.3 + dy, 7.6), bevel=0)
    S.box("LanterneSocle", "Laiton", (1, 1, 0.15), (0, -1.3, 6.95), bevel=0)
    S.crystal("Cristal", "Noyau", 0.3, 0.6, 0.4, (0, -1.3, 7.5), sides=6)
    S.cyl("Chapeau", "Cuivre", 0.6, 0.4, (0, -1.3, 8.4), rot=(90, 0, 0), verts=6, radius2=0.1)
    return S


# Étal de marché : 8 × 5, auvent de toile.
def etal():
    S = fresh("Cite_Etal")
    S.box("Comptoir", "Bois", (8, 3, 3.2), (0, 0, 1.6), bevel=0.08)
    for i, x in enumerate((-3.8, 3.8)):
        for j, y in enumerate((-1.6, 1.6)):
            S.box(f"Montant{i}{j}", "Bois", (0.3, 0.3, 7), (x, y, 3.5), bevel=0)
    S.box("Auvent", "Toile", (9, 4.6, 0.2), (0, -0.6, 7), rot=(-12, 0, 0), bevel=0)
    for i in range(4):
        S.box(f"Bande{i}", "Enduit", (1, 4.62, 0.21), (-3.4 + i * 2.3, -0.6, 7.01), rot=(-12, 0, 0), bevel=0)
    for i, x in enumerate((-2.5, 0, 2.5)):
        S.box(f"Caisse{i}", "Bois", (1.8, 1.4, 1), (x, -0.4, 3.7), bevel=0.05)
    S.gear("Rouage", "Laiton", 0.8, 0.2, 10, (2.6, -0.5, 4.5), tooth=0.15)
    return S


# Fontaine arcanique : bassin de pierre, colonne de laiton, cristal flottant.
def fontaine():
    S = fresh("Cite_Fontaine")
    S.cyl("Bassin", "Pierre", 6, 1.6, (0, 0, 0.8), rot=(90, 0, 0), verts=16)
    S.cyl("Eau", "Noyau", 5.4, 0.2, (0, 0, 1.55), rot=(90, 0, 0), verts=16)
    S.cyl("Colonne", "Laiton", 0.7, 5, (0, 0, 4), rot=(90, 0, 0), verts=10)
    S.ring("Anneau", "Laiton", 1.6, 0.15, (0, 0, 6.8), rot=(90, 0, 0), seg=16, sides=4)
    S.gear("Rouage", "Laiton", 1.3, 0.25, 12, (0, 0, 5.4), rot=(90, 0, 0), tooth=0.25)
    S.crystal("Cristal", "Cristal", 0.9, 2.2, 1.2, (0, 0, 8.6), sides=6)
    return S


# Escalier de pierre : 6 de large, monte de 9 sur 12 de long (vers -Y).
def escalier():
    S = fresh("Cite_Escalier")
    steps = 12
    for i in range(steps):
        h = (i + 1) * 9 / steps
        S.box(f"Marche{i}", "Pierre", (6, 1, h), (0, 6 - (i + 0.5), h / 2), bevel=0.03)
    for side in (-1, 1):
        S.box(f"Rampe{side}", "Fer", (0.15, 15, 0.15), (side * 2.9, 0, 5.6), rot=(-math.degrees(math.atan2(9, 12)), 0, 0), bevel=0)
    return S


# Dirigeable de décor : coque gonflée, nacelle de bois, voiles et hélice.
def dirigeable():
    S = fresh("Cite_Dirigeable")
    S.sphere("Ballon", "Enduit", 6, (0, 0, 10), scale=(1, 3.2, 1), detail=3)
    for i, y in enumerate((-10, 0, 10)):
        S.ring(f"Cerclage{i}", "Laiton", 5.9 if y == 0 else 4.8, 0.15, (0, y, 10), seg=16, sides=4)
    S.box("Nacelle", "Bois", (3.5, 14, 2.6), (0, 0, 1.8), bevel=0.2, taper=(0.7, 0.8))
    S.box("NacelleBord", "Laiton", (3.7, 14.2, 0.3), (0, 0, 3.1), bevel=0)
    for i, y in enumerate((-5, 5)):
        S.cyl(f"Suspente{i}", "Fer", 0.08, 5, (0, y, 5.5), rot=(90, 0, 0), verts=4)
    S.box("Voile", "Enduit", (0.2, 6, 5), (0, 15, 10), rot=(0, 0, 0), bevel=0, taper=(1, 0.4))
    S.box("Gouvernail", "Toile", (5, 3, 0.2), (0, 18, 10), bevel=0)
    S.cyl("Moyeu", "Laiton", 0.5, 1, (0, 19.5, 10), verts=8)
    for i in range(4):
        S.box(f"Pale{i}", "Bois", (0.4, 0.2, 3.2), (0, 20, 10), rot=(0, i * 45, 0), bevel=0)
    S.sphere("Noyau", "Noyau", 0.8, (0, -7, 1.4))
    return S


BUILDS = {
    "Cite_MaisonA": maison_a,
    "Cite_MaisonB": maison_b,
    "Cite_Atelier": atelier,
    "Cite_TourHorloge": tour_horloge,
    "Cite_Arche": arche,
    "Cite_Lampadaire": lampadaire,
    "Cite_Etal": etal,
    "Cite_Fontaine": fontaine,
    "Cite_Escalier": escalier,
    "Cite_Dirigeable": dirigeable,
}


def build_all(only=None):
    out = {}
    for name, fn in BUILDS.items():
        if only and name not in only:
            continue
        fn()
        path = os.path.join(HERE, name + ".fbx")
        parts, tris = LIB["export_by_material"](name, name, path, scale=0.01)
        out[name] = tris
    return out


RESULT = build_all()
