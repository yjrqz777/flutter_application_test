"""生成「多功能调试工具」的应用图标。

一次生成所有平台需要的尺寸：Android mipmap、Web 图标与 favicon、Windows ico。
改图标只要调下面的配色和图形参数，然后重跑本脚本：

    python tools/generate_app_icon.py

设计：绿色圆角方块 + 白色蓝牙符文，和 App 主题种子色一致。
"""

from __future__ import annotations

import os

from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# 配色：与 lib/theme.dart 里的种子色同族
TOP_COLOR = (47, 184, 119)
BOTTOM_COLOR = (26, 124, 84)
GLYPH_COLOR = (255, 255, 255, 255)

MASTER_SIZE = 1024


def vertical_gradient(width: int, height: int) -> Image.Image:
    """两像素的渐变图放大，得到平滑的竖向渐变。"""
    base = Image.new("RGB", (1, 2))
    base.putpixel((0, 0), TOP_COLOR)
    base.putpixel((0, 1), BOTTOM_COLOR)
    return base.resize((width, height), Image.BICUBIC)


def rounded_mask(size: int, radius_ratio: float) -> Image.Image:
    mask = Image.new("L", (size, size), 0)
    radius = int(size * radius_ratio)
    ImageDraw.Draw(mask).rounded_rectangle(
        [0, 0, size - 1, size - 1], radius=radius, fill=255
    )
    return mask


def draw_glyph(canvas: Image.Image, size: int, scale: float) -> None:
    """在画布中央画白色蓝牙符文。scale 控制符文占比。"""
    draw = ImageDraw.Draw(canvas)
    glyph_height = size * 0.46 * scale
    glyph_width = glyph_height * 0.62
    center_x, center_y = size / 2, size / 2

    def point(u: float, v: float) -> tuple[float, float]:
        return (
            center_x + (u - 0.5) * glyph_width,
            center_y + (v - 0.5) * glyph_height,
        )

    top = point(0.5, 0.0)
    upper_right = point(1.0, 0.25)
    lower_left = point(0.0, 0.75)
    bottom = point(0.5, 1.0)
    lower_right = point(1.0, 0.75)
    upper_left = point(0.0, 0.25)

    strokes = (
        [top, upper_right, lower_left],
        [bottom, lower_right, upper_left],
        [top, bottom],
    )
    width = max(int(size * 0.075 * scale), 2)

    for stroke in strokes:
        draw.line(stroke, fill=GLYPH_COLOR, width=width, joint="curve")
        for x, y in stroke:
            radius = width / 2
            draw.ellipse(
                [x - radius, y - radius, x + radius, y + radius],
                fill=GLYPH_COLOR,
            )


def render_icon(size: int, *, rounded: bool = True, glyph_scale: float = 1.0) -> Image.Image:
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    if rounded:
        background = vertical_gradient(size, size).convert("RGBA")
        background.putalpha(rounded_mask(size, 0.22))
        canvas.alpha_composite(background)
    else:
        canvas.alpha_composite(vertical_gradient(size, size).convert("RGBA"))
    draw_glyph(canvas, size, glyph_scale)
    return canvas


def save(image: Image.Image, relative_path: str) -> None:
    target = os.path.join(ROOT, relative_path)
    os.makedirs(os.path.dirname(target), exist_ok=True)
    image.save(target)
    print(f"wrote {relative_path} ({image.width}x{image.height})")


def main() -> None:
    master = render_icon(MASTER_SIZE)

    # Android：传统 mipmap 图标（项目里没有自适应图标目录）
    android_sizes = {
        "mipmap-mdpi": 48,
        "mipmap-hdpi": 72,
        "mipmap-xhdpi": 96,
        "mipmap-xxhdpi": 144,
        "mipmap-xxxhdpi": 192,
    }
    for folder, size in android_sizes.items():
        icon = master.resize((size, size), Image.LANCZOS)
        save(icon, f"android/app/src/main/res/{folder}/ic_launcher.png")

    # Android 启动页图案：xxhdpi 288px 约等于 96dp
    save(
        master.resize((288, 288), Image.LANCZOS),
        "android/app/src/main/res/drawable-xxhdpi/splash_logo.png",
    )

    # Web：普通图标保持透明圆角，maskable 版本铺满并留安全区
    save(master.resize((192, 192), Image.LANCZOS), "web/icons/Icon-192.png")
    save(master.resize((512, 512), Image.LANCZOS), "web/icons/Icon-512.png")
    maskable = render_icon(MASTER_SIZE, rounded=False, glyph_scale=0.72)
    save(maskable.resize((192, 192), Image.LANCZOS), "web/icons/Icon-maskable-192.png")
    save(maskable.resize((512, 512), Image.LANCZOS), "web/icons/Icon-maskable-512.png")
    save(master.resize((64, 64), Image.LANCZOS), "web/favicon.png")

    # Windows：多尺寸 ico
    ico_path = os.path.join(ROOT, "windows/runner/resources/app_icon.ico")
    sizes = [(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)]
    master.save(ico_path, format="ICO", sizes=sizes)
    print(f"wrote windows/runner/resources/app_icon.ico ({', '.join(f'{w}x{h}' for w, h in sizes)})")


if __name__ == "__main__":
    main()
