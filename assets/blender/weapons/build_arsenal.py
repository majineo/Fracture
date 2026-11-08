# Arsenal de la Fracture (v0.10.0) — quatre armes steampunk / arcanes construites par script.
# Usage (Blender) : runpy.run_path(".../assets/blender/weapons/build_arsenal.py")
# Conventions (lib/fracture_shapes.py) : 1 unité = 1 stud ; origine = poignée ; -Y = avant
# (canon, lame, tête) ; +Z = haut ; détails à montrer à la caméra d'épaule côté -X.
# Sorties : Tromblon_Vapeur.fbx, Mitrailleuse_Manivelle.fbx, Marteau_Piston.fbx, Faux_Temps.fbx
import math
import os
import runpy

import bmesh
import bpy

HERE = os.path.dirname(os.path.abspath(__file__)) if "__file__" in globals() else r"C:\Users\neost\Documents\Fracture\assets\blender\weapons"
LIB = runpy.run_path(os.path.join(HERE, "..", "lib", "fracture_shapes.py"))
MATERIALS = LIB["MATERIALS"]
for key in ("Bois", "Laiton", "Metal", "Noyau", "Cuir", "Acier", "Cristal", "Indigo", "Fer"):
    if bpy.data.materials.get(MATERIALS[key]) is None:
        bpy.data.materials.new(MATERIALS[key])


def fresh(name):
    old = bpy.data.collections.get(name)
    if old:
        for o in list(old.objects):
            bpy.data.objects.remove(o, do_unlink=True)
        bpy.data.collections.remove(old)
    return LIB["Shapes"](name)


def merge(S, objs, name, mat):
    """Fusionne des pièces en un seul objet (pièce mobile en jeu, ex. « Rouage »)."""
    bm = bmesh.new()
    for o in objs:
        m = o.data.copy()
        m.transform(o.matrix_world)
        bm.from_mesh(m)
        bpy.data.meshes.remove(m)
        bpy.data.objects.remove(o, do_unlink=True)
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    obj.data.materials.append(bpy.data.materials[MATERIALS[mat]])
    obj["fracture_mat"] = mat
    S.coll.objects.link(obj)
    return obj


