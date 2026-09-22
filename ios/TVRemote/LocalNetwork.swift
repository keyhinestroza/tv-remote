import Darwin
import Foundation

/// Datos de la red local del iPhone: qué interfaz comparte red con el TV y qué
/// direcciones tiene esa red. Lo usan el Wake-on-LAN y la búsqueda de televisores.
enum LocalNetwork {
    /// Interfaz IPv4 activa y con broadcast que está en la misma red que `host`.
    static func interface(reaching host: String) -> (address: in_addr, netmask: in_addr)? {
        var target = in_addr()
        guard inet_pton(AF_INET, host, &target) == 1 else { return nil }

        var list: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&list) == 0 else { return nil }
        defer { freeifaddrs(list) }

        var current = list
        while let entry = current?.pointee {
            defer { current = entry.ifa_next }
            let flags = Int32(entry.ifa_flags)
            guard flags & IFF_UP != 0, flags & IFF_BROADCAST != 0,
                  let addr = entry.ifa_addr, addr.pointee.sa_family == sa_family_t(AF_INET),
                  let mask = entry.ifa_netmask else { continue }

            let local = addr.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { $0.pointee.sin_addr }
            let netmask = mask.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { $0.pointee.sin_addr }
            // Direcciones en orden de red: las operaciones de bits no dependen del orden de bytes.
            if local.s_addr & netmask.s_addr == target.s_addr & netmask.s_addr {
                return (local, netmask)
            }
        }
        return nil
    }

    /// Dirección de broadcast de la red que comparte con `host` (192.168.1.6 /24 → 192.168.1.255).
    static func broadcast(reaching host: String) -> in_addr? {
        guard let (address, netmask) = interface(reaching: host) else { return nil }
        return in_addr(s_addr: address.s_addr | ~netmask.s_addr)
    }

    /// Todas las direcciones de la red del iPhone, sin la suya, la de red ni la de broadcast.
    /// Devuelve vacío si la red es mayor que una /22: barrerla tardaría demasiado.
    static func hostsInLocalNetwork() -> [String] {
        var list: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&list) == 0 else { return [] }
        defer { freeifaddrs(list) }

        var current = list
        while let entry = current?.pointee {
            defer { current = entry.ifa_next }
            let flags = Int32(entry.ifa_flags)
            guard flags & IFF_UP != 0, flags & IFF_BROADCAST != 0, flags & IFF_LOOPBACK == 0,
                  let addr = entry.ifa_addr, addr.pointee.sa_family == sa_family_t(AF_INET),
                  let mask = entry.ifa_netmask else { continue }

            let local = addr.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { $0.pointee.sin_addr }
            let netmask = mask.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { $0.pointee.sin_addr }
            // in_addr guarda la dirección en orden de red; se pasa a orden de máquina para
            // poder recorrerla como número.
            let address = UInt32(bigEndian: local.s_addr)
            let bits = UInt32(bigEndian: netmask.s_addr)
            let hostBits = (~bits).nonzeroBitCount
            guard hostBits > 1, hostBits <= 10 else { continue }

            let network = address & bits
            let last = (UInt32(1) << hostBits) - 1  // esa es la de broadcast
            return (1..<last).compactMap { offset in
                let value = network | offset
                guard value != address else { return nil }
                return string(from: in_addr(s_addr: value.bigEndian))
            }
        }
        return []
    }

    static func string(from address: in_addr) -> String? {
        var address = address
        var buffer = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
        guard inet_ntop(AF_INET, &address, &buffer, socklen_t(INET_ADDRSTRLEN)) != nil else { return nil }
        return String(cString: buffer)
    }
}
