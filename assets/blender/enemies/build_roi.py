# Armure du Roi Sans Heure (Gardien, v0.8.0) : couronne, plastron, cape, épaulières, ceinture,
# jambières, modélisés autour d'un R15 debout (racine à l'origine, échelle 1 : le jeu agrandit ×3).
# Usage (Blender) : runpy.run_path(".../assets/blender/enemies/build_roi.py")
# Repère : Roblox (X, Y, Z) = Blender (-x, z, y) ; l'avant du personnage est -Y dans Blender.
# Export : une pièce par (partie du corps, matériau), nommée « <Partie>__<Matériau> » : le jeu la
# soude à la partie du corps de ce nom (EnemyService.dressOutfit). Sortie : Roi_Equipement.fbx.
import math
import os
import runpy

import bmesh
import bpy
from mathutils import Matrix

HERE = os.path.dirname(os.path.abspath(__file__))
LIB = runpy.run_path(os.path.join(HERE, "..", "lib", "fracture_shapes.py"))
Shapes = LIB["Shapes"]
MATERIALS = LIB["MATERIALS"]

for key in ("Laiton", "Acier", "Metal", "Indigo", "Cristal", "Cuir"):
    if bpy.data.materials.get(MATERIALS[key]) is None:
        bpy.data.materials.new(MATERIALS[key])

COLL = "Roi_Equipement"


def rb(x, y, z):
    """Position Roblox (relative à la racine) → Blender."""
    return (-x, z, y)


def fresh():
    old = bpy.data.collections.get(COLL)
    if old:
        for o in list(old.objects):
            bpy.data.objects.remove(o, do_unlink=True)
        bpy.data.collections.remove(old)
    return Shapes(COLL)


def tag(obj, body):
    obj["fracture_body"] = body
    return obj


def build():
    S = fresh()
    # Couronne : anneau, 6 fleurons, gemmes. Tête : centre (0, 1.59, 0), 1.16 de large.
    head_top = 1.59 + 0.45
    tag(S.cyl("Couronne_Anneau", "Laiton", 0.66, 0.26, rb(0, head_top, 0), rot=(90, 0, 0), verts=16), "Head")
    for i in range(6):
        a = i / 6 * math.tau
        x, z = math.cos(a) * 0.58, math.sin(a) * 0.58
        tag(S.box(f"Couronne_Fleuron_{i}", "Laiton", (0.18, 0.12, 0.42), rb(x, head_top + 0.3, z),
                  rot=(0, 0, -math.degrees(a) + 90), bevel=0.02, taper=(0.3, 1.0)), "Head")
        if i % 2 == 0:
            tag(S.crystal(f"Couronne_Gemme_{i}", "Cristal", 0.09, 0.12, 0.08,
                          rb(math.cos(a) * 0.67, head_top, math.sin(a) * 0.67)), "Head")
    # Plastron (torse 1.94 × 1.70 × 1.00) et col.
    tag(S.box("Plastron", "Acier", (2.08, 1.16, 1.62), rb(0, 0.22, 0), bevel=0.06), "UpperTorso")
    tag(S.box("Plastron_Arete", "Laiton", (0.16, 0.08, 1.4), rb(0, 0.22, -0.6), bevel=0), "UpperTorso")
    tag(S.box("Col", "Metal", (1.3, 0.9, 0.3), rb(0, 1.1, 0), bevel=0.04), "UpperTorso")
    # Cape royale, du haut du dos aux mollets.
    tag(S.box("Cape", "Indigo", (2.2, 0.08, 3.2), rb(0, -0.95, 0.58), rot=(-6, 0, 0), bevel=0), "UpperTorso")
    tag(S.box("Cape_Agrafe", "Laiton", (2.0, 0.12, 0.16), rb(0, 0.9, 0.52), bevel=0), "UpperTorso")
    # Épaulières (bras : centre ±1.5, 0.37).
    for side, body in ((-1, "LeftUpperArm"), (1, "RightUpperArm")):
        tag(S.sphere(f"Epauliere_{body}", "Acier", 0.72, rb(side * 1.55, 0.78, 0), scale=(1.0, 1.0, 0.7), detail=2), body)
        # Bordure couchée (anneau horizontal autour du bas du dôme).
        tag(S.ring(f"Epauliere_Bord_{body}", "Laiton", 0.66, 0.06, rb(side * 1.55, 0.6, 0), rot=(90, 0, 0), seg=14, sides=4), body)
    # Ceinture et tassettes (bas du torse : 0, -0.80).
    tag(S.box("Ceinture", "Cuir", (2.12, 1.1, 0.34), rb(0, -0.78, 0), bevel=0.02), "LowerTorso")
    tag(S.box("Boucle", "Laiton", (0.4, 0.1, 0.3), rb(0, -0.78, -0.56), bevel=0.02), "LowerTorso")
    for i, x in enumerate((-0.55, 0.0, 0.55)):
        tag(S.box(f"Tassette_{i}", "Acier", (0.52, 0.1, 0.62), rb(x, -1.15, -0.53), rot=(8, 0, 0), bevel=0.02), "LowerTorso")
    # Jambières (bas des jambes : ±0.5, -2.20).
    for side, body in ((-1, "LeftLowerLeg"), (1, "RightLowerLeg")):
        tag(S.box(f"Jambiere_{body}", "Acier", (1.06, 1.04, 1.2), rb(side * 0.5, -2.15, 0), bevel=0.05), body)
        tag(S.box(f"Genouillere_{body}", "Laiton", (0.6, 0.2, 0.42), rb(side * 0.5, -1.55, -0.5), bevel=0.04), body)


def export(path):
    coll = bpy.data.collections[COLL]
    depsgraph = bpy.context.evaluated_depsgraph_get()
    groups = {}
    for obj in coll.objects:
        key = (obj["fracture_body"], obj["fracture_mat"])
        groups.setdefault(key, []).append(obj)
    exp_name = COLL + "_Export"
    old = bpy.data.collections.get(exp_name)
    if old:
        for o in list(old.objects):
            bpy.data.objects.remove(o, do_unlink=True)
        bpy.data.collections.remove(old)
    exp = bpy.data.collections.new(exp_name)
    bpy.context.scene.collection.children.link(exp)
    made = []
    for (body, mat), objs in groups.items():
        bm = bmesh.new()
        for obj in objs:
            ev = obj.evaluated_get(depsgraph)
            mesh = ev.to_mesh()
            mesh.transform(obj.matrix_world)
            bm.from_mesh(mesh)
            ev.to_mesh_clear()
        name = f"{body}__{mat}"
        mesh = bpy.data.meshes.new(name)
        bm.to_mesh(mesh)
        bm.free()
        joined = bpy.data.objects.new(name, mesh)
        joined.data.materials.append(bpy.data.materials[MATERIALS[mat]])
        exp.objects.link(joined)
        made.append(joined)
    bpy.ops.object.select_all(action="DESELECT")
    for obj in made:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = made[0]
    bpy.ops.export_scene.fbx(
        filepath=path, use_selection=True, object_types={"MESH"}, use_mesh_modifiers=True,
        mesh_smooth_type="FACE", apply_unit_scale=True, global_scale=1.0,
        axis_forward="-Z", axis_up="Y", bake_space_transform=True, add_leaf_bones=False,
    )
    tris = {o.name: sum(len(p.vertices) - 2 for p in o.data.polygons) for o in made}
    return tris


build()
RESULT = export(os.path.join(HERE, "Roi_Equipement.fbx"))
