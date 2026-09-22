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
| `VolumeButtons.swift` | Volumen con los botones físicos (ver la nota de abajo). |
| `GuideView.swift` · `HelpView.swift` · `SettingsView.swift` | Guía de inicio, ayuda y ajustes. |
| `Localizable.xcstrings` | Textos en inglés (base) y español. |

## Probar la lógica sin interfaz

Las partes puras se compilan sueltas, sin simulador:

```sh
swiftc -O TVRemote/RemoteKey.swift TVRemote/SwipeTracker.swift ruta/a/main.swift -o /tmp/prueba
```

## Pendiente antes de publicar

`VolumeButtons.swift` usa los botones físicos de volumen del iPhone para el volumen del
televisor. No hay API pública para eso y la directriz 2.5.9 de la App Store prohíbe
cambiar la función de los interruptores estándar, así que **hay que decidir si se quita
antes de enviar la app a revisión**. El volumen también está en la hoja de Opciones, que
no tiene ese problema.
