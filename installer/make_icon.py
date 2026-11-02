"""Genera icon.ico, el icono del programa, de la ventana y del instalador.

Cada tamaño se dibuja aparte (brand.app_image): reducir el de 256 dejaría el rayo
demasiado fino a 16 px.
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
import brand  # noqa: E402

SIZES = (16, 20, 24, 32, 40, 48, 64, 256)
images = [brand.app_image(size) for size in SIZES]
images[-1].save(Path(__file__).parent / "icon.ico", sizes=[(s, s) for s in SIZES],
                append_images=images[:-1])
