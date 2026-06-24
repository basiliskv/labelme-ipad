import Foundation
import UIKit

struct LabelmeAPI {
    var baseURL: URL

    init(baseURLString: String) throws {
        let trimmed = baseURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed), url.scheme != nil, url.host != nil else {
            throw URLError(.badURL)
        }
        baseURL = url
    }

    func health() async throws -> ServerHealth {
        try await get(path: "/api/health", queryItems: [])
    }

    func images(offset: Int = 0, limit: Int = 200, query: String = "") async throws -> DatasetImageListResponse {
        try await get(
            path: "/api/images",
            queryItems: [
                URLQueryItem(name: "offset", value: "\(offset)"),
                URLQueryItem(name: "limit", value: "\(limit)"),
                URLQueryItem(name: "q", value: query.isEmpty ? nil : query),
            ]
        )
    }

    func annotation(for item: DatasetImageItem) async throws -> LabelmeAnnotation {
        try await get(path: "/api/annotation/\(item.id)", queryItems: [])
    }

    func save(_ annotation: LabelmeAnnotation, for item: DatasetImageItem) async throws -> LabelmeAnnotation {
        guard let url = makeURL(path: "/api/annotation/\(item.id)", queryItems: []) else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.timeoutInterval = 20
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder.labelme.encode(annotation)
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(data: data, response: response)
        return try JSONDecoder.labelme.decode(LabelmeAnnotation.self, from: data)
    }

    func loadImage(for item: DatasetImageItem) async throws -> UIImage {
        guard let url = URL(string: item.imageUrl) else {
            throw URLError(.badURL)
        }
        let request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 30)
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(data: data, response: response)
        guard let image = UIImage(data: data) else {
            throw URLError(.cannotDecodeContentData)
        }
        return image
    }

    private func get<T: Decodable>(path: String, queryItems: [URLQueryItem]) async throws -> T {
        guard let url = makeURL(path: path, queryItems: queryItems) else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 12
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(data: data, response: response)
        return try JSONDecoder.labelme.decode(T.self, from: data)
    }

    private func makeURL(path: String, queryItems: [URLQueryItem]) -> URL? {
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
        components?.path = path
        components?.queryItems = queryItems.filter { $0.value != nil }
        return components?.url
    }

    private func validate(data: Data, response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else { return }
        guard (200...299).contains(http.statusCode) else {
            if let payload = try? JSONDecoder().decode(ServerErrorPayload.self, from: data) {
                throw LabelmeAPIError.server(payload.error)
            }
            throw LabelmeAPIError.server("HTTP \(http.statusCode)")
        }
    }
}

private struct ServerErrorPayload: Decodable {
    let error: String
}

enum LabelmeAPIError: LocalizedError {
    case server(String)

    var errorDescription: String? {
        switch self {
        case .server(let message):
            message
        }
    }
}

extension JSONDecoder {
    static var labelme: JSONDecoder {
        JSONDecoder()
    }
}

extension JSONEncoder {
    static var labelme: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}
