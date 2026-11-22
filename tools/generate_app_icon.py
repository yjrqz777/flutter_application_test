"""生成「多功能调试工具」的应用图标。

图形取自应用内使用的 Material 图标 developer_board（U+E1C5），
所以桌面图标和 App 里抽屉、关于页的图标是同一个。
一次生成所有平台需要的尺寸：Android mipmap + 启动页图案、Web 图标与 favicon、Windows ico。

改图标只要调下面的配色和 glyph 占比，然后重跑本脚本：

    python tools/generate_app_icon.py
"""

from __future__ import annotations

import os
import sys

from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# 应用图标用的字形：Material Icons 里的 developer_board
GLYPH_CODE_POINT = 0xE1C5
# Flutter SDK 自带的 MaterialIcons 字体（DevTools 资源里那份是完整图标字体）
ICON_FONT_CANDIDATES = (
    r"D:\App\flutter\flutter\bin\cache\dart-sdk\bin\resources\devtools\assets\fonts\MaterialIcons-Regular.otf",
)

# 配色：与 lib/theme.dart 里的种子色同族
TOP_COLOR = (47, 184, 119)
BOTTOM_COLOR = (26, 124, 84)
GLYPH_COLOR = (255, 255, 255, 255)

MASTER_SIZE = 1024
# 字形在图标里的最大占比（maskable 版本会更小，留出安全区）
GLYPH_RATIO = 0.54


def find_icon_font() -> str:
    for path in ICON_FONT_CANDIDATES:
        if os.path.exists(path):
            return path
    sys.exit(
        "找不到 MaterialIcons 字体，请把路径加到 ICON_FONT_CANDIDATES：\n  "
        + "\n  ".join(ICON_FONT_CANDIDATES)
    )


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


def render_glyph(size: int, ratio: float) -> Image.Image:
    """把图标字形渲染成透明底、按墨迹居中裁切的图。"""
    font = ImageFont.truetype(find_icon_font(), int(size * 0.9))
    layer = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    ImageDraw.Draw(layer).text(
        (size / 2, size / 2),
        chr(GLYPH_CODE_POINT),
        font=font,
        fill=GLYPH_COLOR,
        anchor="mm",
    )

    bbox = layer.getbbox()
    if bbox is None:
        sys.exit("字形没有渲染出任何像素，请检查字体是否包含 U+%04X" % GLYPH_CODE_POINT)
    glyph = layer.crop(bbox)

    # 缩放到目标占比：外接框最长边等于 size * ratio
    scale = size * ratio / max(glyph.width, glyph.height)
    return glyph.resize(
        (max(1, round(glyph.width * scale)), max(1, round(glyph.height * scale))),
        Image.LANCZOS,
    )


def render_icon(size: int, *, rounded: bool = True, glyph_ratio: float = GLYPH_RATIO) -> Image.Image:
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    if rounded:
        background = vertical_gradient(size, size).convert("RGBA")
        background.putalpha(rounded_mask(size, 0.22))
        canvas.alpha_composite(background)
    else:
        canvas.alpha_composite(vertical_gradient(size, size).convert("RGBA"))

    glyph = render_glyph(size, glyph_ratio)
    canvas.alpha_composite(
        glyph,
        ((size - glyph.width) // 2, (size - glyph.height) // 2),
    )
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
    maskable = render_icon(MASTER_SIZE, rounded=False, glyph_ratio=GLYPH_RATIO * 0.72)
    save(maskable.resize((192, 192), Image.LANCZOS), "web/icons/Icon-maskable-192.png")
    save(maskable.resize((512, 512), Image.LANCZOS), "web/icons/Icon-maskable-512.png")
    save(master.resize((64, 64), Image.LANCZOS), "web/favicon.png")

    # Windows：多尺寸 ico
    ico_path = os.path.join(ROOT, "windows/runner/resources/app_icon.ico")
    sizes = [(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)]
    master.save(ico_path, format="ICO", sizes=sizes)
    print(
        "wrote windows/runner/resources/app_icon.ico "
        f"({', '.join(f'{w}x{h}' for w, h in sizes)})"
    )


if __name__ == "__main__":
    main()
