# Vignette de revue de l'échantillon de style (v0.12) : assemble les modules Fort_* en un tronçon
# de rempart (tours, courtines, porte, sols, cristal) et rend des vues d'ambiance au crépuscule.
# Usage (Blender) : runpy.run_path(".../render_echantillon.py", init_globals={"OUT": dossier, "VIEWS": [...]})
import math
import os
import random

import bpy
from mathutils import Vector

OUT = globals().get("OUT", r"C:\Users\neost\Documents\Fracture\build\rendus")
os.makedirs(OUT, exist_ok=True)
scene = bpy.context.scene
SET = "Echantillon_Vignette"


def srgb(h):
    r, g, b = (((h >> s) & 255) / 255 for s in (16, 8, 0))
    return (r ** 2.2, g ** 2.2, b ** 2.2, 1)


def reset_set():
    old = bpy.data.collections.get(SET)
    if old:
        for o in list(old.objects):
            bpy.data.objects.remove(o, do_unlink=True)
        bpy.data.collections.remove(old)
    coll = bpy.data.collections.new(SET)
    scene.collection.children.link(coll)
    # les modules sources restent dans le fichier mais hors de la scène (on les instancie)
    for c in list(scene.collection.children):
        if c.name.startswith("Fort_"):
            scene.collection.children.unlink(c)
        elif c.name != SET:
            c.hide_render = True
            c.hide_viewport = True
    return coll


def place(coll, module, loc, rotz=0):
    src = bpy.data.collections[module]
    e = bpy.data.objects.new(f"{module}@{loc[0]:.0f},{loc[1]:.0f}", None)
    e.instance_type = "COLLECTION"
    e.instance_collection = src
    e.location = loc
    e.rotation_euler = (0, 0, math.radians(rotz))
    coll.objects.link(e)
    return e


def material(name, color, emit=0.0, rough=0.9):
    mat = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = color
    bsdf.inputs["Roughness"].default_value = rough
    for socket in ("Emission Color", "Emission"):
        if socket in bsdf.inputs:
            bsdf.inputs[socket].default_value = color
    if "Emission Strength" in bsdf.inputs:
        bsdf.inputs["Emission Strength"].default_value = emit
    return mat


def mesh_obj(coll, name, mat, verts_fn):
    import bmesh

    bm = bmesh.new()
    verts_fn(bm)
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    obj.data.materials.append(mat)
    coll.objects.link(obj)
    return obj


def light(coll, name, kind, color, energy, loc, rot=(0, 0, 0), size=0.5):
    data = bpy.data.lights.new(name, kind)
    data.color = color
    data.energy = energy
    if kind == "SUN":
        data.angle = math.radians(1.5)
    else:
        data.shadow_soft_size = size
    obj = bpy.data.objects.new(name, data)
    obj.location = loc
    obj.rotation_euler = tuple(math.radians(a) for a in rot)
    coll.objects.link(obj)
    return obj


