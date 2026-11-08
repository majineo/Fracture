# Primitives de modélisation de FRACTURE pour Blender (bmesh, sans opérateurs) — v0.4.12.
# Usage (Blender) : ns = runpy.run_path(".../fracture_shapes.py"); S = ns["Shapes"]("MaCollection")
# Conventions : 1 unité = 1 stud ; -Y = avant de l'arme ; +Z = haut ; détails visibles à la
# caméra d'épaule côté -X. Une pièce = un objet ; matériau = suffixe utilisé à l'export.
import math

import bmesh
import bpy
from mathutils import Euler, Matrix, Vector

MATERIALS = {
    "Indigo": "Fracture_Indigo",
    "Ivoire": "Fracture_Ivoire",
    "Laiton": "Fracture_Laiton",
    "Metal": "Fracture_MetalSombre",
    "Noyau": "Fracture_NoyauCyan",
    "Cristal": "Fracture_CristalViolet",
    "Acier": "Fracture_Acier",
    "Cuir": "Fracture_Cuir",
    "Bois": "Fracture_Bois",
    "Fer": "Fracture_FerRouille",
    "Tissu": "Fracture_TissuRouge",
}


def _rotation(rot):
    return Euler(tuple(math.radians(a) for a in rot), "XYZ").to_matrix().to_4x4()


class Shapes:
    def __init__(self, collection_name):
        coll = bpy.data.collections.get(collection_name)
        if coll is None:
            coll = bpy.data.collections.new(collection_name)
            bpy.context.scene.collection.children.link(coll)
        self.coll = coll
        self.count = 0

    # Crée l'objet à partir d'un bmesh, avec matériau et chanfrein optionnel.
    def _finish(self, name, bm, mat, loc, rot, bevel):
        mesh = bpy.data.meshes.new(name)
        bm.to_mesh(mesh)
        bm.free()
        obj = bpy.data.objects.new(name, mesh)
        obj.data.materials.append(bpy.data.materials[MATERIALS.get(mat, mat)])
        obj.matrix_world = Matrix.Translation(Vector(loc)) @ _rotation(rot)
        for poly in mesh.polygons:
            poly.use_smooth = False
        if bevel and bevel > 0:
            mod = obj.modifiers.new("Bevel", "BEVEL")
            mod.width = bevel
            mod.segments = 1
            mod.limit_method = "ANGLE"
        self.coll.objects.link(obj)
        obj["fracture_mat"] = mat
        self.count += 1
        return obj

    def box(self, name, mat, size, loc, rot=(0, 0, 0), bevel=0.015, taper=None):
        bm = bmesh.new()
        bmesh.ops.create_cube(bm, size=1.0)
        for v in bm.verts:
            v.co.x *= size[0]
            v.co.y *= size[1]
            v.co.z *= size[2]
            # taper : (facteur X, facteur Z) appliqué à la face -Y (effilage vers l'avant)
            if taper and v.co.y < 0:
                v.co.x *= taper[0]
                v.co.z *= taper[1]
        return self._finish(name, bm, mat, loc, rot, bevel)

    # Cylindre le long de l'axe Y (canon, lunette…).
    def cyl(self, name, mat, radius, depth, loc, rot=(0, 0, 0), verts=12, radius2=None, bevel=0.0):
        bm = bmesh.new()
        bmesh.ops.create_cone(
            bm, cap_ends=True, cap_tris=False, segments=verts,
            radius1=radius, radius2=radius if radius2 is None else radius2, depth=depth,
        )
        bmesh.ops.rotate(bm, verts=bm.verts, cent=(0, 0, 0), matrix=Matrix.Rotation(math.radians(90), 3, "X"))
        return self._finish(name, bm, mat, loc, rot, bevel)

    # Anneau autour de l'axe Y.
    def ring(self, name, mat, major, minor, loc, rot=(0, 0, 0), seg=16, sides=6):
        bm = bmesh.new()
        rings = []
        for i in range(seg):
            a = 2 * math.pi * i / seg
            ring = []
            for j in range(sides):
                b = 2 * math.pi * j / sides
                r = major + minor * math.cos(b)
                ring.append(bm.verts.new((r * math.cos(a), minor * math.sin(b), r * math.sin(a))))
            rings.append(ring)
        for i in range(seg):
            for j in range(sides):
                a, b = rings[i], rings[(i + 1) % seg]
                bm.faces.new((a[j], b[j], b[(j + 1) % sides], a[(j + 1) % sides]))
        return self._finish(name, bm, mat, loc, rot, 0)

    # Cristal / éclat : bipyramide (pointes haut et bas), allongé selon Z.
    def crystal(self, name, mat, radius, up, down, loc, rot=(0, 0, 0), sides=6):
        bm = bmesh.new()
        mid = [bm.verts.new((radius * math.cos(2 * math.pi * i / sides), radius * math.sin(2 * math.pi * i / sides), 0)) for i in range(sides)]
        top = bm.verts.new((0, 0, up))
        bottom = bm.verts.new((0, 0, -down))
        for i in range(sides):
            a, b = mid[i], mid[(i + 1) % sides]
            bm.faces.new((a, b, top))
            bm.faces.new((b, a, bottom))
        return self._finish(name, bm, mat, loc, rot, 0)

    # Roue dentée plate (axe Y).
    def gear(self, name, mat, radius, thickness, teeth, loc, rot=(0, 0, 0), tooth=0.06):
        bm = bmesh.new()
        n = teeth * 2
        outer = []
        for i in range(n):
            a = 2 * math.pi * i / n
            r = radius + (tooth if i % 2 == 0 else 0)
            outer.append((r * math.cos(a), r * math.sin(a)))
        front = [bm.verts.new((x, -thickness / 2, z)) for x, z in outer]
        back = [bm.verts.new((x, thickness / 2, z)) for x, z in outer]
        bm.faces.new(front)
        bm.faces.new(list(reversed(back)))
        for i in range(n):
            j = (i + 1) % n
            bm.faces.new((front[i], back[i], back[j], front[j]))
        return self._finish(name, bm, mat, loc, rot, 0)

    def sphere(self, name, mat, radius, loc, scale=(1, 1, 1), rot=(0, 0, 0), detail=1):
        bm = bmesh.new()
        bmesh.ops.create_icosphere(bm, subdivisions=detail, radius=radius)
        for v in bm.verts:
            v.co.x *= scale[0]
            v.co.y *= scale[1]
            v.co.z *= scale[2]
        return self._finish(name, bm, mat, loc, rot, 0)


