import Darwin
import Foundation

/// Encendido del TV por Wake-on-LAN.
///
/// En iOS sin el entitlement de multicast (no disponible con cuenta gratuita):
/// - 255.255.255.255 falla siempre ("No route to host").
/// - NWConnection no puede activar SO_BROADCAST: el broadcast de subred da "Permission denied".
/// - La IP del TV no sirve: en reposo profundo no responde ARP y el paquete no llega.
/// Lo que sí funciona es un socket BSD con SO_BROADCAST hacia el broadcast de la subred.
enum WakeOnLAN {
    /// Construye el paquete mágico: 6 bytes 0xFF seguidos de 16 repeticiones de la MAC.
    /// Acepta la MAC con separadores ":" o "-" o sin ellos. Devuelve nil si no es válida.
    static func magicPacket(mac: String) -> Data? {
        let hex = mac.filter(\.isHexDigit)
        guard hex.count == 12, mac.allSatisfy({ $0.isHexDigit || ":-. ".contains($0) }) else { return nil }

        var bytes: [UInt8] = []
        var index = hex.startIndex
        while index < hex.endIndex {
            let next = hex.index(index, offsetBy: 2)
            guard let byte = UInt8(hex[index..<next], radix: 16) else { return nil }
            bytes.append(byte)
            index = next
        }

        var packet = Data(repeating: 0xFF, count: 6)
        for _ in 0..<16 { packet.append(contentsOf: bytes) }
        return packet
    }

    /// Envía el paquete mágico por UDP al broadcast de la subred del TV.
    /// - Parameters:
    ///   - mac: MAC del TV (la que reporta como `wifiMac`).
    ///   - host: IP del TV; determina la subred.
    /// - Returns: false si la MAC no es válida, el iPhone no está en la red del TV o iOS rechaza el envío.
    @discardableResult
    static func wake(mac: String, host: String, port: UInt16 = 9) -> Bool {
        guard let packet = magicPacket(mac: mac),
              let broadcast = LocalNetwork.broadcast(reaching: host.trimmingCharacters(in: .whitespaces)) else { return false }

        let fd = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
        guard fd >= 0 else { return false }
        defer { close(fd) }
        var on: Int32 = 1
        guard setsockopt(fd, SOL_SOCKET, SO_BROADCAST, &on, socklen_t(MemoryLayout<Int32>.size)) == 0 else { return false }

        var address = sockaddr_in()
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = port.bigEndian
        address.sin_addr = broadcast

        // UDP no garantiza entrega (menos aún el broadcast por Wi-Fi): se envía tres veces.
        var delivered = false
        for _ in 0..<3 {
            let sent = packet.withUnsafeBytes { bytes in
                withUnsafePointer(to: &address) {
                    $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                        sendto(fd, bytes.baseAddress, packet.count, 0, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
                    }
                }
            }
            if sent == packet.count { delivered = true }
        }
        return delivered
    }
}
