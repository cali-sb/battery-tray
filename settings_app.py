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


class Backend(QObject):
    devicesChanged = Signal()
    candidatesChanged = Signal()
    liveChanged = Signal()
    scanningChanged = Signal()
    scanFinished = Signal(list)

    def __init__(self):
        super().__init__()
        self._settings = config.load()
        self._candidates = []
        self._live = {}
        self._scanning = False
        self.scanFinished.connect(self._on_scan)
        self._timer = QTimer(self, interval=3000, timeout=self._refresh_live)
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
    app.setApplicationName("Batería")
    engine = QQmlApplicationEngine()
    backend = Backend()
    engine.rootContext().setContextProperty("backend", backend)
    engine.load(QUrl.fromLocalFile(str(config.resource("settings.qml"))))
    if not engine.rootObjects():
        sys.exit(1)
    sys.exit(app.exec())


if __name__ == "__main__":
    main()
