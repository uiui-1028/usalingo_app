import Foundation

enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
}

final class SupabaseClient {
    static let shared = SupabaseClient()

    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    func request<T: Decodable>(
        path: String,
        method: HTTPMethod = .get,
        queryItems: [URLQueryItem] = [],
        accessToken: String? = nil,
        body: Encodable? = nil,
        prefer: String? = nil
    ) async throws -> T {
        var components = URLComponents(url: SupabaseConfig.restURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        components.queryItems = queryItems.isEmpty ? nil : queryItems

        var request = URLRequest(url: components.url!)
        request.httpMethod = method.rawValue
        request.setValue(SupabaseConfig.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let accessToken {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }
        if let prefer {
            request.setValue(prefer, forHTTPHeaderField: "Prefer")
        }
        if let body {
            request.httpBody = try JSONEncoder().encode(AnyEncodable(body))
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw SupabaseError.badResponse(String(data: data, encoding: .utf8) ?? "Unknown error")
        }
        return try decoder.decode(T.self, from: data)
    }

    func execute(
        path: String,
        method: HTTPMethod = .post,
        queryItems: [URLQueryItem] = [],
        accessToken: String? = nil,
        body: Encodable? = EmptyPayload(),
        prefer: String? = nil
    ) async throws {
        var components = URLComponents(url: SupabaseConfig.restURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        components.queryItems = queryItems.isEmpty ? nil : queryItems

        var request = URLRequest(url: components.url!)
        request.httpMethod = method.rawValue
        request.setValue(SupabaseConfig.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let accessToken {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }
        if let prefer {
            request.setValue(prefer, forHTTPHeaderField: "Prefer")
        }
        if let body {
            request.httpBody = try JSONEncoder().encode(AnyEncodable(body))
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw SupabaseError.badResponse(String(data: data, encoding: .utf8) ?? "Unknown error")
        }
    }
}

struct EmptyPayload: Encodable {}

struct AnyEncodable: Encodable {
    private let encodeBlock: (Encoder) throws -> Void

    init(_ wrapped: Encodable) {
        encodeBlock = wrapped.encode
    }

    func encode(to encoder: Encoder) throws {
        try encodeBlock(encoder)
    }
}

enum SupabaseError: LocalizedError {
    case badResponse(String)

    var errorDescription: String? {
        switch self {
        case .badResponse(let message):
            return message
        }
    }
}
