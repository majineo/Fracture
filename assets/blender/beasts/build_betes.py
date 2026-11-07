# Bêtes de test (v0.4.12) — modèles construits par script dans Blender, style « pièces
# superposées, couleurs franches, matières lumineuses » (inspirations fournies par
# l'utilisateur), designs originaux dans l'univers de FRACTURE.
#   Loup_Cristal     : quadrupède en plaques sombres, échine et queue de cristaux violets
#   Scarabee_Horloge : carapace de laiton à cadran, ailes en rouages, six pattes
#   Raie_Temps       : raie volante aux ailes superposées, queue d'anneaux, sablier sur le dos
# Repère : -Y = avant de la bête, +Z = haut ; origine au sol sous le centre.
import math
import os
import runpy

import bpy
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__)) if "__file__" in globals() else r"C:\Users\neost\Documents\Fracture\assets\blender\beasts"
LIB = runpy.run_path(os.path.join(HERE, "..", "lib", "fracture_shapes.py"))


def segment(S, name, mat, a, b, thickness):
    # Barre de section carrée allant du point a au point b.
    d = b - a
    euler = d.to_track_quat("Z", "Y").to_euler("XYZ")
    mid = (a + b) / 2
    return S.box(name, mat, (thickness, thickness, d.length), tuple(mid),
                 rot=(math.degrees(euler.x), math.degrees(euler.y), math.degrees(euler.z)), bevel=0.02)


def fresh(name):
    old = bpy.data.collections.get(name)
    if old:
        for o in list(old.objects):
            bpy.data.objects.remove(o, do_unlink=True)
        bpy.data.collections.remove(old)
    return LIB["Shapes"](name)


def loup(ox):
    S = fresh("Loup_Cristal")
    o = lambda x, y, z: (ox + x, y, z)
    # Corps : plaques sombres superposées
    S.sphere("Corps", "Metal", 1.0, o(0, 0.2, 2.2), scale=(0.85, 1.6, 0.85), detail=2)
    for i in range(6):
        y = -1.0 + i * 0.42
        S.box(f"Plaque{i}", "Indigo", (1.2 - abs(i - 2.5) * 0.08, 0.5, 0.3), o(0, y, 2.95 - abs(i - 2.5) * 0.06), rot=(-12, 0, 0), bevel=0.05)
    # Poitrail
    S.sphere("Poitrail", "Metal", 0.75, o(0, -1.25, 2.1), scale=(0.9, 0.9, 1.1), detail=1)
    # Tête : crâne, museau, mâchoire, oreilles, yeux
    S.box("Crane", "Metal", (0.9, 0.9, 0.75), o(0, -2.05, 2.75), rot=(10, 0, 0), bevel=0.08)
    S.box("Museau", "Metal", (0.55, 0.9, 0.45), o(0, -2.75, 2.55), rot=(8, 0, 0), bevel=0.06, taper=(0.75, 0.8))
    S.box("Machoire", "Indigo", (0.5, 0.75, 0.18), o(0, -2.6, 2.22), rot=(-6, 0, 0), bevel=0.04)
    for side in (-1, 1):
        S.crystal(f"Oreille{side}", "Cristal", 0.14, 0.55, 0.05, o(0.32 * side, -1.95, 3.2), rot=(20, side * 18, 0), sides=4)
        S.sphere(f"Oeil{side}", "Noyau", 0.09, o(0.3 * side, -2.42, 2.88), scale=(0.6, 1, 0.6))
        for k in range(3):
            S.crystal(f"Croc{side}{k}", "Ivoire", 0.04, 0.02, 0.16, o(0.15 * side, -3.05 + k * 0.12, 2.3), sides=4)
    # Pattes : cuisse, jambe, patte
    for side in (-1, 1):
        for front, y in ((True, -0.9), (False, 1.2)):
            S.box(f"Cuisse{side}{front}", "Indigo", (0.42, 0.55, 0.9), o(0.55 * side, y, 1.75), rot=(15 if front else -15, 0, 0), bevel=0.06)
            S.box(f"Jambe{side}{front}", "Metal", (0.28, 0.32, 1.05), o(0.58 * side, y + (0.1 if front else -0.1), 0.75), bevel=0.04)
            S.box(f"Patte{side}{front}", "Metal", (0.36, 0.5, 0.18), o(0.58 * side, y - 0.08, 0.1), bevel=0.04)
            for k in range(3):
                S.crystal(f"Griffe{side}{front}{k}", "Ivoire", 0.035, 0.02, 0.14, o(0.58 * side + (k - 1) * 0.11, y - 0.36, 0.08), rot=(90, 0, 0), sides=4)
    # Échine de cristaux et queue
    for i in range(7):
        y = -1.3 + i * 0.45
        h = 0.9 - abs(i - 2) * 0.12
        S.crystal(f"Echine{i}", "Cristal", 0.16, h, 0.1, o(0, y, 3.05), rot=(-25, 0, (i % 2 * 2 - 1) * 8), sides=5)
    for i in range(5):
        S.crystal(f"Queue{i}", "Cristal" if i % 2 == 0 else "Noyau", 0.18 - i * 0.02, 0.5, 0.2, o(0, 1.9 + i * 0.38, 2.6 + i * 0.22), rot=(-70 + i * 6, 0, 0), sides=5)
    # Éclats de Temps qui flottent autour (pièces séparées)
    for i in range(4):
        a = i * math.pi / 2 + 0.4
        S.crystal(f"Flotte{i}", "Noyau", 0.1, 0.3, 0.3, o(1.6 * math.cos(a), 0.3 + 1.6 * math.sin(a), 3.4), sides=4)
    return S.count


