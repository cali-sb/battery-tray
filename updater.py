"""Actualizaciones desde las releases de GitHub.

Solo el programa de fondo busca e instala. La ventana de ajustes se entera por update.json
y le pide cosas dejando una palabra en update-request; así no hay dos procesos descargando.

Una release vale si su etiqueta es X.Y.Z (con o sin «v»), no es borrador ni pre-release y
lleva un asset «...setup....exe». El instalador se baja a %TEMP%, se comprueba con el
tamaño y el SHA-256 que publica GitHub, y se lanza en silencio: es por usuario, no pide
administrador. El programa se cierra para soltar sus archivos y el instalador lo reabre.
"""
import hashlib
import json
import logging
import os
import re
import subprocess
import sys
import tempfile
import threading
import time
import urllib.request
from pathlib import Path

import config
from version import __version__

REPO = "cali-sb/battery-tray"
RELEASES_API = f"https://api.github.com/repos/{REPO}/releases?per_page=20"
INSTALLER_RE = re.compile(r"setup.*\.exe$", re.IGNORECASE)
USER_AGENT = f"Bateria/{__version__}"
DOWNLOAD_DIR = Path(tempfile.gettempdir()) / "Bateria-update"
STATUS_FILE = config.DATA_DIR / "update.json"
REQUEST_FILE = config.DATA_DIR / "update-request"
FIRST_CHECK = 60  # s tras arrancar: no estorbar al inicio de sesión.
CHECK_EVERY = 6 * 3600

log = logging.getLogger("battery-tray")


def parse(tag):
    match = re.fullmatch(r"v?(\d+)\.(\d+)\.(\d+)", tag.strip(), re.IGNORECASE)
    return tuple(map(int, match.groups())) if match else None


def installed():
    """Solo el programa empaquetado puede sustituirse con el instalador."""
    return getattr(sys, "frozen", False)


def latest():
    """La release más nueva con instalador si es posterior a esta versión; si no, None."""
    request = urllib.request.Request(RELEASES_API, headers={
        "Accept": "application/vnd.github+json", "User-Agent": USER_AGENT})
    with urllib.request.urlopen(request, timeout=15) as response:
        releases = json.load(response)
    best = None
    for release in releases:
        if release.get("draft") or release.get("prerelease"):
            continue
        version = parse(release.get("tag_name", ""))
        asset = next((a for a in release.get("assets", []) if INSTALLER_RE.search(a.get("name", ""))), None)
        if version is None or asset is None or (best and version <= best["key"]):
            continue
        digest = asset.get("digest") or ""
        best = {"key": version, "version": ".".join(map(str, version)),
                "notes": (release.get("body") or "").replace("\r\n", "\n").strip(),
                "url": release.get("html_url", f"https://github.com/{REPO}/releases"),
                "name": asset["name"], "download": asset["browser_download_url"],
                "size": asset.get("size", 0),
                "sha256": digest.split(":", 1)[1] if digest.startswith("sha256:") else None}
    return best if best and best["key"] > parse(__version__) else None


