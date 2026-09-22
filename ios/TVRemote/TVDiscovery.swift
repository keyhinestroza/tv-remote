import Foundation
import Network

/// Un televisor encontrado en la red.
struct FoundTV: Identifiable, Equatable {
    var id: String { ip }
    let ip: String
    let name: String
    let model: String?
    /// MAC que reporta el TV, necesaria para encenderlo con Wake-on-LAN.
    let mac: String?
}

/// Busca televisores en la red local para no tener que escribir la IP a mano.
///
/// Primero por Bonjour: el TV se anuncia como `_samsungmsf._tcp` y en su anuncio ya viene
/// la dirección de su API. Si Bonjour no devuelve nada (hay redes que no dejan pasar mDNS,
/// y el TV en reposo profundo no se anuncia), se recorre la red preguntando por el puerto
/// 8001, que responde sin cifrado ni autorización.
@MainActor
final class TVDiscovery: ObservableObject {
    /// Busca el TV de una MAC concreta. Lo usa el cliente cuando el router le cambia la IP.
    static func find(mac: String) async -> FoundTV? {
        let wanted = normalized(mac)
        guard !wanted.isEmpty else { return nil }
        for tv in await bonjour(timeout: 4) where normalized(tv.mac ?? "") == wanted { return tv }
        for tv in await sweep() where normalized(tv.mac ?? "") == wanted { return tv }
        return nil
    }

    private static func normalized(_ mac: String) -> String {
        mac.lowercased().filter(\.isHexDigit)
    }

    @Published private(set) var found: [FoundTV] = []
    @Published private(set) var isSearching = false
    /// Qué se está haciendo ahora, para contarlo en pantalla.
    @Published private(set) var status = ""

    private let bonjourTimeout: TimeInterval = 4

    func search() async {
        guard !isSearching else { return }
        isSearching = true
        found = []
        defer { isSearching = false; status = "" }

        status = Localization.string("Searching with Bonjour…")
        for tv in await Self.bonjour(timeout: bonjourTimeout) { add(tv) }
        if !found.isEmpty { return }

        let hosts = LocalNetwork.hostsInLocalNetwork()
        guard !hosts.isEmpty else {
            status = Localization.string("Could not read the iPhone's network")
            return
        }
        status = Localization.string("Checking the network (\(hosts.count) addresses)…")
        for tv in await Self.sweep() { add(tv) }
    }

    private func add(_ tv: FoundTV) {
        guard !found.contains(where: { $0.ip == tv.ip }) else { return }
        found.append(tv)
    }

    // MARK: - Bonjour

    /// Televisores anunciados como `_samsungmsf._tcp`. La IP sale del propio anuncio
    /// (campo `se`, que es la URL de la API); el resto se pregunta al TV.
    private static func bonjour(timeout: TimeInterval) async -> [FoundTV] {
        let ips = await withCheckedContinuation { (continuation: CheckedContinuation<[String], Never>) in
            let browser = NWBrowser(for: .bonjourWithTXTRecord(type: "_samsungmsf._tcp", domain: nil), using: .tcp)
            let finished = Locked(false)

            @Sendable func finish(_ ips: [String]) {
                guard !finished.exchange(true) else { return }
                browser.cancel()
                continuation.resume(returning: ips)
            }

            browser.browseResultsChangedHandler = { results, _ in
                let ips = results.compactMap { result -> String? in
                    guard case .bonjour(let txt) = result.metadata else { return nil }
                    return txt["se"].flatMap { URL(string: $0)?.host }
                }
                if !ips.isEmpty { finish(ips) }
            }
            browser.stateUpdateHandler = { state in
                if case .failed = state { finish([]) }
            }
            browser.start(queue: .global(qos: .userInitiated))

            DispatchQueue.global().asyncAfter(deadline: .now() + timeout) { finish([]) }
        }

        var televisores: [FoundTV] = []
        for ip in Set(ips) {
            if let tv = await info(ip: ip, timeout: 3) { televisores.append(tv) }
        }
        return televisores
    }

    /// Recorre la red preguntando por el puerto 8001, en tandas para no abrir
    /// cientos de conexiones a la vez.
    private static func sweep(batch: Int = 24) async -> [FoundTV] {
        let hosts = LocalNetwork.hostsInLocalNetwork()
        var televisores: [FoundTV] = []
        for start in stride(from: 0, to: hosts.count, by: batch) {
            let slice = hosts[start..<min(start + batch, hosts.count)]
            await withTaskGroup(of: FoundTV?.self) { group in
                for host in slice {
                    group.addTask { await info(ip: host, timeout: 1.5) }
                }
                for await tv in group {
                    if let tv { televisores.append(tv) }
                }
            }
        }
        return televisores
    }

    // MARK: - API del TV

    /// Pregunta al TV por su nombre, modelo y MAC. Devuelve nil si esa dirección no es
    /// un TV compatible o no responde a tiempo.
    nonisolated static func info(ip: String, timeout: TimeInterval) async -> FoundTV? {
        guard let url = URL(string: "http://\(ip):8001/api/v2/") else { return nil }
        var request = URLRequest(url: url)
        request.timeoutInterval = timeout

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let device = json["device"] as? [String: Any] else { return nil }

        let name = (json["name"] as? String) ?? (device["name"] as? String) ?? Localization.string("Smart TV")
        return FoundTV(
            ip: (device["ip"] as? String) ?? ip,
            name: name,
            model: device["modelName"] as? String,
            mac: device["wifiMac"] as? String
        )
    }
}

/// Valor protegido por candado, para decidir una sola vez quién termina la búsqueda.
private final class Locked<Value>: @unchecked Sendable {
    private var value: Value
    private let lock = NSLock()

    init(_ value: Value) { self.value = value }

    func exchange(_ new: Value) -> Value {
        lock.lock()
        defer { lock.unlock() }
        let old = value
        value = new
        return old
    }
}