def scarabee(ox):
    S = fresh("Scarabee_Horloge")
    o = lambda x, y, z: (ox + x, y, z)
    S.sphere("Ventre", "Metal", 1.0, o(0, 0, 1.0), scale=(1.1, 1.5, 0.55), detail=2)
    # Carapace : deux élytres de laiton + cadran
    for side in (-1, 1):
        S.sphere(f"Elytre{side}", "Laiton", 1.0, o(0.52 * side, 0.25, 1.45), scale=(0.62, 1.45, 0.5), rot=(0, side * -10, 0), detail=2)
        S.ring(f"ElytreFilet{side}", "Indigo", 0.62, 0.04, o(0.52 * side, 0.25, 1.62), rot=(90, 0, 0), seg=16, sides=4)
    S.cyl("Cadran", "Ivoire", 0.62, 0.06, o(0, 0.1, 1.98), rot=(90, 0, 0), verts=24)
    S.ring("CadranBord", "Laiton", 0.64, 0.05, o(0, 0.1, 2.0), rot=(90, 0, 0), seg=24, sides=4)
    for h in range(12):
        a = 2 * math.pi * h / 12
        S.box(f"Heure{h}", "Metal", (0.05, 0.12 if h % 3 == 0 else 0.07, 0.03), o(0.5 * math.cos(a), 0.1 + 0.5 * math.sin(a), 2.03), rot=(0, 0, math.degrees(a) + 90), bevel=0)
    S.box("Aiguille1", "Metal", (0.05, 0.42, 0.03), o(0.05, 0.25, 2.05), rot=(0, 0, -20), bevel=0)
    S.box("Aiguille2", "Metal", (0.04, 0.3, 0.03), o(-0.1, 0.0, 2.05), rot=(0, 0, 60), bevel=0)
    S.sphere("Axe", "Noyau", 0.08, o(0, 0.1, 2.06))
    # Ailes en rouages, entrouvertes
    for side in (-1, 1):
        S.gear(f"AileRouage{side}", "Laiton", 0.75, 0.05, 14, o(1.15 * side, 0.6, 1.9), rot=(0, side * 35, side * 20))
        S.gear(f"AileRouagePetit{side}", "Acier", 0.4, 0.05, 10, o(1.5 * side, 1.15, 2.05), rot=(0, side * 35, side * 20))
    # Tête, mandibules, antennes, yeux
    S.sphere("Tete", "Metal", 0.55, o(0, -1.55, 1.05), scale=(1.1, 0.9, 0.8), detail=1)
    for side in (-1, 1):
        S.crystal(f"Mandibule{side}", "Laiton", 0.09, 0.05, 0.6, o(0.28 * side, -2.05, 0.9), rot=(-80, 0, side * 25), sides=4)
        S.sphere(f"Oeil{side}", "Noyau", 0.14, o(0.36 * side, -1.9, 1.2))
        S.cyl(f"Antenne{side}", "Laiton", 0.025, 0.9, o(0.22 * side, -2.0, 1.6), rot=(-35, 0, side * 20), verts=5)
        S.sphere(f"AntenneBout{side}", "Noyau", 0.07, o(0.38 * side, -2.4, 1.98))
    # Six pattes articulées : hanche → genou (relevé) → pied au sol
    for side in (-1, 1):
        for k, y in enumerate((-0.8, 0.0, 0.8)):
            hip = Vector(o(0.85 * side, y, 0.95))
            knee = Vector(o(1.55 * side, y + (k - 1) * 0.25, 1.35))
            foot = Vector(o(1.95 * side, y + (k - 1) * 0.5, 0.05))
            segment(S, f"Femur{side}{k}", "Metal", hip, knee, 0.15)
            segment(S, f"Tibia{side}{k}", "Laiton", knee, foot, 0.12)
            S.sphere(f"Genou{side}{k}", "Laiton", 0.11, tuple(knee))
    return S.count


