"""Genera icon.ico, el icono del programa y del instalador."""
from pathlib import Path

from PIL import Image, ImageDraw

s = 256
image = Image.new("RGBA", (s, s), (0, 0, 0, 0))
draw = ImageDraw.Draw(image)
draw.rounded_rectangle((16, 72, 212, 184), radius=24, outline="white", width=18)
draw.rectangle((222, 106, 244, 150), fill="white")
draw.rounded_rectangle((44, 100, 142, 156), radius=6, fill=(70, 210, 110, 255))
image.save(Path(__file__).parent / "icon.ico", sizes=[(16, 16), (24, 24), (32, 32), (48, 48), (256, 256)])
