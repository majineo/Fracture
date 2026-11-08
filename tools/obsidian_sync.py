"""Synchronise la base de connaissance Obsidian de FRACTURE depuis le dépôt (v0.11.0).

Usage (depuis le dossier du projet) :
    lune run tools/export_catalog
    python tools/obsidian_sync.py ["C:/Users/neost/Documents/fracture vault"]

Le dépôt reste la référence : chaque note générée porte `généré: true` dans ses propriétés et
est réécrite à chaque synchronisation (les notes générées devenues inutiles sont supprimées).
Le dossier « Mes notes » et toute note sans `généré: true` ne sont JAMAIS touchés.

Contenu : Accueil, GDD (un chapitre par note), Décisions (une par D-xxx), Versions (une par
version du CHANGELOG), Technique (architecture, assets, feuille de route…), Catalogue (armes,
capacités, objets, ennemis, tuiles, tirés des données du jeu via build/catalogue.json).
Les mentions « D-0xx », « vX.Y.Z » et les liens Markdown vers les documents deviennent des
liens Obsidian, pour un graphe navigable.
"""
import json
import os
import re
import sys
from datetime import date

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
VAULT = sys.argv[1] if len(sys.argv) > 1 else r"C:\Users\neost\Documents\fracture vault"
MARK = "généré: true"
BAD = re.compile(r'[\\/:*?"<>|#^\[\]]')


def read(rel):
    with open(os.path.join(ROOT, rel), encoding="utf-8") as f:
        return f.read()


def clean(name):
    # Les deux-points sont interdits dans un nom de fichier : « A : B » devient « A – B ».
    name = name.replace(" : ", " – ").replace(":", " –")
    name = BAD.sub("", name).replace("  ", " ").strip(" .")
    return name[:110]


notes = {}  # chemin relatif dans le coffre (sans .md) -> (propriétés, corps)
titles = {}  # clé de lien -> nom de note (sans dossier) pour [[...]]


def add(path, kind, body, source=None, tags=()):
    notes[path] = ({"type": kind, "source": source, "tags": list(tags)}, body)
    return os.path.basename(path)


# --- Documents -------------------------------------------------------------------------------
GDD_DIR = "docs/GDD"
DOC_FILES = {}  # nom de fichier .md du dépôt -> nom de note

for fname in sorted(os.listdir(os.path.join(ROOT, GDD_DIR))):
    if not fname.endswith(".md") or fname == "README.md":
        continue
    text = read(f"{GDD_DIR}/{fname}")
    head = re.search(r"^#\s+(.+)$", text, re.M)
    title = clean("GDD " + (head.group(1) if head else fname[:-3]))
    body = re.sub(r"^#\s+.+\n", "", text, count=1)
    DOC_FILES[fname] = title
    add(f"GDD/{title}", "gdd", body, f"{GDD_DIR}/{fname}", ["gdd"])

TECH = {
    "docs/ARCHITECTURE.md": "Architecture",
    "docs/ASSETS.md": "Assets",
    "docs/ROADMAP.md": "Feuille de route",
    "docs/VERSIONING.md": "Numérotation des versions",
    "docs/OMNIROUTE.md": "OmniRoute",
    "README.md": "Présentation du projet",
    "CLAUDE.md": "Règles de travail",
}
for rel, title in TECH.items():
    if not os.path.exists(os.path.join(ROOT, rel)):
        continue
    text = read(rel)
    body = re.sub(r"^#\s+.+\n", "", text, count=1)
    DOC_FILES[os.path.basename(rel)] = title
    add(f"Technique/{title}", "technique", body, rel, ["technique"])

# --- Décisions -------------------------------------------------------------------------------
decisions = []
text = read("docs/DECISIONS.md")
parts = re.split(r"^## (D-\d+) — (.+)$", text, flags=re.M)
for i in range(1, len(parts), 3):
    code, title, body = parts[i], parts[i + 1].strip(), parts[i + 2]
    name = clean(f"{code} — {title}")
    titles[code] = name
    status = re.search(r"\*\*Statut\*\*\s*:\s*([^\n]+)", body)
    dated = re.search(r"\*\*Date\*\*\s*:\s*([\d-]+)", body)
    decisions.append((code, name, status.group(1).strip() if status else "", dated.group(1) if dated else ""))
    add(f"Décisions/{name}", "décision", body.strip() + "\n", "docs/DECISIONS.md", ["décision"])
