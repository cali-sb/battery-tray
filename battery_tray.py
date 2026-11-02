"""Batería del ratón, los mandos y el teclado en la bandeja de Windows.

Fuentes (todas de solo lectura, salvo el aviso del DualSense en el README):
- PRO X 2: HID++ 2.0 por el receptor LIGHTSPEED. Solo contesta mientras se usa.
- Xbox y Ducky: propiedad de batería de Bluetooth que ya mantiene Windows.
- DualSense: informe de entrada HID.

Publica el estado en http://127.0.0.1:47631/battery.json para el Stream Deck.
"""
import ctypes
import json
import logging
import logging.handlers
import os
import threading
import time
import uuid
from ctypes import wintypes
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

import hid
import pystray
from PIL import Image, ImageDraw, ImageFont

PORT = 47631
BT_INTERVAL = 30
DUALSENSE_INTERVAL = 60
MOUSE_INTERVAL = 300
MOUSE_RETRY = 20

LOGI_VID, LOGI_PID = 0x046D, 0xC54D
SONY_VID, SONY_PIDS = 0x054C, (0x0CE6, 0x0DF2)
BT_DEVICES = {
    "AABBCCDDEE01": ("xbox", "Xbox"),
    "AABBCCDDEE02": ("xbox_elite", "Xbox Elite"),
    "AABBCCDDEE03": ("teclado", "Teclado"),
}
ORDER = ["raton", "dualsense", "xbox", "xbox_elite", "teclado"]
NAMES = {"raton": "Ratón", "dualsense": "DualSense"}

DATA_DIR = Path(os.environ["LOCALAPPDATA"]) / "battery-tray"
STATE_FILE = DATA_DIR / "state.json"
log = logging.getLogger("battery-tray")
lock = threading.Lock()
state = {}


