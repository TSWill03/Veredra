#!/usr/bin/env python3
# Signature: dev.tswicolly03

from __future__ import annotations

from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter, ImageFont


ROOT = Path(__file__).resolve().parents[1]
SIGNATURE = "dev.tswicolly03"


def rounded_rect_mask(size: int, radius: int) -> Image.Image:
    mask = Image.new("L", (size, size), 0)
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle((0, 0, size - 1, size - 1), radius=radius, fill=255)
    return mask


def lerp(a: float, b: float, t: float) -> float:
    return a + (b - a) * t


def gradient_background(size: int) -> Image.Image:
    image = Image.new("RGBA", (size, size))
    pixels = image.load()
    top = (15, 37, 45)
    bottom = (5, 16, 23)
    accent = (201, 168, 104)

    for y in range(size):
      t = y / max(size - 1, 1)
      for x in range(size):
        dx = (x - size * 0.35) / size
        dy = (y - size * 0.30) / size
        radial = max(0.0, 1.0 - ((dx * dx) + (dy * dy)) * 5.8)
        r = int(lerp(top[0], bottom[0], t) + radial * 18)
        g = int(lerp(top[1], bottom[1], t) + radial * 16)
        b = int(lerp(top[2], bottom[2], t) + radial * 14)
        glow = max(0.0, 1.0 - ((x - size * 0.7) ** 2 + (y - size * 0.2) ** 2) / (size * size * 0.28))
        r = min(255, r + int(accent[0] * glow * 0.10))
        g = min(255, g + int(accent[1] * glow * 0.09))
        b = min(255, b + int(accent[2] * glow * 0.07))
        pixels[x, y] = (r, g, b, 255)

    vignette = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    vignette_draw = ImageDraw.Draw(vignette)
    vignette_draw.ellipse(
        (-size * 0.10, -size * 0.08, size * 1.18, size * 1.20),
        outline=(255, 255, 255, 12),
        width=max(4, size // 128),
    )
    image = Image.alpha_composite(image, vignette)
    image.putalpha(rounded_rect_mask(size, int(size * 0.24)))
    return image


def draw_glow(base: Image.Image, bounds: tuple[int, int, int, int], color: tuple[int, int, int, int], blur: int) -> None:
    overlay = Image.new("RGBA", base.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)
    draw.ellipse(bounds, fill=color)
    overlay = overlay.filter(ImageFilter.GaussianBlur(blur))
    base.alpha_composite(overlay)


def draw_book_icon(size: int = 1024) -> Image.Image:
    image = gradient_background(size)

    draw_glow(
        image,
        (
            int(size * 0.18),
            int(size * 0.08),
            int(size * 0.84),
            int(size * 0.72),
        ),
        (214, 185, 121, 42),
        blur=max(12, size // 22),
    )

    shadow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    shadow_draw = ImageDraw.Draw(shadow)
    shadow_draw.rounded_rectangle(
        (
            int(size * 0.24),
            int(size * 0.29),
            int(size * 0.77),
            int(size * 0.75),
        ),
        radius=int(size * 0.10),
        fill=(0, 0, 0, 110),
    )
    shadow = shadow.filter(ImageFilter.GaussianBlur(radius=max(10, size // 28)))
    image.alpha_composite(shadow)

    draw = ImageDraw.Draw(image)
    page_fill = (245, 236, 212, 255)
    page_fill_alt = (237, 226, 197, 255)
    left_page = [
        (size * 0.27, size * 0.26),
        (size * 0.48, size * 0.24),
        (size * 0.51, size * 0.63),
        (size * 0.30, size * 0.68),
    ]
    right_page = [
        (size * 0.52, size * 0.24),
        (size * 0.73, size * 0.26),
        (size * 0.70, size * 0.68),
        (size * 0.49, size * 0.63),
    ]
    draw.polygon(left_page, fill=page_fill)
    draw.polygon(right_page, fill=page_fill_alt)

    draw.line(
        [(size * 0.50, size * 0.25), (size * 0.50, size * 0.64)],
        fill=(133, 108, 68, 200),
        width=max(4, size // 90),
    )

    for index in range(5):
        y = size * (0.31 + index * 0.06)
        draw.line(
            [(size * 0.33, y), (size * 0.45, y - size * 0.015)],
            fill=(200, 186, 150, 150),
            width=max(3, size // 160),
        )
        draw.line(
            [(size * 0.55, y - size * 0.015), (size * 0.67, y)],
            fill=(197, 180, 145, 150),
            width=max(3, size // 160),
        )

    ribbon = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    ribbon_draw = ImageDraw.Draw(ribbon)
    ribbon_points = [
        (size * 0.57, size * 0.21),
        (size * 0.60, size * 0.31),
        (size * 0.58, size * 0.42),
        (size * 0.54, size * 0.53),
        (size * 0.56, size * 0.65),
        (size * 0.63, size * 0.80),
    ]
    ribbon_draw.line(
        ribbon_points,
        fill=(213, 180, 103, 255),
        width=max(18, size // 32),
        joint="curve",
    )
    ribbon_draw.line(
        [(size * 0.58, size * 0.21), (size * 0.60, size * 0.80)],
        fill=(245, 227, 178, 120),
        width=max(5, size // 100),
    )
    ribbon = ribbon.filter(ImageFilter.GaussianBlur(radius=max(1, size // 190)))
    image.alpha_composite(ribbon)

    badge = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    badge_draw = ImageDraw.Draw(badge)
    badge_draw.rounded_rectangle(
        (
            int(size * 0.34),
            int(size * 0.67),
            int(size * 0.67),
            int(size * 0.81),
        ),
        radius=int(size * 0.05),
        fill=(11, 24, 31, 210),
        outline=(220, 196, 140, 130),
        width=max(3, size // 160),
    )
    image.alpha_composite(badge)

    try:
        font = ImageFont.truetype("arial.ttf", size // 12)
        small_font = ImageFont.truetype("arial.ttf", size // 30)
    except OSError:
        font = ImageFont.load_default()
        small_font = ImageFont.load_default()

    draw = ImageDraw.Draw(image)
    badge_text = "V"
    badge_bbox = draw.textbbox((0, 0), badge_text, font=font)
    badge_width = badge_bbox[2] - badge_bbox[0]
    badge_height = badge_bbox[3] - badge_bbox[1]
    draw.text(
        (
            size * 0.505 - badge_width / 2,
            size * 0.724 - badge_height / 2,
        ),
        badge_text,
        fill=(245, 235, 210, 255),
        font=font,
    )
    draw.text(
        (size * 0.35, size * 0.86),
        SIGNATURE,
        fill=(223, 208, 176, 98),
        font=small_font,
    )

    return image


def save_resized(source: Image.Image, target_path: Path, size: int) -> None:
    target_path.parent.mkdir(parents=True, exist_ok=True)
    resized = source.resize((size, size), Image.Resampling.LANCZOS)
    resized.save(target_path)


def write_ios_icons(source: Image.Image) -> None:
    ios_dir = ROOT / "ios" / "Runner" / "Assets.xcassets" / "AppIcon.appiconset"
    ios_sizes = {
        "Icon-App-20x20@1x.png": 20,
        "Icon-App-20x20@2x.png": 40,
        "Icon-App-20x20@3x.png": 60,
        "Icon-App-29x29@1x.png": 29,
        "Icon-App-29x29@2x.png": 58,
        "Icon-App-29x29@3x.png": 87,
        "Icon-App-40x40@1x.png": 40,
        "Icon-App-40x40@2x.png": 80,
        "Icon-App-40x40@3x.png": 120,
        "Icon-App-60x60@2x.png": 120,
        "Icon-App-60x60@3x.png": 180,
        "Icon-App-76x76@1x.png": 76,
        "Icon-App-76x76@2x.png": 152,
        "Icon-App-83.5x83.5@2x.png": 167,
        "Icon-App-1024x1024@1x.png": 1024,
    }
    for file_name, size in ios_sizes.items():
        save_resized(source, ios_dir / file_name, size)


def write_macos_icons(source: Image.Image) -> None:
    mac_dir = ROOT / "macos" / "Runner" / "Assets.xcassets" / "AppIcon.appiconset"
    mac_sizes = {
        "app_icon_16.png": 16,
        "app_icon_32.png": 32,
        "app_icon_64.png": 64,
        "app_icon_128.png": 128,
        "app_icon_256.png": 256,
        "app_icon_512.png": 512,
        "app_icon_1024.png": 1024,
    }
    for file_name, size in mac_sizes.items():
        save_resized(source, mac_dir / file_name, size)


def write_android_icons(source: Image.Image) -> None:
    android_dir = ROOT / "android" / "app" / "src" / "main" / "res"
    android_sizes = {
        "mipmap-mdpi/ic_launcher.png": 48,
        "mipmap-hdpi/ic_launcher.png": 72,
        "mipmap-xhdpi/ic_launcher.png": 96,
        "mipmap-xxhdpi/ic_launcher.png": 144,
        "mipmap-xxxhdpi/ic_launcher.png": 192,
    }
    for relative_path, size in android_sizes.items():
        save_resized(source, android_dir / relative_path, size)


def write_windows_icon(source: Image.Image) -> None:
    icon_path = ROOT / "windows" / "runner" / "resources" / "app_icon.ico"
    icon_path.parent.mkdir(parents=True, exist_ok=True)
    source.save(
        icon_path,
        sizes=[(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)],
    )


def write_branding_assets(source: Image.Image) -> None:
    branding_dir = ROOT / "assets" / "branding"
    branding_dir.mkdir(parents=True, exist_ok=True)
    source.save(branding_dir / "app_icon_master.png")
    preview = source.resize((256, 256), Image.Resampling.LANCZOS)
    preview.save(branding_dir / "app_icon_preview.png")


def main() -> None:
    master = draw_book_icon(1024)
    write_branding_assets(master)
    write_android_icons(master)
    write_ios_icons(master)
    write_macos_icons(master)
    write_windows_icon(master)
    print("Branding assets generated successfully.")


if __name__ == "__main__":
    main()
