"""Store-Screenshots für HörspielLog 1.19 im Stil der Serie aus 1.14.

Hellblauer Verlauf, Überschrift und Unterzeile in Myriad Pro, Gerät mit
abgerundeten Ecken und weichem Schatten, eine herausgehobene Zeile.

Aufruf: python3 tools/build_store_screenshots_v119.py <Rohaufnahmen> <Ausgabe>
"""
from __future__ import annotations

import sys
from dataclasses import dataclass
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

FONTS = Path("/Applications/Adobe Lightroom Classic/Adobe Lightroom Classic.app/Contents/Support/TypeSupport/Fonts")
FONT_TITLE = FONTS / "MyriadPro-Regular.otf"
FONT_SUB = FONTS / "MyriadPro-Semibold.otf"

TOP = (154, 198, 235)
BOTTOM = (223, 229, 243)


@dataclass
class Shot:
    raw: str
    out: str
    title: str
    subtitle: list[str]
    # Ausschnitt der Rohaufnahme (Pixel), der herausgehoben wird.
    popout: tuple[int, int, int, int] | None = None


def gradient(size: tuple[int, int]) -> Image.Image:
    w, h = size
    column = Image.new("RGB", (1, h))
    for y in range(h):
        t = y / (h - 1)
        column.putpixel((0, y), tuple(round(a + (b - a) * t) for a, b in zip(TOP, BOTTOM)))
    return column.resize((w, h)).convert("RGBA")


def rounded(image: Image.Image, radius: int) -> Image.Image:
    mask = Image.new("L", image.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, *image.size), radius=radius, fill=255)
    out = image.convert("RGBA")
    out.putalpha(mask)
    return out


def paste_with_shadow(base: Image.Image, image: Image.Image, xy: tuple[int, int], blur: int, offset: int, alpha: int) -> None:
    shadow = Image.new("RGBA", base.size, (0, 0, 0, 0))
    silhouette = Image.new("RGBA", image.size, (20, 40, 80, alpha))
    silhouette.putalpha(image.getchannel("A").point(lambda a: a * alpha // 255))
    shadow.alpha_composite(silhouette, (xy[0], xy[1] + offset))
    base.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(blur)))
    base.alpha_composite(image, xy)


def add_dynamic_island(raw: Image.Image) -> None:
    """Simulator-Aufnahmen haben keine Dynamic Island, die alte Serie schon.
    Maße vom iPhone 17/18 Pro Max (1320 px breit)."""
    if sum(raw.getpixel((660, 95))) < 30:
        return
    ImageDraw.Draw(raw).rounded_rectangle((472, 42, 847, 151), radius=55, fill=(0, 0, 0))


def centered_text(draw: ImageDraw.ImageDraw, text: str, y: int, font: ImageFont.FreeTypeFont, width: int) -> None:
    box = draw.textbbox((0, 0), text, font=font)
    draw.text(((width - (box[2] - box[0])) / 2 - box[0], y), text, font=font, fill=(255, 255, 255))


def compose(shot: Shot, raw_dir: Path, out_dir: Path, canvas: tuple[int, int], device_width: int,
            device_top: int, title_size: int, sub_size: int, corner: int, island: bool = False) -> None:
    w, h = canvas
    base = gradient(canvas)
    draw = ImageDraw.Draw(base)
    title_font = ImageFont.truetype(str(FONT_TITLE), title_size)
    sub_font = ImageFont.truetype(str(FONT_SUB), sub_size)
    y = round(title_size * 0.55)
    centered_text(draw, shot.title, y, title_font, w)
    y += round(title_size * 1.2)
    for line in shot.subtitle:
        centered_text(draw, line, y, sub_font, w)
        y += round(sub_size * 1.2)

    raw = Image.open(raw_dir / shot.raw).convert("RGB")
    if island:
        add_dynamic_island(raw)
    scale = device_width / raw.width
    device = raw.resize((device_width, round(raw.height * scale)), Image.LANCZOS)
    device = rounded(device, corner)
    x = (w - device_width) // 2
    paste_with_shadow(base, device, (x, device_top), blur=40, offset=24, alpha=110)

    if shot.popout:
        left, top, right, bottom = shot.popout
        crop = raw.crop(shot.popout)
        pop_width = min(w - 2 * round(w * 0.05), round(device_width * 1.11))
        pop_scale = pop_width / crop.width
        pop = crop.resize((pop_width, round(crop.height * pop_scale)), Image.LANCZOS)
        pop = rounded(pop, round(18 * pop_scale))
        center_y = device_top + round((top + bottom) / 2 * scale)
        paste_with_shadow(base, pop, ((w - pop_width) // 2, center_y - pop.height // 2), blur=28, offset=18, alpha=140)

    out_dir.mkdir(parents=True, exist_ok=True)
    base.convert("RGB").save(out_dir / shot.out, quality=95)


IPHONE = [
    Shot("iphone_home.png", "01-uebersicht.jpg", "Deine Sammlung",
         ["Alles im Blick", "Offene Folgen sofort erkennbar"], popout=(60, 2195, 1260, 2410)),
    Shot("iphone_upnext.png", "02-als-naechstes.jpg", "Als nächstes",
         ["Ein Vorschlag, was du", "jetzt hören kannst"], popout=(60, 534, 1260, 1185)),
    Shot("iphone_detail.png", "03-starte.jpg", "Starte",
         ["jede Folge sofort"], popout=(105, 2000, 1215, 2150)),
    Shot("iphone_year.png", "04-hoerjahr.jpg", "Dein Hörjahr",
         ["Dein Rückblick zum Teilen"], popout=(132, 1239, 1188, 1512)),
    Shot("iphone_widgets.png", "05-widgets.jpg", "Widgets",
         ["Für deine nächste Folge"], popout=(96, 936, 1224, 1464)),
]

IPAD = [
    Shot("ipad_home.png", "01-uebersicht.jpg", "Deine Sammlung", ["Alles im Blick"]),
    Shot("ipad_upnext.png", "02-als-naechstes.jpg", "Als nächstes", ["Ein Vorschlag, was du jetzt hören kannst"]),
    Shot("ipad_year.png", "03-hoerjahr.jpg", "Dein Hörjahr", ["Dein Rückblick zum Teilen"]),
]


def main() -> None:
    raw_dir, out_dir = Path(sys.argv[1]), Path(sys.argv[2])
    which = sys.argv[3] if len(sys.argv) > 3 else "all"
    if which in ("all", "iphone"):
        for shot in IPHONE:
            if (raw_dir / shot.raw).exists():
                compose(shot, raw_dir, out_dir / "iPhone", (1320, 2868), device_width=1017,
                        device_top=560, title_size=150, sub_size=82, corner=110, island=True)
    if which in ("all", "ipad"):
        for shot in IPAD:
            if (raw_dir / shot.raw).exists():
                compose(shot, raw_dir, out_dir / "iPad", (2732, 2048), device_width=2050,
                        device_top=430, title_size=150, sub_size=80, corner=40)


if __name__ == "__main__":
    main()
