"""Ajustes que comparten el programa de fondo y la ventana.

Todo está en settings.json. El programa de fondo vigila el archivo, así que un cambio
hecho desde la ventana se aplica solo, sin reiniciar nada.
"""
import ctypes
import itertools
import json
import os
import re
import sys
from pathlib import Path

DATA_DIR = Path(os.environ["LOCALAPPDATA"]) / "battery-tray"
SETTINGS_FILE = DATA_DIR / "settings.json"
STATE_FILE = DATA_DIR / "state.json"

TRAY_MUTEX = "BatteryTrayMutex"  # installer/battery-tray.iss usa el mismo nombre.
WINDOW_MUTEX = "BatteryTraySettingsMutex"

KINDS = ("mouse", "headset", "gamepad", "keyboard", "other")
DEFAULTS = {"devices": [], "streamdeck": True, "low_level": 15}
DEFAULT_COLOUR = "#46D26E"
REQUIRED = {"id", "driver", "name", "ref"}
ERROR_ALREADY_EXISTS = 183

_mutexes = []  # Se conservan abiertos: al cerrarse dejarían de bloquear otra instancia.


def resource(name):
    """Archivo que acompaña al programa, también dentro del paquete de PyInstaller."""
    return Path(getattr(sys, "_MEIPASS", Path(__file__).parent)) / name


def single_instance(name):
    """True si es la primera instancia. Sustituye al antiguo bloqueo por el puerto de la API."""
    kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)
    kernel32.CreateMutexW.restype = ctypes.c_void_p
    handle = kernel32.CreateMutexW(None, False, name)
    _mutexes.append(handle)
    return ctypes.get_last_error() != ERROR_ALREADY_EXISTS


def load():
    settings = dict(DEFAULTS, devices=[])
    try:
        saved = json.loads(SETTINGS_FILE.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return settings
    if isinstance(saved, dict):
        settings.update({key: saved[key] for key in DEFAULTS if key in saved})
    devices = settings["devices"] if isinstance(settings["devices"], list) else []
    settings["devices"] = [d for d in devices if isinstance(d, dict) and REQUIRED <= d.keys()]
    return settings


def save(settings):
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    tmp = SETTINGS_FILE.with_suffix(".tmp")
    tmp.write_text(json.dumps(settings, ensure_ascii=False, indent=2), encoding="utf-8")
    tmp.replace(SETTINGS_FILE)


def modified():
    try:
        return SETTINGS_FILE.stat().st_mtime_ns
    except OSError:
        return 0


def new_device(settings, candidate):
    """Crea la entrada de un dispositivo encontrado, con un id que no se repita."""
    base = re.sub(r"[^a-z0-9]+", "_", candidate["name"].lower()).strip("_") or "dispositivo"
    ids = {d["id"] for d in settings["devices"]}
    device_id = next(c for c in itertools.chain([base], (f"{base}_{n}" for n in itertools.count(2)))
                     if c not in ids)
    return {"id": device_id, "driver": candidate["driver"], "ref": candidate["ref"],
            "name": candidate["name"], "kind": candidate["kind"], "tray": True,
            "color": DEFAULT_COLOUR, "color_mode": "level", "tint_glyph": False}
