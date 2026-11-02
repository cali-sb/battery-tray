"""Ventana de ajustes (PySide6 + Qt Quick).

Va en un proceso aparte del de fondo: solo escribe settings.json y lee state.json.
"""
import json
import sys
import threading

from PySide6.QtCore import Property, QObject, QTimer, QUrl, Signal, Slot
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtQuickControls2 import QQuickStyle

import config
import devices
import updater
from version import __version__


class Backend(QObject):
    devicesChanged = Signal()
    candidatesChanged = Signal()
    liveChanged = Signal()
    updateChanged = Signal()
    scanningChanged = Signal()
    scanFinished = Signal(list)

    def __init__(self):
        super().__init__()
        self._settings = config.load()
        self._candidates = []
        self._live = {}
        self._update = None  # None hasta la primera lectura.
        self._scanning = False
        self.scanFinished.connect(self._on_scan)
        self._timer = QTimer(self, interval=1000, timeout=self._refresh_live)
        self._timer.start()
        self._refresh_live()

    def _reload(self):
        """Antes de escribir: el menú de la bandeja también cambia el archivo."""
        self._settings = config.load()

    def _save(self):
        config.save(self._settings)

    def _refresh_live(self):
        try:
            data = json.loads(config.STATE_FILE.read_text(encoding="utf-8"))
        except (OSError, ValueError):
            data = {}
        if data != self._live:
            self._live = data
            self.liveChanged.emit()
        status = updater.read_status()
        # Solo si empieza con la ventana abierta: un «installing» viejo, de una
        # actualización que no llegó a terminar, no debe cerrarla nada más abrirla.
        starting = (status.get("status") == "installing" and self._update is not None
                    and self._update.get("status") != "installing")
        if status != self._update:
            self._update = status
            self.updateChanged.emit()
        if starting:
            QGuiApplication.quit()  # Suelta sus archivos; el instalador espera a que se cierre.

    @Property(str, constant=True)
    def version(self):
        return __version__

    @Property("QVariantMap", notify=updateChanged)
    def update(self):
        """update.json del programa de fondo; vacío si no está en marcha."""
        return self._update

    @Property(bool, constant=True)
    def autoUpdate(self):
        return self._settings["auto_update"]

    @Slot(bool)
    def setAutoUpdate(self, enabled):
        self._reload()
        self._settings["auto_update"] = enabled
        self._save()

    @Slot(str)
    def requestUpdate(self, action):
        updater.request(action)

    @Property("QVariantList", notify=devicesChanged)
    def devices(self):
        return self._settings["devices"]

    @Property("QVariantList", notify=candidatesChanged)
    def candidates(self):
        return self._candidates

    @Property("QVariantMap", notify=liveChanged)
    def live(self):
        return self._live

    @Property(bool, notify=scanningChanged)
    def scanning(self):
        return self._scanning

    @Property(bool, constant=True)
    def streamdeck(self):
        return self._settings["streamdeck"]

    @Property(int, constant=True)
    def lowLevel(self):
        return self._settings["low_level"]

    @Slot(str, str, "QVariant")
    def setField(self, device_id, field, value):
        self._reload()
        for device in self._settings["devices"]:
            if device["id"] == device_id:
                device[field] = value
        self._save()
        self.devicesChanged.emit()

    @Slot(str)
    def remove(self, device_id):
        self._reload()
        self._settings["devices"] = [d for d in self._settings["devices"] if d["id"] != device_id]
        self._save()
        self.devicesChanged.emit()
        self._mark_added()

    @Slot(bool)
    def setStreamdeck(self, enabled):
        self._reload()
        self._settings["streamdeck"] = enabled
        self._save()

    @Slot(int)
    def setLowLevel(self, level):
        self._reload()
        self._settings["low_level"] = level
        self._save()

    @Slot()
    def scan(self):
        if self._scanning:
            return
        self._scanning = True
        self.scanningChanged.emit()
        threading.Thread(target=lambda: self.scanFinished.emit(devices.discover()), daemon=True).start()

    @Slot(list)
    def _on_scan(self, found):
        self._candidates = found
        self._scanning = False
        self.scanningChanged.emit()
        self._mark_added()

    def _mark_added(self):
        added = {(d["driver"], d["ref"]) for d in self._settings["devices"]}
        self._candidates = [dict(c, added=(c["driver"], c["ref"]) in added) for c in self._candidates]
        self.candidatesChanged.emit()

    @Slot(int)
    def add(self, index):
        self._reload()
        self._settings["devices"].append(config.new_device(self._settings, self._candidates[index]))
        self._save()
        self.devicesChanged.emit()
        self._mark_added()


def main():
    if not config.single_instance(config.WINDOW_MUTEX):
        return
    QQuickStyle.setStyle("Basic")  # El único que permite dibujar los controles a medida.
    app = QGuiApplication(sys.argv)
    app.setApplicationName("Litio")
    engine = QQmlApplicationEngine()
    backend = Backend()
    engine.rootContext().setContextProperty("backend", backend)
    engine.load(QUrl.fromLocalFile(str(config.resource("settings.qml"))))
    if not engine.rootObjects():
        sys.exit(1)
    sys.exit(app.exec())


if __name__ == "__main__":
    main()
