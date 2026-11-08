# Rendu de revue du kit complet Fort_* (v0.12) : tous les modules alignés sur un sol sombre,
# même ambiance de crépuscule que la vignette (render_echantillon.py).
# Usage (Blender) : runpy.run_path(".../render_kit.py", init_globals={"OUT": dossier, "VIEWS": [...]})
import math
import os
import runpy

import bpy

HERE = os.path.dirname(os.path.abspath(__file__)) if "__file__" in globals() else r"C:\Users\neost\Documents\Fracture\assets\blender\fortress"
OUT = globals().get("OUT", r"C:\Users\neost\Documents\Fracture\build\rendus")
V = runpy.run_path(os.path.join(HERE, "render_echantillon.py"), init_globals={"OUT": OUT, "VIEWS": [], "BUILD_SET": False})
scene = bpy.context.scene

ROWS = [
    # (y, [(module, x)])
    (0, [("Fort_Donjon", 0)]),
    (-40, [("Fort_TourGuet", -38), ("Fort_GrandeMaison", -16), ("Fort_Maison", 2), ("Fort_Corps", 20), ("Fort_Tourelle", 38)]),
    (-62, [("Fort_Tourelle", -40), ("Fort_Mur", -31), ("Fort_MurFracture", -23), ("Fort_Porte", -14), ("Fort_Rempart", -5),
           ("Fort_Rempart", 3), ("Fort_Escalier", 14), ("Fort_Trebuchet", 27), ("Fort_Belier", 38)]),
    (-80, [("Fort_Barricade", -34), ("Fort_Chaudiere", -24), ("Fort_Horloge", -16), ("Fort_Cloche", -8), ("Fort_Puits", 0),
           ("Fort_Ratelier", 8), ("Fort_Sarcophage", 15), ("Fort_Cristal", 22), ("Fort_Etendard", 28), ("Fort_Eboulis", 35)]),
]


def build():
    old = bpy.data.collections.get("Revue_Kit")
    if old:
        for o in list(old.objects):
            bpy.data.objects.remove(o, do_unlink=True)
        bpy.data.collections.remove(old)
    coll = bpy.data.collections.new("Revue_Kit")
    scene.collection.children.link(coll)
    for c in list(scene.collection.children):
        if c.name.startswith("Fort_"):
            scene.collection.children.unlink(c)
        elif c.name != "Revue_Kit":
            c.hide_render = True
            c.hide_viewport = True
    for r, (y, row) in enumerate(ROWS):
        for module, x in row:
            e = V["place"](coll, module, (x, y, 0))
            e["rangee"] = r
    ground = V["material"]("Vignette_Sol", V["srgb"](0x1E242C), rough=1)

    def plane(bm):
        import bmesh

        bmesh.ops.create_grid(bm, x_segments=1, y_segments=1, size=200)

    V["mesh_obj"](coll, "Revue_Sol", ground, plane)
    V["light"](coll, "Revue_Lune", "SUN", (0.62, 0.78, 1.0), 3.5, (0, 0, 50), rot=(62, 0, 150))
    V["light"](coll, "Revue_Appoint", "SUN", (0.45, 0.7, 0.8), 0.6, (0, 0, 50), rot=(35, 0, -25))
    return coll


build()
V["setup_render"]()
fog = bpy.data.objects.get("Vignette_Brume")
if fog:
    bpy.data.collections["Revue_Kit"].objects.link(fog) if fog.name not in bpy.data.collections["Revue_Kit"].objects else None
# une vue par rangée (les autres rangées masquées) : (rangée, caméra, cible, focale)
CAMS = {
    "kit_donjon": (0, (-44, -62, 14), (0, 0, 30), 26),
    "kit_batiments": (1, (-6, -92, 12), (0, -40, 12), 28),
    "kit_murs": (2, (-4, -98, 8), (2, -62, 6), 30),
    "kit_decor": (3, (0, -104, 7), (0, -80, 3), 30),
}
done = []
for view in globals().get("VIEWS", list(CAMS)):
    row, loc, tgt, lens = CAMS[view]
    for o in bpy.data.collections["Revue_Kit"].objects:
        if "rangee" in o:
            o.hide_render = o["rangee"] != row
    done.append(V["shot"](V["camera"]("Revue_" + view, loc, tgt, lens), f"{view}.png"))
RESULT = done
