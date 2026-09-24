"""Genera logos, conceptos, previews y recursos Android de Cátedra y Kairós.

Una sola construcción para las dos marcas: rejilla de 108 (la del ícono
adaptativo de Android), anillo de radio 24 con trazo 6 y remates redondos,
centrado en (54,54). Cada marca abre el anillo y pone su símbolo en el centro.
"""
import math, os, subprocess, sys, tempfile
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

MARCA = "kairos"
REPO = Path(__file__).resolve().parents[2]
FONTS = REPO / "assets" / "fonts"
TMP = tempfile.mkdtemp(prefix="logo-")
W = 6
CX = CY = 54
R = 24
# En el lanzador el símbolo se reduce para quedar en ~50 dp de los 72 visibles.
LS = 0.86


def P(x, y):
    return f"{x:.2f},{y:.2f}"


def pol(r, deg, cx=CX, cy=CY):
    a = math.radians(deg)
    return cx + r * math.cos(a), cy + r * math.sin(a)


# Primitivas: ("s", d, rol, ancho) trazo · ("f", d, rol) relleno. rol = fg | ac
def flame(cx, base, h, w):
    b = base
    return (f"M{P(cx + w*0.25, b - h)} "
            f"C{P(cx + w*0.9, b - h*0.72)} {P(cx + w, b - h*0.52)} {P(cx + w, b - w)} "
            f"A{w:.2f},{w:.2f} 0 0 1 {P(cx - w, b - w)} "
            f"C{P(cx - w, b - h*0.50)} {P(cx - w*0.35, b - h*0.62)} {P(cx - w*0.15, b - h*0.80)} "
            f"C{P(cx - w*0.02, b - h*0.66)} {P(cx + w*0.35, b - h*0.80)} {P(cx + w*0.25, b - h)}Z")


def dot(cx, cy, r):
    return f"M{P(cx - r, cy)} A{r},{r} 0 1 0 {P(cx + r, cy)} A{r},{r} 0 1 0 {P(cx - r, cy)}Z"


def ring_open(center_deg, half_gap):
    """Anillo abierto: hueco de 2*half_gap grados centrado en center_deg."""
    x0, y0 = pol(R, center_deg + half_gap)
    x1, y1 = pol(R, center_deg - half_gap)
    return f"M{P(x0, y0)} A{R},{R} 0 1 1 {P(x1, y1)}"


def catedra():
    # C abierta a la derecha (±42°) que guarda la llama de la lucerna.
    return [("s", ring_open(0, 42), "fg", W),
            ("f", flame(CX + 1, CY + 10, 26, 7.8), "ac")]


def kairos():
    # Esfera abierta hacia la 1:40 (±24° alrededor de -50°): el minutero
    # sale por el hueco, el horario marca las 9. El momento oportuno es la
    # rendija por la que se pasa.
    x, y = pol(R + 3, -50)
    return [("s", ring_open(-50, 24), "fg", W),
            ("s", f"M{CX},{CY} H{CX - 14}", "fg", W),
            ("s", f"M{CX},{CY} L{P(x, y)}", "ac", W),
            ("f", dot(CX, CY, 5), "ac")]


BRANDS = {
    "catedra": dict(
        name="Cátedra", fn=catedra, stat="ic_stat_catedra",
        tagline="gestión académica",
        dark=dict(bg="#2C2620", fg="#F1E6D3", ac="#C89B5C", text="#EDE4D8", sub="#A2968A"),
        light=dict(bg="#F5F0E6", fg="#2C2620", ac="#9A6F32", text="#2C2620", sub="#6A5F55"),
        mono="#2C2620"),
    "kairos": dict(
        name="Kairós", fn=kairos, stat="ic_stat_kairos",
        tagline="el momento oportuno",
        dark=dict(bg="#5B4A6E", fg="#F1E6D3", ac="#CDB5EE", text="#F1E6D3", sub="#CDBFDC"),
        light=dict(bg="#F5F0E6", fg="#3E3150", ac="#7A5A9E", text="#3E3150", sub="#6A5F55"),
        mono="#3E3150"),
}


