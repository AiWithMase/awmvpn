"""Makes every icon of AWMVPN from the brand's two SVG masters:

    brand/tile.svg   the mark on the rounded dark tile (the app's icon)
    brand/mark.svg   the mark alone, transparent

Run from the repository root, with ImageMagick 7 (`magick`) on the PATH:

    python app/tool/app_icons.py

It writes the Windows .ico, the macOS icon set, Android's legacy and adaptive
icons, the Linux and web icons, the app's logo asset, and the tray icons of the
app and of the core. Replace the two SVGs (or point SOURCE_DIR at a folder with
same-named files) to rebrand; nothing else here names a colour.
"""
import os
import shutil
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
BRAND = os.path.join(ROOT, "brand")
MAGICK = shutil.which("magick")
if not MAGICK:
    sys.exit("ImageMagick 7 (magick) is needed")

TILE_SVG = os.path.join(BRAND, "tile.svg")
MARK_SVG = os.path.join(BRAND, "mark.svg")

TILE = os.path.join(tempfile.gettempdir(), "awmvpn-tile.png")
MARK = os.path.join(tempfile.gettempdir(), "awmvpn-mark.png")

# Android's launcher densities: the legacy icon's size, and the adaptive
# layers' size (108 dp).
DENSITIES = {
    "mdpi": (48, 108),
    "hdpi": (72, 162),
    "xhdpi": (96, 216),
    "xxhdpi": (144, 324),
    "xxxhdpi": (192, 432),
}

# The tray icons: mark colour, dot colour, dot radius at 80 px. The app's
# tray (the core's has the same shape, other states).
APP_TRAY = {
    "off": ("#C9C4BE", None, 0),
    "busy1": ("#E8772E", "#E8772E", 3),
    "busy2": ("#E8772E", "#E8772E", 5),
    "busy3": ("#E8772E", "#E8772E", 7),
    "busy4": ("#E8772E", "#E8772E", 9),
    "on": ("#FFFFFF", "#2ECC71", 10),
    "idle": ("#FFFFFF", "#2ECC71", 10),
    "error": ("#FFFFFF", "#E74C3C", 10),
}
CORE_TRAY = {
    "waiting": ("#FFFFFF", "#9AA0A6", 9),
    "off": ("#C9C4BE", None, 0),
    "running": ("#FFFFFF", "#2ECC71", 10),
    "running-asleep": ("#8C8883", "#9AA0A6", 9),
    "set": ("#FFFFFF", "#3B82F6", 10),
    "set-asleep": ("#8C8883", "#9AA0A6", 9),
    "error": ("#FFFFFF", "#E74C3C", 10),
}


def run(*args):
    subprocess.run([MAGICK, *args], check=True)


def resize(src, size, dst):
    run(src, "-resize", f"{size}x{size}", "-strip", "-depth", "8", dst)


def ico(src, dst):
    run(src, "-define", "icon:auto-resize=256,128,64,48,32,24,16", dst)


def tray_svg(path, mark_color, dot_color, dot_radius, size):
    """The mark with the state's dot, as an SVG at [size] px.

    The coordinates are the 80 px ones the dot radii are given in, so the
    same drawing scales to any size.
    """
    mark = open(MARK_SVG, encoding="utf-8").read()
    # Keep the mark's paths only: drop the XML declaration, the outer <svg>
    # tag, and the comments.
    body = mark
    if body.lstrip().startswith("<?xml"):
        body = body.split("?>", 1)[1]
    body = body.split(">", 1)[1].rsplit("</svg>", 1)[0]
    body = body.replace("#E8772E", mark_color).replace("#B9B3AC", mark_color)
    dot = (
        ""
        if not dot_color
        else f'<circle cx="62" cy="62" r="{dot_radius}" fill="{dot_color}"/>'
    )
    svg = (
        '<svg xmlns="http://www.w3.org/2000/svg" width="{0}" height="{0}" '
        'viewBox="0 0 80 80">'
        '<g transform="translate(-7,-15) scale(0.0767)">'
        "{1}</g>{2}</svg>"
    ).format(size, body, dot)
    with open(path, "w", encoding="utf-8") as f:
        f.write(svg)