def download(update):
    """Baja el instalador y comprueba tamaño y huella. Devuelve la ruta."""
    DOWNLOAD_DIR.mkdir(parents=True, exist_ok=True)
    path = DOWNLOAD_DIR / Path(update["name"]).name
    partial = path.with_suffix(".part")
    sha, size = hashlib.sha256(), 0
    request = urllib.request.Request(update["download"], headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(request, timeout=30) as response, open(partial, "wb") as out:
        while chunk := response.read(256 * 1024):
            out.write(chunk)
            sha.update(chunk)
            size += len(chunk)
    if update["size"] and size != update["size"]:
        partial.unlink()
        raise OSError(f"descarga incompleta: {size} de {update['size']} bytes")
    if update["sha256"] and sha.hexdigest() != update["sha256"]:
        partial.unlink()
        raise OSError("el SHA-256 no coincide con el publicado en GitHub")
    os.replace(partial, path)
    return path


def launch(path):
    # El ejecutable de PyInstaller deja en el entorno variables de su carpeta temporal; si el
    # instalador las heredase, el programa nuevo intentaría usar la del viejo, que ya no existe.
    env = {k: v for k, v in os.environ.items() if not k.startswith("_PYI_") and k != "_MEIPASS2"}
    env["PYINSTALLER_RESET_ENVIRONMENT"] = "1"
    subprocess.Popen([str(path), "/VERYSILENT", "/SUPPRESSMSGBOXES", "/NORESTART", "/update=1",
                      f"/LOG={DOWNLOAD_DIR / 'instalacion.log'}"], env=env, close_fds=True,
                     creationflags=subprocess.DETACHED_PROCESS | subprocess.CREATE_NEW_PROCESS_GROUP)


def cleanup():
    """Borra instaladores de actualizaciones ya hechas o abandonadas."""
    for item in DOWNLOAD_DIR.glob("*"):
        try:
            item.unlink()
        except OSError:
            pass


def read_status():
    try:
        return json.loads(STATUS_FILE.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return {}


def request(action):
    """Desde la ventana: «check» o «install»."""
    config.DATA_DIR.mkdir(parents=True, exist_ok=True)
    REQUEST_FILE.write_text(action, encoding="utf-8")


class Updater:
    """Hilo del programa de fondo. on_install se llama justo después de lanzar el instalador."""

    def __init__(self, auto, on_install):
        self.auto = auto
        self.on_install = on_install
        self.available = None
        self.pending = None
        self.wake = threading.Event()
        self.status = {}

    def _set(self, status, message, **extra):
        self.status = {"current": __version__, "status": status, "message": message,
                       "installable": installed(), **extra}
        if self.available:
            self.status["available"] = {k: self.available[k] for k in ("version", "notes", "url")}
        config.DATA_DIR.mkdir(parents=True, exist_ok=True)
        tmp = STATUS_FILE.with_suffix(".tmp")
        tmp.write_text(json.dumps(self.status, ensure_ascii=False), encoding="utf-8")
        tmp.replace(STATUS_FILE)

    def poll(self):
        """Desde el bucle principal: recoge lo que haya pedido la ventana."""
        try:
            action = REQUEST_FILE.read_text(encoding="utf-8").strip()
            REQUEST_FILE.unlink()
        except OSError:
            return
        self.ask(action)

    def ask(self, action):
        if action in ("check", "install"):
            self.pending = action
            self.wake.set()

    def run(self):
        cleanup()
        self._set("idle", "Aún no se ha buscado.")
        next_check = time.monotonic() + FIRST_CHECK
        while True:
            self.wake.wait(max(0.0, next_check - time.monotonic()))
            self.wake.clear()
            action, self.pending = self.pending or "check", None
            if action == "install" and self.available:
                self._install()
                continue
            next_check = time.monotonic() + CHECK_EVERY
            if self._check() and self.auto() and installed():
                self._install()

    def _check(self):
        self._set("checking", "Buscando…")
        try:
            self.available = latest()
        except Exception as exc:  # Sin red, GitHub caído, límite de peticiones…
            log.warning("no se pudo buscar actualizaciones: %s", exc)
            self._set("error", "No se pudo consultar GitHub.", checked=int(time.time()))
            return False
        if self.available:
            self._set("available", f"Versión {self.available['version']} disponible.", checked=int(time.time()))
        else:
            self._set("latest", "Tienes la última versión.", checked=int(time.time()))
        return bool(self.available)

    def _install(self):
        version = self.available["version"]
        if not installed():
            self._set("available", f"Versión {version} disponible. Desde el código fuente no se instala: usa git pull.")
            return
        self._set("downloading", f"Descargando la versión {version}…")
        try:
            path = download(self.available)
            self._set("installing", f"Instalando la versión {version}…")
            launch(path)
        except Exception as exc:
            log.exception("falló la actualización a %s", version)
            self._set("available", f"No se pudo actualizar: {exc}")
            return
        self.on_install()
