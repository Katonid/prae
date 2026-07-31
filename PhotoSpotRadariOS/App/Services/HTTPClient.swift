import Foundation

enum ServiceError: LocalizedError {
    case invalidResponse, rateLimited, server(Int), malformedData
    var errorDescription: String? {
        switch self {
        case .invalidResponse: "Ungültige Serverantwort"
        case .rateLimited: "Datenquelle ist vorübergehend ausgelastet"
        case .server(let code): "Serverfehler (\(code))"
        case .malformedData: "Antwort konnte nicht verarbeitet werden"
        }
    }
}

/// Shared networking actor provides consistent policy and keeps providers testable.
actor HTTPClient {
    private let session: URLSession

    init(session: URLSession = .shared) { self.session = session }

    func data(for request: URLRequest, timeout: TimeInterval = 20) async throws -> Data {
        var request = request
        request.timeoutInterval = timeout
        request.setValue("PhotoSpotRadar/1.0 (iOS; contact@example.com)", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw ServiceError.invalidResponse }
        if http.statusCode == 429 { throw ServiceError.rateLimited }
        guard 200..<300 ~= http.statusCode else { throw ServiceError.server(http.statusCode) }
        return data
    }
}
