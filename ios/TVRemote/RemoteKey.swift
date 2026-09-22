import Foundation

/// Teclas del control remoto. El rawValue es el código que entiende el TV (KEY_XXX).
enum RemoteKey: String {
    case power = "KEY_POWER"
    case source = "KEY_SOURCE"
    case home = "KEY_HOME"
    case back = "KEY_RETURN"

    case volumeUp = "KEY_VOLUP"
    case volumeDown = "KEY_VOLDOWN"
    case mute = "KEY_MUTE"
    case channelUp = "KEY_CHUP"
    case channelDown = "KEY_CHDOWN"

    case up = "KEY_UP"
    case down = "KEY_DOWN"
    case left = "KEY_LEFT"
    case right = "KEY_RIGHT"
    case ok = "KEY_ENTER"

    case num0 = "KEY_0"
    case num1 = "KEY_1"
    case num2 = "KEY_2"
    case num3 = "KEY_3"
    case num4 = "KEY_4"
    case num5 = "KEY_5"
    case num6 = "KEY_6"
    case num7 = "KEY_7"
    case num8 = "KEY_8"
    case num9 = "KEY_9"

    /// Tecla numérica para un dígito 0-9.
    static func digit(_ n: Int) -> RemoteKey? {
        RemoteKey(rawValue: "KEY_\(n)")
    }
}