def load_state():
    try:
        saved = json.loads(STATE_FILE.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return
    for value in saved.values():
        value["online"] = False
    state.update(saved)


def update(key, name, level=None, charging=False, online=True):
    """Guarda una lectura; sin nivel nuevo conserva el último conocido."""
    with lock:
        current = state.setdefault(key, {"name": name, "level": None, "charging": False,
                                         "online": False, "updated": None})
        current["online"] = online
        if level is not None:
            current.update(level=level, charging=charging, updated=int(time.time()))
        else:
            current["charging"] = False
        snapshot = json.dumps(state, ensure_ascii=False)
    tmp = STATE_FILE.with_suffix(".tmp")
    tmp.write_text(snapshot, encoding="utf-8")
    tmp.replace(STATE_FILE)


class LastInput(ctypes.Structure):
    _fields_ = [("cbSize", wintypes.UINT), ("dwTime", wintypes.DWORD)]


def idle_ms():
    info = LastInput(ctypes.sizeof(LastInput), 0)
    ctypes.windll.user32.GetLastInputInfo(ctypes.byref(info))
    return (ctypes.windll.kernel32.GetTickCount() - info.dwTime) & 0xFFFFFFFF


class HidppMouse:
    """Lee la función 0x1004 (Unified Battery) del dispositivo 1 del receptor."""

    DEVICE = 1
    FEATURE = 0x1004

    def __init__(self):
        self.index = None
        self.sw = 0

    def _call(self, dev, idx, fn, params=b"", timeout=0.7):
        # Cada petición lleva su propio id: una respuesta atrasada de otra
        # petición llegó a leerse como batería (7 % en vez de 57 %).
        self.sw = self.sw % 15 + 1
        expected = (fn << 4) | self.sw
        dev.write((bytes([0x11, self.DEVICE, idx, expected]) + params).ljust(20, b"\0"))
        end = time.monotonic() + timeout
        while time.monotonic() < end:
            raw = dev.read(20)
            if not raw:
                time.sleep(0.003)
                continue
            r = bytes(raw)
            if r[1] == self.DEVICE and r[2] == 0xFF and r[3] == idx and r[4] == expected:
                return None
            if r[1] == self.DEVICE and r[2] == idx and r[3] == expected:
                return r[4:]
        return None

    def read(self):
        """Devuelve (porcentaje, cargando) o None si el ratón no contesta."""
        path = next((d["path"] for d in hid.enumerate(LOGI_VID, LOGI_PID)
                     if d["usage_page"] == 0xFF00 and d["usage"] == 2), None)
        if path is None:
            return None
        dev = hid.device()
        dev.open_path(path)
        try:
            dev.set_nonblocking(True)
            if self.index is None:
                reply = self._call(dev, 0, 0, self.FEATURE.to_bytes(2, "big"))
                if not reply or reply[0] == 0:
                    return None
                self.index = reply[0]
            reply = self._call(dev, self.index, 1)
            if not reply or not 0 <= reply[0] <= 100:
                self.index = None
                return None
            return reply[0], reply[2] in (1, 2, 3, 4)
        finally:
            dev.close()


class DevPropKey(ctypes.Structure):
    _fields_ = [("fmtid", ctypes.c_byte * 16), ("pid", wintypes.ULONG)]


def propkey(guid, pid):
    key = DevPropKey()
    key.fmtid[:] = list(int.from_bytes(bytes([b]), "little", signed=True)
                        for b in uuid.UUID(guid).bytes_le)
    key.pid = pid
    return key


KEY_CONNECTED = propkey("83DA6326-97A6-4088-9453-A1923F573B29", 15)
KEY_BATTERY = propkey("104EA319-6EE2-4701-BD47-8DDBF425BBE5", 2)
CM_FILTER_ENUMERATOR, CM_FILTER_PRESENT = 0x1, 0x100
cfgmgr = ctypes.windll.cfgmgr32


def device_ids(enumerator):
    flags = CM_FILTER_ENUMERATOR | CM_FILTER_PRESENT
    size = wintypes.ULONG()
    if cfgmgr.CM_Get_Device_ID_List_SizeW(ctypes.byref(size), enumerator, flags):
        return []
    buffer = ctypes.create_unicode_buffer(size.value)
    if cfgmgr.CM_Get_Device_ID_ListW(enumerator, buffer, size, flags):
        return []
    return [item for item in buffer[:].split("\0") if item]


def get_property(devinst, key):
    prop_type, data = wintypes.ULONG(), (ctypes.c_ubyte * 8)()
    size = wintypes.ULONG(ctypes.sizeof(data))
    if cfgmgr.CM_Get_DevNode_PropertyW(devinst, ctypes.byref(key), ctypes.byref(prop_type),
                                       data, ctypes.byref(size), 0):
        return None
    return data[0]


def read_bluetooth():
    for enumerator in ("BTHLE", "BTHENUM"):
        for instance in device_ids(enumerator):
            upper = instance.upper()
            if "\\DEV_" not in upper:
                continue
            mac = upper.split("\\DEV_")[1][:12]
            if mac not in BT_DEVICES:
                continue
            devinst = wintypes.DWORD()
            if cfgmgr.CM_Locate_DevNodeW(ctypes.byref(devinst), instance, 0):
                continue
            key, name = BT_DEVICES[mac]
            online = bool(get_property(devinst, KEY_CONNECTED))
            update(key, name, get_property(devinst, KEY_BATTERY) if online else None, False, online)


def read_dualsense():
    """Devuelve (porcentaje, cargando) o None si el mando está apagado.

    Con el mando por USB, Windows sigue listando su interfaz Bluetooth, que ya
    no envía nada: hay que probarlas todas, no quedarse con la primera.
    """
    interfaces = [d for d in hid.enumerate(SONY_VID) if d["product_id"] in SONY_PIDS]
    interfaces.sort(key=lambda d: d.get("bus_type") != 1)  # USB primero.
    for interface in interfaces:
        reading = read_dualsense_interface(interface["path"])
        if reading:
            return reading
    return None


def read_dualsense_interface(path):
    dev = hid.device()
    try:
        dev.open_path(path)
    except OSError:
        return None
    try:
        asked = False
        empty = 0
        for _ in range(20):
            r = dev.read(100, 150)
            if not r:
                empty += 1
                if empty >= 3:
                    return None
                continue
            if r[0] == 0x31 and len(r) >= 78:
                status = r[54]
            elif r[0] == 0x01 and len(r) >= 64:
                status = r[53]
            elif r[0] == 0x01 and not asked:
                # En Bluetooth arranca en modo reducido, sin batería: pedir la
                # calibración lo pasa al informe completo 0x31.
                dev.get_feature_report(0x05, 41)
                asked = True
                continue
            else:
                continue
            charge, mode = status & 0x0F, status >> 4
            if mode == 2:
                return 100, True
            if mode in (0, 1) and charge <= 10:
                return min(charge * 10 + 5, 100), mode == 1
        return None
    finally:
        dev.close()


def worker():
    mouse = HidppMouse()
    next_mouse = next_bt = next_ds = 0.0
    while True:
        now = time.monotonic()
        try:
            if now >= next_bt:
                next_bt = now + BT_INTERVAL
                read_bluetooth()
            if now >= next_ds:
                next_ds = now + DUALSENSE_INTERVAL
                reading = read_dualsense()
                update("dualsense", NAMES["dualsense"], *(reading or (None, False)),
                       online=reading is not None)
            if now >= next_mouse and idle_ms() < 1500:
                reading = mouse.read()
                next_mouse = now + (MOUSE_INTERVAL if reading else MOUSE_RETRY)
                if reading:
                    update("raton", NAMES["raton"], *reading)
                elif "raton" not in state:
                    update("raton", NAMES["raton"], online=False)
        except Exception:
            log.exception("fallo al leer")
        time.sleep(0.5)


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path != "/battery.json":
            self.send_error(404)
            return
        with lock:
            body = json.dumps(state, ensure_ascii=False).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *args):
        pass


