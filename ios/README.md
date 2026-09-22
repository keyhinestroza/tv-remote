# App de iPhone

SwiftUI, iOS 17 o superior. El proyecto de Xcode se genera con XcodeGen:

```sh
xcodegen generate
```

## Cómo está organizado

| Archivo | Qué hace |
|---------|----------|
| `TVRemoteApp.swift` | Arranque de la app y el idioma elegido. |
| `RemoteView.swift` | La pantalla del mando. |
| `TouchPad.swift` · `SwipeTracker.swift` | El panel táctil: la vista y, aparte, la lógica del gesto, que es pura y se puede probar sin interfaz. |
| `TVRemoteClient.swift` | Conexión con el televisor por WebSocket y recuperación automática si cambia de dirección. |
| `TVDiscovery.swift` · `LocalNetwork.swift` | Búsqueda en la red y cálculo de direcciones. |
| `WakeOnLAN.swift` | Encendido del televisor apagado. |
| `PadGestures.swift` | Los gestos del panel en UIKit, porque SwiftUI no cuenta dedos. |
| `TVMute.swift` | Lee del televisor si está silenciado (lo único fiable que informa por UPnP). |
| `GuideView.swift` · `HelpView.swift` · `SettingsView.swift` | Guía de inicio, ayuda y ajustes. |
| `Localizable.xcstrings` | Textos en inglés (base) y español. |

## Probar la lógica sin interfaz

Las partes puras se compilan sueltas, sin simulador:

```sh
swiftc -O TVRemote/RemoteKey.swift TVRemote/SwipeTracker.swift ruta/a/main.swift -o /tmp/prueba
```

## El volumen

Se maneja con **dos dedos sobre el panel**: arriba y abajo lo cambian, un toque con dos
dedos silencia. Antes usaba los botones físicos del iPhone, pero la directriz 2.5.9 de la
App Store prohíbe cambiar la función de los interruptores estándar, así que se quitó.

Como un gesto que nadie ve no existe, se explica en cuatro sitios: una pantalla de la guía
de inicio, un recordatorio flotante cada vez que se abre la app (que deja de salir en cuanto
se usa el gesto), la pantalla de ayuda, y los botones de siempre en la hoja de Opciones.
Subir, bajar y silenciar están además como acciones de VoiceOver, porque con el lector
activo el gesto no llega a la app.