# Joint les pièces d'une collection par matériau dans une collection « <nom>_Export »
# (modificateurs appliqués) et exporte un FBX. `keep` : noms de pièces à garder à part.
def export_by_material(source_name, prefix, fbx_path, keep=(), origin=(0, 0, 0), scale=1.0):
    # scale = 0.01 : Studio lit les FBX de Blender en centimètres ; à 0,01, l'import par défaut
    # donne directement 1 unité Blender = 1 stud (v0.11.0, modules de la Cité).
    src = bpy.data.collections[source_name]
    export_name = source_name + "_Export"
    old = bpy.data.collections.get(export_name)
    if old:
        for o in list(old.objects):
            bpy.data.objects.remove(o, do_unlink=True)
        bpy.data.collections.remove(old)
    exp = bpy.data.collections.new(export_name)
    bpy.context.scene.collection.children.link(exp)
    depsgraph = bpy.context.evaluated_depsgraph_get()
    groups = {}
    for obj in src.objects:
        if obj.type != "MESH":
            continue
        key = obj.name if obj.name in keep else obj.get("fracture_mat", "Metal")
        groups.setdefault(key, []).append(obj)
    offset = Matrix.Translation(-Vector(origin))
    made = []
    for key, objs in groups.items():
        bm = bmesh.new()
        mat_name = None
        for obj in objs:
            evaluated = obj.evaluated_get(depsgraph)
            mesh = evaluated.to_mesh()
            mesh.transform(offset @ obj.matrix_world)
            bm.from_mesh(mesh)
            evaluated.to_mesh_clear()
            mat_name = MATERIALS.get(obj.get("fracture_mat", "Metal"))
        name = f"{prefix}_{key}" if key not in keep else f"{prefix}_{key}"
        mesh = bpy.data.meshes.new(name)
        bm.to_mesh(mesh)
        bm.free()
        joined = bpy.data.objects.new(name, mesh)
        joined.data.materials.append(bpy.data.materials[mat_name])
        exp.objects.link(joined)
        made.append(joined)
    bpy.ops.object.select_all(action="DESELECT")
    for obj in made:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = made[0]
    bpy.ops.export_scene.fbx(
        filepath=fbx_path, use_selection=True, object_types={"MESH"}, use_mesh_modifiers=True,
        mesh_smooth_type="FACE", apply_unit_scale=True, global_scale=scale,
        axis_forward="-Z", axis_up="Y", bake_space_transform=True, add_leaf_bones=False,
    )
    bpy.ops.object.select_all(action="DESELECT")
    tris = sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in made)
    return {o.name: sum(len(p.vertices) - 2 for p in o.data.polygons) for o in made}, tris
