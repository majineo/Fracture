# Kit de la forteresse gothique de l'Éclat (v0.12, échantillon de style).
# Usage (Blender) : runpy.run_path(".../assets/blender/fortress/build_fort_kit.py",
#                                  init_globals={"ONLY": None, "EXPORT": False})
# Direction : forteresse gothique sombre arrachée au temps (références dans le coffre Obsidian,
# Fracture/Environment/Art-Direction) — silhouettes franches, maçonnerie en assises, arcs brisés,
# énergie cyan INTÉGRÉE (failles, cristaux qui percent la pierre, éclats suspendus).
# Repère : 1 unité = 1 stud ; origine en bas au centre ; façade (extérieur) vers -Y ; +Z = haut.
# Export : une pièce par matériau, « <Module>_<Matériau> » (Server/Place/Lib/Kit applique les looks).
import math
import os
import random
import runpy

import bmesh
import bpy

HERE = os.path.dirname(os.path.abspath(__file__)) if "__file__" in globals() else r"C:\Users\neost\Documents\Fracture\assets\blender\fortress"
LIB = runpy.run_path(os.path.join(HERE, "..", "lib", "fracture_shapes.py"))
MATERIALS = LIB["MATERIALS"]

# Palette (Art-Direction, en sRGB ; convertie en linéaire). emission : force d'émission.
PALETTE = {
    "Pierre": ((0x4A, 0x53, 0x61), 0, 0.85),
    "PierreSombre": ((0x2E, 0x35, 0x40), 0, 0.9),
    "PierreClaire": ((0x8C, 0x93, 0xA0), 0, 0.8),
    "Ardoise": ((0x2F, 0x3E, 0x57), 0, 0.6),
    "Bois": ((0x5A, 0x3D, 0x27), 0, 0.8),
    "Fer": ((0x2A, 0x2D, 0x34), 0, 0.45),
    "Laiton": ((0xB0, 0x80, 0x3A), 0, 0.35),
    "Noyau": ((0x50, 0xE6, 0xFF), 3.0, 0.2),
    "Cristal": ((0x96, 0x5A, 0xF0), 3.0, 0.2),
    "Lumiere": ((0xFF, 0x9A, 0x3C), 8.0, 0.5),
    "Tissu": ((0x7A, 0x1F, 0x24), 0, 0.9),
    "Mousse": ((0x4E, 0x6B, 0x3A), 0, 0.95),
    "Origine": ((0x80, 0x80, 0x80), 0, 1.0),
}