def build_set():
    coll = reset_set()
    rng = random.Random(21)
    # Rempart : tour – courtine fissurée – courtine – PORTE – courtine – courtine – tour
    for x, mod in ((-27, "Fort_Tour"), (-17, "Fort_MurFracture"), (-9, "Fort_Mur"), (0, "Fort_Porte"),
                   (9, "Fort_Mur"), (17, "Fort_Mur"), (27, "Fort_Tour")):
        place(coll, mod, (x, 0, 0))
    # Sols devant le rempart : chaussée pavée vers la porte, dalles ailleurs, un platelage, des marches
    for gx in range(-4, 5):
        for gy in range(1, 6):
            x, y = gx * 8, -2 - gy * 8 + 4
            if gx == 0:
                mod = "Fort_Pave"
            elif (gx, gy) in ((-2, 2), (-1, 3)):
                mod = "Fort_DalleFissure"
            elif (gx, gy) in ((2, 2), (3, 2), (2, 3), (3, 3)):
                mod = "Fort_Plancher"
            else:
                mod = "Fort_Dalle"
            place(coll, mod, (x, y, 0), rotz=rng.choice((0, 90, 180, 270)) if mod == "Fort_Dalle" else 0)
    place(coll, "Fort_Marches", (20, -1.5 - 8 * 3.5, 0), rotz=0)
    place(coll, "Fort_Cristal", (-14, -15, 0.5))
    place(coll, "Fort_Cristal", (-31, -9, 0.5), rotz=140)
    # Terrain au-delà : sol sombre et Vide
    ground = material("Vignette_Sol", srgb(0x1E242C), rough=1)

    def plane(bm):
        import bmesh

        bmesh.ops.create_grid(bm, x_segments=1, y_segments=1, size=160)

    g = mesh_obj(coll, "Vignette_Sol", ground, plane)
    g.location = (0, 0, 0.05)
    # Lune, îlots flottants à l'horizon (références : ruines suspendues)
    moon = material("Vignette_Lune", (0.85, 0.95, 1.0, 1), emit=6)
    m = mesh_obj(coll, "Vignette_Lune", moon, lambda bm: __import__("bmesh").ops.create_icosphere(bm, subdivisions=3, radius=14))
    m.location = (-70, 260, 120)
    rock = material("Vignette_Roc", srgb(0x2A303A), rough=1)
    glow = material("Vignette_Eclat", srgb(0x50E6FF), emit=8, rough=0.2)
    for i, (x, y, z, s) in enumerate(((-90, 180, 55, 12), (60, 210, 70, 16), (130, 150, 40, 8), (-30, 140, 85, 6))):
        def islet(bm, seed=i):
            import bmesh

            rr = random.Random(seed)
            bmesh.ops.create_icosphere(bm, subdivisions=2, radius=1)
            for v in bm.verts:
                k = 1 + rr.uniform(-0.18, 0.18)
                if v.co.z > 0:
                    v.co.z *= 0.25  # dessus presque plat
                else:
                    v.co.z *= 1.7  # dessous effilé en pointe
                    v.co.x *= 0.6 + 0.4 * (1 + v.co.z / 1.7)
                    v.co.y *= 0.6 + 0.4 * (1 + v.co.z / 1.7)
                v.co *= k

        r = mesh_obj(coll, f"Vignette_Ilot{i}", rock, islet)
        r.location = (x, y, z)
        r.scale = (s, s * 0.8, s)
        r.rotation_euler = (0, 0, rng.uniform(0, 3))
        c = mesh_obj(coll, f"Vignette_IlotEclat{i}", glow, lambda bm: __import__("bmesh").ops.create_cone(
            bm, cap_ends=True, segments=5, radius1=0.0, radius2=0.25, depth=1.4))
        c.location = (x, y, z - s * 1.2)
        c.scale = (s, s, s)
    # Lumières : lune froide en contre-jour, appoint du ciel, lanternes chaudes, lueurs cyan
    light(coll, "Vignette_Lune_Lumiere", "SUN", (0.62, 0.78, 1.0), 3.5, (0, 0, 50), rot=(62, 0, 150))
    light(coll, "Vignette_Appoint", "SUN", (0.45, 0.7, 0.8), 0.45, (0, 0, 50), rot=(35, 0, -25))
    light(coll, "Vignette_LanternePorte", "POINT", (1.0, 0.6, 0.25), 600, (3.9, -3.4, 3.8), size=0.3)
    light(coll, "Vignette_LanterneTour", "POINT", (1.0, 0.6, 0.25), 260, (-29.4, -7, 16.5), size=0.3)
    light(coll, "Vignette_Brasero", "POINT", (1.0, 0.55, 0.2), 1500, (12, -10, 2.2), size=0.8)
    light(coll, "Vignette_Cristal", "POINT", (0.3, 0.9, 1.0), 2000, (-14, -15, 3.5), size=1)
    light(coll, "Vignette_Faille", "POINT", (0.3, 0.9, 1.0), 700, (-17, -3.5, 7), size=1)
    light(coll, "Vignette_Rosace", "POINT", (0.3, 0.9, 1.0), 300, (-27, -8, 26.5), size=1)
    light(coll, "Vignette_Rosace2", "POINT", (0.3, 0.9, 1.0), 300, (27, -8, 26.5), size=1)
    return coll


