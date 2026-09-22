import Combine
import Foundation

/// Estado de la conexión con el TV.
enum ConnectionState: Equatable {
    case disconnected
    case connecting
    case connected
}

/// Cliente del control remoto Samsung (Tizen) por WebSocket seguro, puerto 8002.
///
/// Flujo: abre wss://IP:8002/api/v2/channels/samsung.remote.control con el nombre
/// de la app en base64 y el token guardado (si hay). El TV responde con el evento
/// `ms.channel.connect`; si trae `data.token` se guarda en Keychain y se reutiliza
/// para que el TV no vuelva a pedir autorización.
@MainActor
final class TVRemoteClient: ObservableObject {
    @Published private(set) var state: ConnectionState = .disconnected
    /// Último error legible, para mostrarlo bajo el estado de conexión.
    @Published private(set) var lastError: String?
    /// true si el TV está apagado pero con la red aún activa (reposo ligero).
    @Published private(set) var isStandby = false

    /// Nombre con el que la app aparece en el TV al pedir autorización.
    private let appName = "RemotoKey"
    /// Tiempo máximo para abrir el socket (TV apagado o IP incorrecta).
    private let openTimeout: TimeInterval = 8
    /// Tiempo máximo para que el usuario acepte la autorización en el TV.
    private let authorizationTimeout: TimeInterval = 60

    private var host = ""
    private var session: URLSession?
    private var task: URLSessionWebSocketTask?
    /// Identifica la conexión vigente; los callbacks de conexiones viejas se ignoran.
    private var generation = 0
    /// true mientras la app quiera estar conectada (activa la reconexión automática).
    private var wantsConnection = false
    private var reconnectAttempt = 0
    private var reconnectWork: Task<Void, Never>?
    private var watchdog: Task<Void, Never>?
    private var heartbeat: Task<Void, Never>?
    /// Si no es nil y no ha vencido, se envía KEY_POWER en cuanto haya conexión.
    private var pendingPowerUntil: Date?
    /// true si ya se buscó el TV en esta racha de fallos: solo se intenta una vez.
    private var addressChecked = false

    // MARK: - API pública

    /// Conecta con el TV. Si ya había una conexión, la reemplaza.
    func connect(host: String) {
        let host = host.trimmingCharacters(in: .whitespaces)
        guard !host.isEmpty else {
            disconnect()
            return
        }
        // Misma IP y conexión en curso o establecida: no hay nada que hacer.
        if host == self.host, state != .disconnected { return }
        self.host = host
        wantsConnection = true
        reconnectAttempt = 0
        openConnection()
    }

    /// Cierra la conexión y detiene la reconexión automática.
    func disconnect() {
        wantsConnection = false
        tearDown()
        state = .disconnected
    }

    /// Envía una pulsación de tecla. Se ignora si no hay conexión.
    func sendKey(_ key: RemoteKey) {
        guard state == .connected, let task else { return }
        let payload: [String: Any] = [
            "method": "ms.remote.control",
            "params": [
                "Cmd": "Click",
                "DataOfCmd": key.rawValue,
                "Option": "false",
                "TypeOfRemote": "SendRemoteKey",
            ],
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: payload),
              let text = String(data: data, encoding: .utf8) else { return }

        let id = generation
        task.send(.string(text)) { [weak self] error in
            guard let error else { return }
            Task { @MainActor in
                self?.connectionLost(id: id, reason: NetworkError.message(for: error))
            }
        }
    }

    /// Enciende o apaga el TV eligiendo el método según su estado real:
    /// - Encendido o reposo ligero (la API responde): KEY_POWER por WebSocket. En reposo
    ///   ligero el TV ignora el Wake-on-LAN.
    /// - Reposo profundo (la API no responde): solo despierta con el paquete mágico.
    func togglePower(host: String, mac: String) {
        let host = host.trimmingCharacters(in: .whitespaces)
        guard !host.isEmpty else { return }
        Task {
            if await Self.fetchPowerState(host: host) != nil {
                if state == .connected {
                    sendKey(.power)
                } else {
                    pendingPowerUntil = Date().addingTimeInterval(15)
                    connect(host: host)
                }
            } else {
                // El socket que hubiera está muerto: se reabre mientras el TV arranca.
                self.host = host
                wantsConnection = true
                reconnectAttempt = 0
                openConnection()
                for _ in 0..<3 {
                    WakeOnLAN.wake(mac: mac, host: host)
                    try? await Task.sleep(for: .seconds(1.5))
                }
            }
        }
    }

    /// Borra el token guardado: el TV pedirá autorización en la próxima conexión.
    func forgetToken(host: String) {
        KeychainStore.delete(host: host)
    }

    // MARK: - Conexión

