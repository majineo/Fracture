# Rendus de revue de la maquette (v0.11.0). Usage : runpy.run_path(..., init_globals={"OUT": dossier})
# Vues : ensemble (silhouette et Vide), dessus orthographique (grille, bords, routes), gros plans.
import math
import os

import bpy
from mathutils import Vector

OUT = globals().get("OUT", r"C:\Users\neost\Documents\Fracture\build\rendus")
os.makedirs(OUT, exist_ok=True)
scene = bpy.context.scene


def setup():
    try:
        scene.render.engine = "BLENDER_EEVEE_NEXT"
    except TypeError:
        try:
            scene.render.engine = "BLENDER_EEVEE"
        except TypeError:
            pass
    scene.render.resolution_x, scene.render.resolution_y = 1600, 900
    scene.render.resolution_percentage = 100
    world = scene.world or bpy.data.worlds.new("Monde")
    scene.world = world
    world.use_nodes = True
    bg = next((n for n in world.node_tree.nodes if n.type == "BACKGROUND"), None)
    if bg:
        bg.inputs[0].default_value = (0.3, 0.42, 0.62, 1)  # ciel bleu / Vide
        bg.inputs[1].default_value = 0.45
    sun = bpy.data.objects.get("Revue_Soleil")
    if sun is None:
        data = bpy.data.lights.new("Revue_Soleil", "SUN")
        sun = bpy.data.objects.new("Revue_Soleil", data)
        scene.collection.objects.link(sun)
    sun.data.energy = 4.5
    sun.data.angle = math.radians(6)
    sun.rotation_euler = (math.radians(52), math.radians(8), math.radians(35))
    try:
        scene.view_settings.view_transform = "AgX"
    except TypeError:
        pass


def camera(name, location, target, lens=35, ortho=None):
    cam = bpy.data.objects.get(name)
    if cam is None:
        cam = bpy.data.objects.new(name, bpy.data.cameras.new(name))
        scene.collection.objects.link(cam)
    cam.location = Vector(location)
    direction = Vector(target) - cam.location
    cam.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    cam.data.lens = lens
    cam.data.clip_end = 5000
    if ortho:
        cam.data.type = "ORTHO"
        cam.data.ortho_scale = ortho
    else:
        cam.data.type = "PERSP"
    return cam


def shot(cam, filename):
    scene.camera = cam
    scene.render.filepath = os.path.join(OUT, filename)
    bpy.ops.render.render(write_still=True)
    return scene.render.filepath


def points(visible):
    coll = bpy.data.collections.get("Maquette_Points_de_jeu")
    if coll:
        coll.hide_render = not visible
        for child in coll.children:
            child.hide_render = not visible


setup()
VIEWS = globals().get("VIEWS", ["ensemble", "dessus", "donjon"])
done = []
for view in VIEWS:
    if view == "ensemble":
        points(False)
        done.append(shot(camera("Cam_Ensemble", (520, -640, 420), (0, 0, -20), lens=30), "01_ensemble.png"))
    elif view == "dessus":
        points(True)
        done.append(shot(camera("Cam_Dessus", (0, 0, 900), (0, 0, 0), ortho=700), "02_dessus_points.png"))
    elif view == "donjon":
        points(False)
        done.append(shot(camera("Cam_Donjon", (95, -120, 110), (0, 0, 8), lens=30), "03_donjon.png"))
    elif isinstance(view, tuple):
        name, loc, target, lens = view
        points(False)
        done.append(shot(camera("Cam_" + name, loc, target, lens=lens), name + ".png"))
RESULT = done