def setup_render():
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
    nt = world.node_tree
    for n in list(nt.nodes):
        nt.nodes.remove(n)
    out = nt.nodes.new("ShaderNodeOutputWorld")
    bg = nt.nodes.new("ShaderNodeBackground")
    coord = nt.nodes.new("ShaderNodeTexCoord")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    nt.links.new(coord.outputs["Generated"], sep.inputs[0])
    # Generated d'un monde = direction normalisée : z de 0 (horizon) à 1 (zénith)
    nt.links.new(sep.outputs["Z"], ramp.inputs["Fac"])
    ramp.color_ramp.elements[0].position = 0.0
    ramp.color_ramp.elements[0].color = srgb(0x4F8A90)  # horizon teal clair
    ramp.color_ramp.elements[1].position = 0.7
    ramp.color_ramp.elements[1].color = srgb(0x0B1A24)  # zénith sombre
    mid = ramp.color_ramp.elements.new(0.22)
    mid.color = srgb(0x1E4652)
    nt.links.new(ramp.outputs["Color"], bg.inputs["Color"])
    bg.inputs["Strength"].default_value = 0.75
    nt.links.new(bg.outputs["Background"], out.inputs["Surface"])
    # Brume : cube de volume autour du décor (un volume de monde masquerait tout le ciel dans EEVEE)
    fog = bpy.data.objects.get("Vignette_Brume")
    if fog is None:
        import bmesh

        bm = bmesh.new()
        bmesh.ops.create_cube(bm, size=1)
        mesh = bpy.data.meshes.new("Vignette_Brume")
        bm.to_mesh(mesh)
        bm.free()
        fog = bpy.data.objects.new("Vignette_Brume", mesh)
        bpy.data.collections[SET].objects.link(fog)
    fog.location = (0, 40, 40)
    fog.scale = (420, 420, 90)
    fmat = bpy.data.materials.get("Vignette_Brume") or bpy.data.materials.new("Vignette_Brume")
    fmat.use_nodes = True
    fnt = fmat.node_tree
    for n in list(fnt.nodes):
        fnt.nodes.remove(n)
    fout = fnt.nodes.new("ShaderNodeOutputMaterial")
    vol = fnt.nodes.new("ShaderNodeVolumePrincipled")
    vol.inputs["Color"].default_value = srgb(0x5E8F98)
    vol.inputs["Density"].default_value = 0.0012
    fnt.links.new(vol.outputs["Volume"], fout.inputs["Volume"])
    fog.data.materials.clear()
    fog.data.materials.append(fmat)
    try:
        scene.view_settings.view_transform = "AgX"
        scene.view_settings.look = "AgX - Medium High Contrast"
        scene.view_settings.exposure = 0.0
    except TypeError:
        pass
    eevee = scene.eevee
    for attr, val in (("use_shadows", True), ("use_raytracing", True), ("volumetric_end", 400),
                      ("volumetric_tile_size", "4"), ("taa_render_samples", 64)):
        try:
            setattr(eevee, attr, val)
        except (AttributeError, TypeError):
            pass
    # Halo lumineux (bloom) en post-traitement
    if hasattr(scene, "compositing_node_group"):  # Blender 5 : groupe de nœuds de composition
        ct = bpy.data.node_groups.get("Echantillon_Compo") or bpy.data.node_groups.new("Echantillon_Compo", "CompositorNodeTree")
        scene.compositing_node_group = ct
        if not ct.interface.items_tree:
            ct.interface.new_socket("Image", in_out="OUTPUT", socket_type="NodeSocketColor")
    else:
        scene.use_nodes = True
        ct = scene.node_tree
    for n in list(ct.nodes):
        ct.nodes.remove(n)
    rl = ct.nodes.new("CompositorNodeRLayers")
    glare = ct.nodes.new("CompositorNodeGlare")
    for attr, val in (("glare_type", "FOG_GLOW"), ("quality", "HIGH"), ("threshold", 0.9), ("size", 8)):
        try:
            setattr(glare, attr, val)
        except (AttributeError, TypeError):
            pass
    for key, val in (("Threshold", 0.9), ("Strength", 0.8), ("Size", 0.6)):
        if key in glare.inputs:
            try:
                glare.inputs[key].default_value = val
            except (TypeError, AttributeError):
                pass
    if "Type" in glare.inputs:
        try:
            glare.inputs["Type"].default_value = "Fog Glow"
        except (TypeError, AttributeError):
            pass
    out = ct.nodes.new("NodeGroupOutput") if hasattr(scene, "compositing_node_group") else ct.nodes.new("CompositorNodeComposite")
    ct.links.new(rl.outputs["Image"], glare.inputs["Image"])
    ct.links.new(glare.outputs["Image"], out.inputs[0])


def camera(name, location, target, lens=28):
    cam = bpy.data.objects.get(name)
    if cam is None:
        cam = bpy.data.objects.new(name, bpy.data.cameras.new(name))
        scene.collection.objects.link(cam)
    cam.location = Vector(location)
    cam.rotation_euler = (Vector(target) - cam.location).to_track_quat("-Z", "Y").to_euler()
    cam.data.lens = lens
    cam.data.clip_end = 2000
    cam.data.type = "PERSP"
    return cam


def shot(cam, filename):
    scene.camera = cam
    scene.render.filepath = os.path.join(OUT, filename)
    bpy.ops.render.render(write_still=True)
    return scene.render.filepath


CAMS = {
    "ensemble": (( -22, -58, 9), (2, 0, 13), 24),
    "porte": ((6, -22, 3.2), (0, 0, 7), 26),
    "faille": ((-8, -14, 5), (-17, -1, 7), 30),
    "tour": ((-12, -30, 2.0), (-27, 0, 24), 22),
}

if globals().get("BUILD_SET", True):
    build_set()
setup_render()
done = []
for view in globals().get("VIEWS", list(CAMS)):
    loc, tgt, lens = CAMS[view]
    done.append(shot(camera("Echantillon_" + view, loc, tgt, lens), f"echantillon_{view}.png"))
RESULT = done
