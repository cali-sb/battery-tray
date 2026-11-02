# battery-tray

Batería del ratón, los mandos y el teclado en Windows: icono de bandeja y teclas del Stream Deck, sin G HUB ni programas de cada fabricante.

Es un programa en Python (`battery_tray.py`) que lee los dispositivos y publica el estado en una API local, y un plugin de Stream Deck que lee esa API. Sin el programa en marcha, las teclas salen con `--`.

## Uso

- **Bandeja:** el número es el dispositivo conectado con menos batería. Al pasar el ratón sale la lista; con clic derecho, también los desconectados y «Salir».
- **Stream Deck:** categoría «Batería», una acción por dispositivo. El anillo marca el nivel, el rayo sustituye al icono mientras carga y el gris indica el último dato de un dispositivo desconectado.
- **Colores:** verde desde 30 %, ámbar desde 15 %, rojo por debajo.
- **API local:** `http://127.0.0.1:47631/battery.json`, solo en este PC.
- **Estado y log:** `%LOCALAPPDATA%\battery-tray` (`state.json` y `battery-tray.log`).

## Fuentes y refresco

| Dispositivo | Cómo se lee | Cada cuánto | Notas |
|---|---|---|---|
| Ratón PRO X 2 | HID++ 2.0, función `0x1004`, por el receptor `046D:C54D` | 5 min, solo con actividad en el PC; si no contesta, reintenta a los 20 s | Solo contesta mientras se usa. Porcentaje real |
| Xbox (`…0695`), Xbox Elite (`…54CF`), teclado Ducky | Propiedad de batería de Bluetooth de Windows | 30 s | El Xbox cambia de 5 en 5 aproximadamente: es lo que da el mando (Windows coincide con su `0x2A19` leído directamente). El Ducky solo se ve por Bluetooth, no por cable |
| DualSense | Informe HID `0x31` (Bluetooth) o `0x01` (USB) | 60 s | Tramos de 10 %: el mando no da más precisión |

Las teclas piden el estado cada 15 s o al pulsarlas. Pulsar no fuerza una lectura nueva del dispositivo.

Los intervalos están al principio de `battery_tray.py`, y las MAC y los nombres, en `BT_DEVICES`.

## Cosas que no son evidentes

- **HID++:** cada petición lleva su propio id y solo se acepta la respuesta con ese id. Sin eso, una respuesta atrasada de otra función se leyó como batería: el 7 de un falso «7 %» era la longitud del nombre «PRO X 2».
- **DualSense por USB:** Windows sigue listando su interfaz Bluetooth, que ya no envía nada. Hay que probar todas las interfaces, USB primero; con la primera de la lista, el valor se queda congelado.
- **DualSense por Bluetooth:** arranca en un modo reducido sin batería. Para leerla se pide el informe de calibración `0x05`, que lo pasa al modo completo hasta que se apague. Steam y los juegos con soporte nativo ya lo hacen, pero un juego antiguo que use el modo reducido podría ver mal los controles.

## Instalar

Desde la carpeta del repo, `D:\IT\battery-tray`:

```powershell
py -3.13 -m venv .venv
.venv\Scripts\python.exe -m pip install -r requirements.txt
New-Item -ItemType Junction -Path "$env:APPDATA\Elgato\StreamDeck\Plugins\com.cali.battery.sdPlugin" -Target "$PWD\streamdeck\com.cali.battery.sdPlugin"
```

Después, reiniciar el Stream Deck y arrastrar las teclas. Arranque automático al iniciar sesión:

```powershell
Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' -Name BatteryTray -Value "`"$PWD\.venv\Scripts\pythonw.exe`" `"$PWD\battery_tray.py`""
```

Si se mueve la carpeta hay que rehacer los tres pasos: el `.venv` guarda rutas absolutas, y el enlace del plugin y la clave `Run` también.

## Cambiar algo

- **Programa:** salir desde la bandeja y arrancarlo con `.venv\Scripts\pythonw.exe battery_tray.py`. Solo admite una instancia: si el puerto está ocupado, la segunda sale sin avisar.
- **Dibujo de la tecla:** `key.js`. Hay que reiniciar el Stream Deck para verlo.
- **Iconos del plugin:** `streamdeck\make_icons.py` (solo para cambiar el dibujo).
- **Dispositivo Bluetooth nuevo:** añadir su MAC a `BT_DEVICES` y su clave a `ORDER`; para tener tecla, una acción más en `manifest.json` con esa clave al final del `UUID`.

## Quitar

```powershell
Remove-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' -Name BatteryTray
cmd /c rmdir "$env:APPDATA\Elgato\StreamDeck\Plugins\com.cali.battery.sdPlugin"
```

`rmdir` quita solo el enlace del plugin, no su contenido en el repo.
