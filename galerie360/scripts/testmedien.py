# Erzeugt equirektangulare Testbilder: Längengrade farbig, Breitengrade als Linien, Beschriftung der Himmelsrichtungen.
import sys, math
from PIL import Image, ImageDraw, ImageFont
def bild(w, pfad, farbe=0):
    h = w // 2
    im = Image.new('RGB', (w, h))
    d = ImageDraw.Draw(im)
    for x in range(0, w, max(1, w // 360)):
        lon = x / w * 360
        hue = (lon + farbe) % 360
        import colorsys
        r, g, b = colorsys.hsv_to_rgb(hue / 360, 0.5, 0.85)
        d.rectangle([x, 0, x + w // 360, h], fill=(int(r*255), int(g*255), int(b*255)))
    for lat in range(-80, 90, 10):
        y = int((0.5 - lat / 180) * h)
        d.line([0, y, w, y], fill=(255, 255, 255) if lat else (255, 0, 0), width=max(1, w // 1000))
    for lon in range(0, 360, 15):
        x = int(lon / 360 * w)
        d.line([x, 0, x, h], fill=(0, 0, 0), width=max(1, w // 1500))
    try:
        f = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf', w // 30)
    except Exception:
        f = ImageFont.load_default()
    for name, lon in [('MITTE', 180), ('RECHTS', 270), ('HINTEN', 0), ('LINKS', 90)]:
        x = lon / 360 * w
        d.text((x, h / 2 - w / 40), name, fill=(0, 0, 0), font=f, anchor='mm')
    im.save(pfad, quality=90)
for a in sys.argv[1:]:
    w, pfad, *rest = a.split(':')
    bild(int(w), pfad, int(rest[0]) if rest else 0)