decisions.sort(key=lambda d: int(d[0][2:]))
DOC_FILES["DECISIONS.md"] = "Décisions"

# --- Versions --------------------------------------------------------------------------------
versions = []
text = read("CHANGELOG.md")
parts = re.split(r"^## \[(v[\d.]+)\] — ([\d-]+)(?: — (.+))?$", text, flags=re.M)
for i in range(1, len(parts), 4):
    ver, day, label, body = parts[i], parts[i + 1], (parts[i + 2] or "").strip(), parts[i + 3]
    label = label.strip("«» \"")
    name = clean(f"{ver} — {label}" if label else ver)
    titles[ver] = name
    versions.append((ver, name, day, label))
    body = re.sub(r"\n---\s*$", "\n", body.strip()) + "\n"
    add(f"Versions/{name}", "version", f"**Date** : {day}\n\n{body}", "CHANGELOG.md", ["version"])
DOC_FILES["CHANGELOG.md"] = "Versions"

# --- Catalogue (données du jeu) --------------------------------------------------------------
catalogue_path = os.path.join(ROOT, "build", "catalogue.json")
cat = None
if os.path.exists(catalogue_path):
    with open(catalogue_path, encoding="utf-8") as f:
        cat = json.load(f)


def table(rows):
    lines = ["| Propriété | Valeur |", "|---|---|"]
    for key, value in rows:
        if value is None or value == "":
            continue
        if isinstance(value, float):
            value = f"{value:g}"
        lines.append(f"| {key} | {value} |")
    return "\n".join(lines)