def tray_icons(states, out_dir, size):
    os.makedirs(out_dir, exist_ok=True)
    for name, (mark_color, dot_color, radius) in states.items():
        svg = os.path.join(tempfile.gettempdir(), f"awmvpn-tray-{name}.svg")
        png = os.path.join(out_dir, name + ".png")
        tray_svg(svg, mark_color, dot_color, radius, size)
        run(
            "-background", "none", svg, "-resize", f"{size}x{size}", "-strip",
            "-depth", "8", png,
        )
        ico(png, os.path.join(out_dir, name + ".ico"))


def main():
    run("-background", "none", TILE_SVG, "-resize", "1024x1024", "-strip", TILE)
    run("-background", "none", MARK_SVG, "-resize", "1024x1024", "-strip", MARK)

    # Windows: the app's executable and the core's (the installer takes the
    # same file).
    ico(TILE, os.path.join(ROOT, "app/windows/runner/resources/app_icon.ico"))
    ico(TILE, os.path.join(ROOT, "core/internal/desktop/appicon.ico"))

    # macOS: exactly the sizes Contents.json names.
    mac = os.path.join(ROOT, "app/macos/Runner/Assets.xcassets/AppIcon.appiconset")
    for size in (16, 32, 64, 128, 256, 512, 1024):
        resize(TILE, size, os.path.join(mac, f"app_icon_{size}.png"))

    # Android: the legacy icon, and the adaptive icon's two layers.
    res = os.path.join(ROOT, "app/android/app/src/main/res")
    for density, (legacy, adaptive) in DENSITIES.items():
        d = os.path.join(res, f"mipmap-{density}")
        os.makedirs(d, exist_ok=True)
        resize(TILE, legacy, os.path.join(d, "ic_launcher.png"))
        # The background is the tile's own colour; the foreground is the
        # mark, well inside the 66 dp safe zone.
        run(
            "-size",
            f"{adaptive}x{adaptive}",
            "xc:#1A1918",
            "-strip",
            os.path.join(d, "ic_launcher_background.png"),
        )
        run(
            MARK,
            "-resize",
            f"{int(adaptive * 0.56)}x",
            "-background",
            "none",
            "-gravity",
            "center",
            "-extent",
            f"{adaptive}x{adaptive}",
            "-strip",
            os.path.join(d, "ic_launcher_foreground.png"),
        )

    # Linux, the web dashboard, and the logo beside the app's name.
    resize(TILE, 512, os.path.join(ROOT, "app/linux/runner/resources/app_icon.png"))
    resize(TILE, 512, os.path.join(ROOT, "core/internal/service/web/icon.png"))
    resize(TILE, 512, os.path.join(ROOT, "app/assets/logo.png"))

    # The trays.
    # The trays: the app's at 64 px, the core's at 32 px (what each draws).
    tray_icons(APP_TRAY, os.path.join(ROOT, "app/assets/tray"), 64)
    tray_icons(CORE_TRAY, os.path.join(ROOT, "core/internal/desktop/tray"), 32)

    # The Android status bar's icon: the mark's A, in white, as a vector.
    with open(
        os.path.join(res, "drawable/ic_stat_logo.xml"), "w", encoding="utf-8"
    ) as f:
        f.write(
            '<?xml version="1.0" encoding="utf-8"?>\n'
            '<vector xmlns:android="http://schemas.android.com/apk/res/android"\n'
            '    android:width="24dp"\n'
            '    android:height="24dp"\n'
            '    android:viewportWidth="24"\n'
            '    android:viewportHeight="24">\n'
            '    <path\n'
            '        android:fillColor="#FFFFFFFF"\n'
            '        android:pathData="M12,2 L22,22 H17.6 L12,9.6 L6.4,22 H2 Z" />\n'
            '    <path\n'
            '        android:fillColor="#FFFFFFFF"\n'
            '        android:pathData="M12,14.4 m-1.7,0 a1.7,1.7 0 1,0 3.4,0 '
            'a1.7,1.7 0 1,0 -3.4,0" />\n'
            "</vector>\n"
        )

    print("icons written")


if __name__ == "__main__":
    main()