def strip(S, name, mat, side_a, side_b, thickness):
    """Bande extrudée en X entre deux polylignes (y, z) de même longueur (lame courbe)."""
    bm = bmesh.new()
    h = thickness / 2
    front_a = [bm.verts.new((-h, y, z)) for (y, z) in side_a]
    front_b = [bm.verts.new((-h, y, z)) for (y, z) in side_b]
    back_a = [bm.verts.new((h, y, z)) for (y, z) in side_a]
    back_b = [bm.verts.new((h, y, z)) for (y, z) in side_b]
    for k in range(len(side_a) - 1):
        bm.faces.new((front_a[k], front_b[k], front_b[k + 1], front_a[k + 1]))
        bm.faces.new((back_a[k + 1], back_b[k + 1], back_b[k], back_a[k]))
        bm.faces.new((front_a[k], front_a[k + 1], back_a[k + 1], back_a[k]))
        bm.faces.new((front_b[k + 1], front_b[k], back_b[k], back_b[k + 1]))
    last = len(side_a) - 1
    bm.faces.new((front_a[0], back_a[0], back_b[0], front_b[0]))
    bm.faces.new((front_b[last], back_b[last], back_a[last], front_a[last]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return S._finish(name, bm, mat, (0, 0, 0), (0, 0, 0), 0)


# Tromblon à vapeur ---------------------------------------------------------------------------
def tromblon():
    S = fresh("Tromblon_Vapeur")
    # Poignée-pistolet et crosse de bois
    S.box("Poignee", "Bois", (0.17, 0.22, 0.5), (0, 0.07, -0.15), rot=(-16, 0, 0), bevel=0.03)
    S.box("Crosse", "Bois", (0.2, 0.95, 0.34), (0, 0.66, 0.02), rot=(6, 0, 0), bevel=0.05, taper=(1, 0.8))
    S.box("Plaque", "Laiton", (0.22, 0.07, 0.42), (0, 1.13, -0.03), rot=(6, 0, 0), bevel=0.015)
    S.box("CrosseCuir", "Cuir", (0.215, 0.4, 0.18), (0, 0.55, 0.05), rot=(6, 0, 0), bevel=0.02)
    # Carcasse et détente
    S.box("Carcasse", "Laiton", (0.26, 0.75, 0.3), (0, -0.2, 0.17), bevel=0.04)
    S.ring("PonteDetente", "Laiton", 0.1, 0.02, (0, -0.14, -0.04), rot=(0, 0, 90), seg=12, sides=4)
    S.box("Detente", "Metal", (0.03, 0.04, 0.1), (0, -0.12, -0.03), rot=(-20, 0, 0), bevel=0)
    S.box("Chien", "Metal", (0.06, 0.12, 0.16), (0, 0.12, 0.38), rot=(-30, 0, 0), bevel=0.01)
    # Fût de bois sous le canon
    S.box("Fut", "Bois", (0.22, 0.95, 0.16), (0, -1.0, 0.07), bevel=0.03, taper=(0.85, 0.8))
    # Canon évasé en cloche (le tromblon) : tronc conique + pavillon
    S.cyl("Canon", "Laiton", 0.1, 1.5, (0, -1.25, 0.22), verts=12, radius2=0.13)
    S.cyl("Pavillon", "Laiton", 0.14, 0.45, (0, -2.2, 0.22), verts=14, radius2=0.3)
    S.ring("PavillonLevre", "Laiton", 0.3, 0.03, (0, -2.43, 0.22), seg=16, sides=4)
    S.cyl("PavillonFond", "Metal", 0.27, 0.02, (0, -2.4, 0.22), verts=14)
    for i, y in enumerate((-0.7, -1.2, -1.7)):
        S.cyl(f"Bague{i}", "Metal", 0.125, 0.05, (0, y, 0.22), verts=12)
    # Réservoir de vapeur en cuivre (côté visible -X), manomètre et tuyaux
    S.cyl("Reservoir", "Fer", 0.12, 0.7, (-0.25, -0.6, 0.2), verts=12)
    S.sphere("ReservoirAvant", "Fer", 0.12, (-0.25, -0.95, 0.2), scale=(1, 0.5, 1))
    S.sphere("ReservoirArriere", "Fer", 0.12, (-0.25, -0.25, 0.2), scale=(1, 0.5, 1))
    for i, y in enumerate((-0.4, -0.8)):
        S.ring(f"Cerclage{i}", "Laiton", 0.125, 0.018, (-0.25, y, 0.2), seg=12, sides=4)
    S.cyl("ManometreBoitier", "Laiton", 0.09, 0.05, (-0.38, -0.6, 0.2), rot=(0, 0, 90), verts=14)
    S.cyl("Manometre", "Noyau", 0.07, 0.055, (-0.385, -0.6, 0.2), rot=(0, 0, 90), verts=14)
    S.box("Aiguille", "Metal", (0.01, 0.012, 0.06), (-0.415, -0.6, 0.22), rot=(0, 30, 0), bevel=0)
    S.cyl("Tuyau", "Laiton", 0.025, 0.55, (-0.18, -1.15, 0.3), rot=(-12, 0, 0), verts=6)
    S.cyl("Soupape", "Laiton", 0.04, 0.12, (-0.25, -0.6, 0.36), rot=(90, 0, 0), verts=8)
    # Noyau de Fracture serti sur la carcasse
    S.ring("NoyauSerti", "Laiton", 0.08, 0.018, (-0.135, -0.05, 0.2), rot=(0, 0, 90), seg=12, sides=4)
    S.sphere("Noyau", "Noyau", 0.06, (-0.14, -0.05, 0.2), scale=(0.6, 1, 1))
    return S


# Mitrailleuse à manivelle --------------------------------------------------------------------
def mitrailleuse():
    S = fresh("Mitrailleuse_Manivelle")
    S.box("Poignee", "Bois", (0.17, 0.22, 0.48), (0, 0.06, -0.15), rot=(-12, 0, 0), bevel=0.03)
    S.box("Crosse", "Bois", (0.2, 0.7, 0.3), (0, 0.55, 0.04), bevel=0.04, taper=(1, 0.85))
    S.box("Plaque", "Laiton", (0.22, 0.06, 0.34), (0, 0.92, 0.04), bevel=0.015)
    S.box("Carcasse", "Metal", (0.34, 0.95, 0.4), (0, -0.35, 0.2), bevel=0.04)
    S.box("CarcasseFilet", "Laiton", (0.35, 0.9, 0.03), (0, -0.35, 0.41), bevel=0)
    S.ring("PonteDetente", "Laiton", 0.1, 0.02, (0, -0.12, -0.05), rot=(0, 0, 90), seg=12, sides=4)
    S.box("Detente", "Metal", (0.03, 0.04, 0.1), (0, -0.1, -0.04), rot=(-20, 0, 0), bevel=0)
    # Tambour-chargeur sous la carcasse
    S.cyl("Tambour", "Laiton", 0.26, 0.2, (0, -0.55, -0.15), rot=(0, 0, 90), verts=16)
    S.cyl("TambourCentre", "Metal", 0.09, 0.22, (0, -0.55, -0.15), rot=(0, 0, 90), verts=10)
    # Bloc de canons rotatif (« Rouage » : tourne en jeu autour de l'axe du canon)
    rouage = []
    rouage.append(S.cyl("RouageMoyeu", "Metal", 0.09, 1.7, (0, -1.6, 0.2), verts=10))
    for i in range(6):
        a = i / 6 * math.tau
        rouage.append(S.cyl(f"RouageCanon{i}", "Metal", 0.045, 1.75, (math.cos(a) * 0.15, -1.62, 0.2 + math.sin(a) * 0.15), verts=8))
    for i, y in enumerate((-1.0, -2.2)):
        rouage.append(S.cyl(f"RouageFlasque{i}", "Laiton", 0.22, 0.06, (0, y, 0.2), verts=12))
    rouage.append(S.cyl("RouageBouche", "Laiton", 0.21, 0.1, (0, -2.45, 0.2), verts=12))
    merge(S, rouage, "RouageCanons", "Metal")
    # Carter de laiton à l'arrière des canons
    S.cyl("Carter", "Laiton", 0.25, 0.3, (0, -0.85, 0.2), verts=14)
    # Manivelle sur le flanc visible (-X)
    S.cyl("ManivelleAxe", "Metal", 0.04, 0.2, (-0.25, -0.85, 0.2), rot=(0, 0, 90), verts=8)
    S.box("ManivelleBras", "Laiton", (0.04, 0.05, 0.35), (-0.36, -0.85, 0.05), bevel=0.01)
    S.cyl("ManivellePoignee", "Bois", 0.04, 0.16, (-0.44, -0.85, -0.1), rot=(0, 0, 90), verts=8)
    # Poignée avant et noyau cyan
    S.box("PoigneeAvant", "Bois", (0.12, 0.14, 0.32), (0, -1.25, -0.08), rot=(10, 0, 0), bevel=0.02)
    S.ring("NoyauSerti", "Laiton", 0.09, 0.02, (-0.175, -0.4, 0.22), rot=(0, 0, 90), seg=12, sides=4)
    S.sphere("Noyau", "Noyau", 0.07, (-0.18, -0.4, 0.22), scale=(0.6, 1, 1))
    S.box("Visee", "Laiton", (0.05, 0.1, 0.12), (0, -0.7, 0.47), bevel=0.01)
    return S


# Marteau-piston -------------------------------------------------------------------------------
def marteau():
    S = fresh("Marteau_Piston")
    # Manche long (poignée à l'origine, la tête vers -Y)
    S.cyl("Pommeau", "Laiton", 0.1, 0.12, (0, 0.55, 0), verts=8)
    S.cyl("Manche", "Bois", 0.07, 3.2, (0, -1.0, 0), verts=8)
    S.cyl("Prise", "Cuir", 0.085, 0.9, (0, 0.05, 0), verts=8)
    for i, y in enumerate((-0.5, -1.6, -2.4)):
        S.cyl(f"Bague{i}", "Laiton", 0.09, 0.07, (0, y, 0), verts=8)
    # Tête : bloc de fer, deux pistons (faces de frappe ±Z), cylindre de vapeur
    S.box("Tete", "Metal", (0.55, 0.6, 0.75), (0, -2.85, 0), bevel=0.05)
    S.cyl("PistonHaut", "Acier", 0.24, 0.35, (0, -2.85, 0.52), rot=(90, 0, 0), verts=12)
    S.cyl("PistonBas", "Acier", 0.24, 0.35, (0, -2.85, -0.52), rot=(90, 0, 0), verts=12)
    S.cyl("FaceHaut", "Laiton", 0.27, 0.06, (0, -2.85, 0.72), rot=(90, 0, 0), verts=12)
    S.cyl("FaceBas", "Laiton", 0.27, 0.06, (0, -2.85, -0.72), rot=(90, 0, 0), verts=12)
    for i, z in enumerate((0.38, -0.38)):
        S.ring(f"Cerclage{i}", "Laiton", 0.25, 0.025, (0, -2.85, z), rot=(90, 0, 0), seg=12, sides=4)
    # Chaudière sur le flanc visible (-X), noyau cyan qui alimente les pistons
    S.cyl("Chaudiere", "Fer", 0.14, 0.5, (-0.38, -2.85, 0), rot=(90, 0, 0), verts=10)
    S.ring("NoyauSerti", "Laiton", 0.1, 0.02, (-0.29, -2.85, 0), rot=(0, 0, 90), seg=12, sides=4)
    S.sphere("Noyau", "Noyau", 0.08, (-0.3, -2.85, 0), scale=(0.6, 1, 1))
    S.cyl("Echappement", "Laiton", 0.04, 0.3, (-0.38, -2.85, 0.42), rot=(90, 0, 0), verts=6)
    S.gear("RouageDeco", "Laiton", 0.18, 0.03, 10, (0.29, -2.85, 0), rot=(0, 0, 90))
    return S


# Faux du Temps -------------------------------------------------------------------------------
def faux():
    S = fresh("Faux_Temps")
    S.cyl("Pommeau", "Laiton", 0.09, 0.14, (0, 0.6, 0), verts=8)
    S.crystal("PommeauCristal", "Cristal", 0.06, 0.18, 0.04, (0, 0.72, 0), rot=(-90, 0, 0), sides=5)
    S.cyl("Hampe", "Indigo", 0.06, 3.6, (0, -1.15, 0), verts=8)
    S.cyl("Prise", "Cuir", 0.075, 0.8, (0, 0.05, 0), verts=8)
    S.cyl("PriseHaute", "Cuir", 0.075, 0.5, (0, -1.5, 0), verts=8)
    for i, y in enumerate((-0.6, -2.2, -2.85)):
        S.cyl(f"Bague{i}", "Laiton", 0.08, 0.07, (0, y, 0), verts=8)
    # Collet : cadran d'horloge, d'où sort la lame
    S.cyl("Collet", "Laiton", 0.22, 0.12, (0, -3.0, 0), rot=(0, 0, 90), verts=16)
    S.cyl("Cadran", "Noyau", 0.17, 0.13, (0, -3.0, 0), rot=(0, 0, 90), verts=16)
    S.box("AiguilleA", "Metal", (0.14, 0.014, 0.02), (-0.07, -3.0, 0.04), rot=(0, 20, 0), bevel=0)
    S.box("AiguilleB", "Metal", (0.14, 0.014, 0.1), (-0.07, -3.0, -0.02), rot=(0, 0, 0), bevel=0)
    # Lame en croissant d'une seule pièce : part du collet vers le haut (+Z) et se recourbe vers
    # l'arrière (+Y) ; le fil (bord intérieur, côté +Y) est souligné de néon cyan.
    spine, edge = [], []
    n = 12
    for k in range(n + 1):
        t = k / n
        a = math.radians(5 + 95 * t)
        y = -3.0 + (1 - math.cos(a)) * 1.25
        z = 0.12 + math.sin(a) * 1.9
        w = 0.42 * (1 - t) ** 0.8 + 0.02
        # normale vers l'intérieur de la courbe (côté +Y puis vers le bas) : tangente tournée
        ny, nz = 1.9 * math.cos(a), -1.25 * math.sin(a)
        nl = math.hypot(ny, nz)
        spine.append((y, z))
        edge.append((y + ny / nl * w, z + nz / nl * w))
    strip(S, "Lame", "Acier", spine, edge, 0.05)
    fil = [(y + 0.0, z) for (y, z) in edge]
    fil_in = [(y - 0.05 * (1 - k / n), z) for k, (y, z) in enumerate(edge)]
    strip(S, "LameFil", "Noyau", fil_in, fil, 0.07)
    S.crystal("Pointe", "Cristal", 0.05, 0.22, 0.04, (0, spine[-1][0] + 0.05, spine[-1][1] + 0.05), rot=(-80, 0, 0), sides=4)
    return S


BUILDS = {
    "Tromblon_Vapeur": tromblon,
    "Mitrailleuse_Manivelle": mitrailleuse,
    "Marteau_Piston": marteau,
    "Faux_Temps": faux,
}


def build_all():
    out = {}
    for name, fn in BUILDS.items():
        fn()
        path = os.path.join(HERE, name + ".fbx")
        parts, tris = LIB["export_by_material"](name, name, path, keep=("RouageCanons",))
        out[name] = (tris, sorted(parts))
    return out


RESULT = build_all()