SLOT = {"Firearm": "Arme à feu (emplacement 1)", "Melee": "Mêlée (emplacement 2)"}
weapon_notes, ability_notes, item_notes, enemy_notes, tile_notes = [], [], [], [], []
if cat:
    for aid, a in sorted(cat["abilities"].items()):
        name = clean(a["name"])
        titles["ability:" + aid] = name
    for wid, w in sorted(cat["weapons"].items(), key=lambda kv: (kv[1]["slot"], kv[1]["name"])):
        name = clean(w["name"])
        titles["weapon:" + wid] = name
    for wid, w in sorted(cat["weapons"].items(), key=lambda kv: (kv[1]["slot"], kv[1]["name"])):
        name = titles["weapon:" + wid]
        weapon_notes.append((name, w["slot"]))
        abil = [titles.get("ability:" + w[k]) for k in ("ability", "ability2") if w.get(k)]
        rows = [
            ("Identifiant", f"`{wid}`"), ("Emplacement", SLOT.get(w["slot"], w["slot"])),
            ("Type", "Tir instantané" if w["kind"] == "Hitscan" else "Mêlée"),
            ("Dégâts", f"{w['damage']}" + (f" × {w['pellets']} plombs" if w.get("pellets") else "")),
            ("Cadence", f"{w['fireRate']:g} / s" + (" (automatique)" if w.get("automatic") else "")),
            ("Chargeur", w["magazine"] or "—"), ("Rechargement", f"{w['reloadTime']:g} s" if w["reloadTime"] else "—"),
            ("Portée", f"{w['range']:g} studs"),
            ("Chute des dégâts", f"{w['falloffStart']:g} → {w['falloffEnd']:g} studs (min {w['minDamageRatio']:.0%})" if w["kind"] == "Hitscan" else None),
            ("Perforation", w.get("pierce")), ("Cône de frappe", f"{w['arcDegrees']:g}°" if w.get("arcDegrees") else None),
            ("Attaque chargée", f"× {w['heavyMultiplier']:g} en {w['heavyChargeTime']:g} s" if w.get("heavyMultiplier") else None),
            ("Parade", f"{w['parryWindow']:g} s" if w.get("parryWindow") else None),
            ("Lunette", f"{w['scopeFov']}°" if w.get("scopeFov") else None),
            ("Passif", w.get("passive")),
        ]
        body = table(rows) + "\n\n## Capacités\n" + ("\n".join(f"- [[{a}]]" for a in abil) or "- —") + "\n"
        body += "\nSource : `src/shared/Combat/WeaponDefs.luau` · voir aussi [[" + DOC_FILES["03-combat.md"] + "]].\n"
        add(f"Catalogue/Armes/{name}", "arme", body, "src/shared/Combat/WeaponDefs.luau", ["arme", w["slot"].lower()])
    for aid, a in sorted(cat["abilities"].items()):
        name = titles["ability:" + aid]
        ability_notes.append(name)
        users = [titles["weapon:" + wid] for wid, w in cat["weapons"].items() if aid in (w.get("ability"), w.get("ability2"))]
        rows = [("Identifiant", f"`{aid}`"), ("Noyau à remplir", f"{a['charge']} dégâts"), ("Annonce", f"{a['windup']:g} s")]
        rows += [(k, v) for k, v in sorted(a.items()) if k not in ("id", "name", "charge", "windup")]
        body = table(rows) + "\n\n## Armes\n" + ("\n".join(f"- [[{u}]]" for u in users) or "- —") + "\n"
        body += "\nSource : `src/shared/Combat/Ability.luau`.\n"
        add(f"Catalogue/Capacités/{name}", "capacité", body, "src/shared/Combat/Ability.luau", ["capacité"])
    for iid, it in sorted(cat["items"].items(), key=lambda kv: kv[1]["name"]):
        name = clean(it["name"])
        item_notes.append((name, it["rarity"]))
        rows = [("Identifiant", f"`{iid}`"), ("Rareté", it["rarity"]), ("Pile max", it["maxStack"]), ("Valeur", f"{it['value']} Grains"),
                ("Soin", it.get("heal")), ("Durée d'usage", f"{it['useTime']} s" if it.get("useTime") else None),
                ("Relique", "oui (3 charges)" if it.get("relic") else None)]
        body = (it.get("description", "") + "\n\n" if it.get("description") else "") + table(rows)
        body += "\n\nSource : `src/shared/Loot/ItemDefs.luau` · voir aussi [[" + DOC_FILES["05-equipement-economie.md"] + "]].\n"
        add(f"Catalogue/Objets/{name}", "objet", body, "src/shared/Loot/ItemDefs.luau", ["objet", it["rarity"].lower()])
    for eid, e in sorted(cat["enemies"].items(), key=lambda kv: kv[1]["name"]):
        name = clean(e["name"])
        enemy_notes.append(name)
        weapon = titles.get("weapon:" + e.get("weaponModel", ""))
        rows = [("Identifiant", f"`{eid}`"), ("Comportement", e["behavior"]), ("Santé", e["health"]), ("Armure", e["armor"]),
                ("Dégâts", e["damage"]), ("Préparation / visée", f"{e['windup']:g} s"), ("Recharge", f"{e['cooldown']:g} s"),
                ("Repérage", f"{e['aggroRange']} studs"), ("Portée d'attaque", f"{e['attackRange']} studs"),
                ("Arme tenue", f"[[{weapon}]]" if weapon else f"`{e.get('weaponModel')}`"), ("Tenue", e.get("outfit"))]
        body = table(rows) + "\n\nSource : `src/shared/Combat/EnemyDefs.luau` · voir aussi [[" + DOC_FILES["07-ennemis.md"] + "]].\n"
        add(f"Catalogue/Ennemis/{name}", "ennemi", body, "src/shared/Combat/EnemyDefs.luau", ["ennemi"])
    ROLES = {"Donjon": "Centre, unique : Gardien, Faille finale", "CourArmes": "Combat ouvert", "Remparts": "Chemins en hauteur, tireurs",
             "TourGuet": "Point de vue, autel possible", "Village": "Village fortifié, combat rapproché",
             "PontLevis": "Pont-levis et douves, passage risqué", "Crypte": "Souterrain, butin rare (unique)",
             "Bord": "Bord d'Éclat : apparition des escouades"}
    def as_list(value):
        # Une table Luau vide est exportée comme un objet JSON {}.
        return list(value.values()) if isinstance(value, dict) else (value or [])

    for kind, d in cat["districts"].items():
        d = dict(d)
        for key in ("buildings", "props", "stairs", "solids", "loot", "posts"):
            d[key] = as_list(d.get(key))
        name = clean(f"Tuile {kind}")
        tile_notes.append(name)
        lines = [f"**Rôle** : {ROLES.get(kind, '')}", "", f"Tuile de {cat['grid']['tile']} × {cat['grid']['tile']} studs, grille de "
                 f"{cat['grid']['size']} × {cat['grid']['size']} (voir D-052).", ""]
        def listing(title, items, fmt):
            lines.append(f"## {title}")
            lines.extend(fmt(i) for i in items) if items else lines.append("- —")
            lines.append("")
        listing("Bâtiments", d["buildings"], lambda p: f"- `{p['module']}` en ({p['x']}, {p['z']})")
        listing("Escaliers et plateformes", d["stairs"] + d["solids"],
                lambda s: f"- escalier : montée {s['rise']} sur {s['run']}" if "rise" in s else f"- bloc {s['w']} × {s['d']}, haut à {s['top']}")
        props = {}
        for p in d["props"]:
            props[p["module"]] = props.get(p["module"], 0) + 1
        listing("Décor", sorted(props.items()), lambda kv: f"- `{kv[0]}` × {kv[1]}")
        listing("Butin", d["loot"], lambda s: f"- {s['table']} en ({s['x']}, {s['y']}, {s['z']})")
        listing("Échoués", d["posts"], lambda s: f"- `{s['id']}` en ({s['x']}, {s['y']}, {s['z']})")
        lines.append(f"**Extraction** : ({d['extract']['x']}, {d['extract']['y']}, {d['extract']['z']})")
        for key, label in (("altar", "Autel possible"), ("spawn", "Apparition"), ("throne", "Trône du Gardien")):
            if d.get(key):
                lines.append(f"**{label}** : ({d[key]['x']}, {d[key]['y']}, {d[key]['z']})")
        lines.append("\nSource : `src/shared/Eclat/Districts.luau` · voir aussi [[" + DOC_FILES["06-environnements.md"] + "]].")
        add(f"Catalogue/Tuiles/{name}", "tuile", "\n".join(lines) + "\n", "src/shared/Eclat/Districts.luau", ["tuile"])