def gwrap(body, scale):
    if scale == 1:
        return body
    return f'<g transform="translate(54 54) scale({scale}) translate(-54 -54)">{body}</g>'


def svg_body(prims, fg, ac):
    out = []
    for p in prims:
        c = fg if p[2] == "fg" else ac
        if p[0] == "s":
            out.append(f'<path d="{p[1]}" fill="none" stroke="{c}" stroke-width="{p[3]}" '
                       f'stroke-linecap="round" stroke-linejoin="round"/>')
        else:
            out.append(f'<path d="{p[1]}" fill="{c}"/>')
    return "\n  ".join(out)


def svg(prims, fg, ac, bg=None, shape="squircle", title="", scale=1):
    b = ""
    if bg and shape == "squircle":
        b = f'<rect width="108" height="108" rx="24" fill="{bg}"/>\n  '
    elif bg and shape == "circle":
        b = f'<circle cx="54" cy="54" r="54" fill="{bg}"/>\n  '
    elif bg:
        b = f'<rect width="108" height="108" fill="{bg}"/>\n  '
    t = f"<title>{title}</title>\n  " if title else ""
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 108 108" width="108" height="108">\n  '
            f'{t}{b}{gwrap(svg_body(prims, fg, ac), scale)}\n</svg>\n')


def raster(svgtxt, size, out):
    tmp = f"{TMP}/_r.svg"
    open(tmp, "w").write(svgtxt)
    subprocess.run(["rsvg-convert", "-w", str(size), "-h", str(size), tmp, "-o", out], check=True)
    return Image.open(out).convert("RGBA")


def vd(prims, color, viewport=108, translate=0, comment="", scale=1):
    items = []
    for p in prims:
        if p[0] == "s":
            items.append(f'        <path\n            android:pathData="{p[1]}"\n'
                         f'            android:strokeColor="{color}"\n'
                         f'            android:strokeWidth="{p[3]}"\n'
                         f'            android:strokeLineCap="round"\n'
                         f'            android:strokeLineJoin="round" />')
        else:
            items.append(f'        <path\n            android:pathData="{p[1]}"\n'
                         f'            android:fillColor="{color}" />')
    size = 108 if viewport == 108 else 24
    return (f'<?xml version="1.0" encoding="utf-8"?>\n{comment}'
            f'<vector xmlns:android="http://schemas.android.com/apk/res/android"\n'
            f'    android:width="{size}dp"\n    android:height="{size}dp"\n'
            f'    android:viewportWidth="{viewport}"\n    android:viewportHeight="{viewport}">\n'
            f'    <group\n        android:translateX="{-translate}"\n        android:translateY="{-translate}"\n'
            f'        android:pivotX="54"\n        android:pivotY="54"\n'
            f'        android:scaleX="{scale}"\n        android:scaleY="{scale}">\n'
            + "\n".join(items) + "\n    </group>\n</vector>\n")


def vd_color(prims, fg, ac, comment=""):
    items = []
    for p in prims:
        c = fg if p[2] == "fg" else ac
        if p[0] == "s":
            items.append(f'    <path\n        android:pathData="{p[1]}"\n'
                         f'        android:strokeColor="{c}"\n'
                         f'        android:strokeWidth="{p[3]}"\n'
                         f'        android:strokeLineCap="round"\n'
                         f'        android:strokeLineJoin="round" />')
        else:
            items.append(f'    <path\n        android:pathData="{p[1]}"\n'
                         f'        android:fillColor="{c}" />')
    return (f'<?xml version="1.0" encoding="utf-8"?>\n{comment}'
            f'<vector xmlns:android="http://schemas.android.com/apk/res/android"\n'
            f'    android:width="108dp"\n    android:height="108dp"\n'
            f'    android:viewportWidth="108"\n    android:viewportHeight="108">\n'
            + '    <group\n        android:pivotX="54"\n        android:pivotY="54"\n'
            + f'        android:scaleX="{LS}"\n        android:scaleY="{LS}">\n'
            + "\n".join("    " + l if l else l for i in items for l in i.split("\n")) + "\n    </group>\n</vector>\n")


