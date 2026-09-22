import Foundation

/// Estado de silencio del televisor, por UPnP (servicio RenderingControl, puerto 9197).
///
/// Solo el silencio: el nivel de volumen que informa ese mismo servicio es falso
/// (responde siempre el mismo número aunque el volumen cambie de verdad), pero el
/// silencio sí refleja la realidad. Comprobado contra el televisor.
enum TVMute {
    /// true si está silenciado, o nil si el TV no responde.
    static func isMuted(host: String) async -> Bool? {
        guard let url = URL(string: "http://\(host):9197/upnp/control/RenderingControl1") else { return nil }
        let service = "urn:schemas-upnp-org:service:RenderingControl:1"
        let envelope = """
        <?xml version="1.0"?>\
        <s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" \
        s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">\
        <s:Body><u:GetMute xmlns:u="\(service)">\
        <InstanceID>0</InstanceID><Channel>Master</Channel>\
        </u:GetMute></s:Body></s:Envelope>
        """

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 2
        request.setValue("text/xml; charset=\"utf-8\"", forHTTPHeaderField: "Content-Type")
        request.setValue("\"\(service)#GetMute\"", forHTTPHeaderField: "SOAPACTION")
        request.httpBody = Data(envelope.utf8)

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let xml = String(data: data, encoding: .utf8),
              let start = xml.range(of: "<CurrentMute>"),
              let end = xml.range(of: "</CurrentMute>", range: start.upperBound..<xml.endIndex) else { return nil }
        return xml[start.upperBound..<end.lowerBound].trimmingCharacters(in: .whitespacesAndNewlines) == "1"
    }
}