    private func openConnection() {
        tearDown()
        guard let url = makeURL() else {
            lastError = Localization.string("Invalid address")
            state = .disconnected
            return
        }

        generation += 1
        let id = generation
        state = .connecting
        lastError = nil

        // El delegate acepta el certificado autofirmado solo para el host del TV.
        let delegate = SessionDelegate(
            trustedHost: host,
            onOpen: { [weak self] in
                Task { @MainActor in self?.socketOpened(id: id) }
            },
            onClose: { [weak self] reason in
                Task { @MainActor in self?.connectionLost(id: id, reason: reason) }
            }
        )
        let config = URLSessionConfiguration.ephemeral
        // El socket pasa mucho tiempo inactivo: los límites los ponen los watchdogs.
        config.timeoutIntervalForRequest = 60 * 60 * 24
        config.waitsForConnectivity = false
        let session = URLSession(configuration: config, delegate: delegate, delegateQueue: nil)
        let task = session.webSocketTask(with: url)
        self.session = session
        self.task = task

        task.resume()
        listen(on: task, id: id)
        startWatchdog(id: id, seconds: openTimeout, message: Localization.string("TV not found. Is it on?"))
    }

    private func makeURL() -> URL? {
        var components = URLComponents()
        components.scheme = "wss"
        components.host = host
        components.port = 8002
        components.path = "/api/v2/channels/samsung.remote.control"
        var items = [URLQueryItem(name: "name", value: Data(appName.utf8).base64EncodedString())]
        if let token = KeychainStore.token(host: host) {
            items.append(URLQueryItem(name: "token", value: token))
        }
        components.queryItems = items
        return components.url
    }

    /// Socket abierto: ahora se espera `ms.channel.connect` (puede requerir aceptar en el TV).
    private func socketOpened(id: Int) {
        guard id == generation, state == .connecting else { return }
        startWatchdog(id: id, seconds: authorizationTimeout, message: Localization.string("The TV did not authorise the connection"))
    }

    /// Bucle de recepción: cada mensaje recibido vuelve a armar la escucha.
    private func listen(on task: URLSessionWebSocketTask, id: Int) {
        task.receive { [weak self] result in
            Task { @MainActor in
                guard let self, id == self.generation else { return }
                switch result {
                case .success(let message):
                    self.handle(message)
                    self.listen(on: task, id: id)
                case .failure(let error):
                    self.connectionLost(id: id, reason: NetworkError.message(for: error))
                }
            }
        }
    }

    private func handle(_ message: URLSessionWebSocketTask.Message) {
        let data: Data
        switch message {
        case .string(let text): data = Data(text.utf8)
        case .data(let raw): data = raw
        @unknown default: return
        }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let event = json["event"] as? String else { return }

        switch event {
        case "ms.channel.connect":
            // El token llega como texto o número según el firmware.
            var tokenSaved = true
            if let info = json["data"] as? [String: Any], let raw = info["token"] {
                let token = (raw as? String) ?? "\(raw)"
                if !token.isEmpty { tokenSaved = KeychainStore.save(token: token, host: host) }
            }
            watchdog?.cancel()
            reconnectAttempt = 0
            // Sin token guardado la conexión funciona, pero el TV la tratará como nueva cada vez.
            lastError = tokenSaved ? nil : Localization.string("Could not save the authorisation to the Keychain")
            addressChecked = false
            state = .connected
            startHeartbeat(id: generation)
            if let deadline = pendingPowerUntil, deadline > Date() { sendKey(.power) }
            pendingPowerUntil = nil

        case "ms.channel.unauthorized":
            // Token rechazado o permiso denegado: se descarta para pedir uno nuevo.
            KeychainStore.delete(host: host)
            wantsConnection = false
            tearDown()
            lastError = Localization.string("The TV refused the connection. Accept the prompt on screen.")
            state = .disconnected

        case "ms.channel.timeOut":
            connectionLost(id: generation, reason: Localization.string("Nobody accepted the prompt on the TV"))

        default:
            break
        }
    }

    // MARK: - Reconexión

    private func connectionLost(id: Int, reason: String?) {
        guard id == generation else { return }
        tearDown()
        state = .disconnected
        lastError = reason
        scheduleReconnect()
    }