def preview_lockup(b, theme, out):
    th = b[theme]
    Wd, H = 1200, 520
    img = Image.new("RGBA", (Wd, H), th["bg"])
    mark = raster(svg(b["fn"](), th["fg"], th["ac"]), 400, f"{TMP}/_m.png")
    img.paste(mark, (40, 60), mark)
    d = ImageDraw.Draw(img)
    f1 = ImageFont.truetype(f"{FONTS}/SourceSans3-SemiBold.ttf", 150)
    f2 = ImageFont.truetype(f"{FONTS}/IBMPlexMono-Regular.ttf", 36)
    d.text((470, 150), b["name"], font=f1, fill=th["text"])
    d.text((476, 330), b["tagline"], font=f2, fill=th["sub"])
    img.save(out)


def preview_launcher(b, out):
    """Ícono del lanzador: máscara redonda y squircle, a 192 y a 48 px, sobre
    fondo de pantalla claro y oscuro, y el tema monocromo de Android 13."""
    th = b["dark"]
    prims = b["fn"]()
    wall = [("#E9E4DA", "#2B2B2B")]
    img = Image.new("RGBA", (1000, 560), "#D8D2C6")
    d = ImageDraw.Draw(img)
    d.rectangle((500, 0, 1000, 560), fill="#1B1B1E")
    variants = [
        svg(prims, th["fg"], th["ac"], th["bg"], "circle", scale=LS),
        svg(prims, th["fg"], th["ac"], th["bg"], "squircle", scale=LS),
        svg(prims, "#1F1B24", "#1F1B24", "#D9CFE8" if b["name"] == "Kairós" else "#E8DCC8", "circle", scale=LS),
    ]
    for side, x0 in ((0, 40), (1, 540)):
        for i, v in enumerate(variants):
            if side == 1 and i == 2:
                v = svg(prims, "#E8DCC8" if b["name"] == "Cátedra" else "#D9CFE8",
                        "#E8DCC8" if b["name"] == "Cátedra" else "#D9CFE8", "#2E2A33", "circle", scale=LS)
            v = v.replace('viewBox="0 0 108 108"', 'viewBox="18 18 72 72"').replace('r="54" fill', 'r="36" fill').replace('rx="24"', 'x="18" y="18" rx="16"').replace('width="108" height="108" x=', 'width="72" height="72" x=')
            big = raster(v, 128, f"{TMP}/_b.png")
            small = raster(v, 48, f"{TMP}/_s.png")
            img.paste(big, (x0 + i * 145, 60), big)
            img.paste(small, (x0 + i * 145 + 40, 260), small)
        f = ImageFont.truetype(f"{FONTS}/SourceSans3-Regular.ttf", 22)
        col = "#2C2620" if side == 0 else "#EDE4D8"
        for i, lab in enumerate(["redondo", "squircle", "temático"]):
            d.text((x0 + i * 145 + 20, 330), lab, font=f, fill=col)
        big = raster(variants[0].replace('viewBox="0 0 108 108"', 'viewBox="18 18 72 72"').replace('r="54" fill', 'r="36" fill'), 96, f"{TMP}/_c.png")
        f3 = ImageFont.truetype(f"{FONTS}/SourceSans3-Regular.ttf", 26)
        img.paste(big, (x0 + 150, 390), big)
        d.text((x0 + 198 - d.textlength(b["name"], font=f3) / 2, 495), b["name"], font=f3, fill=col)
    img.save(out)


LEGACY = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}


