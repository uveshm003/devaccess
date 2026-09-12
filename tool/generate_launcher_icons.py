#!/usr/bin/env python3
"""Renders the DevAccess launcher icons from the same geometry as the vector sources.

API 26+ uses the adaptive icon in `android/app/src/main/res/mipmap-anydpi-v26/`, and
Android 12+ draws the splash from `drawable/ic_splash_logo.xml`. Those are vectors and need
no build step. This script exists for the two things that must be rasters:

  * the legacy `mipmap-*/ic_launcher.png` and `ic_launcher_round.png` sets (API 24-25);
  * `store/ic_launcher_512.png`, the Play Console listing icon.

Run it after changing the mark so every surface stays in step:

    python3 tool/generate_launcher_icons.py

Requires Pillow. The geometry below mirrors `lib/widgets/brand.dart` and
`res/drawable/ic_launcher_foreground.xml` — a terminal prompt (`>_`) on a gradient tile.
"""

from __future__ import annotations

import os
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RES = os.path.join(ROOT, "android", "app", "src", "main", "res")

# Brand ramp — keep in step with res/values/colors.xml and AppTheme.brandSeed.
GRADIENT_START = (0x3B, 0xE3, 0xB4)
GRADIENT_END = (0x17, 0xB4, 0x89)
INK = (0x06, 0x23, 0x1B)

# Mark geometry, as fractions of the tile.
CORNER = 0.28
STROKE = 0.10
CHEVRON = [(0.30, 0.31), (0.52, 0.50), (0.30, 0.69)]
CURSOR = [(0.57, 0.69), (0.74, 0.69)]

# Legacy launcher densities.
DENSITIES = {
    "mipmap-mdpi": 48,
    "mipmap-hdpi": 72,
    "mipmap-xhdpi": 96,
    "mipmap-xxhdpi": 144,
    "mipmap-xxxhdpi": 192,
}

SUPERSAMPLE = 4


def diagonal_gradient(size: int) -> Image.Image:
    """A top-left to bottom-right linear ramp between the two brand greens."""
    image = Image.new("RGB", (size, size))
    pixels = []
    span = max(1, (size - 1) * 2)
    for y in range(size):
        for x in range(size):
            t = (x + y) / span
            pixels.append(
                tuple(
                    round(start + (end - start) * t)
                    for start, end in zip(GRADIENT_START, GRADIENT_END)
                )
            )
    image.putdata(pixels)
    return image


def draw_glyph(draw: ImageDraw.ImageDraw, size: int, offset: float = 0.0) -> None:
    """The `>_` prompt, with round caps and joins drawn as explicit discs."""
    width = max(1, round(STROKE * size))
    radius = width / 2

    def point(fraction: tuple[float, float]) -> tuple[float, float]:
        return (offset + fraction[0] * size, offset + fraction[1] * size)

    for path in (CHEVRON, CURSOR):
        points = [point(f) for f in path]
        draw.line(points, fill=INK, width=width, joint="curve")
        for x, y in points:
            draw.ellipse((x - radius, y - radius, x + radius, y + radius), fill=INK)


def render(size: int, *, rounded: bool, padding: float = 0.0, circle: bool = False) -> Image.Image:
    """Renders one icon at `size` px, supersampled then downsampled for clean edges."""
    scale = size * SUPERSAMPLE
    inset = round(padding * scale)
    tile = scale - inset * 2

    canvas = Image.new("RGBA", (scale, scale), (0, 0, 0, 0))

    gradient = diagonal_gradient(tile)
    mask = Image.new("L", (tile, tile), 0)
    if circle:
        ImageDraw.Draw(mask).ellipse((0, 0, tile - 1, tile - 1), fill=255)
    elif rounded:
        ImageDraw.Draw(mask).rounded_rectangle(
            (0, 0, tile - 1, tile - 1), radius=round(CORNER * tile), fill=255
        )
    else:
        ImageDraw.Draw(mask).rectangle((0, 0, tile - 1, tile - 1), fill=255)
    canvas.paste(gradient, (inset, inset), mask)

    draw_glyph(ImageDraw.Draw(canvas), tile, offset=inset)
    return canvas.resize((size, size), Image.LANCZOS)


def main() -> None:
    for folder, size in DENSITIES.items():
        target = os.path.join(RES, folder)
        os.makedirs(target, exist_ok=True)
        # A little padding: legacy launchers do not mask, so the tile needs its own margin.
        render(size, rounded=True, padding=0.04).save(
            os.path.join(target, "ic_launcher.png")
        )
        # API 25 asked for a circular variant via android:roundIcon.
        render(size, rounded=True, circle=True).save(
            os.path.join(target, "ic_launcher_round.png")
        )
        print(f"  {folder}/ic_launcher[_round].png  ({size}x{size})")

    store = os.path.join(ROOT, "store")
    os.makedirs(store, exist_ok=True)
    # Play wants a full-bleed 512 square with no transparency; the store applies its own mask.
    listing = Image.new("RGB", (512, 512), GRADIENT_START)
    listing.paste(render(512, rounded=False), (0, 0), render(512, rounded=False))
    listing.save(os.path.join(store, "ic_launcher_512.png"))
    print("  store/ic_launcher_512.png  (512x512)")


if __name__ == "__main__":
    main()