# --- Index -----------------------------------------------------------------------------------
add("Décisions", "index", "Toutes les décisions importantes (on ajoute, on n'efface pas).\n\n| Code | Décision | Statut | Date |\n|---|---|---|---|\n"
    + "\n".join(f"| {c} | [[{n}\\|{n.split(' — ', 1)[1]}]] | {s} | {d} |" for c, n, s, d in decisions) + "\n", "docs/DECISIONS.md", ["index"])
add("Versions", "index", "Historique des versions (préversions tant que < 1.0).\n\n| Version | Nom | Date |\n|---|---|---|\n"
    + "\n".join(f"| [[{n}\\|{v}]] | {l} | {d} |" for v, n, d, l in versions) + "\n", "CHANGELOG.md", ["index"])
gdd_titles = [t for f, t in sorted(DOC_FILES.items()) if f[:2].isdigit()]
add("GDD", "index", "Game Design Document, chapitre par chapitre.\n\n" + "\n".join(f"- [[{t}]]" for t in gdd_titles) + "\n", "docs/GDD/README.md", ["index"])
if cat:
    body = f"Données du jeu, version {cat['version']}.\n\n## Armes\n"
    for slot in ("Firearm", "Melee"):
        body += f"\n**{SLOT[slot]}**\n" + "\n".join(f"- [[{n}]]" for n, s in weapon_notes if s == slot) + "\n"
    body += "\n## Capacités\n" + "\n".join(f"- [[{n}]]" for n in ability_notes) + "\n"
    body += "\n## Objets\n" + "\n".join(f"- [[{n}]] ({r})" for n, r in item_notes) + "\n"
    body += "\n## Ennemis\n" + "\n".join(f"- [[{n}]]" for n in enemy_notes) + "\n"
    body += "\n## Tuiles de l'Éclat\n" + "\n".join(f"- [[{n}]]" for n in tile_notes) + "\n"
    add("Catalogue", "index", body, "build/catalogue.json", ["index"])

latest_v = versions[0] if versions else None
home = [
    "# FRACTURE", "",
    "Jeu Roblox d'extraction PvPvE dans l'univers des Éclats temporels. Ce coffre est **généré depuis "
    "le dépôt Git** (référence) : relancer `python tools/obsidian_sync.py` pour le mettre à jour. "
    "Tes notes personnelles vont dans **[[Mes notes/Lisez-moi|Mes notes]]** (jamais touchées).", "",
    f"**Version actuelle** : [[{latest_v[1]}|{latest_v[0]}]] ({latest_v[2]})" if latest_v else "", "",
    "## Explorer", "- [[Présentation du projet]] · [[Règles de travail]]", "- [[GDD]] — le design complet",
    "- [[Catalogue]] — armes, capacités, objets, ennemis, tuiles", "- [[Décisions]] — pourquoi le jeu est comme il est",
    "- [[Versions]] — ce qui a changé, version par version",
    "- Technique : [[Architecture]] · [[Assets]] · [[Feuille de route]] · [[Numérotation des versions]] · [[OmniRoute]]", "",
    "## Dernières versions", *[f"- [[{n}|{v}]] — {l}" for v, n, d, l in versions[:5]], "",
    "## Dernières décisions", *[f"- [[{n}]]" for c, n, s, d in decisions[-5:][::-1]], "",
    f"_Synchronisé le {date.today().isoformat()}._",
]
add("Accueil", "index", "\n".join(home) + "\n", None, ["accueil"])

