# Remoto TV

Control remoto para televisores conectados a la red local, desde el teléfono.
Sin internet, sin cuentas y sin el mando original: el teléfono le habla al televisor
directamente por la red de casa.

La app encuentra el televisor sola (Bonjour, con barrido de la red como respaldo),
lo enciende aunque esté apagado del todo (Wake-on-LAN) y se maneja con un panel táctil
de deslizar y tocar, como el mando del Apple TV.

## Estructura

| Carpeta  | Qué hay |
|----------|---------|
| `ios/`   | La app de iPhone: SwiftUI, proyecto generado con XcodeGen desde `project.yml`. |
| `docs/`  | La política de privacidad como página web, lista para GitHub Pages. |
| `tools/` | Utilidades de desarrollo en Python para hablar con el televisor y validar el protocolo. |
| `store/` | Material para las tiendas: capturas por plataforma. |

Android todavía no existe; cuando llegue, irá en `android/` y compartirá con iOS la
documentación, las utilidades y el material de tienda que ya están aquí.

## iOS

Requiere Xcode 26 o superior (Apple lo exige para enviar a la App Store desde
abril de 2026) y [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```sh
cd ios
xcodegen generate          # regenera TVRemote.xcodeproj desde project.yml
open TVRemote.xcodeproj
```

El proyecto se genera desde `ios/project.yml`: los ajustes de firma, el idioma base y
las claves del Info.plist se editan ahí, no en Xcode, o se pierden en la siguiente
regeneración.

La app no trae ningún televisor preconfigurado. En el primer arranque muestra la guía
y busca el televisor en la red.

## Utilidades

`tools/validar_tv.py` comprueba el protocolo contra un televisor real y escribe un
`config.json` con su IP, modelo y MAC. Ese archivo **no se sube al repositorio**: contiene
datos de la red de quien desarrolla. Hay una plantilla en `tools/config.example.json`.

```sh
python3 -m venv .venv && .venv/bin/pip install samsungtvws
.venv/bin/python tools/validar_tv.py 192.168.1.10
```

## Privacidad

La app no recoge ningún dato. Todo lo que guarda (la dirección del televisor, el idioma
y la autorización que entrega el propio televisor) se queda en el teléfono.
La política completa está publicada en **https://keyhinestroza.github.io/tv-remote/**
y su fuente es `docs/index.html`.