def raie(ox):
    S = fresh("Raie_Temps")
    o = lambda x, y, z: (ox + x, y, z)
    H = 3.2  # hauteur de vol
    S.sphere("Corps", "Indigo", 1.0, o(0, 0, H), scale=(1.1, 1.7, 0.35), detail=2)
    # Ailes : trois couches de plaques superposées par côté
    for side in (-1, 1):
        for layer in range(3):
            span = 3.6 - layer * 0.7
            S.box(f"Aile{side}{layer}", "Indigo" if layer != 1 else "Metal",
                  (span, 1.8 - layer * 0.35, 0.08), o(side * (0.9 + span / 2 - 0.3), 0.2 + layer * 0.25, H + 0.02 * layer),
                  rot=(0, side * (-8 - layer * 4), side * (12 + layer * 6)), bevel=0.03, taper=(1, 1))
            S.box(f"AileBord{side}{layer}", "Noyau", (span * 0.9, 0.05, 0.05),
                  o(side * (0.9 + span / 2 - 0.3), -0.65 + layer * 0.4, H + 0.06 + 0.02 * layer),
                  rot=(0, side * (-8 - layer * 4), side * (12 + layer * 6)), bevel=0)
        S.crystal(f"Corne{side}", "Ivoire", 0.08, 0.05, 0.7, o(0.45 * side, -1.75, H), rot=(-90, 0, side * -15), sides=4)
        S.sphere(f"Oeil{side}", "Noyau", 0.11, o(0.45 * side, -1.35, H + 0.22))
    # Queue : anneaux de laiton qui rapetissent, pointe de cristal
    for i in range(7):
        r = 0.22 - i * 0.022
        S.ring(f"QueueAnneau{i}", "Laiton", r, 0.04, o(0, 1.7 + i * 0.42, H - i * 0.05), seg=10, sides=4)
        S.cyl(f"QueueSegment{i}", "Metal", r * 0.6, 0.38, o(0, 1.9 + i * 0.42, H - i * 0.05), verts=6)
    S.crystal("QueuePointe", "Cristal", 0.12, 0.08, 0.6, o(0, 4.85, H - 0.38), rot=(-90, 0, 0), sides=5)
    # Sablier sur le dos
    S.cyl("SablierBas", "Laiton", 0.32, 0.08, o(0, 0.25, H + 0.35), rot=(90, 0, 0), verts=8)
    S.cyl("SablierHaut", "Laiton", 0.32, 0.08, o(0, 0.25, H + 1.15), rot=(90, 0, 0), verts=8)
    S.crystal("SablierVerre1", "Noyau", 0.26, 0.0, 0.36, o(0, 0.25, H + 1.12), sides=8)
    S.crystal("SablierVerre2", "Noyau", 0.26, 0.36, 0.0, o(0, 0.25, H + 0.38), sides=8)
    for k in range(3):
        a = 2 * math.pi * k / 3
        S.cyl(f"SablierMontant{k}", "Laiton", 0.03, 0.8, o(0.3 * math.cos(a), 0.25 + 0.3 * math.sin(a), H + 0.75), rot=(90, 0, 0), verts=5)
    # Ventre lumineux
    for i in range(3):
        S.box(f"Ventre{i}", "Noyau", (0.9 - i * 0.2, 0.06, 0.03), o(0, -0.5 + i * 0.5, H - 0.33), bevel=0)
    return S.count


def build_all():
    return {"Loup_Cristal": loup(20), "Scarabee_Horloge": scarabee(28), "Raie_Temps": raie(36)}


def export_all():
    results = {}
    for name, ox in (("Loup_Cristal", 20), ("Scarabee_Horloge", 28), ("Raie_Temps", 36)):
        out = os.path.join(HERE, name + ".fbx")
        parts, tris = LIB["export_by_material"](name, name, out, origin=(ox, 0, 0))
        results[name] = (tris, list(parts))
    return results


if __name__ == "__main__":
    print(build_all(), export_all())