# --- Liens -----------------------------------------------------------------------------------
LINK_MD = re.compile(r"\[([^\]]+)\]\(([^)\s]+?\.md)(#[^)]*)?\)")
REF = re.compile(r"(?<![\w\-\[|])(D-\d{3}|v\d+\.\d+\.\d+)(?![\w.])")


def linkify(body, own):
    out_lines = []
    for line in body.split("\n"):
        in_table = line.lstrip().startswith("|")
        pipe = "\\|" if in_table else "|"

        def md(m):
            target = DOC_FILES.get(os.path.basename(m.group(2)))
            return f"[[{target}{pipe}{m.group(1)}]]" if target else m.group(0)

        line = LINK_MD.sub(md, line)
        # Ne pas toucher l'intérieur des [[...]] ni le code `...`.
        chunks = re.split(r"(\[\[[^\]]*\]\]|`[^`]*`)", line)
        for i in range(0, len(chunks), 2):
            def ref(m):
                target = titles.get(m.group(1))
                if not target or target == own:
                    return m.group(0)
                return f"[[{target}{pipe}{m.group(1)}]]"
            chunks[i] = REF.sub(ref, chunks[i])
        out_lines.append("".join(chunks))
    return "\n".join(out_lines)


# --- Écriture --------------------------------------------------------------------------------
def frontmatter(props):
    lines = ["---", MARK, f"type: {props['type']}"]
    if props["source"]:
        lines.append(f"source: \"{props['source']}\"")
    if props["tags"]:
        lines.append("tags:")
        lines.extend(f"  - {t}" for t in props["tags"])
    lines.append("---")
    return "\n".join(lines) + "\n"


written = set()
note_names = set()
for path, (props, body) in notes.items():
    note_names.add(os.path.basename(path))
    own = os.path.basename(path)
    banner = ""
    if props["source"]:
        banner = f"> [!info] Note générée depuis `{props['source']}` — modifier le dépôt, pas cette note.\n\n"
    full = frontmatter(props) + banner + linkify(body, own)
    dest = os.path.join(VAULT, *path.split("/")) + ".md"
    os.makedirs(os.path.dirname(dest), exist_ok=True)
    with open(dest, "w", encoding="utf-8", newline="\n") as f:
        f.write(full)
    written.add(os.path.normcase(os.path.abspath(dest)))

# Dossier personnel (créé une fois, jamais réécrit)
mine = os.path.join(VAULT, "Mes notes")
os.makedirs(mine, exist_ok=True)
readme = os.path.join(mine, "Lisez-moi.md")
if not os.path.exists(readme):
    with open(readme, "w", encoding="utf-8", newline="\n") as f:
        f.write("# Mes notes\n\nCe dossier est à toi : la synchronisation depuis le dépôt ne le touche jamais.\n"
                "Retour à l'[[Accueil]].\n")

# Notes générées devenues inutiles
removed = 0
for folder, _, files in os.walk(VAULT):
    if ".obsidian" in folder or os.path.abspath(folder).startswith(os.path.abspath(mine)):
        continue
    for name in files:
        p = os.path.join(folder, name)
        if not name.endswith(".md") or os.path.normcase(os.path.abspath(p)) in written:
            continue
        with open(p, encoding="utf-8") as f:
            head = f.read(200)
        if head.startswith("---") and MARK in head:
            os.remove(p)
            removed += 1

# Liens cassés (contrôle)
names = note_names | {"Mes notes/Lisez-moi", "Lisez-moi"}
broken = set()
for p in written:
    with open(p, encoding="utf-8") as f:
        for target in re.findall(r"\[\[([^\]|\\]+)", f.read()):
            if target not in names and os.path.basename(target) not in names:
                broken.add(target)
print(f"{len(written)} notes écrites, {removed} supprimées, liens cassés : {sorted(broken) or 'aucun'}")
