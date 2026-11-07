# Fusil du Zénith (sniper, v0.4.12) — modèle construit par script dans Blender.
# Original, inspiré d'un style « arme de prestige » (indigo, filigrane de laiton, ivoire) et de
# l'univers de FRACTURE : lentille-cadran d'horloge, rouage, cristal de Temps.
# Origine = poignée. -Y = canon. Détails visibles à la caméra d'épaule côté -X.
import math
import os
import runpy

import bpy

HERE = os.path.dirname(os.path.abspath(__file__)) if "__file__" in globals() else r"C:\Users\neost\Documents\Fracture\assets\blender\weapons"
LIB = runpy.run_path(os.path.join(HERE, "..", "lib", "fracture_shapes.py"))


def build():
    old = bpy.data.collections.get("Fusil_Zenith")
    if old:
        for o in list(old.objects):
            bpy.data.objects.remove(o, do_unlink=True)
        bpy.data.collections.remove(old)
    S = LIB["Shapes"]("Fusil_Zenith")

    # Poignée et crosse --------------------------------------------------------------------
    S.box("Poignee", "Indigo", (0.17, 0.22, 0.5), (0, 0.06, -0.14), rot=(-14, 0, 0), bevel=0.03)
    S.box("PoigneeTalon", "Laiton", (0.19, 0.24, 0.05), (0, 0.11, -0.4), rot=(-14, 0, 0))
    S.box("Crosse", "Indigo", (0.2, 0.86, 0.36), (0, 0.6, 0.06), bevel=0.04, taper=(1, 0.85))
    S.box("CrosseJoue", "Ivoire", (0.03, 0.62, 0.2), (-0.105, 0.62, 0.1), bevel=0.01)
    S.box("CrosseJoueD", "Ivoire", (0.03, 0.62, 0.2), (0.105, 0.62, 0.1), bevel=0.01)
    S.box("Plaque", "Laiton", (0.22, 0.06, 0.4), (0, 1.05, 0.05), bevel=0.015)
    for i, y in enumerate((0.3, 0.9)):
        S.box(f"CrosseFilet{i}", "Laiton", (0.215, 0.025, 0.37), (0, y, 0.06), bevel=0)

    # Carcasse ---------------------------------------------------------------------------------
    S.box("Carcasse", "Indigo", (0.26, 1.15, 0.34), (0, -0.4, 0.2), bevel=0.035)
    S.box("CarcasseFiletHaut", "Laiton", (0.265, 1.1, 0.03), (0, -0.4, 0.37), bevel=0)
    S.box("CarcasseFiletBas", "Laiton", (0.265, 1.1, 0.03), (0, -0.4, 0.03), bevel=0)
    S.box("Chargeur", "Indigo", (0.15, 0.24, 0.34), (0, -0.55, -0.12), rot=(8, 0, 0), bevel=0.02)
    S.box("ChargeurPied", "Laiton", (0.17, 0.26, 0.04), (0, -0.53, -0.3), rot=(8, 0, 0))
    S.ring("PonteDetente", "Laiton", 0.1, 0.02, (0, -0.16, -0.05), rot=(0, 0, 90), seg=12, sides=4)
    S.box("Detente", "Metal", (0.03, 0.04, 0.1), (0, -0.14, -0.04), rot=(-20, 0, 0), bevel=0)
    # Levier de culasse, côté visible (-X)
    S.cyl("Levier", "Laiton", 0.025, 0.2, (-0.22, -0.02, 0.27), rot=(0, 0, 90), verts=6)
    S.sphere("LevierBoule", "Laiton", 0.05, (-0.33, -0.02, 0.27))
    # Noyau de Temps serti, côté visible
    S.ring("NoyauSerti", "Laiton", 0.11, 0.022, (-0.135, -0.5, 0.2), rot=(0, 0, 90), seg=16, sides=4)
    S.sphere("Noyau", "Noyau", 0.085, (-0.14, -0.5, 0.2), scale=(0.6, 1, 1))
    # Filigrane : petites volutes de laiton sur le flanc visible
    for i, (y, z) in enumerate(((-0.12, 0.27), (-0.82, 0.27), (-0.82, 0.13))):
        S.ring(f"Volute{i}", "Laiton", 0.045, 0.012, (-0.132, y, z), rot=(0, 0, 90), seg=10, sides=3)

    # Garde-main octogonal ---------------------------------------------------------------------
    S.cyl("GardeMain", "Indigo", 0.155, 1.25, (0, -1.6, 0.2), verts=8)
    for i, y in enumerate((-1.0, -1.6, -2.2)):
        S.cyl(f"GardeBande{i}", "Laiton", 0.168, 0.06, (0, y, 0.2), verts=8)
    S.box("GardePlaqueG", "Ivoire", (0.02, 0.5, 0.12), (-0.15, -1.3, 0.2), bevel=0.005)
    S.box("GardePlaqueG2", "Ivoire", (0.02, 0.5, 0.12), (-0.15, -1.9, 0.2), bevel=0.005)
    S.box("GardePlaqueD", "Ivoire", (0.02, 1.1, 0.12), (0.15, -1.6, 0.2), bevel=0.005)
    for i, y in enumerate((-1.3, -1.9)):
        S.box(f"GardeLumiere{i}", "Noyau", (0.012, 0.3, 0.03), (-0.163, y, 0.2), bevel=0)

    # Canon et frein de bouche ---------------------------------------------------------------
    S.cyl("Canon", "Metal", 0.065, 1.55, (0, -2.98, 0.22), verts=10)
    for i, y in enumerate((-2.55, -3.05, -3.45)):
        S.cyl(f"CanonBague{i}", "Laiton", 0.08, 0.04, (0, y, 0.22), verts=10)
    S.cyl("Frein", "Laiton", 0.11, 0.32, (0, -3.86, 0.22), verts=8)
    S.cyl("FreinNoyau", "Noyau", 0.07, 0.34, (0, -3.86, 0.22), verts=8)
    for i, x in enumerate((-0.112, 0.112)):
        S.box(f"FreinFente{i}", "Metal", (0.02, 0.16, 0.06), (x, -3.86, 0.22), bevel=0)

    # Lunette ----------------------------------------------------------------------------------
    for i, y in enumerate((-0.18, -0.82)):
        S.box(f"Montage{i}", "Laiton", (0.12, 0.12, 0.2), (0, y, 0.47), bevel=0.01)
        S.ring(f"Collier{i}", "Laiton", 0.125, 0.025, (0, y, 0.63), seg=12, sides=4)
    S.cyl("LunetteTube", "Indigo", 0.11, 1.15, (0, -0.55, 0.63), verts=12)
    S.cyl("LunetteOculaire", "Laiton", 0.13, 0.16, (0, 0.1, 0.63), verts=12, radius2=0.11)
    S.cyl("Objectif", "Indigo", 0.2, 0.3, (0, -1.3, 0.63), verts=8, radius2=0.13)
    S.ring("ObjectifLunette", "Laiton", 0.2, 0.03, (0, -1.46, 0.63), seg=8, sides=4)
    # Lentille-cadran d'horloge (lumineuse), avec repères et aiguilles
    S.cyl("Cadran", "Noyau", 0.165, 0.02, (0, -1.46, 0.63), verts=16)
    for h in range(12):
        a = 2 * math.pi * h / 12
        S.box(f"Repere{h}", "Laiton", (0.015, 0.012, 0.035 if h % 3 == 0 else 0.022),
              (0.13 * math.cos(a), -1.475, 0.63 + 0.13 * math.sin(a)), rot=(0, -math.degrees(a) + 90, 0), bevel=0)
    S.box("AiguilleHeure", "Laiton", (0.016, 0.012, 0.08), (0.02, -1.48, 0.66), rot=(0, -30, 0), bevel=0)
    S.box("AiguilleMinute", "Laiton", (0.012, 0.012, 0.12), (-0.03, -1.48, 0.68), rot=(0, 25, 0), bevel=0)
    # Rouage autour de l'objectif (pièce séparée : il tourne en jeu)
    S.gear("Rouage", "Laiton", 0.23, 0.035, 12, (0, -1.15, 0.63))
    # Cristal de Temps au-dessus de la lunette
    S.box("CristalSocle", "Laiton", (0.1, 0.18, 0.05), (0, -0.55, 0.76), bevel=0.01)
    S.crystal("Cristal", "Cristal", 0.07, 0.28, 0.06, (0, -0.55, 0.82), sides=6)
    S.crystal("CristalPetit1", "Cristal", 0.035, 0.13, 0.03, (0.06, -0.47, 0.8), rot=(0, 25, 0), sides=5)
    S.crystal("CristalPetit2", "Cristal", 0.035, 0.12, 0.03, (-0.06, -0.63, 0.8), rot=(0, -25, 0), sides=5)
    return S.count


def export():
    out = os.path.join(HERE, "Fusil_Zenith.fbx")
    parts, tris = LIB["export_by_material"]("Fusil_Zenith", "Fusil_Zenith", out, keep=("Rouage",))
    return out, parts, tris


if __name__ == "__main__":
    print(build(), export())
