# Rendu d'aperçu rapproché d'une collection (contrôle visuel des modèles) — v0.4.12.
# preview(collection, out_png, views=[(azimut°, élévation°)], size=(w, h)) : une image par vue,
# caméra cadrée sur la boîte englobante, fond gris, lumière douce. Ne modifie pas la scène
# (caméra, lumières et réglages temporaires supprimés / restaurés).
import math
import os

import bpy
from mathutils import Vector


def _bounds(coll):
    pts = []
    for obj in coll.all_objects:
        if obj.type == "MESH":
            pts += [obj.matrix_world @ Vector(c) for c in obj.bound_box]
    lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    return (lo + hi) / 2, (hi - lo).length


def preview(collection, out_dir, views=((210, 15),), size=(900, 520), name="apercu"):
    scene = bpy.context.scene
    coll = bpy.data.collections[collection]
    center, diag = _bounds(coll)
    saved = {
        "camera": scene.camera,
        "x": scene.render.resolution_x,
        "y": scene.render.resolution_y,
        "pct": scene.render.resolution_percentage,
        "path": scene.render.filepath,
        "fmt": scene.render.image_settings.file_format,
        "transparent": scene.render.film_transparent,
    }
    hidden = {}
    for c in bpy.data.collections:
        if c.name != collection and not coll.user_of_id(c) if hasattr(coll, "user_of_id") else c.name != collection:
            hidden[c.name] = c.hide_render
            c.hide_render = True
    cam_data = bpy.data.cameras.new("QA_ApercuCam")
    cam_data.lens = 60
    cam = bpy.data.objects.new("QA_ApercuCam", cam_data)
    scene.collection.objects.link(cam)
    light_data = bpy.data.lights.new("QA_ApercuSoleil", "SUN")
    light_data.energy = 3.5
    light = bpy.data.objects.new("QA_ApercuSoleil", light_data)
    light.rotation_euler = (math.radians(50), math.radians(10), math.radians(-40))
    scene.collection.objects.link(light)
    world = scene.world
    old_color = None
    if world and world.use_nodes:
        bg = next((n for n in world.node_tree.nodes if n.type == "BACKGROUND"), None)
        if bg:
            old_color = tuple(bg.inputs[0].default_value)
            bg.inputs[0].default_value = (0.25, 0.27, 0.32, 1)
    outputs = []
    try:
        scene.camera = cam
        scene.render.resolution_x, scene.render.resolution_y = size
        scene.render.resolution_percentage = 100
        scene.render.image_settings.file_format = "PNG"
        scene.render.film_transparent = False
        distance = diag * 1.7
        for i, (az, el) in enumerate(views):
            a, e = math.radians(az), math.radians(el)
            offset = Vector((math.cos(e) * math.cos(a), math.cos(e) * math.sin(a), math.sin(e))) * distance
            cam.location = center + offset
            direction = center - cam.location
            cam.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
            path = os.path.join(out_dir, f"{name}_{i}.png")
            scene.render.filepath = path
            bpy.ops.render.render(write_still=True)
            outputs.append(path)
    finally:
        scene.camera = saved["camera"]
        scene.render.resolution_x = saved["x"]
        scene.render.resolution_y = saved["y"]
        scene.render.resolution_percentage = saved["pct"]
        scene.render.filepath = saved["path"]
        scene.render.image_settings.file_format = saved["fmt"]
        scene.render.film_transparent = saved["transparent"]
        for cname, value in hidden.items():
            if cname in bpy.data.collections:
                bpy.data.collections[cname].hide_render = value
        if old_color and world:
            bg = next((n for n in world.node_tree.nodes if n.type == "BACKGROUND"), None)
            if bg:
                bg.inputs[0].default_value = old_color
        bpy.data.objects.remove(cam, do_unlink=True)
        bpy.data.cameras.remove(cam_data)
        bpy.data.objects.remove(light, do_unlink=True)
        bpy.data.lights.remove(light_data)
    return outputs
