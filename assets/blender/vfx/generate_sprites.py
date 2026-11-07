# Textures des particules de FRACTURE (v0.4.9), générées dans Blender (Python + numpy).
# Lancer dans Blender (onglet Script, ou via le serveur MCP) : écrit les PNG à côté de ce
# fichier. Blanc sur fond transparent : Roblox teinte les particules (cyan, rouge…).
#   Eclat.png      éclat de Temps (cristal effilé à facettes)
#   Etincelle.png  étincelle étirée
#   Lueur.png      halo doux
#   Poussiere.png  bouffée de poussière
#   Vignette.png   bords d'écran (santé basse, dégâts, soin)
import os

import bpy
import numpy as np

SIZE = 256
OUT = os.path.dirname(os.path.abspath(__file__)) if "__file__" in globals() else ""


def grid():
    lin = np.linspace(-0.5, 0.5, SIZE)
    x, y = np.meshgrid(lin, lin)
    return x, -y  # y vers le haut


def smooth(edge0, edge1, v):
    t = np.clip((v - edge0) / (edge1 - edge0), 0, 1)
    return t * t * (3 - 2 * t)


def value_noise(scale, seed):
    rng = np.random.default_rng(seed)
    coarse = rng.random((scale + 1, scale + 1))
    lin = np.linspace(0, scale, SIZE, endpoint=False)
    i = lin.astype(int)
    f = lin - i
    f = f * f * (3 - 2 * f)
    a = coarse[np.ix_(i, i)]
    b = coarse[np.ix_(i, i + 1)]
    c = coarse[np.ix_(i + 1, i)]
    d = coarse[np.ix_(i + 1, i + 1)]
    fx, fy = np.meshgrid(f, f)
    return (a * (1 - fx) + b * fx) * (1 - fy) + (c * (1 - fx) + d * fx) * fy


def shard():
    x, y = grid()
    # Losange effilé (plus long vers le haut), bord légèrement adouci.
    d = np.abs(x) / 0.17 + np.abs(y - 0.03) / np.where(y > 0.03, 0.45, 0.3)
    body = 1 - smooth(0.92, 1.0, d)
    # Facette : la moitié gauche plus claire, arête centrale brillante.
    facet = np.where(x < 0, 1.0, 0.72)
    ridge = np.exp(-(x / 0.012) ** 2) * 0.6
    halo = np.exp(-(d - 1) ** 2 / 0.08) * 0.25 * (d > 1)
    value = np.clip(body * (facet + ridge), 0, 1)
    alpha = np.clip(body + halo, 0, 1)
    return value, alpha


def spark():
    x, y = grid()
    d = (x / 0.035) ** 2 + (y / 0.46) ** 2
    core = np.exp(-d * 2.2)
    glow = np.exp(-((x / 0.09) ** 2 + (y / 0.5) ** 2) * 1.5) * 0.35
    alpha = np.clip(core + glow, 0, 1)
    return np.ones_like(alpha), alpha


def glow():
    x, y = grid()
    r2 = x * x + y * y
    alpha = np.exp(-r2 / (2 * 0.16 ** 2)) * 0.85 + np.exp(-r2 / (2 * 0.04 ** 2)) * 0.6
    return np.ones_like(alpha), np.clip(alpha, 0, 1)


def dust():
    x, y = grid()
    r = np.sqrt(x * x + y * y)
    noise = 0.55 * value_noise(4, 7) + 0.3 * value_noise(9, 11) + 0.15 * value_noise(18, 13)
    shape = 1 - smooth(0.22, 0.5, r + (noise - 0.5) * 0.18)
    alpha = np.clip(shape * (0.45 + 0.55 * noise), 0, 1)
    value = 0.85 + 0.15 * noise
    return value, alpha


def vignette():
    # Bords d'écran : transparent au centre, opaque dans les coins (étiré en plein écran).
    x, y = grid()
    r = np.sqrt((x * 2) ** 2 + (y * 2) ** 2) / np.sqrt(2)
    alpha = smooth(0.45, 1.0, r) ** 1.4
    return np.ones_like(alpha), alpha


def save(name, value, alpha):
    image = bpy.data.images.get(name) or bpy.data.images.new(name, SIZE, SIZE, alpha=True)
    rgba = np.zeros((SIZE, SIZE, 4), dtype=np.float32)
    rgba[..., 0] = value
    rgba[..., 1] = value
    rgba[..., 2] = value
    rgba[..., 3] = alpha
    image.pixels.foreach_set(rgba[::-1].ravel())  # Blender : première ligne = bas de l'image
    image.filepath_raw = os.path.join(OUT, name + ".png")
    image.file_format = "PNG"
    image.save()
    return image.filepath_raw


def run(out_dir=None):
    global OUT
    if out_dir:
        OUT = out_dir
    return [
        save("Eclat", *shard()),
        save("Etincelle", *spark()),
        save("Lueur", *glow()),
        save("Poussiere", *dust()),
        save("Vignette", *vignette()),
    ]


if __name__ == "__main__":
    print(run())