def ensure_materials():
    for key, (rgb, emit, rough) in PALETTE.items():
        name = "Fort_" + key
        MATERIALS[key] = name
        mat = bpy.data.materials.get(name) or bpy.data.materials.new(name)
        lin = tuple((c / 255) ** 2.2 for c in rgb)
        mat.diffuse_color = (*lin, 1)
        mat.use_nodes = True
        bsdf = next((n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
        if bsdf:
            bsdf.inputs["Base Color"].default_value = (*lin, 1)
            bsdf.inputs["Roughness"].default_value = rough
            if key in ("Fer", "Laiton"):
                bsdf.inputs["Metallic"].default_value = 0.8
            for socket in ("Emission Color", "Emission"):
                if socket in bsdf.inputs:
                    bsdf.inputs[socket].default_value = (*lin, 1)
            if "Emission Strength" in bsdf.inputs:
                bsdf.inputs["Emission Strength"].default_value = emit


ensure_materials()


def fresh(name):
    old = bpy.data.collections.get(name)
    if old:
        for o in list(old.objects):
            bpy.data.objects.remove(o, do_unlink=True)
        bpy.data.collections.remove(old)
    return LIB["Shapes"](name)


def ribbon(S, name, mat, side_a, side_b, depth, y=0.0):
    """Bande extrudée en Y entre deux polylignes (x, z) de même longueur (arcs, failles)."""
    bm = bmesh.new()
    h = depth / 2
    fa = [bm.verts.new((x, y - h, z)) for x, z in side_a]
    fb = [bm.verts.new((x, y - h, z)) for x, z in side_b]
    ba = [bm.verts.new((x, y + h, z)) for x, z in side_a]
    bb = [bm.verts.new((x, y + h, z)) for x, z in side_b]
    for k in range(len(side_a) - 1):
        bm.faces.new((fa[k], fa[k + 1], fb[k + 1], fb[k]))
        bm.faces.new((ba[k + 1], ba[k], bb[k], bb[k + 1]))
        bm.faces.new((fa[k + 1], fa[k], ba[k], ba[k + 1]))
        bm.faces.new((fb[k], fb[k + 1], bb[k + 1], bb[k]))
    last = len(side_a) - 1
    bm.faces.new((fa[0], fb[0], bb[0], ba[0]))
    bm.faces.new((fa[last], ba[last], bb[last], fb[last]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return S._finish(name, bm, mat, (0, 0, 0), (0, 0, 0), 0)


def pointed_arch(span, radius, spring, steps=8):
    """Polyligne (x, z) d'un arc brisé : deux arcs de rayon `radius` qui se croisent au sommet."""
    off = radius - span / 2  # centre de chaque arc, de l'autre côté de l'axe
    apex = math.sqrt(radius * radius - off * off)
    left, right = [], []
    a0 = math.atan2(0, -span / 2 - off)  # du point de naissance gauche…
    a1 = math.atan2(apex, -off)  # …jusqu'au sommet (arc centré en x = +off)
    for k in range(steps + 1):
        a = a0 + (a1 - a0) * k / steps
        left.append((off + radius * math.cos(a), spring + radius * math.sin(a)))
    for x, z in reversed(left):
        right.append((-x, z))
    return left + right[1:], spring + apex


def masonry(S, prefix, x0, x1, z0, z1, y, rng, course=1.4, depth=0.35, mat="Pierre", skip=None, bevel=0.06,
            stone=(1.6, 2.6)):
    """Assises de pierres décalées sur une face (plan y), entre x0..x1 et z0..z1."""
    row = 0
    z = z0
    while z < z1 - 0.05:
        h = min(course, z1 - z)
        x = x0 - (stone[0] * 0.4 if row % 2 else 0)
        while x < x1 - 0.05:
            w = rng.uniform(*stone)
            a, b = max(x, x0), min(x + w, x1)
            roll = rng.random()
            if b - a > 0.3 and not (skip and skip((a + b) / 2, z + h / 2)) and roll > 0.04:
                # pierres patinées : teinte sombre aléatoire, saillie irrégulière, quelques manques
                jitter = rng.uniform(-0.12, 0.08)
                tint = "PierreSombre" if mat == "Pierre" and roll < 0.3 else mat
                S.box(f"{prefix}_{row}_{x:.1f}", tint, (b - a - 0.1, depth, h - 0.1),
                      ((a + b) / 2, y + jitter, z + h / 2), bevel=bevel)
            x += w
        z += h
        row += 1


# --- Murs ------------------------------------------------------------------------------------
def courtine(name="Fort_Mur", fracture=False, seed=1):
    """Courtine de 8 × 4 × 14 : soubassement, assises, rebord clair, deux merlons à meurtrière."""
    rng = random.Random(seed)
    S = fresh(name)
    W, D, H = 8, 4, 14
    S.box("Soubassement", "PierreSombre", (W, D + 0.6, 1.6), (0, 0, 0.8), bevel=0.1)
    S.box("Ame", "PierreSombre", (W - 0.02, D - 0.5, H - 2.4), (0, 0, 1.6 + (H - 2.4 - 1.6) / 2 + 0.4), bevel=0)
    crack = None
    if fracture:
        # Faille en zigzag du soubassement au chemin de ronde.
        pts = [(-0.6, 1.6), (0.4, 3.6), (-0.3, 5.8), (0.9, 7.6), (0.1, 9.6), (0.8, 11.6)]
        crack = pts

        def skip(x, z):
            for (ax, az), (bx, bz) in zip(pts, pts[1:]):
                if az <= z <= bz:
                    t = (z - az) / max(bz - az, 1e-3)
                    if abs(x - (ax + (bx - ax) * t)) < 0.9:
                        return True
            return False
    else:
        skip = None
    for side in (-1, 1):
        masonry(S, f"Assise{side}", -W / 2, W / 2, 1.6, H - 2.0, side * (D / 2 - 0.15), rng, skip=skip if side == -1 else None, bevel=0)
    # Chemin de ronde : rebord de pierre claire (indice d'escalade lisible)
    S.box("Rebord", "PierreClaire", (W, D + 0.4, 0.5), (0, 0, H - 1.75), bevel=0.08)
    S.box("Dallage", "Pierre", (W - 0.1, D - 0.8, 0.3), (0, 0.3, H - 1.4), bevel=0.04)
    # Merlons côté extérieur, avec meurtrière et chapeau
    for i, x in enumerate((-2, 2)):
        S.box(f"Merlon{i}", "Pierre", (2.6, 1.1, 2.0), (x, -D / 2 + 0.6, H - 0.5), bevel=0.08)
        S.box(f"MerlonChapeau{i}", "PierreClaire", (2.8, 1.3, 0.3), (x, -D / 2 + 0.6, H + 0.6), bevel=0.06, taper=(0.9, 1))
        S.box(f"Meurtriere{i}", "Fer", (0.25, 1.15, 1.1), (x, -D / 2 + 0.6, H - 0.4), bevel=0)
    # Corbeaux sous le rebord (silhouette)
    for i, x in enumerate((-3, -1, 1, 3)):
        S.box(f"Corbeau{i}", "PierreSombre", (0.6, 0.6, 0.7), (x, -D / 2 - 0.15, H - 2.3), bevel=0.05, taper=(1, 0.5))
    if fracture:
        # Fente lumineuse (deux bords de la faille) et cristaux qui percent la pierre
        inner = [(x - 0.18, z) for x, z in crack]
        outer = [(x + 0.18, z) for x, z in crack]
        ribbon(S, "Faille", "Noyau", inner, outer, 0.25, y=-D / 2 + 0.05)
        for i, (x, z, s, tilt) in enumerate(((-0.2, 4.2, 0.45, -25), (0.6, 8.2, 0.35, 30), (0.3, 10.6, 0.3, -15))):
            S.crystal(f"Eclat{i}", "Noyau", s, s * 3, s, (x, -D / 2 - 0.2, z), rot=(-70, tilt, 0), sides=5)
        S.crystal("Cristal", "Cristal", 0.3, 1.0, 0.3, (0.9, -D / 2 - 0.1, 6.6), rot=(-60, 40, 0), sides=5)
        mark(S, "Fx", "Faille", (0.2, -D / 2 - 0.4, 6.5), size=1.2, height=9.0)
        # Pierres arrachées qui flottent devant la faille
        for i in range(4):
            S.box(f"PierreSuspendue{i}", "Pierre", (0.7, 0.4, 0.5), (rng.uniform(-1.5, 1.5), -D / 2 - rng.uniform(0.8, 1.8), rng.uniform(3, 11)),
                  rot=(rng.uniform(0, 40), rng.uniform(0, 40), rng.uniform(0, 40)), bevel=0.05)
    return S


def porte(name="Fort_Porte"):
    """Porte à arc brisé de 10 de large (le passage du jeu), herse levée, larmier, pinacles."""
    S = fresh(name)
    W, D, H = 10, 4, 14
    spring, R0, R1 = 4.5, 6.4, 7.0
    off = R0 - 4.2  # passage de 8,4 ; arcs concentriques (mêmes centres) pour une épaisseur constante

    def arc(radius):
        return pointed_arch(2 * (radius - off), radius, spring)

    intrados, apex = arc(R0)
    extrados, apex_ext = arc(R1)
    ribbon(S, "Arc", "Pierre", intrados, extrados, D + 0.3)
    top = H - 2.0
    # Écoinçons : âme sombre entre l'extrados et les bords du module, jusqu'au chemin de ronde
    half = len(extrados) // 2
    for side in (-1, 1):
        pts = extrados[: half + 1] if side < 0 else list(reversed(extrados[half:]))
        edge_a = pts + [(0, top)]
        edge_b = [(side * W / 2, z) for _, z in pts] + [(side * W / 2, top)]
        ribbon(S, f"Ecoincon{side}", "PierreSombre", edge_a, edge_b, D - 0.5)

    def in_arch(x, z):
        if z >= apex_ext + 0.2:
            return False
        dz = max(z - spring, 0)
        if dz >= R1:
            return True
        return abs(x) < math.sqrt(R1 * R1 - dz * dz) - off + 0.25

    # Maçonnerie qui épouse l'arc (les pierres s'arrêtent sur l'extrados)
    rng = random.Random(7)
    masonry(S, "Tympan", -W / 2, W / 2, spring, top, -D / 2 + 0.15, rng, skip=in_arch)
    masonry(S, "TympanArr", -W / 2, W / 2, spring, top, D / 2 - 0.15, rng, skip=in_arch, bevel=0)
    for side in (-1, 1):
        # piédroits (jambages clairs) sous la naissance de l'arc
        S.box(f"Piedroit{side}", "Pierre", (0.8, D + 0.3, spring), (side * (W / 2 - 0.4), 0, spring / 2), bevel=0.05)
        S.box(f"Imposte{side}", "PierreClaire", (1.1, D + 0.5, 0.35), (side * (W / 2 - 0.45), 0, spring), bevel=0.04)
        # pinacles gothiques sur le chemin de ronde
        S.box(f"PinacleBase{side}", "Pierre", (1.4, 1.4, 1.6), (side * (W / 2 - 0.7), -D / 2 + 0.7, H - 1.0), bevel=0.06)
        S.crystal(f"Pinacle{side}", "PierreClaire", 0.7, 2.4, 0.01, (side * (W / 2 - 0.7), -D / 2 + 0.7, H + 0.2), sides=4)
    S.box("Rebord", "PierreClaire", (W, D + 0.4, 0.5), (0, 0, H - 1.75), bevel=0.08)
    S.box("Dallage", "Pierre", (W - 0.1, D - 0.8, 0.3), (0, 0.3, H - 1.4), bevel=0.04)
    # Larmier (moulure en arc au-dessus de l'extrados)
    hood_in, _ = arc(R1 + 0.05)
    hood_out, _ = arc(R1 + 0.4)
    ribbon(S, "Larmier", "PierreClaire", hood_in, hood_out, 0.5, y=-D / 2 - 0.2)
    # Clé de voûte avec un éclat de cristal serti
    S.box("Cle", "PierreClaire", (0.9, D + 0.5, 1.2), (0, 0, apex + 0.6), bevel=0.06, taper=(0.7, 1))
    S.crystal("CleCristal", "Noyau", 0.3, 0.6, 0.3, (0, -D / 2 - 0.35, apex + 0.6), rot=(-90, 0, 0), sides=6)
    # Herse levée (dents visibles sous l'arc, au-dessus du passage)
    for i in range(7):
        x = -3.0 + i * 1.0
        S.box(f"HerseBarreau{i}", "Fer", (0.18, 0.18, 3.0), (x, 0.4, apex - 1.9), bevel=0)
        S.crystal(f"HerseDent{i}", "Fer", 0.12, 0.01, 0.4, (x, 0.4, apex - 3.4), sides=4)
    for z in (apex - 1.0, apex - 2.4):
        S.box(f"HerseTraverse{z:.1f}", "Fer", (6.4, 0.16, 0.16), (0, 0.4, z), bevel=0)
    # Lanterne chaude sous l'arc (contraste avec le cyan)
    S.box("LanternePotence", "Fer", (0.12, 0.9, 0.12), (W / 2 - 0.4, -D / 2 - 0.45, 3.6), bevel=0)
    mark(S, "Pose", "Fort_Torche", (-W / 2 + 0.4, -D / 2 - 0.2, 2.6))
    mark(S, "Pose", "Fort_Torche", (W / 2 - 0.4, D / 2 + 0.2, 2.6), yaw=180)
    S.box("Lanterne", "Lumiere", (0.45, 0.45, 0.6), (W / 2 - 0.4, -D / 2 - 0.95, 3.25), bevel=0.04)
    S.box("LanterneToit", "Fer", (0.6, 0.6, 0.15), (W / 2 - 0.4, -D / 2 - 0.95, 3.6), bevel=0, taper=(0.5, 0.5))
    return S


def lancet(S, name, mat, x, z, width, height, y, depth=0.3, frame="PierreClaire"):
    """Fenêtre en lancette (arc brisé plein) sur le plan y, avec un encadrement clair."""
    arch, apex = pointed_arch(width, width * 0.9, z + height - width * 0.75, steps=5)
    fill = [(px + x, pz) for px, pz in arch]
    base = [(px + x, z) for px, _ in arch]
    ribbon(S, name, mat, base, fill, depth, y=y)
    outer = [(px * 1.35 + x, z + height - width * 0.75 + (pz - (z + height - width * 0.75)) * 1.25 + 0.15) for px, pz in arch]
    ribbon(S, name + "Cadre", frame, fill, outer, depth + 0.1, y=y)
    S.box(name + "Appui", frame, (width + 0.5, depth + 0.4, 0.25), (x, y - 0.1, z - 0.1), bevel=0.03)
    return apex


def tour(name="Fort_Tour", seed=11):
    """Tour carrée 12 × 12 × 34 : contreforts d'angle, cordons, lancettes, mâchicoulis, créneaux,
    toit d'ardoise très pentu avec flèche de laiton et rosace cyan. Silhouette dominante."""
    rng = random.Random(seed)
    S = fresh(name)
    W, H = 12, 34
    S.box("Soubassement", "PierreSombre", (W + 1.2, W + 1.2, 3), (0, 0, 1.5), bevel=0.12, taper=None)
    S.box("Fut", "PierreSombre", (W - 0.6, W - 0.6, H - 3), (0, 0, 3 + (H - 3) / 2), bevel=0)
    masonry(S, "Facade", -W / 2 + 0.9, W / 2 - 0.9, 3, H - 1, -W / 2 + 0.15, rng, course=1.6, depth=0.4, bevel=0.06)
    for side in (-1, 1):
        masonry(S, f"Flanc{side}", -W / 2 + 0.9, W / 2 - 0.9, 3, H - 1, 0, rng, course=1.6, depth=0.4, bevel=0)
    # les flancs : on tourne les assises créées ci-dessus (plan y=0) vers x = ±W/2
    for obj in list(S.coll.objects):
        if obj.name.startswith("Flanc"):
            side = -1 if obj.name.startswith("Flanc-1") else 1
            obj.location = (side * (W / 2 - 0.15), obj.location.x, obj.location.z)
            obj.rotation_euler = (obj.rotation_euler.x, obj.rotation_euler.y, math.radians(90))
    # contreforts d'angle en gradins
    for sx in (-1, 1):
        for sy in (-1, 1):
            for k, (h, s) in enumerate(((12, 2.4), (10, 1.9), (6, 1.4))):
                z0 = sum(v for v, _ in ((12, 0), (10, 0), (6, 0))[:k])
                S.box(f"Contrefort{sx}{sy}{k}", "Pierre", (s, s, h), (sx * (W / 2 + 0.2), sy * (W / 2 + 0.2), z0 + h / 2), bevel=0.08,
                      taper=None)
                S.box(f"ContrefortGlacis{sx}{sy}{k}", "PierreClaire", (s + 0.2, s + 0.2, 0.35), (sx * (W / 2 + 0.2), sy * (W / 2 + 0.2), z0 + h), bevel=0.04)
    # cordons (bandes claires) et lancettes
    for z in (12, 22):
        S.box(f"Cordon{z}", "PierreClaire", (W + 0.4, W + 0.4, 0.45), (0, 0, z), bevel=0.06)
    lancet(S, "Lancette0", "Fer", 0, 6.0, 1.4, 4.2, -W / 2 - 0.05)
    lancet(S, "Lancette1", "Lumiere", -2.4, 14.5, 1.2, 4.6, -W / 2 - 0.05)
    lancet(S, "Lancette2", "Fer", 2.4, 14.5, 1.2, 4.6, -W / 2 - 0.05)
    for side in (-1, 1):
        obj_name = f"LancetteFlanc{side}"
        lancet(S, obj_name, "Fer" if side < 0 else "Lumiere", 0, 14.5, 1.2, 4.6, 0)
    for obj in list(S.coll.objects):
        if obj.name.startswith("LancetteFlanc"):
            side = -1 if "Flanc-1" in obj.name else 1
            obj.location = (side * (W / 2 + 0.05), obj.location.x, obj.location.z)
            obj.rotation_euler = (0, 0, math.radians(90))
    # rosace cyan (l'énergie de la Fracture à travers le vitrail)
    S.cyl("RosaceFond", "Noyau", 1.9, 0.3, (0, -W / 2 - 0.05, 26.5), verts=16)
    S.ring("Rosace", "PierreClaire", 2.0, 0.28, (0, -W / 2 - 0.2, 26.5), seg=16, sides=4)
    for i in range(6):
        a = i / 6 * math.tau
        S.box(f"RosaceRayon{i}", "PierreClaire", (0.22, 0.4, 3.8), (0, -W / 2 - 0.2, 26.5), rot=(0, math.degrees(a), 0), bevel=0)
    # mâchicoulis : corbeaux + parapet en encorbellement + créneaux
    for face in range(4):
        rotz = face * 90
        for i in range(6):
            x = -5 + i * 2
            px, py = (x, -W / 2 - 0.5)
            c, s = math.cos(math.radians(rotz)), math.sin(math.radians(rotz))
            S.box(f"Machi{face}_{i}", "PierreSombre", (0.7, 1.2, 1.4), (px * c - py * s, px * s + py * c, H - 0.2), rot=(0, 0, rotz), bevel=0.04, taper=(1, 0.4))
    S.box("Parapet", "Pierre", (W + 2.2, W + 2.2, 1.6), (0, 0, H + 1.3), bevel=0.08)
    S.box("ParapetRebord", "PierreClaire", (W + 2.5, W + 2.5, 0.4), (0, 0, H + 0.5), bevel=0.05)
    for face in range(4):
        rotz = face * 90
        c, s = math.cos(math.radians(rotz)), math.sin(math.radians(rotz))
        for i in range(4):
            x = -4.5 + i * 3
            px, py = (x, -W / 2 - 0.6)
            S.box(f"Creneau{face}_{i}", "Pierre", (1.6, 1.0, 1.6), (px * c - py * s, px * s + py * c, H + 2.9), rot=(0, 0, rotz), bevel=0.06)
    # toit d'ardoise très pentu (pyramide), lucarnes, flèche et girouette de laiton
    S.cyl("Toit", "Ardoise", 0.05, 16, (0, 0, H + 2.1 + 8), rot=(90, 0, 45), verts=4, radius2=(W - 0.5) * 0.72)
    S.cyl("ToitBas", "Ardoise", (W - 0.5) * 0.72, 1.2, (0, 0, H + 2.4), rot=(90, 0, 45), verts=4, radius2=(W + 0.5) * 0.72)
    for face in range(4):
        rotz = face * 90
        c, s = math.cos(math.radians(rotz)), math.sin(math.radians(rotz))
        px, py = 0, -3.6
        S.box(f"Lucarne{face}", "Pierre", (1.6, 1.6, 2.2), (px * c - py * s, px * s + py * c, H + 6), rot=(0, 0, rotz), bevel=0.04)
        S.cyl(f"LucarneToit{face}", "Ardoise", 0.05, 1.6, (px * c - py * s, px * s + py * c, H + 7.8), rot=(90, 0, rotz + 45), verts=4, radius2=1.3)
    S.cyl("Fleche", "Laiton", 0.12, 4.5, (0, 0, H + 20), rot=(90, 0, 0), verts=6)
    S.sphere("FlecheBoule", "Laiton", 0.35, (0, 0, H + 18.6))
    S.crystal("FlecheEclat", "Noyau", 0.3, 0.9, 0.5, (0, 0, H + 22.6), sides=4)
    return S


# --- Sols ------------------------------------------------------------------------------------
def dalles(name="Fort_Dalle", seed=3, fissure=False):
    """Dalles de pierre irrégulières 8 × 8 (épaisseur 0,6), légers écarts de hauteur, joints sombres."""
    rng = random.Random(seed)
    S = fresh(name)
    S.box("Lit", "PierreSombre", (8, 8, 0.4), (0, 0, 0.2), bevel=0)
    cuts = [-4, -1.4 + rng.uniform(-0.4, 0.4), 1.3 + rng.uniform(-0.4, 0.4), 4]
    for i in range(3):
        rows = [-4, rng.uniform(-1.8, -0.6), rng.uniform(0.6, 1.8), 4] if i % 2 else [-4, rng.uniform(-0.8, 0.8), 4]
        for j in range(len(rows) - 1):
            x0, x1, y0, y1 = cuts[i], cuts[i + 1], rows[j], rows[j + 1]
            S.box(f"Dalle{i}{j}", "Pierre" if rng.random() < 0.7 else "PierreSombre",
                  (x1 - x0 - 0.14, y1 - y0 - 0.14, 0.3), ((x0 + x1) / 2, (y0 + y1) / 2, 0.55 + rng.uniform(-0.05, 0.05)),
                  rot=(rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(-1.5, 1.5)), bevel=0.06)
    if fissure:
        pts = [(-4, -0.5), (-2.2, 0.3), (-0.4, -0.2), (1.5, 0.6), (4, 0.1)]
        a = [(x, y - 0.08) for x, y in pts]
        b = [(x, y + 0.08) for x, y in pts]
        # la fissure lumineuse affleure entre les dalles (plan XY : ribbon en (x, z) tourné à plat)
        obj = ribbon(S, "Fissure", "Noyau", a, b, 0.2, y=0)
        obj.rotation_euler = (math.radians(90), 0, 0)
        obj.location = (0, 0, 0.62)
        mark(S, "Fx", "Faille", (0, 0, 0.8), size=0.8, height=0.5)
    return S


def paves(name="Fort_Pave", seed=4):
    """Pavés 8 × 8 : petits blocs arrondis en rangs décalés."""
    rng = random.Random(seed)
    S = fresh(name)
    S.box("Lit", "PierreSombre", (8, 8, 0.4), (0, 0, 0.2), bevel=0)
    y = -4 + 0.35
    row = 0
    while y < 4:
        x = -4 + (0.35 if row % 2 else 0.7)
        while x < 4 - 0.3:
            w = rng.uniform(0.6, 0.85)
            S.box(f"Pave{row}_{x:.1f}", "Pierre", (w, 0.62, 0.3), (x, y, 0.5 + rng.uniform(-0.03, 0.03)),
                  rot=(0, 0, rng.uniform(-6, 6)), bevel=0, taper=(0.8, 0.8))
            x += w + 0.08
        y += 0.72
        row += 1
    return S


def plancher(name="Fort_Plancher"):
    """Platelage de bois 8 × 8 surélevé (1 stud) : planches, bandes de fer, poutres dessous."""
    S = fresh(name)
    for i in range(10):
        x = -3.6 + i * 0.8
        S.box(f"Planche{i}", "Bois", (0.74, 8, 0.25), (x, 0, 0.88 + (0.02 if i % 3 == 0 else 0)), rot=(0, 0, 0.3 * ((i % 2) - 0.5)), bevel=0.03)
    for y in (-3.4, 3.4):
        S.box(f"Bande{y}", "Fer", (8.05, 0.25, 0.06), (0, y, 1.02), bevel=0)
        S.box(f"Poutre{y}", "Bois", (8, 0.6, 0.6), (0, y, 0.45), bevel=0.04)
    for x in (-3.4, 3.4):
        for y in (-3.4, 3.4):
            S.box(f"Pilot{x}{y}", "Bois", (0.6, 0.6, 0.75), (x, y, 0.37), bevel=0.04)
    return S


def marches(name="Fort_Marches"):
    """Trois marches de pierre 8 de large (montée 1,5 sur 3), nez de marche clair."""
    S = fresh(name)
    for i in range(3):
        S.box(f"Marche{i}", "Pierre", (8, 3 - i, 0.5 * (i + 1)), (0, (i) * 0.5, 0.25 * (i + 1)), bevel=0.05)
        S.box(f"Nez{i}", "PierreClaire", (8.02, 0.25, 0.12), (0, -1.5 + i + 0.12, 0.5 * (i + 1) - 0.04), bevel=0.02)
    return S


# --- Énergie temporelle ------------------------------------------------------------------------
def cristal(name="Fort_Cristal", seed=5):
    """Monolithe de cristal qui perce le sol : grappe inclinée, socle de gravats, éclats suspendus."""
    rng = random.Random(seed)
    S = fresh(name)
    # Gravats soulevés (le sol s'est fendu)
    for i in range(7):
        a = i / 7 * math.tau + rng.uniform(-0.3, 0.3)
        r = rng.uniform(1.2, 2.0)
        S.box(f"Gravat{i}", "PierreSombre" if i % 2 else "Pierre", (rng.uniform(0.8, 1.4), rng.uniform(0.6, 1.1), rng.uniform(0.4, 0.9)),
              (math.cos(a) * r, math.sin(a) * r, 0.25), rot=(rng.uniform(-25, 25), rng.uniform(-25, 25), math.degrees(a)), bevel=0.06)
    # Monolithe principal et cristaux secondaires
    S.crystal("Monolithe", "Noyau", 0.75, 5.2, 0.6, (0, 0, 0.4), rot=(6, -8, 15), sides=6)
    for i, (x, y, s, h, rx, ry) in enumerate(((0.9, 0.4, 0.4, 2.2, 20, 25), (-0.8, 0.5, 0.35, 1.8, -10, -30), (0.2, -0.9, 0.3, 1.4, -30, 5))):
        S.crystal(f"Cristal{i}", "Noyau", s, h, 0.2, (x, y, 0.3), rot=(rx, ry, 0), sides=5)
    S.crystal("CristalViolet", "Cristal", 0.25, 1.1, 0.1, (-0.4, -0.7, 0.3), rot=(25, -20, 0), sides=5)
    mark(S, "Fx", "Eclats", (0, 0, 3.0), size=1.6)
    mark(S, "Fx", "Orbite", (0, 0, 6.2), radius=2.2, count=5)
    # Éclats suspendus au-dessus
    for i in range(4):
        S.crystal(f"EclatSuspendu{i}", "Noyau", 0.12, 0.35, 0.3, (rng.uniform(-1.2, 1.2), rng.uniform(-1.2, 1.2), rng.uniform(5.6, 7.2)),
                  rot=(rng.uniform(0, 90), rng.uniform(0, 90), 0), sides=4)
    for i in range(3):
        S.box(f"PierreSuspendue{i}", "Pierre", (0.5, 0.4, 0.35), (rng.uniform(-1.5, 1.5), rng.uniform(-1.5, 1.5), rng.uniform(4, 6)),
              rot=(rng.uniform(0, 60), rng.uniform(0, 60), rng.uniform(0, 60)), bevel=0.04)
    return S


# --- Outils de composition ---------------------------------------------------------------------
from mathutils import Matrix  # noqa: E402


def on_face(S, angle, fn):
    """Construit avec fn() dans le repère de la façade -Y, puis tourne le résultat de `angle`° autour de Z
    (90 : façade +X, 180 : façade +Y, 270 : façade -X)."""
    before = set(S.coll.objects)
    fn()
    rot = Matrix.Rotation(math.radians(angle), 4, "Z")
    for o in S.coll.objects:
        if o not in before:
            o.matrix_world = rot @ o.matrix_world


def mark(S, kind, key, loc, axis=(0, 0, 1), yaw=0.0, **extra):
    """Repère exporté vers Studio (un Empty) : effet (« Fx »), pivot d'animation (« Pivot ») ou module
    à poser (« Pose »). L'axe local Z de l'Empty = axe de rotation ; le repère suit on_face()."""
    from mathutils import Vector

    e = bpy.data.objects.new(f"Mark_{kind}_{key}", None)
    rot = Vector((0, 0, 1)).rotation_difference(Vector(axis)).to_matrix().to_4x4()
    e.matrix_world = Matrix.Translation(loc) @ Matrix.Rotation(math.radians(yaw), 4, "Z") @ rot
    e["kind"], e["key"] = kind, key
    for k, v in extra.items():
        e[k] = v
    S.coll.objects.link(e)
    return e


def anim(objs, key):
    """Sépare ces pièces à l'export (« <Module>_Anim<Clé>_<Matériau> ») pour les animer en jeu."""
    for o in objs:
        o["anim"] = key


def prism(S, name, mat, profile, length, axis="x", center=(0, 0, 0)):
    """Polygone (a, b) extrudé sur ±length/2 : axe x → profil (y, z) ; axe y → profil (x, z)."""
    bm = bmesh.new()
    h = length / 2

    def P(a, b, t):
        return (t, a, b) if axis == "x" else (a, t, b)

    A = [bm.verts.new(P(a, b, -h)) for a, b in profile]
    B = [bm.verts.new(P(a, b, h)) for a, b in profile]
    bm.faces.new(A)
    bm.faces.new(list(reversed(B)))
    n = len(profile)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((A[i], A[j], B[j], B[i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return S._finish(name, bm, mat, center, (0, 0, 0), 0)


def pyramid(S, name, mat, half, z0, height, sides=4, turn=45, loc=(0, 0)):
    """Toit en pyramide / cône (base de demi-largeur `half` à z0, pointe à z0 + height)."""
    radius = half / math.cos(math.pi / sides) if sides == 4 else half
    return S.cyl(name, mat, 0.04, height, (loc[0], loc[1], z0 + height / 2), rot=(90, 0, turn), verts=sides, radius2=radius)


def merlons(S, prefix, x0, x1, y, z, rng=None, width=1.6, gap=1.2, height=1.6, depth=0.9, slit=True, skip=None):
    """Créneaux le long de x0..x1 sur le plan y, chapeau clair et meurtrière."""
    n = max(1, int((x1 - x0 + gap) // (width + gap)))
    span = n * width + (n - 1) * gap
    start = (x0 + x1) / 2 - span / 2 + width / 2
    for i in range(n):
        x = start + i * (width + gap)
        if skip and skip(x):
            continue
        S.box(f"{prefix}{i}", "Pierre", (width, depth, height), (x, y, z + height / 2), bevel=0.05)
        S.box(f"{prefix}Ch{i}", "PierreClaire", (width + 0.2, depth + 0.2, 0.25), (x, y, z + height + 0.12), bevel=0.03)
        if slit:
            S.box(f"{prefix}Fe{i}", "Fer", (0.22, depth + 0.05, height * 0.55), (x, y, z + height * 0.45), bevel=0)


def ring_stones(S, prefix, radius, z0, z1, rng, course=1.5, count=12, depth=0.35):
    """Maçonnerie d'un fût rond : assises de pierres tangentes, décalées d'une assise à l'autre."""
    z, row = z0, 0
    while z < z1 - 0.05:
        h = min(course, z1 - z)
        for i in range(count):
            if rng.random() < 0.04:
                continue
            a = (i + (0.5 if row % 2 else 0)) / count * math.tau
            w = 2 * radius * math.sin(math.pi / count) * 0.96
            tint = "PierreSombre" if rng.random() < 0.3 else "Pierre"
            r = radius + rng.uniform(-0.08, 0.05)
            S.box(f"{prefix}{row}_{i}", tint, (w, depth, h - 0.1), (math.cos(a) * r, math.sin(a) * r, z + h / 2),
                  rot=(0, 0, math.degrees(a) + 90), bevel=0)
        z += h
        row += 1


def stone_walls(S, prefix, w, d, z0, z1, rng, course=1.8, stone=(2.2, 3.4), skip_front=None, skip_back=None,
                skip_sides=None, depth=0.4):
    """Maçonnerie sur les quatre faces d'un volume w × d (façade -Y)."""
    masonry(S, prefix + "F", -w / 2, w / 2, z0, z1, -d / 2 + depth / 2 - 0.05, rng, course, depth, skip=skip_front, bevel=0, stone=stone)
    on_face(S, 180, lambda: masonry(S, prefix + "B", -w / 2, w / 2, z0, z1, -d / 2 + depth / 2 - 0.05, rng, course, depth,
                                    skip=skip_back, bevel=0, stone=stone))
    for ang in (90, 270):
        on_face(S, ang, lambda: masonry(S, prefix + f"S{ang}", -d / 2, d / 2, z0, z1, -w / 2 + depth / 2 - 0.05, rng, course,
                                        depth, skip=skip_sides, bevel=0, stone=stone))


def arched_door(S, prefix, x, y, width, spring, mat_door="Bois", depth=0.5, z=0.0):
    """Porte fermée à arc brisé sur le plan y : vantaux de bois cerclés de fer, voussure, larmier."""
    span = width
    R = span * 0.8
    inner, apex = pointed_arch(span, R, z + spring, steps=6)
    off = R - span / 2
    outer, _ = pointed_arch(2 * (R + 0.6 - off), R + 0.6, z + spring, steps=6)
    fill = [(px + x, pz) for px, pz in inner]
    base = [(px + x, z) for px, _ in inner]
    ribbon(S, prefix + "Vantail", mat_door, base, fill, 0.3, y=y + 0.15)
    ribbon(S, prefix + "Voussure", "Pierre", [(px + x, pz) for px, pz in inner], [(px + x, pz) for px, pz in outer], depth, y=y - 0.1)
    for side in (-1, 1):
        S.box(f"{prefix}Jambage{side}", "Pierre", (0.6, depth, spring), (x + side * (span / 2 + 0.3), y - 0.1, z + spring / 2), bevel=0.03)
    for k, zz in enumerate((z + spring * 0.3, z + spring * 0.75)):
        S.box(f"{prefix}Penture{k}", "Fer", (span * 0.9, 0.1, 0.18), (x, y - 0.05, zz), bevel=0)
    S.box(prefix + "Joint", "Fer", (0.12, 0.1, spring + (apex - spring) * 0.8), (x, y - 0.05, z + (spring + (apex - spring) * 0.8) / 2), bevel=0)
    return apex


def gable_roof(S, prefix, w, d, z0, h, overhang=0.6, along="x", slates=4):
    """Toit à deux pans d'ardoise (faîtage selon `along`), rangs d'ardoises en relief et faîtière de fer."""
    if along == "x":
        half, length = d / 2 + overhang, w + overhang * 2
    else:
        half, length = w / 2 + overhang, d + overhang * 2
    prism(S, prefix + "Toit", "Ardoise", [(-half, z0), (half, z0), (0, z0 + h)], length, axis=along)
    slope = math.degrees(math.atan2(h, half))
    run = math.hypot(half, h)
    for side in (-1, 1):
        for k in range(1, slates):
            t = k / slates
            a, zz = side * half * (1 - t), z0 + h * t
            if along == "x":
                S.box(f"{prefix}Rang{side}{k}", "Ardoise", (length - 0.1, run / slates * 0.15, 0.12), (0, a + side * 0.06, zz + 0.05),
                      rot=(side * -slope, 0, 0), bevel=0)
            else:
                S.box(f"{prefix}Rang{side}{k}", "Ardoise", (run / slates * 0.15, length - 0.1, 0.12), (a + side * 0.06, 0, zz + 0.05),
                      rot=(0, side * slope, 0), bevel=0)
    if along == "x":
        S.box(prefix + "Faitage", "Fer", (length, 0.35, 0.3), (0, 0, z0 + h), bevel=0)
    else:
        S.box(prefix + "Faitage", "Fer", (0.35, length, 0.3), (0, 0, z0 + h), bevel=0)


def gable_wall(S, prefix, w, z0, h, y, depth=0.6):
    """Pignon triangulaire de pierre (plan y) sous un toit à faîtage selon y."""
    prism(S, prefix + "Pignon", "PierreSombre", [(-w / 2, z0), (w / 2, z0), (0, z0 + h)], depth, axis="y", center=(0, y, 0))


def window_row(S, prefix, xs, z, y, width=1.1, height=2.6, lit=(), mat="Fer"):
    for i, x in enumerate(xs):
        lancet(S, f"{prefix}{i}", "Lumiere" if i in lit else mat, x, z, width, height, y)


def crystal_cluster(S, prefix, loc, scale=1.0, rng=None, tilt=(0, 0), count=4):
    """Grappe de cristaux qui sort de la maçonnerie (direction moyenne inclinée de `tilt`)."""
    rng = rng or random.Random(3)
    x, y, z = loc
    for i in range(count):
        s = scale * rng.uniform(0.6, 1.0)
        S.crystal(f"{prefix}{i}", "Noyau" if i else "Cristal" if count > 3 else "Noyau", 0.25 * s, 1.6 * s, 0.4 * s,
                  (x + rng.uniform(-0.3, 0.3) * scale, y + rng.uniform(-0.3, 0.3) * scale, z + rng.uniform(-0.3, 0.3) * scale),
                  rot=(tilt[0] + rng.uniform(-25, 25), tilt[1] + rng.uniform(-25, 25), 0), sides=5)


def floating(S, prefix, center, spread, count, rng, zr=(0, 3), mat="Pierre", size=0.5, min_r=0.0):
    cx, cy, cz = center
    for i in range(count):
        dx = dy = 0.0
        for _ in range(30):
            dx, dy = rng.uniform(-spread, spread), rng.uniform(-spread, spread)
            if max(abs(dx), abs(dy)) >= min_r:
                break
        p = (cx + dx, cy + dy, cz + rng.uniform(*zr))
        if i % 3 == 2:
            S.crystal(f"{prefix}E{i}", "Noyau", size * 0.25, size * 0.8, size * 0.5, p, rot=(rng.uniform(0, 90), rng.uniform(0, 90), 0), sides=4)
        else:
            S.box(f"{prefix}P{i}", mat, (size * rng.uniform(0.8, 1.4), size * rng.uniform(0.6, 1), size * rng.uniform(0.5, 0.9)), p,
                  rot=(rng.uniform(0, 60), rng.uniform(0, 60), rng.uniform(0, 60)), bevel=0)


# --- Remparts et tours -----------------------------------------------------------------------
def rempart(name="Fort_Rempart", seed=21):
    """Rempart 8 × 6 : chemin de ronde PRATICABLE à 14 (dallage), parapet crénelé côté extérieur (-Y),
    parapet bas côté intérieur, maçonnerie sur les deux faces."""
    rng = random.Random(seed)
    S = fresh(name)
    W, D, H = 8, 6, 14
    S.box("Soubassement", "PierreSombre", (W, D + 0.8, 2), (0, 0, 1), bevel=0.1, taper=None)
    S.box("Ame", "PierreSombre", (W - 0.02, D - 0.7, H - 2.4), (0, 0, 2 + (H - 2.4) / 2 - 0.2))
    masonry(S, "Ext", -W / 2, W / 2, 2, H - 1.2, -D / 2 + 0.2, rng, course=1.6, depth=0.4, bevel=0, stone=(1.8, 3.0))
    on_face(S, 180, lambda: masonry(S, "Int", -W / 2, W / 2, 2, H - 1.2, -D / 2 + 0.2, rng, course=1.6, depth=0.4, bevel=0, stone=(1.8, 3.0)))
    S.box("Cordon", "PierreClaire", (W, D + 0.5, 0.45), (0, 0, H - 1.0), bevel=0.06)
    S.box("Dallage", "Pierre", (W - 0.05, D - 0.2, 0.4), (0, 0, H - 0.2), bevel=0.03)
    for i, x in enumerate((-3, -1, 1, 3)):
        S.box(f"Corbeau{i}", "PierreSombre", (0.6, 0.7, 0.8), (x, -D / 2 - 0.2, H - 1.6), bevel=0.04, taper=(1, 0.5))
    S.box("Parapet", "Pierre", (W, 0.9, 1.0), (0, -D / 2 + 0.45, H + 0.5), bevel=0.05)
    merlons(S, "Merlon", -W / 2, W / 2, -D / 2 + 0.45, H + 1.0, width=2.2, gap=1.6, height=1.6)
    # côté intérieur : simple rebord clair à fleur du dallage (les escaliers y débouchent)
    S.box("RebordInt", "PierreClaire", (W, 0.5, 0.15), (0, D / 2 - 0.25, H + 0.07), bevel=0.02)
    return S


def tourelle(name="Fort_Tourelle", seed=22):
    """Tourelle d'angle ronde (10 × 10) : fût à fruit, meurtrières, couronne en encorbellement, poivrière."""
    rng = random.Random(seed)
    S = fresh(name)
    S.cyl("Socle", "PierreSombre", 4.6, 3, (0, 0, 1.5), rot=(90, 0, 0), verts=12, radius2=5.0)
    S.cyl("Fut", "PierreSombre", 4.15, 11, (0, 0, 8.5), rot=(90, 0, 0), verts=12, radius2=4.4)
    ring_stones(S, "Assise", 4.35, 3, 13, rng, course=1.5, count=12)
    S.cyl("Cordon", "PierreClaire", 4.6, 0.4, (0, 0, 8), rot=(90, 0, 0), verts=12)
    for i in range(4):
        a = (i + 0.5) / 4 * math.tau
        S.box(f"Meurtriere{i}", "Fer", (0.3, 0.5, 1.8), (math.cos(a) * 4.5, math.sin(a) * 4.5, 10.5), rot=(0, 0, math.degrees(a) + 90), bevel=0)
    for i in range(12):
        a = i / 12 * math.tau
        S.box(f"Corbeau{i}", "PierreSombre", (0.7, 1.1, 1.2), (math.cos(a) * 4.7, math.sin(a) * 4.7, 12.6), rot=(0, 0, math.degrees(a) + 90),
              bevel=0.04, taper=(1, 0.4))
    S.cyl("Couronne", "Pierre", 5.1, 3, (0, 0, 14.6), rot=(90, 0, 0), verts=12)
    S.cyl("CouronneRebord", "PierreClaire", 5.3, 0.35, (0, 0, 13.2), rot=(90, 0, 0), verts=12)
    for i in range(3):
        a = (i + 0.25) / 3 * math.tau
        lancet_r = 5.15
        before = set(S.coll.objects)
        lancet(S, f"Jour{i}", "Lumiere" if i == 0 else "Fer", 0, 13.6, 0.7, 1.9, 0, depth=0.3)
        rot = Matrix.Translation((math.cos(a) * lancet_r, math.sin(a) * lancet_r, 0)) @ Matrix.Rotation(a + math.pi / 2, 4, "Z")
        for o in S.coll.objects:
            if o not in before:
                o.matrix_world = rot @ o.matrix_world
    S.cyl("Avanttoit", "Ardoise", 5.2, 0.8, (0, 0, 16.4), rot=(90, 0, 0), verts=12, radius2=5.8)
    pyramid(S, "Poivriere", "Ardoise", 5.4, 16.8, 7.5, sides=12, turn=0)
    for k in range(1, 4):
        S.cyl(f"PoivriereRang{k}", "Ardoise", 5.45 * (1 - k / 4) + 0.05, 0.2, (0, 0, 16.8 + 7.5 * k / 4), rot=(90, 0, 0), verts=12)
    S.cyl("Epi", "Laiton", 0.1, 2.6, (0, 0, 25.3), rot=(90, 0, 0), verts=6)
    S.sphere("EpiBoule", "Laiton", 0.25, (0, 0, 24.6))
    S.crystal("EpiEclat", "Noyau", 0.22, 0.7, 0.4, (0, 0, 26.9), sides=4)
    return S


def escalier(name="Fort_Escalier"):
    """Volée de 12 marches (6 × 12, montée 9 vers -Y), limons de pierre ; étirée par le jeu."""
    S = fresh(name)
    W, D, H, n = 6, 12, 9, 12
    prism(S, "Massif", "PierreSombre", [(D / 2, 0), (-D / 2, 0), (-D / 2, H - 0.4), (D / 2 - D / n, 0.35)], W - 1.0, axis="x")
    for i in range(n):
        y1 = D / 2 - i * D / n
        y0 = y1 - D / n
        top = (i + 1) * H / n
        S.box(f"Marche{i}", "Pierre", (W - 0.9, D / n + 0.05, 0.45), (0, (y0 + y1) / 2, top - 0.22), bevel=0.04)
        S.box(f"Nez{i}", "PierreClaire", (W - 0.85, 0.18, 0.12), (0, y1 - D / n + 0.06, top - 0.05), bevel=0)
    for side in (-1, 1):
        prism(S, f"Limon{side}", "Pierre", [(D / 2, 0), (-D / 2, 0), (-D / 2, H + 0.5), (D / 2, 0.9)], 0.5, axis="x",
              center=(side * (W / 2 - 0.25), 0, 0))
    return S


# --- Donjon ------------------------------------------------------------------------------------
def donjon(name="Fort_Donjon", seed=31):
    """Donjon : masse de 32 × 32 à terrasse PRATICABLE à 24 (ouvertures du parapet à l'arrivée des
    passerelles), grande porte, rosaces cyan ; tour centrale 12 × 12 jusqu'à 56 : horloge figée,
    mâchicoulis, toit d'ardoise et flèche (≈ 76). Repère de toute la carte."""
    rng = random.Random(seed)
    S = fresh(name)
    W, R = 32, 24
    S.box("Soubassement", "PierreSombre", (W + 1.5, W + 1.5, 3), (0, 0, 1.5), bevel=0.15)
    S.box("Ame", "PierreSombre", (W - 0.6, W - 0.6, R - 3.2), (0, 0, 3 + (R - 3.2) / 2))

    def door_skip(x, z):
        return abs(x) < 5.6 and z < 12.5

    def rose_skip(x, z):
        return math.hypot(x, z - 16.5) < 3.6

    def front_skip(x, z):
        return door_skip(x, z) or rose_skip(x, z)

    stone_walls(S, "Mur", W, W, 3, R - 1.6, rng, course=2.0, stone=(2.6, 3.8), skip_front=front_skip, skip_back=front_skip)
    # contreforts en gradins : angles + deux par face
    for ang in (0, 90, 180, 270):
        def buttresses():
            for x in (-8.5, 8.5):
                for k, (z0, h, s) in enumerate(((0, 9, 2.6), (9, 7, 2.0), (16, 5, 1.5))):
                    S.box(f"Contrefort{x}_{k}", "Pierre", (2.0, s, h), (x, -W / 2 - s / 2 + 0.3, z0 + h / 2), bevel=0.06)
                    S.box(f"Glacis{x}_{k}", "PierreClaire", (2.2, s + 0.15, 0.3), (x, -W / 2 - s / 2 + 0.3, z0 + h), bevel=0.03)
            for k, (z0, h, s) in enumerate(((0, 10, 3.2), (10, 7, 2.5), (17, 5, 1.8))):
                S.box(f"Angle_{k}", "Pierre", (s, s, h), (-W / 2, -W / 2, z0 + h / 2), bevel=0.06)
                S.box(f"AngleGlacis_{k}", "PierreClaire", (s + 0.2, s + 0.2, 0.3), (-W / 2, -W / 2, z0 + h), bevel=0.03)
            for x in (-13, -4.0, 4.0, 13):
                if abs(x) > 5 or ang in (90, 270):
                    lancet(S, f"Lancette{x}", "Lumiere" if (x == -13 and ang == 0) or (x == 4.0 and ang == 90) else "Fer",
                           x, 7.0 if abs(x) > 5 else 6.0, 1.3, 4.0, -W / 2 - 0.05)
            S.box("Cordon", "PierreClaire", (W + 0.6, 0.5, 0.45), (0, -W / 2 - 0.05, 13.2), bevel=0.05)
            S.box("CordonHaut", "PierreClaire", (W + 0.8, 0.6, 0.5), (0, -W / 2 - 0.1, R - 1.3), bevel=0.05)
            for i in range(14):
                x = -14.3 + i * 2.2
                S.box(f"Machi{i}", "PierreSombre", (0.8, 1.2, 1.4), (x, -W / 2 - 0.4, R - 2.1), bevel=0.04, taper=(1, 0.4))
        on_face(S, ang, buttresses)
    # grandes portes et rosaces (façades avant et arrière)
    for ang in (0, 180):
        def portal():
            arched_door(S, "Portail", 0, -W / 2 - 0.05, 8.4, 5.5)
            S.box("PortailLarmier", "PierreClaire", (10.4, 0.6, 0.4), (0, -W / 2 - 0.3, 13.0), bevel=0.04)
            S.box("Lanterne0", "Lumiere", (0.5, 0.5, 0.7), (-5.6, -W / 2 - 0.9, 7.2), bevel=0.04)
            S.box("Lanterne1", "Lumiere", (0.5, 0.5, 0.7), (5.6, -W / 2 - 0.9, 7.2), bevel=0.04)
            for x in (-5.6, 5.6):
                S.box(f"Potence{x}", "Fer", (0.12, 0.9, 0.12), (x, -W / 2 - 0.45, 7.65), bevel=0)
            mark(S, "Pose", "Fort_Torche", (-6.4, -W / 2 - 0.1, 4.0))
            mark(S, "Pose", "Fort_Torche", (6.4, -W / 2 - 0.1, 4.0))
            mark(S, "Fx", "Lueur", (0, -W / 2 - 1.0, 16.5), size=1.5)
            S.cyl("RosaceFond", "Noyau", 2.9, 0.3, (0, -W / 2 + 0.1, 16.5), verts=16)
            S.ring("Rosace", "Pierre", 3.15, 0.38, (0, -W / 2 - 0.15, 16.5), seg=16, sides=4)
            S.ring("RosaceIn", "Pierre", 1.0, 0.2, (0, -W / 2 - 0.15, 16.5), seg=10, sides=4)
            for i in range(8):
                S.box(f"RosaceRayon{i}", "Pierre", (0.22, 0.4, 5.8), (0, -W / 2 - 0.15, 16.5), rot=(0, i * 22.5, 0), bevel=0)
        on_face(S, ang, portal)
    # terrasse praticable (dessus à 24) et parapet crénelé, ouvert à l'arrivée des passerelles :
    # Roblox (-16, z ∈ [-16, -10]) → Blender (x = +16, y ∈ [-16, -10]) ; Roblox (16, [10, 16]) → Blender (-16, [10, 16])
    S.box("Terrasse", "Pierre", (W - 0.4, W - 0.4, 0.5), (0, 0, R - 0.25), bevel=0.03)
    for i in range(-3, 4):
        S.box(f"Joint{i}", "PierreSombre", (W - 0.6, 0.12, 0.06), (0, i * 4.3, R + 0.01), bevel=0)
    for ang in (0, 90, 180, 270):
        def parapet(ang=ang):
            gap = None
            if ang == 90:
                gap = (-16.5, -9.5)  # face +X : x local = y monde
            elif ang == 270:
                gap = (-16.5, -9.5)  # face -X : x local = -y monde → y ∈ [10, 16]
            spans = [(-W / 2, W / 2)] if gap is None else [(-W / 2, gap[0]), (gap[1], W / 2)]
            for j, (a, b) in enumerate(spans):
                if b - a < 0.5:
                    continue
                S.box(f"Parapet{j}", "Pierre", (b - a, 1.0, 1.1), ((a + b) / 2, -W / 2 + 0.5, R + 0.55), bevel=0.05)
                merlons(S, f"Merlon{j}_", a + 0.3, b - 0.3, -W / 2 + 0.5, R + 1.1, width=2.0, gap=1.5, height=1.5, depth=1.0)
        on_face(S, ang, parapet)
    # cristaux qui percent la maçonnerie (angle nord-ouest) et éclats suspendus
    crystal_cluster(S, "Percee", (-W / 2 - 0.4, -W / 2 + 4, 18), scale=2.2, rng=rng, tilt=(60, -30), count=5)
    crystal_cluster(S, "PerceeB", (W / 2 + 0.3, W / 2 - 6, 9), scale=1.6, rng=rng, tilt=(-60, 30), count=4)
    # --- Tour centrale (12 × 12, de 24 à 56, toit et flèche au-dessus)
    T, T0, T1 = 12, R, 52
    S.box("TourAme", "PierreSombre", (T - 0.6, T - 0.6, T1 - T0), (0, 0, T0 + (T1 - T0) / 2))

    def clock_skip(x, z):
        return math.hypot(x, z - 44) < 3.4 or (abs(x) < 1.6 and z < T0 + 4.2)

    stone_walls(S, "TourMur", T, T, T0, T1 - 0.8, rng, course=1.8, stone=(2.2, 3.2), skip_front=clock_skip, skip_back=clock_skip,
                skip_sides=lambda x, z: math.hypot(x, z - 44) < 3.4)
    for ang in (0, 90, 180, 270):
        def tower_face(ang=ang):
            for k, (z0, h, s) in enumerate(((T0, 12, 1.8), (T0 + 12, 10, 1.4))):
                for x in (-T / 2, T / 2):
                    S.box(f"TourContrefort{x}{k}", "Pierre", (s, s, h), (x, -T / 2, z0 + h / 2), bevel=0.05)
            S.box("TourCordon", "PierreClaire", (T + 0.5, 0.5, 0.4), (0, -T / 2 - 0.05, 38), bevel=0.04)
            lancet(S, "TourLancette0", "Lumiere" if ang in (0, 180) else "Fer", -2.2, 31, 1.1, 4.2, -T / 2 - 0.05)
            lancet(S, "TourLancette1", "Fer", 2.2, 31, 1.1, 4.2, -T / 2 - 0.05)
            # horloge figée : cadran clair, chiffres de fer, aiguilles de laiton, fêlure cyan
            S.cyl("Cadran", "PierreClaire", 3.2, 0.35, (0, -T / 2 - 0.1, 44), verts=24)
            S.ring("CadranCercle", "Laiton", 3.25, 0.18, (0, -T / 2 - 0.3, 44), seg=24, sides=4)
            for h in range(12):
                a = h / 12 * math.tau
                S.box(f"Heure{h}", "Fer", (0.18, 0.12, 0.6), (math.sin(a) * 2.6, -T / 2 - 0.3, 44 + math.cos(a) * 2.6), rot=(0, -h * 30, 0), bevel=0)
            anim([S.box("Aiguille", "Laiton", (0.25, 0.14, 2.3), (0.55, -T / 2 - 0.42, 44.9), rot=(0, 28, 0), bevel=0)], f"Aiguille{ang}")
            anim([S.box("Petite", "Laiton", (0.32, 0.14, 1.5), (-0.55, -T / 2 - 0.42, 43.6), rot=(0, 140, 0), bevel=0)], f"Petite{ang}")
            mark(S, "Pivot", f"Aiguille{ang}", (0, -T / 2 - 0.42, 44), axis=(0, -1, 0), mode="tick", ratio=1.0)
            mark(S, "Pivot", f"Petite{ang}", (0, -T / 2 - 0.42, 44), axis=(0, -1, 0), mode="tick", ratio=0.25)
            pts = [(-2.6, 45.6), (-1.2, 44.6), (-0.2, 45.1), (1.1, 43.4), (2.7, 42.9)]
            ribbon(S, "Felure", "Noyau", [(x, z - 0.08) for x, z in pts], [(x, z + 0.08) for x, z in pts], 0.3, y=-T / 2 - 0.25)
            for i in range(5):
                x = -4.8 + i * 2.4
                S.box(f"TourMachi{i}", "PierreSombre", (0.7, 1.1, 1.3), (x, -T / 2 - 0.4, T1 - 0.6), bevel=0.04, taper=(1, 0.4))
            S.box("TourParapet", "Pierre", (T + 2.2, 1.0, 2.0), (0, -T / 2 - 0.6, T1 + 1.0), bevel=0.05)
            merlons(S, "TourMerlon", -T / 2 - 1, T / 2 + 1, -T / 2 - 0.6, T1 + 2.0, width=1.6, gap=1.4, height=1.4, depth=1.0)
        on_face(S, ang, tower_face)
    arched_door(S, "TourPorte", 0, -T / 2 - 0.05, 2.8, 2.6, z=T0)
    S.box("TourSol", "Pierre", (T + 1.6, T + 1.6, 0.5), (0, 0, T1 + 0.25), bevel=0.03)
    pyramid(S, "TourToit", "Ardoise", 7.6, T1 + 3.4, 18)
    for k in range(1, 5):
        hk = 7.6 * (1 - k / 5)
        S.box(f"TourToitRang{k}", "Ardoise", (hk * 2 + 0.3, hk * 2 + 0.3, 0.25), (0, 0, T1 + 3.4 + 18 * k / 5), bevel=0)
    for ang in (0, 90, 180, 270):
        def dormer():
            S.box("Lucarne", "Pierre", (2.0, 1.8, 2.6), (0, -4.3, T1 + 5.6), bevel=0.04)
            lancet(S, "LucarneJour", "Lumiere", 0, T1 + 4.6, 0.7, 1.8, -5.25, depth=0.2)
            pyramid(S, "LucarneToit", "Ardoise", 1.3, T1 + 6.9, 1.8, turn=45, loc=(0, -4.3))
        on_face(S, ang, dormer)
    S.cyl("Fleche", "Laiton", 0.16, 6, (0, 0, T1 + 23.5), rot=(90, 0, 0), verts=6)
    S.sphere("FlecheBoule", "Laiton", 0.5, (0, 0, T1 + 21.6))
    S.crystal("FlecheEclat", "Noyau", 0.45, 1.6, 0.8, (0, 0, T1 + 27.5), sides=5)
    floating(S, "Fragment", (0, 0, T1 + 6), 12, 10, rng, zr=(0, 16), size=0.9, min_r=9)
    mark(S, "Fx", "Orbite", (0, 0, T1 + 12), radius=12.0, count=10)
    mark(S, "Fx", "Eclats", (-W / 2 - 0.4, -W / 2 + 4, 18), size=2.0)
    mark(S, "Fx", "Eclats", (W / 2 + 0.3, W / 2 - 6, 9), size=1.5)
    mark(S, "Pose", "Fort_Brasero", (-13.5, -13.5, R))
    mark(S, "Pose", "Fort_Brasero", (13.5, 13.5, R))
    mark(S, "Pose", "Fort_Torche", (-2.4, -T / 2 - 0.1, T0 + 1.2))
    return S


# --- Tour de guet --------------------------------------------------------------------------------
def tour_guet(name="Fort_TourGuet", seed=32):
    """Tour de guet 14 × 14 à terrasse PRATICABLE à 24 (ouverture du parapet côté escalier), échauguette
    d'angle à poivrière, lancettes, mâchicoulis."""
    rng = random.Random(seed)
    S = fresh(name)
    W, R = 14, 24
    S.box("Soubassement", "PierreSombre", (W + 1.2, W + 1.2, 3), (0, 0, 1.5), bevel=0.12)
    S.box("Ame", "PierreSombre", (W - 0.6, W - 0.6, R - 3.2), (0, 0, 3 + (R - 3.2) / 2))
    stone_walls(S, "Mur", W, W, 3, R - 1.6, rng, course=1.8, stone=(2.2, 3.2), skip_front=lambda x, z: abs(x) < 1.8 and z < 6)
    for ang in (0, 90, 180, 270):
        def face(ang=ang):
            for k, (z0, h, s) in enumerate(((0, 10, 2.4), (10, 8, 1.8), (18, 4, 1.3))):
                S.box(f"Contrefort{k}", "Pierre", (s, s, h), (-W / 2, -W / 2, z0 + h / 2), bevel=0.06)
                S.box(f"Glacis{k}", "PierreClaire", (s + 0.2, s + 0.2, 0.3), (-W / 2, -W / 2, z0 + h), bevel=0.03)
            S.box("Cordon", "PierreClaire", (W + 0.5, 0.5, 0.4), (0, -W / 2 - 0.05, 12), bevel=0.04)
            lancet(S, "Lancette", "Lumiere" if ang == 0 else "Fer", 0, 14.5, 1.2, 4.4, -W / 2 - 0.05)
            S.box("Meurtriere", "Fer", (0.3, 0.5, 2.2), (-3.5, -W / 2 - 0.05, 7.5), bevel=0)
            for i in range(6):
                S.box(f"Machi{i}", "PierreSombre", (0.7, 1.1, 1.3), (-5.5 + i * 2.2, -W / 2 - 0.4, R - 1.6), bevel=0.04, taper=(1, 0.4))
            S.box("CordonHaut", "PierreClaire", (W + 0.7, 0.6, 0.45), (0, -W / 2 - 0.1, R - 0.9), bevel=0.04)
        on_face(S, ang, face)
    arched_door(S, "Porte", 0, -W / 2 - 0.05, 3.0, 3.0)
    mark(S, "Pose", "Fort_Torche", (-2.6, -W / 2 - 0.1, 3.0))
    mark(S, "Pose", "Fort_Brasero", (-5.0, 5.0, R))
    mark(S, "Fx", "Eclats", (W / 2 + 0.3, -2, 9), size=1.5)
    S.box("Terrasse", "Pierre", (W - 0.4, W - 0.4, 0.5), (0, 0, R - 0.25), bevel=0.03)
    # ouverture du parapet : l'escalier arrive par l'ouest du jeu (Roblox -X → Blender +X), z ∈ [-2, 4]
    for ang in (0, 90, 180, 270):
        def parapet(ang=ang):
            spans = [(-W / 2, W / 2)] if ang != 90 else [(-W / 2, -2.6), (4.6, W / 2)]
            for j, (a, b) in enumerate(spans):
                S.box(f"Parapet{j}", "Pierre", (b - a, 1.0, 1.1), ((a + b) / 2, -W / 2 + 0.5, R + 0.55), bevel=0.05)
                merlons(S, f"Merlon{j}_", a + 0.3, b - 0.3, -W / 2 + 0.5, R + 1.1, width=1.8, gap=1.4, height=1.5, depth=1.0)
        on_face(S, ang, parapet)
    # échauguette d'angle (-X, -Y) à poivrière
    cx, cy = -W / 2 - 0.4, -W / 2 - 0.4
    S.cyl("EchauguetteCul", "PierreSombre", 0.3, 2.4, (cx, cy, R - 2.4), rot=(90, 0, 0), verts=8, radius2=0.3)
    S.cyl("EchauguetteCone", "PierreSombre", 1.7, 2.2, (cx, cy, R - 2.2), rot=(90, 0, 0), verts=8, radius2=0.2)
    S.cyl("Echauguette", "Pierre", 1.8, 4.2, (cx, cy, R + 1.0), rot=(90, 0, 0), verts=8)
    S.box("EchauguetteJour", "Lumiere", (0.4, 0.3, 1.2), (cx - 0.9, cy - 1.45, R + 1.5), rot=(0, 0, 45), bevel=0)
    pyramid(S, "EchauguetteToit", "Ardoise", 2.2, R + 3.1, 4.8, sides=8, turn=22.5, loc=(cx, cy))
    S.cyl("EchauguetteEpi", "Laiton", 0.08, 1.4, (cx, cy, R + 8.4), rot=(90, 0, 0), verts=6)
    crystal_cluster(S, "Percee", (W / 2 + 0.3, -2, 9), scale=1.6, rng=rng, tilt=(-70, 20), count=4)
    return S


# --- Habitations ---------------------------------------------------------------------------------
def maison(name="Fort_Maison", W=12, D=10, H=16, seed=41, grande=False):
    """Maison gothique : rez de pierre, étage en encorbellement à colombages sombres, toit d'ardoise
    très pentu (faîtage selon X), portes sur les deux façades, cheminée, lucarnes."""
    rng = random.Random(seed)
    S = fresh(name)
    G = 6.5  # hauteur du rez
    E = 11.0 if not grande else 12.0  # haut de l'étage (naissance du toit)
    S.box("Soubassement", "PierreSombre", (W + 0.4, D + 0.4, 1.0), (0, 0, 0.5), bevel=0.06)
    S.box("RezAme", "PierreSombre", (W - 0.5, D - 0.5, G - 1), (0, 0, 1 + (G - 1) / 2))

    def door_skip(x, z):
        return abs(x - (-2.0)) < 1.9 and z < 5.2

    stone_walls(S, "Rez", W, D, 1, G, rng, course=1.4, stone=(1.6, 2.6), skip_front=door_skip, skip_back=door_skip, depth=0.35)
    for ang in (0, 180):
        def front():
            arched_door(S, "Porte", -2.0, -D / 2 - 0.05, 2.6, 3.2, z=0.3)
            mark(S, "Pose", "Fort_Torche", (-4.2, -D / 2 - 0.1, 2.6))
            S.box("Seuil", "PierreClaire", (3.4, 0.8, 0.3), (-2.0, -D / 2 - 0.3, 0.15), bevel=0.03)
            lancet(S, "Fenetre", "Lumiere" if ang == 0 else "Fer", 2.6, 2.4, 1.1, 2.6, -D / 2 - 0.05)
            S.box("Enseigne", "Fer", (0.1, 1.2, 0.1), (4.5, -D / 2 - 0.6, 5.4), bevel=0)
            S.box("EnseignePlaque", "Bois", (0.12, 1.0, 0.8), (4.5, -D / 2 - 1.0, 4.9), bevel=0.02)
        on_face(S, ang, front)
    # encorbellement : solives saillantes puis étage plus large
    S.box("Plancher", "Bois", (W + 1.0, D + 1.0, 0.4), (0, 0, G + 0.2), bevel=0.03)
    for side in (-1, 1):
        for i in range(int(W / 1.5)):
            S.box(f"Solive{side}{i}", "Bois", (0.35, 0.8, 0.35), (-W / 2 + 0.75 + i * 1.5, side * (D / 2 + 0.2), G - 0.2), bevel=0)
    S.box("EtageAme", "PierreSombre", (W + 0.6, D + 0.6, E - G - 0.4), (0, 0, G + 0.4 + (E - G - 0.4) / 2))
    # colombages : poteaux, sablières, croix de Saint-André
    for ang in (0, 90, 180, 270):
        length = W + 0.6 if ang in (0, 180) else D + 0.6
        dist = (D + 0.6) / 2 if ang in (0, 180) else (W + 0.6) / 2

        def timber(length=length, dist=dist, ang=ang):
            y = -dist - 0.08
            n = max(2, int(length / 2.4))
            for i in range(n + 1):
                x = -length / 2 + i * length / n
                S.box(f"Poteau{i}", "Bois", (0.35, 0.2, E - G - 0.4), (x, y, G + 0.4 + (E - G - 0.4) / 2), bevel=0)
            for zz in (G + 0.55, E - 0.15):
                S.box(f"Sabliere{zz:.1f}", "Bois", (length, 0.22, 0.3), (0, y, zz), bevel=0)
            for i in range(n):
                x0 = -length / 2 + i * length / n
                x1 = x0 + length / n
                if i % 2 == 0 and not (ang in (0, 180) and i == n // 2):
                    for sgn in (-1, 1):
                        dx, dz = x1 - x0, E - G - 0.9
                        S.box(f"Croix{i}{sgn}", "Bois", (math.hypot(dx, dz) - 0.2, 0.18, 0.22), ((x0 + x1) / 2, y, G + 0.4 + (E - G - 0.4) / 2),
                              rot=(0, sgn * math.degrees(math.atan2(dz, dx)), 0), bevel=0)
            if ang in (0, 180):
                xs = [-length / 2 + (i + 0.5) * length / n for i in range(n) if i % 2 == 1 or i == n // 2]
                window_row(S, "Croisee", xs[:3], G + 1.3, y - 0.05, width=0.9, height=2.2, lit=(0,) if ang == 0 else (1,))
        on_face(S, ang, timber)
    # toit à deux pans très pentu, pignons de pierre sur les côtés
    roof_h = H - E
    gable_roof(S, "Toit", W + 0.6, D + 0.6, E, roof_h, overhang=0.7, along="x", slates=5)
    for side in (-1, 1):
        prism(S, f"Pignon{side}", "PierreSombre", [(-(D + 0.6) / 2, E), ((D + 0.6) / 2, E), (0, E + roof_h - 0.3)], 0.5, axis="x",
              center=(side * (W / 2 + 0.1), 0, 0))
        S.box(f"PignonFenetre{side}", "Lumiere" if side < 0 else "Fer", (0.3, 0.8, 1.4), (side * (W / 2 + 0.35), 0, E + 2.2), bevel=0)
    # lucarnes sur le pan avant et la cheminée
    for x in ((-3, 3) if not grande else (-4.5, 0, 4.5)):
        z0 = E + roof_h * 0.25
        yb = -(D + 0.6) / 2 * 0.75
        S.box(f"Lucarne{x}", "PierreSombre", (1.8, 2.0, 2.2), (x, yb, z0 + 1.1), bevel=0.03)
        S.box(f"LucarneJour{x}", "Lumiere" if x < 0 else "Fer", (0.8, 0.1, 1.1), (x, yb - 1.02, z0 + 1.1), bevel=0)
        prism(S, f"LucarneToit{x}", "Ardoise", [(-1.2, z0 + 2.2), (1.2, z0 + 2.2), (0, z0 + 3.6)], 2.4, axis="y", center=(x, yb, 0))
    S.box("Cheminee", "PierreSombre", (1.4, 1.4, roof_h + 1.5), (W / 2 - 2.0, (D + 0.6) / 4, E + (roof_h + 1.5) / 2), bevel=0.04)
    S.box("ChemineeCh", "PierreClaire", (1.7, 1.7, 0.3), (W / 2 - 2.0, (D + 0.6) / 4, E + roof_h + 1.55), bevel=0.03)
    mark(S, "Fx", "Fumee", (W / 2 - 2.0, (D + 0.6) / 4, E + roof_h + 1.8), size=1.2)
    if grande:
        # tourelle d'escalier en façade avant (silhouette)
        cx, cy = W / 2 - 1.2, -D / 2 + 1.0
        S.cyl("Tourelle", "Pierre", 1.6, H - 3, (cx, cy, (H - 3) / 2), rot=(90, 0, 0), verts=8)
        S.box("TourelleJour", "Lumiere", (0.3, 0.3, 1.4), (cx, cy - 1.55, 9), bevel=0)
        pyramid(S, "TourelleToit", "Ardoise", 2.0, H - 3, 5.5, sides=8, turn=22.5, loc=(cx, cy))
        S.cyl("TourelleEpi", "Laiton", 0.08, 1.2, (cx, cy, H + 3.0), rot=(90, 0, 0), verts=6)
    return S


def corps(name="Fort_Corps", seed=43):
    """Corps de garde 14 × 10 × 12 : bâtisse trapue crénelée, porte cloutée, meurtrières, bretèche."""
    rng = random.Random(seed)
    S = fresh(name)
    W, D, H = 14, 10, 10.5
    S.box("Soubassement", "PierreSombre", (W + 0.8, D + 0.8, 1.6), (0, 0, 0.8), bevel=0.1)
    S.box("Ame", "PierreSombre", (W - 0.5, D - 0.5, H - 1.6), (0, 0, 1.6 + (H - 1.6) / 2))

    def door_skip(x, z):
        return abs(x) < 2.0 and z < 5.4

    stone_walls(S, "Mur", W, D, 1.6, H - 0.8, rng, course=1.6, stone=(2.0, 3.0), skip_front=door_skip, depth=0.4)
    arched_door(S, "Porte", 0, -D / 2 - 0.05, 2.8, 3.4, z=0.2)
    for ang in (0, 90, 180, 270):
        length = W if ang in (0, 180) else D

        def face(length=length, ang=ang):
            for x in (-length / 2 + 2.2, length / 2 - 2.2):
                S.box(f"Meurtriere{x}", "Fer", (0.3, 0.5, 2.0), (x, -(D if ang in (0, 180) else W) / 2 - 0.05, 5.5), bevel=0)
            S.box("Cordon", "PierreClaire", (length + 0.5, 0.5, 0.4), (0, -(D if ang in (0, 180) else W) / 2 - 0.05, H - 0.6), bevel=0.04)
            dist = (D if ang in (0, 180) else W) / 2
            S.box("Parapet", "Pierre", (length + 0.4, 0.9, 1.0), (0, -dist + 0.25, H + 0.5), bevel=0.05)
            merlons(S, "Merlon", -length / 2, length / 2, -dist + 0.25, H + 1.0, width=1.8, gap=1.3, height=1.4, depth=0.9)
        on_face(S, ang, face)
    S.box("Toit", "Pierre", (W - 0.6, D - 0.6, 0.4), (0, 0, H + 0.2), bevel=0.03)
    # bretèche au-dessus de la porte
    S.box("Breteche", "Pierre", (3.4, 1.4, 2.2), (0, -D / 2 - 0.8, 7.6), bevel=0.05)
    for x in (-1.2, 0, 1.2):
        S.box(f"BretecheCorbeau{x}", "PierreSombre", (0.5, 1.2, 1.0), (x, -D / 2 - 0.6, 6.2), bevel=0.03, taper=(1, 0.4))
    S.box("BretecheMeurtriere", "Fer", (0.25, 0.1, 1.0), (0, -D / 2 - 1.55, 7.7), bevel=0)
    S.box("Lanterne", "Lumiere", (0.45, 0.45, 0.6), (2.4, -D / 2 - 0.9, 4.6), bevel=0.04)
    S.box("LanternePotence", "Fer", (0.12, 0.9, 0.12), (2.4, -D / 2 - 0.45, 5.0), bevel=0)
    mark(S, "Pose", "Fort_Torche", (-2.4, -D / 2 - 0.1, 2.8))
    mark(S, "Pose", "Fort_Brasero", (-5.2, -D / 2 - 1.8, 0))
    for side in (-1, 1):
        mark(S, "Pose", "Fort_Torche", (side * (W / 2 + 0.1), 0, 3.0), yaw=side * 90)
    # étendard pendu sur le flanc
    S.box("Tenture", "Tissu", (2.0, 0.08, 4.0), (-4.5, -D / 2 - 0.12, 6.2), bevel=0)
    S.box("TentureBarre", "Fer", (2.4, 0.15, 0.15), (-4.5, -D / 2 - 0.15, 8.25), bevel=0)
    S.box("TentureBlason", "Laiton", (0.8, 0.06, 0.8), (-4.5, -D / 2 - 0.2, 6.6), rot=(0, 45, 0), bevel=0)
    return S


# --- Siège et décor ------------------------------------------------------------------------------
def plank_row(S, prefix, x0, x1, y, z0, z1, thick=0.3, width=0.9, mat="Bois", rng=None):
    rng = rng or random.Random(1)
    x = x0
    i = 0
    while x < x1 - 0.1:
        w = min(width * rng.uniform(0.85, 1.1), x1 - x)
        top = z1 + rng.uniform(-0.3, 0.2)
        S.box(f"{prefix}{i}", mat, (w - 0.06, thick, top - z0), (x + w / 2, y, (z0 + top) / 2), rot=(0, rng.uniform(-2, 2), 0), bevel=0.02)
        x += w
        i += 1


def trebuchet(name="Fort_Trebuchet", seed=51):
    """Trébuchet brisé (10 × 8 × 12) : châssis de poutres, chevalets en A, verge cassée, huche à
    contrepoids cerclée de fer, roues."""
    rng = random.Random(seed)
    S = fresh(name)
    for y in (-3.2, 3.2):
        S.box(f"Longeron{y}", "Bois", (10, 0.8, 0.8), (0, y, 0.6), bevel=0.04)
    for x in (-4.4, 0, 4.4):
        S.box(f"Traverse{x}", "Bois", (0.8, 7.2, 0.7), (x, 0, 1.2), bevel=0.04)
    for x in (-4.4, 4.4):
        for y in (-3.6, 3.6):
            S.cyl(f"Roue{x}{y}", "Bois", 1.0, 0.4, (x, y, 1.0), verts=10)
            S.cyl(f"Moyeu{x}{y}", "Fer", 0.3, 0.5, (x, y, 1.0), verts=6)
    for y in (-2.6, 2.6):
        for sx in (-1, 1):
            S.box(f"Chevalet{y}{sx}", "Bois", (0.6, 0.6, 8.6), (sx * 1.9, y, 4.9), rot=(0, sx * -14, 0), bevel=0.03)
        S.box(f"ChevaletEntretoise{y}", "Bois", (3.4, 0.5, 0.5), (0, y, 4.5), bevel=0.03)
    S.cyl("Axe", "Fer", 0.35, 6.4, (0, 0, 9.0), verts=8)
    # verge brisée : tronçon court vers la huche, tronçon long cassé posé au sol
    S.box("Verge", "Bois", (0.7, 0.7, 4.6), (1.2, 0, 7.4), rot=(0, 32, 0), bevel=0.03)
    S.box("VergeEclat", "Bois", (0.5, 0.5, 1.2), (-0.2, 0, 10.3), rot=(0, -18, 0), bevel=0.02)
    S.box("VergeTombee", "Bois", (0.7, 0.7, 7.5), (-3.0, 1.0, 1.7), rot=(80, 0, 62), bevel=0.03)
    S.box("Huche", "Bois", (2.6, 2.4, 2.4), (2.7, 0, 3.6), rot=(0, 10, 0), bevel=0.04)
    for z in (2.8, 4.4):
        S.box(f"HucheCercle{z}", "Fer", (2.7, 2.5, 0.2), (2.7, 0, z), rot=(0, 10, 0), bevel=0)
    S.box("Fronde", "Tissu", (0.08, 1.6, 2.2), (-4.6, 0.8, 0.9), rot=(0, 70, 30), bevel=0)
    mark(S, "Fx", "Fumee", (2.7, 0, 4.9), size=0.7)
    mark(S, "Fx", "Braises", (2.7, 0, 4.9), size=0.6)
    floating(S, "Pierre", (-1, -1, 0.6), 2.5, 4, rng, zr=(0, 0.6), size=0.9)
    crystal_cluster(S, "Eclat", (0.4, -0.8, 9.6), scale=0.8, rng=rng, tilt=(20, 40), count=3)
    return S


def belier(name="Fort_Belier", seed=52):
    """Bélier couvert (4 × 10 × 5) : châssis à roues, toit en bâtière de planches et de peaux,
    tronc suspendu à tête de fer."""
    rng = random.Random(seed)
    S = fresh(name)
    for x in (-1.6, 1.6):
        S.box(f"Longeron{x}", "Bois", (0.5, 10, 0.5), (x, 0, 0.9), bevel=0.03)
        for y in (-3.8, 0, 3.8):
            S.cyl(f"Roue{x}{y}", "Bois", 0.75, 0.35, (x * 1.15, y, 0.75), rot=(0, 0, 90), verts=10)
            S.box(f"Poteau{x}{y}", "Bois", (0.4, 0.4, 3.0), (x, y, 2.4), bevel=0.02)
    for y in (-3.8, 0, 3.8):
        S.box(f"Entrait{y}", "Bois", (3.6, 0.35, 0.35), (0, y, 3.8), bevel=0)
    prism(S, "Toit", "Bois", [(-2.4, 3.8), (2.4, 3.8), (0, 5.3)], 10.4, axis="y")
    for side in (-1, 1):
        S.box(f"Peaux{side}", "Tissu", (0.08, 9.0, 2.4), (side * 1.25, 0.3, 4.5), rot=(0, side * -58, 0), bevel=0)
    S.cyl("Tronc", "Bois", 0.45, 10.5, (0, -0.3, 2.6), verts=8)
    S.cyl("Tete", "Fer", 0.65, 1.2, (0, -5.6, 2.6), verts=8, radius2=0.3)
    for y in (-2.5, 2.5):
        S.box(f"Chaine{y}", "Fer", (0.1, 0.1, 1.2), (0, y, 3.2), bevel=0)
    return S


def barricade(name="Fort_Barricade", seed=53):
    """Barricade (8 × 2 × 3) : planches clouées sur des chevalets, pieux appointés, sacs."""
    rng = random.Random(seed)
    S = fresh(name)
    plank_row(S, "Planche", -4, 4, -0.2, 0.0, 2.7, rng=rng)
    S.box("Traverse", "Bois", (8.2, 0.25, 0.35), (0, -0.45, 2.0), bevel=0)
    S.box("TraverseBas", "Bois", (8.2, 0.25, 0.35), (0, -0.45, 0.7), bevel=0)
    for x in (-3.4, 0, 3.4):
        S.box(f"Etai{x}", "Bois", (0.35, 0.35, 3.0), (x, 0.55, 1.3), rot=(28, 0, 0), bevel=0)
    for i, x in enumerate((-3.6, -2.4, -1.2, 0, 1.2, 2.4, 3.6)):
        S.box(f"Pieu{i}", "Bois", (0.3, 0.3, 1.8), (x, -0.95, 1.6 + rng.uniform(-0.2, 0.2)), rot=(-40, 0, 0), bevel=0)
        S.crystal(f"PieuPointe{i}", "Bois", 0.2, 0.01, 0.45, (x, -1.55, 2.3), rot=(140, 0, 0), sides=4)
    for i in range(3):
        S.box(f"Bande{i}", "Fer", (0.1, 0.32, 2.4), (-3 + i * 3, -0.38, 1.3), bevel=0)
    for i, (x, z) in enumerate(((-2.8, 0.35), (-1.9, 0.35), (-2.35, 0.95))):
        S.sphere(f"Sac{i}", "Tissu", 0.6, (x, 0.65, z), scale=(1.2, 0.8, 0.55))
    return S


def chaudiere(name="Fort_Chaudiere", seed=54):
    """Chaudière à vapeur (6 × 6 × 8) : cuve rivetée sur socle de pierre, foyer chaud, hublot cyan,
    soupapes, manomètre, tuyaux et cheminée."""
    rng = random.Random(seed)
    S = fresh(name)
    S.box("Socle", "PierreSombre", (5.6, 5.6, 1.4), (0, 0, 0.7), bevel=0.06)
    S.box("Foyer", "Fer", (2.4, 0.4, 1.2), (0, -2.1, 1.9), bevel=0.03)
    S.box("FoyerBraises", "Lumiere", (1.8, 0.3, 0.6), (0, -2.25, 1.7), bevel=0)
    S.cyl("Cuve", "Laiton", 2.3, 4.8, (0, 0, 4.0), rot=(90, 0, 0), verts=14)
    S.sphere("Dome", "Laiton", 2.3, (0, 0, 6.4), scale=(1, 1, 0.45), detail=2)
    for z in (2.0, 3.4, 4.8, 6.1):
        S.cyl(f"Cercle{z}", "Fer", 2.38, 0.22, (0, 0, z), rot=(90, 0, 0), verts=14)
    S.cyl("Hublot", "Noyau", 0.55, 0.3, (0, -2.25, 4.2), verts=10)
    S.ring("HublotCercle", "Fer", 0.62, 0.12, (0, -2.35, 4.2), seg=10, sides=4)
    S.cyl("Manometre", "Laiton", 0.45, 0.25, (1.5, -1.95, 5.4), rot=(0, 0, 30), verts=10)
    S.cyl("ManometreCadran", "PierreClaire", 0.36, 0.1, (1.56, -2.1, 5.4), rot=(0, 0, 30), verts=10)
    S.cyl("Cheminee", "Fer", 0.45, 3.2, (0.8, 0.6, 8.4), rot=(90, 0, 0), verts=8)
    S.cyl("ChemineeCol", "Fer", 0.65, 0.5, (0.8, 0.6, 10.0), rot=(90, 0, 0), verts=8)
    S.cyl("Soupape", "Laiton", 0.25, 1.0, (-0.9, -0.4, 7.4), rot=(90, 0, 0), verts=6)
    mark(S, "Fx", "Vapeur", (0.8, 0.6, 10.4), size=1.2)
    mark(S, "Fx", "Soupape", (-0.9, -0.4, 8.0), size=0.6)
    mark(S, "Fx", "Braises", (0, -2.5, 1.8), size=1.0)
    mark(S, "Fx", "Lueur", (0, -2.6, 4.2), size=0.8)
    S.gear("Volant", "Fer", 0.55, 0.12, 6, (-1.6, -1.8, 3.1), rot=(0, 0, 40), tooth=0.12)
    S.cyl("Tuyau", "Laiton", 0.22, 4.0, (2.6, 0.5, 3.0), rot=(90, 0, 0), verts=8)
    S.cyl("TuyauCoude", "Laiton", 0.22, 2.2, (1.6, 0.5, 5.0), rot=(0, 0, 90), verts=8)
    S.cyl("TuyauSol", "Laiton", 0.22, 2.4, (2.6, -0.7, 1.0), rot=(0, 0, 0), verts=8)
    return S


def horloge(name="Fort_Horloge", seed=55):
    """Mécanisme d'horlogerie figé (6 × 4 × 8) : bâti de fer sur socle de pierre, roues dentées de laiton,
    cadran, balancier arrêté, éclat de cristal coincé dans les engrenages."""
    rng = random.Random(seed)
    S = fresh(name)
    S.box("Socle", "PierreSombre", (6, 4, 1.0), (0, 0, 0.5), bevel=0.05)
    for x in (-2.6, 2.6):
        S.box(f"Montant{x}", "Fer", (0.4, 0.4, 7.0), (x, -1.2, 4.5), bevel=0.02)
        S.box(f"MontantB{x}", "Fer", (0.4, 0.4, 7.0), (x, 1.2, 4.5), bevel=0.02)
    for z in (3.0, 7.8):
        S.box(f"Traverse{z}", "Fer", (5.6, 0.35, 0.35), (0, -1.2, z), bevel=0)
        S.box(f"TraverseB{z}", "Fer", (5.6, 0.35, 0.35), (0, 1.2, z), bevel=0)
    gears = (("Roue0", "Laiton", 1.8, 0.25, 18, (-0.9, -0.2, 5.0), 0.18, 1.0),
             ("Roue1", "Laiton", 1.0, 0.25, 10, (1.6, 0.3, 6.1), 0.15, -1.8),
             ("Roue2", "Laiton", 0.7, 0.25, 8, (1.4, -0.5, 3.9), 0.12, 2.25),
             ("Roue3", "Fer", 1.2, 0.2, 12, (-1.2, 0.7, 6.9), 0.14, -1.5))
    for key, mat, r, t, teeth, loc, tooth, ratio in gears:
        anim([S.gear(key, mat, r, t, teeth, loc, tooth=tooth)], key)
        mark(S, "Pivot", key, loc, axis=(0, 1, 0), mode="tick", ratio=ratio)
    for x, z in ((-0.9, 5.0), (1.6, 6.1), (1.4, 3.9), (-1.2, 6.9)):
        S.cyl(f"Axe{x}", "Fer", 0.12, 2.6, (x, 0, z), verts=6)
    S.cyl("Cadran", "PierreClaire", 1.3, 0.2, (0, -1.5, 8.9), verts=16)
    S.ring("CadranCercle", "Laiton", 1.35, 0.12, (0, -1.6, 8.9), seg=16, sides=4)
    S.box("CadranSupport", "Fer", (0.3, 0.3, 1.0), (0, -1.2, 8.1), bevel=0)
    S.box("Aiguille", "Fer", (0.12, 0.1, 1.0), (0.3, -1.68, 9.2), rot=(0, 30, 0), bevel=0)
    anim([S.box("Balancier", "Fer", (0.12, 0.12, 4.2), (0.5, 0.2, 3.6), rot=(0, 12, 0), bevel=0),
          S.cyl("BalancierDisque", "Laiton", 0.6, 0.15, (0.95, 0.2, 1.65), verts=12)], "Balancier")
    mark(S, "Pivot", "Balancier", (0.06, 0.2, 5.65), axis=(0, 1, 0), mode="stutter")
    mark(S, "Fx", "Eclats", (0.4, -0.6, 5.6), size=0.6)
    crystal_cluster(S, "Coince", (0.4, -0.4, 5.6), scale=1.0, rng=rng, tilt=(-40, 25), count=3)
    floating(S, "Rouage", (0, -1.4, 7.8), 1.6, 3, rng, zr=(0.5, 2.5), mat="Laiton", size=0.4)
    return S


def cloche(name="Fort_Cloche", seed=56):
    """Cloche figée (5 × 5 × 8) : beffroi de poutres sur dalle, petit toit, cloche de laiton arrêtée
    en pleine volée, fêlure cyan."""
    rng = random.Random(seed)
    S = fresh(name)
    S.box("Dalle", "PierreSombre", (5, 5, 0.6), (0, 0, 0.3), bevel=0.05)
    for x in (-2.0, 2.0):
        for y in (-2.0, 2.0):
            S.box(f"Poteau{x}{y}", "Bois", (0.5, 0.5, 6.4), (x, y, 3.8), bevel=0.03)
    for y in (-2.0, 2.0):
        S.box(f"Sabliere{y}", "Bois", (4.8, 0.45, 0.45), (0, y, 6.8), bevel=0.02)
    S.box("Joug", "Bois", (4.6, 0.6, 0.6), (0, 0, 6.3), bevel=0.02)
    prism(S, "Toit", "Ardoise", [(-3.0, 7.0), (3.0, 7.0), (0, 8.8)], 5.4, axis="x")
    S.cyl("Cloche", "Laiton", 0.5, 2.6, (0.6, 0, 4.6), rot=(90, 0, 0), verts=14, radius2=1.4)
    S.cyl("ClocheLevre", "Laiton", 1.5, 0.3, (0.6, 0, 3.35), rot=(90, 0, 0), verts=14)
    pts = [(-0.1, 5.4), (0.3, 4.9), (0.0, 4.4), (0.4, 3.7)]
    ribbon(S, "Felure", "Noyau", [(x + 0.6, z - 0.2) for x, z in pts], [(x + 0.75, z - 0.2) for x, z in pts], 0.25, y=-1.05)
    # cloche figée en pleine volée : on bascule cloche, lèvre et fêlure autour du joug
    tilt = Matrix.Translation((0.6, 0, 6.0)) @ Matrix.Rotation(math.radians(24), 4, "Y") @ Matrix.Translation((-0.6, 0, -6.0))
    for o in S.coll.objects:
        if o.name.split(".")[0] in ("Cloche", "ClocheLevre", "Felure"):
            o.matrix_world = tilt @ o.matrix_world
    anim([o for o in S.coll.objects if o.name.split(".")[0] in ("Cloche", "ClocheLevre", "Felure")], "Cloche")
    mark(S, "Pivot", "Cloche", (0, 0, 6.0), axis=(0, 1, 0), mode="tremble")
    mark(S, "Fx", "Eclats", (0.9, -0.6, 4.2), size=0.8)
    floating(S, "Eclat", (0.8, 0, 3.0), 1.5, 4, rng, zr=(0, 2.0), size=0.35)
    return S


def puits(name="Fort_Puits", seed=57):
    """Puits (5 × 5 × 4) : margelle de pierre, eau sombre teintée de cyan, potence à treuil, seau."""
    rng = random.Random(seed)
    S = fresh(name)
    ring_stones(S, "Margelle", 2.1, 0, 1.6, rng, course=0.8, count=12, depth=0.5)
    S.cyl("MargelleAme", "PierreSombre", 1.95, 1.6, (0, 0, 0.8), rot=(90, 0, 0), verts=12)
    S.cyl("Rebord", "PierreClaire", 2.35, 0.3, (0, 0, 1.75), rot=(90, 0, 0), verts=12)
    S.cyl("Eau", "Noyau", 1.6, 0.1, (0, 0, 1.2), rot=(90, 0, 0), verts=12)
    mark(S, "Fx", "Eclats", (0, 0, 1.6), size=1.0)
    for x in (-2.0, 2.0):
        S.box(f"Montant{x}", "Bois", (0.35, 0.35, 3.6), (x, 0, 3.4), bevel=0.02)
    S.cyl("Treuil", "Bois", 0.3, 3.8, (0, 0, 4.0), rot=(0, 0, 90), verts=8)
    S.box("Manivelle", "Fer", (0.12, 0.12, 0.7), (2.3, 0, 3.7), bevel=0)
    prism(S, "Toit", "Ardoise", [(-1.6, 5.0), (1.6, 5.0), (0, 6.2)], 4.8, axis="x")
    S.box("Corde", "Tissu", (0.08, 0.08, 1.6), (0, 0, 3.1), bevel=0)
    S.cyl("Seau", "Bois", 0.35, 0.6, (0, 0, 2.1), rot=(90, 0, 0), verts=8, radius2=0.28)
    return S


def ratelier(name="Fort_Ratelier", seed=58):
    """Râtelier d'armes (6 × 1 × 4) : cadre de bois, lances, épées et bouclier."""
    rng = random.Random(seed)
    S = fresh(name)
    for x in (-2.8, 2.8):
        S.box(f"Montant{x}", "Bois", (0.3, 0.6, 3.4), (x, 0, 1.7), bevel=0.02)
        S.box(f"Pied{x}", "Bois", (0.4, 1.2, 0.3), (x, 0, 0.15), bevel=0.02)
    for z in (0.6, 2.8):
        S.box(f"Barre{z}", "Bois", (5.9, 0.35, 0.3), (0, 0, z), bevel=0.02)
    for i in range(6):
        x = -2.2 + i * 0.85
        if i % 3 == 2:
            S.box(f"Lame{i}", "Fer", (0.18, 0.05, 2.4), (x, -0.25, 1.9), rot=(0, 0, 0), bevel=0)
            S.box(f"Garde{i}", "Laiton", (0.6, 0.12, 0.12), (x, -0.25, 0.8), bevel=0)
        else:
            S.cyl(f"Hampe{i}", "Bois", 0.07, 3.6, (x, -0.2, 1.9), rot=(90, 0, rng.uniform(-3, 3)), verts=6)
            S.crystal(f"Fer{i}", "Fer", 0.12, 0.5, 0.05, (x, -0.2, 3.8), sides=4)
    S.cyl("Bouclier", "Bois", 0.75, 0.15, (1.9, -0.45, 1.3), rot=(0, 10, 0), verts=10)
    S.cyl("BouclierUmbo", "Fer", 0.25, 0.2, (1.9, -0.55, 1.3), verts=8)
    S.box("BouclierBande", "Tissu", (0.3, 0.06, 1.4), (1.9, -0.53, 1.3), rot=(0, 10, 0), bevel=0)
    return S


def sarcophage(name="Fort_Sarcophage", seed=59):
    """Sarcophage (3 × 6 × 2,2) : cuve à arcatures gothiques, couvercle à gisant fendu, lueur cyan."""
    rng = random.Random(seed)
    S = fresh(name)
    S.box("Socle", "PierreSombre", (3.2, 6.2, 0.4), (0, 0, 0.2), bevel=0.04)
    S.box("Cuve", "Pierre", (2.8, 5.8, 1.3), (0, 0, 1.05), bevel=0.05)
    for side in (-1, 1):
        for i in range(4):
            y = -2.1 + i * 1.4
            lancet(S, f"Arcature{side}{i}", "PierreSombre", 0, 0.55, 0.7, 0.9, 0, depth=0.08, frame="PierreClaire")
            for o in list(S.coll.objects)[-3:]:
                o.matrix_world = Matrix.Translation((side * 1.43, y, 0)) @ Matrix.Rotation(math.radians(90), 4, "Z") @ o.matrix_world
    # couvercle fendu en deux, une moitié déplacée : la lueur s'échappe
    S.box("Couvercle0", "PierreClaire", (3.0, 3.1, 0.35), (0, -1.45, 1.88), rot=(0, 0, 0), bevel=0.05)
    S.box("Couvercle1", "PierreClaire", (3.0, 2.8, 0.35), (0.35, 1.6, 1.95), rot=(3, -4, 9), bevel=0.05)
    S.box("Gisant", "Pierre", (1.1, 2.6, 0.4), (0, -1.5, 2.25), bevel=0.08)
    S.sphere("GisantTete", "Pierre", 0.35, (0, -2.6, 2.4), scale=(1, 1, 0.8))
    S.box("Lueur", "Noyau", (2.4, 0.15, 0.1), (0.1, 0.05, 1.75), rot=(0, 0, 9), bevel=0)
    mark(S, "Fx", "Eclats", (0.1, 0.05, 2.0), size=0.8)
    floating(S, "Eclat", (0.2, 0.3, 2.3), 0.8, 3, rng, zr=(0.3, 1.5), size=0.3)
    return S


def etendard(name="Fort_Etendard", seed=60):
    """Étendard déchiré (1 × 1 × 10) : mât de bois à pointe de fer, bannière pourpre effrangée, blason de laiton."""
    rng = random.Random(seed)
    S = fresh(name)
    S.cyl("Mat", "Bois", 0.14, 10, (0, 0, 5), rot=(90, 0, 0), verts=8)
    S.box("Pied", "PierreSombre", (1.0, 1.0, 0.5), (0, 0, 0.25), bevel=0.05)
    S.crystal("Pointe", "Fer", 0.18, 0.7, 0.05, (0, 0, 10.05), sides=4)
    S.cyl("Hampe", "Fer", 0.06, 2.4, (1.15, 0, 9.4), rot=(0, 0, 90), verts=6)
    # bannière : bas en dents de scie, légère ondulation
    top = 9.3
    xs = [0.15 + i * 0.3 for i in range(9)]
    upper = [(x, top) for x in xs]
    lower = [(x, top - 5.2 + (0.9 if i % 2 else 0) + rng.uniform(-0.3, 0.3) - (0.8 if 3 <= i <= 5 else 0)) for i, x in enumerate(xs)]
    ribbon(S, "Banniere", "Tissu", lower, upper, 0.06, y=0)
    for o in list(S.coll.objects)[-1:]:
        for v in o.data.vertices:
            v.co.y += math.sin(v.co.x * 2.4) * 0.15
    S.box("Blason", "Laiton", (0.8, 0.08, 0.9), (1.35, -0.1, 7.4), rot=(0, 0, 0), bevel=0.02)
    S.crystal("BlasonEclat", "Noyau", 0.12, 0.35, 0.2, (1.35, -0.18, 7.45), rot=(90, 0, 0), sides=4)
    anim([o for o in S.coll.objects if o.name.split(".")[0] in ("Banniere", "Blason", "BlasonEclat")], "Banniere")
    mark(S, "Pivot", "Banniere", (0.15, 0, 9.3), axis=(0, 0, 1), mode="sway")
    return S


def eboulis(name="Fort_Eboulis", seed=61):
    """Éboulis (5 × 3 × 2,5) : blocs de maçonnerie tombés, merlon brisé, poutre, éclats."""
    rng = random.Random(seed)
    S = fresh(name)
    blocks = ((-1.6, 0.2, 0.55, 1.6, 1.2, 1.1), (0.2, -0.3, 0.5, 1.8, 1.4, 1.0), (1.7, 0.4, 0.45, 1.3, 1.1, 0.9),
              (-0.6, 0.5, 1.4, 1.5, 1.1, 0.9), (0.9, 0.1, 1.3, 1.2, 1.0, 0.8), (-0.1, -0.1, 2.1, 1.6, 0.9, 0.8))
    for i, (x, y, z, w, d, h) in enumerate(blocks):
        S.box(f"Bloc{i}", "Pierre" if i % 3 else "PierreSombre", (w, d, h), (x, y, z), rot=(rng.uniform(-12, 12), rng.uniform(-12, 12), rng.uniform(-25, 25)),
              bevel=0.06)
    S.box("MerlonBrise", "Pierre", (1.6, 0.9, 1.3), (-1.9, -0.6, 1.2), rot=(25, -30, 10), bevel=0.05)
    S.box("MerlonChapeau", "PierreClaire", (1.8, 1.1, 0.25), (-2.1, -0.8, 1.9), rot=(25, -30, 10), bevel=0.03)
    S.box("Poutre", "Bois", (0.5, 0.5, 4.2), (1.0, 0.6, 1.3), rot=(70, 10, 30), bevel=0.03)
    for i in range(5):
        S.box(f"Gravat{i}", "PierreSombre", (0.5, 0.4, 0.3), (rng.uniform(-2.4, 2.4), rng.uniform(-1.4, 1.4), 0.15), rot=(0, 0, rng.uniform(0, 90)), bevel=0)
    crystal_cluster(S, "Eclat", (1.9, -0.5, 0.5), scale=0.7, rng=rng, tilt=(-30, 40), count=3)
    return S


# --- Feux -----------------------------------------------------------------------------------------
def torche(name="Fort_Torche"):
    """Torche murale (pose : platine contre le mur en y = 0, la torche sort vers -Y) : platine de fer,
    bras, coupe, manche de bois, flamme (Lumiere) ; le jeu y ajoute feu, lumière vacillante, braises."""
    S = fresh(name)
    S.box("Platine", "Fer", (0.7, 0.12, 1.2), (0, -0.06, 0.6), bevel=0.02)
    for z in (0.2, 1.0):
        S.cyl(f"Clou{z}", "Laiton", 0.07, 0.1, (0, -0.15, z), verts=6)
    S.box("Bras", "Fer", (0.12, 0.8, 0.12), (0, -0.45, 0.55), rot=(-25, 0, 0), bevel=0)
    S.ring("Collier", "Fer", 0.2, 0.05, (0, -0.85, 0.8), rot=(90, 0, 0), seg=8, sides=4)
    S.cyl("Manche", "Bois", 0.1, 1.5, (0, -0.95, 1.05), rot=(70, 0, 0), verts=6, radius2=0.14)
    S.cyl("Coupe", "Fer", 0.26, 0.4, (0, -1.15, 1.75), rot=(70, 0, 0), verts=8, radius2=0.14)
    S.crystal("Flamme", "Lumiere", 0.18, 0.55, 0.05, (0, -1.2, 1.95), sides=5)
    mark(S, "Fx", "Flamme", (0, -1.2, 2.05), size=1.0)
    return S


def brasero(name="Fort_Brasero"):
    """Brasero (2 × 2 × 3) : trépied de fer, vasque, braises (Lumiere) ; le jeu y ajoute feu et fumée."""
    S = fresh(name)
    for i in range(3):
        a = i / 3 * math.tau
        S.box(f"Pied{i}", "Fer", (0.14, 0.14, 2.4), (math.cos(a) * 0.55, math.sin(a) * 0.55, 1.1),
              rot=(math.sin(a) * -12, math.cos(a) * 12, 0), bevel=0)
    S.ring("Anneau", "Fer", 0.6, 0.06, (0, 0, 0.9), rot=(90, 0, 0), seg=10, sides=4)
    S.cyl("Vasque", "Fer", 0.95, 0.6, (0, 0, 2.35), rot=(90, 0, 0), verts=10, radius2=0.55)
    S.ring("Levre", "Fer", 0.95, 0.08, (0, 0, 2.65), rot=(90, 0, 0), seg=10, sides=4)
    S.cyl("Braises", "Lumiere", 0.82, 0.12, (0, 0, 2.6), rot=(90, 0, 0), verts=10)
    for i in range(5):
        a = i / 5 * math.tau
        S.box(f"Buche{i}", "Bois", (0.16, 0.9, 0.16), (math.cos(a) * 0.3, math.sin(a) * 0.3, 2.75),
              rot=(25, 0, math.degrees(a)), bevel=0)
    mark(S, "Fx", "Feu", (0, 0, 2.8), size=1.4)
    return S


BUILDS = {
    "Fort_Mur": lambda: courtine("Fort_Mur"),
    "Fort_MurFracture": lambda: courtine("Fort_MurFracture", fracture=True, seed=2),
    "Fort_Porte": porte,
    "Fort_Rempart": rempart,
    "Fort_Tourelle": tourelle,
    "Fort_Escalier": escalier,
    "Fort_Donjon": donjon,
    "Fort_TourGuet": tour_guet,
    "Fort_Maison": maison,
    "Fort_GrandeMaison": lambda: maison("Fort_GrandeMaison", W=16, D=12, H=18, seed=42, grande=True),
    "Fort_Corps": corps,
    "Fort_Trebuchet": trebuchet,
    "Fort_Belier": belier,
    "Fort_Barricade": barricade,
    "Fort_Chaudiere": chaudiere,
    "Fort_Horloge": horloge,
    "Fort_Cloche": cloche,
    "Fort_Puits": puits,
    "Fort_Ratelier": ratelier,
    "Fort_Sarcophage": sarcophage,
    "Fort_Cristal": cristal,
    "Fort_Etendard": etendard,
    "Fort_Eboulis": eboulis,
    "Fort_Torche": torche,
    "Fort_Brasero": brasero,
    "Fort_Dalle": dalles,
    "Fort_DalleFissure": lambda: dalles("Fort_DalleFissure", seed=9, fissure=True),
    "Fort_Pave": paves,
    "Fort_Plancher": plancher,
    "Fort_Marches": marches,
    "Fort_Tour": tour,  # tour de l'échantillon (vignette seulement, non exportée)
}
NOT_EXPORTED = {"Fort_Tour"}


def join_by_material(name):
    """Joint les pièces du module par matériau (modificateurs appliqués) dans « <nom>_Export » :
    une pièce « <Module>_<Matériau> » par matériau, origine du module = origine Blender."""
    src = bpy.data.collections[name]
    export_name = name + "_Export"
    old = bpy.data.collections.get(export_name)
    if old:
        for o in list(old.objects):
            bpy.data.objects.remove(o, do_unlink=True)
        bpy.data.collections.remove(old)
    exp = bpy.data.collections.new(export_name)
    bpy.context.scene.collection.children.link(exp)
    dg = bpy.context.evaluated_depsgraph_get()
    groups = {}
    for obj in src.objects:
        if obj.type == "MESH":
            mat = obj.get("fracture_mat", "Pierre")
            key = f"Anim{obj['anim']}_{mat}" if "anim" in obj else mat
            groups.setdefault(key, []).append(obj)
    made = {}
    for key, objs in groups.items():
        bm = bmesh.new()
        for obj in objs:
            ev = obj.evaluated_get(dg)
            mesh = ev.to_mesh()
            mesh.transform(obj.matrix_world)
            bm.from_mesh(mesh)
            ev.to_mesh_clear()
        mesh = bpy.data.meshes.new(f"{name}_{key}")
        bm.to_mesh(mesh)
        bm.free()
        joined = bpy.data.objects.new(f"{name}_{key}", mesh)
        joined.data.materials.append(bpy.data.materials[MATERIALS[key.split("_")[-1]]])
        exp.objects.link(joined)
        made[joined.name] = sum(len(p.vertices) - 2 for p in mesh.polygons)
    return exp, made


def export_fbx(collections, path):
    """Un seul FBX pour tout le kit (un seul import dans Studio) ; échelle 0,01 (Studio lit des cm)."""
    bpy.ops.object.select_all(action="DESELECT")
    for coll in collections:
        for o in coll.objects:
            o.select_set(True)
    bpy.context.view_layer.objects.active = collections[0].objects[0]
    bpy.ops.export_scene.fbx(
        filepath=path, use_selection=True, object_types={"MESH"}, use_mesh_modifiers=True,
        mesh_smooth_type="FACE", apply_unit_scale=True, global_scale=0.01,
        axis_forward="-Z", axis_up="Y", bake_space_transform=True, add_leaf_bones=False,
    )
    bpy.ops.object.select_all(action="DESELECT")


def collect_marks(name):
    """Repères du module en coordonnées Blender (le script d'import Studio les convertit)."""
    from mathutils import Vector

    out = []
    for o in bpy.data.collections[name].objects:
        if o.type == "EMPTY" and "kind" in o:
            m = o.matrix_world
            axis = m.to_3x3() @ Vector((0, 0, 1))
            fwd = m.to_3x3() @ Vector((0, -1, 0))
            entry = {"kind": o["kind"], "key": o["key"], "pos": [round(v, 4) for v in m.translation],
                     "axis": [round(v, 4) for v in axis], "fwd": [round(v, 4) for v in fwd]}
            for k in o.keys():
                if k not in ("kind", "key"):
                    entry[k] = o[k]
            out.append(entry)
    return out


def build(only=None, export=False):
    out = {}
    exports = []
    marks = {}
    for name, fn in BUILDS.items():
        if only and name not in only:
            continue
        S = fn()
        if name not in NOT_EXPORTED:
            S.box("Origine", "Origine", (0.2, 0.2, 0.2), (0, 0, 0), bevel=0)
        exp, parts = join_by_material(name)
        marks[name] = collect_marks(name)
        out[name] = {"tris": sum(parts.values()), "max": max(parts.values()), "parts": len(parts)}
        if name in NOT_EXPORTED:
            for o in list(exp.objects):
                bpy.data.objects.remove(o, do_unlink=True)
            bpy.data.collections.remove(exp)
        else:
            exp.hide_render = True
            exports.append(exp)
    if export and exports:
        import json

        export_fbx(exports, os.path.join(HERE, "FortKit.fbx" if not only else "FortKit_partiel.fbx"))
        path = os.path.join(HERE, "FortKit_marks.json" if not only else "FortKit_partiel_marks.json")
        with open(path, "w", encoding="utf-8") as f:
            json.dump({k: v for k, v in marks.items() if k not in NOT_EXPORTED}, f, ensure_ascii=False, indent=1)
    for exp in exports:
        bpy.context.scene.collection.children.unlink(exp)
    return out


RESULT = build(globals().get("ONLY"), globals().get("EXPORT", False))