def colour(level):
    if level is None:
        return (150, 150, 150, 255)
    if level >= 30:
        return (70, 210, 110, 255)
    return (245, 170, 40, 255) if level >= 15 else (240, 70, 60, 255)


def tray_image(level):
    image = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    text = "?" if level is None else str(level)
    font = ImageFont.truetype("arialbd.ttf", 30 if len(text) > 2 else 46)
    box = draw.textbbox((0, 0), text, font=font)
    draw.text(((64 - box[2] - box[0]) / 2, (64 - box[3] - box[1]) / 2), text,
              font=font, fill=colour(level))
    return image


def sorted_devices():
    with lock:
        return [dict(state[key]) for key in ORDER if key in state]


def line(device):
    if device["level"] is None:
        return f"{device['name']}: sin datos"
    bolt = " (cargando)" if device["charging"] else ""
    off = "" if device["online"] else " (último dato)"
    return f"{device['name']}: {device['level']} %{bolt}{off}"


def tray_loop(icon):
    icon.visible = True
    shown = None
    while True:
        devices = sorted_devices()
        online = [d["level"] for d in devices if d["online"] and d["level"] is not None]
        lowest = min(online) if online else None
        lines = [line(d) for d in devices if d["online"] or d["name"] == "Ratón"]
        current = (lowest, tuple(lines))
        if current != shown:
            shown = current
            icon.icon = tray_image(lowest)
            icon.title = ("\n".join(lines) or "Sin dispositivos")[:127]
            icon.update_menu()
        time.sleep(2)


def menu_items():
    items = [pystray.MenuItem(line(d), None, enabled=False) for d in sorted_devices()]
    return items + [pystray.Menu.SEPARATOR,
                    pystray.MenuItem("Salir", lambda icon, _: icon.stop())]


def main():
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    handler = logging.handlers.RotatingFileHandler(DATA_DIR / "battery-tray.log",
                                                   maxBytes=200_000, backupCount=1, encoding="utf-8")
    logging.basicConfig(level=logging.WARNING, handlers=[handler],
                        format="%(asctime)s %(levelname)s %(message)s")
    load_state()
    try:
        server = ThreadingHTTPServer(("127.0.0.1", PORT), Handler)
    except OSError:
        return  # Ya hay otra instancia con el puerto.
    threading.Thread(target=server.serve_forever, daemon=True).start()
    threading.Thread(target=worker, daemon=True).start()
    icon = pystray.Icon("battery-tray", tray_image(None), "Batería", pystray.Menu(menu_items))
    icon.run(setup=lambda i: threading.Thread(target=tray_loop, args=(i,), daemon=True).start())


if __name__ == "__main__":
    main()