    /// Reintenta con espera creciente (2, 4, 8… máx. 15 s) mientras se quiera conexión.
    private func scheduleReconnect() {
        guard wantsConnection else { return }
        reconnectAttempt += 1
        // Tras varios intentos fallidos, lo más probable es que el router le haya
        // cambiado la IP al TV: se busca por su MAC en vez de quedarse esperando.
        if reconnectAttempt == 3, !addressChecked {
            addressChecked = true
            Task { await recoverAddress() }
        }
        let delay = min(pow(2, Double(reconnectAttempt)), 15)
        reconnectWork = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled, let self, self.wantsConnection else { return }
            self.openConnection()
        }
    }

    /// Busca el TV por su MAC y, si aparece en otra dirección, se cambia a ella y lo guarda.
    /// Solo sirve con el TV encendido o en reposo ligero: en reposo profundo no responde.
    private func recoverAddress() async {
        let defaults = UserDefaults.standard
        let mac = defaults.string(forKey: TVConfig.Keys.mac) ?? ""
        guard !mac.isEmpty, wantsConnection else { return }

        guard let tv = await TVDiscovery.find(mac: mac), tv.ip != host, wantsConnection else { return }
        defaults.set(tv.ip, forKey: TVConfig.Keys.ip)
        host = tv.ip
        reconnectAttempt = 0
        lastError = Localization.string("The TV moved to \(tv.ip)")
        openConnection()
    }

    /// Latido: cada 5 s consulta el estado del TV. Detecta el reposo y el socket muerto
    /// (al pasar a reposo profundo el TV no cierra el WebSocket, simplemente desaparece).
    private func startHeartbeat(id: Int) {
        heartbeat?.cancel()
        heartbeat = Task { [weak self] in
            var misses = 0
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(5))
                guard let self, !Task.isCancelled, id == self.generation else { return }
                let power = await Self.fetchPowerState(host: self.host)
                guard !Task.isCancelled, id == self.generation else { return }
                if let power {
                    misses = 0
                    self.isStandby = power == "standby"
                } else {
                    misses += 1
                    if misses >= 2 {
                        self.connectionLost(id: id, reason: Localization.string("The TV is off or not responding"))
                        return
                    }
                }
            }
        }
    }

    /// PowerState que reporta la API REST del TV ("on" / "standby"), o nil si no responde.
    private nonisolated static func fetchPowerState(host: String) async -> String? {
        guard let url = URL(string: "https://\(host):8002/api/v2/") else { return nil }
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 3
        let delegate = SessionDelegate(trustedHost: host, onOpen: {}, onClose: { _ in })
        let session = URLSession(configuration: config, delegate: delegate, delegateQueue: nil)
        defer { session.finishTasksAndInvalidate() }
        guard let (data, _) = try? await session.data(from: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let device = json["device"] as? [String: Any] else { return nil }
        // Firmwares antiguos no traen PowerState: si la API responde, el TV está encendido.
        return device["PowerState"] as? String ?? "on"
    }

    private func startWatchdog(id: Int, seconds: TimeInterval, message: String) {
        watchdog?.cancel()
        watchdog = Task { [weak self] in
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled, let self, self.state == .connecting else { return }
            self.connectionLost(id: id, reason: message)
        }
    }

    /// Libera socket, sesión y temporizadores. Invalida los callbacks pendientes.
    private func tearDown() {
        generation += 1
        watchdog?.cancel()
        heartbeat?.cancel()
        reconnectWork?.cancel()
        isStandby = false
        task?.cancel(with: .goingAway, reason: nil)
        session?.invalidateAndCancel()
        task = nil
        session = nil
    }
}

// MARK: - Errores

/// Traduce los errores de red que llegan del sistema.
///
/// `localizedDescription` se traduce con los idiomas que declara la app, no con el del
/// iPhone, así que aquí salía en inglés en medio de una interfaz en español.
enum NetworkError {
    static func message(for error: Error) -> String {
        guard let error = error as? URLError else { return Localization.string("Could not connect to the TV") }
        switch error.code {
        case .cannotConnectToHost:
            return Localization.string("The TV is refusing the connection. Is it on?")
        case .timedOut:
            return Localization.string("The TV did not answer in time")
        case .networkConnectionLost:
            return Localization.string("Lost the connection to the TV")
        case .cannotFindHost, .dnsLookupFailed:
            return Localization.string("Could not find the TV on the network")
        case .notConnectedToInternet:
            return Localization.string("This iPhone is not on the TV's network")
        case .secureConnectionFailed, .serverCertificateUntrusted, .serverCertificateHasBadDate,
             .serverCertificateNotYetValid, .serverCertificateHasUnknownRoot:
            return Localization.string("The TV refused the encrypted connection")
        case .cancelled:
            return Localization.string("Connection closed")
        default:
            return Localization.string("Could not connect to the TV")
        }
    }
}

// MARK: - Delegate de URLSession

/// Acepta el certificado autofirmado únicamente si el host es el del TV,
/// y avisa de la apertura y el cierre del WebSocket.
private final class SessionDelegate: NSObject, URLSessionWebSocketDelegate {
    private let trustedHost: String
    private let onOpen: () -> Void
    private let onClose: (String?) -> Void

    init(trustedHost: String, onOpen: @escaping () -> Void, onClose: @escaping (String?) -> Void) {
        self.trustedHost = trustedHost
        self.onOpen = onOpen
        self.onClose = onClose
    }

    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        let space = challenge.protectionSpace
        guard space.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              space.host == trustedHost,
              let trust = space.serverTrust else {
            // Cualquier otro host sigue la validación normal del sistema.
            completionHandler(.performDefaultHandling, nil)
            return
        }
        completionHandler(.useCredential, URLCredential(trust: trust))
    }

    func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didOpenWithProtocol protocol: String?
    ) {
        onOpen()
    }

    func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didCloseWith closeCode: URLSessionWebSocketTask.CloseCode,
        reason: Data?
    ) {
        onClose(Localization.string("The TV closed the connection"))
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error { onClose(NetworkError.message(for: error)) }
    }
}
