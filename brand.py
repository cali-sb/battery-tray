"""El rayo de Litio: un solo dibujo para el icono del programa, la bandeja y el Stream Deck.

El mismo trazado está en settings.qml (glyphs.bolt) y en key.js (GLYPHS.bolt), en SVG.
"""
from PIL import Image, ImageDraw

# Rejilla de 24 x 24, la misma del SVG: «M13.5 2 5 13.5h6L10 22l9-12.5h-6.2z».
BOLT = [(13.5, 2), (5, 13.5), (11, 13.5), (10, 22), (19, 9.5), (12.8, 9.5)]
GREEN_TOP = (98, 230, 134)
GREEN_BOTTOM = (22, 160, 74)
INK = (7, 24, 13, 255)  # El mismo verde casi negro que onAccent en la ventana.
SCALE = 8  # Se dibuja a 8 aumentos y se reduce: bordes suaves también a 16 px.


def _bolt(draw, size, height, fill, dx=0.0, dy=0.0):
    """Rayo centrado que ocupa height (fracción del lado)."""
    k = size * height / 20  # El rayo mide 20 de alto en la rejilla.
    points = [((x - 12) * k + size / 2 + dx * size, (y - 12) * k + size / 2 + dy * size) for x, y in BOLT]
    draw.polygon(points, fill=fill)


def bolt_image(size, ink, height=0.92):
    """Rayo solo, sobre transparente: bandeja y categoría del Stream Deck."""
    s = size * SCALE
    image = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    _bolt(ImageDraw.Draw(image), s, height, ink)
    return image.resize((size, size), Image.LANCZOS)


def app_image(size):
    """Icono del programa: cuadrado redondeado verde con el rayo oscuro."""
    s = size * SCALE
    gradient = Image.new("RGBA", (1, s))
    for y in range(s):
        t = y / (s - 1)
        gradient.putpixel((0, y), tuple(round(a + (b - a) * t) for a, b in zip(GREEN_TOP, GREEN_BOTTOM)) + (255,))
    gradient = gradient.resize((s, s))
    # A tamaño pequeño el cuadrado llena el hueco y el rayo crece: si no, se pierde.
    small = size <= 24
    margin = 0 if small else s * 0.06
    mask = Image.new("L", (s, s), 0)
    ImageDraw.Draw(mask).rounded_rectangle((margin, margin, s - margin, s - margin),
                                           radius=s * (0.2 if small else 0.22), fill=255)
    image = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    image.paste(gradient, (0, 0), mask)
    _bolt(ImageDraw.Draw(image), s, 0.74 if small else 0.62, INK)
    return image.resize((size, size), Image.LANCZOS)
