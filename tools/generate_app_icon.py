"""生成「多功能调试工具」的应用图标。

图形取自应用内使用的 Material 图标 developer_board（U+E1C5），
所以桌面图标和 App 里抽屉、关于页的图标是同一个。

默认输出透明底、绿色字形（和 App 内的图标同色）；
maskable 图标按规范需要铺满，仍保留绿色底 + 白色字形。

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
# 透明底版本里字形用的颜色（深绿，白底/深底都看得清）
GLYPH_COLOR_ON_TRANSPARENT = (26, 124, 84, 255)

MASTER_SIZE = 1024
# 透明底时字形占满画布的比例
GLYPH_RATIO = 0.84
# 实底（maskable）时字形占比，留出安全区
GLYPH_RATIO_ON_SOLID = 0.54


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


def render_glyph(
    size: int, ratio: float, color: tuple[int, int, int, int]
) -> Image.Image:
    """把图标字形渲染成透明底、按墨迹居中裁切的图。"""
    font = ImageFont.truetype(find_icon_font(), int(size * 0.9))
    layer = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    ImageDraw.Draw(layer).text(
        (size / 2, size / 2),
        chr(GLYPH_CODE_POINT),
        font=font,
        fill=color,
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


def render_transparent_icon(size: int) -> Image.Image:
    """透明底 + 绿色字形：没有方块底，直接是图形本身。"""
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    glyph = render_glyph(size, GLYPH_RATIO, GLYPH_COLOR_ON_TRANSPARENT)
    canvas.alpha_composite(
        glyph,
        ((size - glyph.width) // 2, (size - glyph.height) // 2),
    )
    return canvas


def render_solid_icon(size: int) -> Image.Image:
    """绿色圆角底 + 白色字形：给 maskable 图标用。"""
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    background = vertical_gradient(size, size).convert("RGBA")
    background.putalpha(rounded_mask(size, 0.22))
    canvas.alpha_composite(background)

    glyph = render_glyph(size, GLYPH_RATIO_ON_SOLID, GLYPH_COLOR)
    canvas.alpha_composite(
        glyph,
        ((size - glyph.width) // 2, (size - glyph.height) // 2),
    )
    return canvas


def render_maskable(size: int) -> Image.Image:
    """maskable 要求铺满且内容留在安全区，所以实底 + 缩小字形。"""
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    canvas.alpha_composite(vertical_gradient(size, size).convert("RGBA"))
    glyph = render_glyph(size, GLYPH_RATIO_ON_SOLID * 0.72, GLYPH_COLOR)
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
    master = render_transparent_icon(MASTER_SIZE)

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

    # Web：普通图标透明底，maskable 用实底版本
    save(master.resize((192, 192), Image.LANCZOS), "web/icons/Icon-192.png")
    save(master.resize((512, 512), Image.LANCZOS), "web/icons/Icon-512.png")
    maskable = render_maskable(MASTER_SIZE)
    save(maskable.resize((192, 192), Image.LANCZOS), "web/icons/Icon-maskable-192.png")
    save(maskable.resize((512, 512), Image.LANCZOS), "web/icons/Icon-maskable-512.png")
    save(master.resize((64, 64), Image.LANCZOS), "web/favicon.png")

    # Windows：多尺寸 ico（透明底）
    ico_path = os.path.join(ROOT, "windows/runner/resources/app_icon.ico")
    sizes = [(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)]
    master.save(ico_path, format="ICO", sizes=sizes)
    print(
        "wrote windows/runner/resources/app_icon.ico "
        f"({', '.join(f'{w}x{h}' for w, h in sizes)})"
    )


if __name__ == "__main__":
    main()
