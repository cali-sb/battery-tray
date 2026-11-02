"""Genera los PNG del plugin. Solo hace falta si se cambia el dibujo.

- plugin: el icono de Litio (brand.app_image), en la lista de plugins.
- category: el rayo en blanco, junto al nombre de la categoría «Litio».
- action y key: la pila, porque la acción es «Batería».
"""
import sys
from pathlib import Path

from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
import brand  # noqa: E402

OUT = Path(__file__).parent / "com.cali.battery.sdPlugin" / "images"
OUT.mkdir(exist_ok=True)
WHITE = (255, 255, 255, 255)


def battery(size):
    s = size * 4
    image = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    w, h = s * 0.70, s * 0.42
    x, y = s * 0.10, (s - h) / 2
    t = max(s // 14, 1)
    draw.rounded_rectangle((x, y, x + w, y + h), radius=s // 14, outline="white", width=t)
    draw.rectangle((x + w + t, s * 0.42, x + w + t * 2.2, s * 0.58), fill="white")
    draw.rectangle((x + t * 2, y + t * 2, x + w * 0.62, y + h - t * 2), fill=(70, 210, 110, 255))
    return image.resize((size, size), Image.LANCZOS)


for name, size in {"plugin.png": 28, "plugin@2x.png": 56}.items():
    brand.app_image(size).save(OUT / name)
for name, size in {"category.png": 28, "category@2x.png": 56}.items():
    brand.bolt_image(size, WHITE, height=0.8).save(OUT / name)
for name, size in {"action.png": 20, "action@2x.png": 40, "key.png": 72, "key@2x.png": 144}.items():
    battery(size).save(OUT / name)