def android(b):
    res = f"{REPO}/android/app/src/main/res"
    prims = b["fn"]()
    th = b["dark"]
    os.makedirs(f"{res}/mipmap-anydpi-v26", exist_ok=True)
    hdr = ("<!-- Generado por design/logo/generar.py: no editar a mano. Primer plano del\n"
           "     ícono adaptativo en la rejilla de 108 dp; el símbolo ocupa un círculo de\n"
           "     ~52 dp (escala LS), dentro de la zona segura de 66 dp. -->\n")
    open(f"{res}/drawable/ic_launcher_foreground.xml", "w").write(
        vd_color(prims, th["fg"], th["ac"], hdr))
    open(f"{res}/drawable/ic_launcher_monochrome.xml", "w").write(
        vd(prims, "#FFFFFFFF", scale=LS, comment="<!-- Capa monocroma para los íconos temáticos de Android 13+:\n"
                                       "     el sistema solo usa el alfa y la tiñe con el color del tema. -->\n"))
    open(f"{res}/values/ic_launcher_colors.xml", "w").write(
        '<?xml version="1.0" encoding="utf-8"?>\n<resources>\n'
        f'    <!-- Fondo del ícono adaptativo: {"tinta" if b["name"] == "Cátedra" else "ciruela"} de la marca. -->\n'
        f'    <color name="ic_launcher_background">{th["bg"]}</color>\n</resources>\n')
    adaptive = ('<?xml version="1.0" encoding="utf-8"?>\n'
                '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
                '    <background android:drawable="@color/ic_launcher_background" />\n'
                '    <foreground android:drawable="@drawable/ic_launcher_foreground" />\n'
                '    <monochrome android:drawable="@drawable/ic_launcher_monochrome" />\n'
                '</adaptive-icon>\n')
    for n in ("ic_launcher", "ic_launcher_round"):
        open(f"{res}/mipmap-anydpi-v26/{n}.xml", "w").write(adaptive)
    for dens, px in LEGACY.items():
        # Respaldo < API 26: lo que se ve dentro de la máscara (72/108 del lienzo).
        inner = (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="18 18 72 72">'
                 f'{{BG}}{gwrap(svg_body(prims, th["fg"], th["ac"]), LS)}</svg>')
        sq = inner.replace("{BG}", f'<rect x="18" y="18" width="72" height="72" rx="14" fill="{th["bg"]}"/>')
        rd = inner.replace("{BG}", f'<circle cx="54" cy="54" r="36" fill="{th["bg"]}"/>')
        raster(sq, px, f"{res}/mipmap-{dens}/ic_launcher.png")
        raster(rd, px, f"{res}/mipmap-{dens}/ic_launcher_round.png")
    stat_hdr = ("<!-- Icono monocromo de la barra de estado: el símbolo del logo en silueta\n"
                "     blanca. Android lo tiñe solo. Generado por design/logo/generar.py. -->\n")
    open(f"{res}/drawable/{b['stat']}.xml", "w").write(vd(prims, "#FFFFFFFF", viewport=58, translate=25, comment=stat_hdr))


def logos(b):
    out = f"{REPO}/design/logo"
    prims = b["fn"]()
    th = b["dark"]
    open(f"{out}/logo.svg", "w").write(svg(prims, th["fg"], th["ac"], th["bg"], "squircle", b["name"]))
    open(f"{out}/logo-transparente.svg", "w").write(svg(prims, b["light"]["fg"], b["light"]["ac"], title=b["name"]))
    open(f"{out}/logo-mono.svg", "w").write(svg(prims, b["mono"], b["mono"], title=b["name"]))
    preview_lockup(b, "light", f"{out}/preview-claro.png")
    preview_lockup(b, "dark", f"{out}/preview-oscuro.png")
    preview_launcher(b, f"{out}/preview-lanzador.png")


if __name__ == "__main__":
    # Uso: python3 design/logo/generar.py   (desde la raíz del repo; necesita rsvg-convert y Pillow)
    marca = MARCA
    logos(BRANDS[marca])
    android(BRANDS[marca])
