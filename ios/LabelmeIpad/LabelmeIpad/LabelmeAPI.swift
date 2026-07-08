import Foundation
import UIKit

struct LabelmeAPI {
    var baseURL: URL
    var cloudflareAccess: CloudflareAccessCredentials

    init(baseURLString: String, cloudflareAccess: CloudflareAccessCredentials = .empty) throws {
        let trimmed = baseURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed), url.scheme != nil, url.host != nil else {
            throw URLError(.badURL)
        }
        baseURL = url
        self.cloudflareAccess = cloudflareAccess
    }

    func health() async throws -> ServerHealth {
        try await get(path: "/api/health", queryItems: [])
    }

    func images(offset: Int = 0, limit: Int = 1000, query: String = "") async throws -> DatasetImageListResponse {
        try await get(
            path: "/api/images",
            queryItems: [
                URLQueryItem(name: "offset", value: "\(offset)"),
                URLQueryItem(name: "limit", value: "\(limit)"),
                URLQueryItem(name: "q", value: query.isEmpty ? nil : query),
            ]
        )
    }

    func allImages(query: String = "") async throws -> DatasetImageListResponse {
        let pageLimit = 1000
        var offset = 0
        var allItems: [DatasetImageItem] = []
        var firstPage: DatasetImageListResponse?
        var total = 0

        repeat {
            let page = try await images(offset: offset, limit: pageLimit, query: query)
            if firstPage == nil {
                firstPage = page
            }
            total = page.total
            allItems.append(contentsOf: page.items)
            if page.items.isEmpty {
                break
            }
            offset += page.items.count
        } while allItems.count < total

        guard let firstPage else {
            return DatasetImageListResponse(
                datasetRoot: "",
                imagesRoot: "",
                labelsRoot: "",
                offset: 0,
                limit: pageLimit,
                total: 0,
                items: []
            )
        }

        return DatasetImageListResponse(
            datasetRoot: firstPage.datasetRoot,
            imagesRoot: firstPage.imagesRoot,
            labelsRoot: firstPage.labelsRoot,
            offset: 0,
            limit: allItems.count,
            total: total,
            items: allItems
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
        applyAccessHeaders(to: &request)
        request.httpBody = try JSONEncoder.labelme.encode(annotation)
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(data: data, response: response)
        return try JSONDecoder.labelme.decode(LabelmeAnnotation.self, from: data)
    }

    func uploadImages(from urls: [URL]) async throws -> DatasetImageUploadResponse {
        guard let url = makeURL(path: "/api/images", queryItems: []) else {
            throw URLError(.badURL)
        }
        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 120
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        applyAccessHeaders(to: &request)
        request.httpBody = try multipartBody(for: urls, boundary: boundary)
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(data: data, response: response)
        return try JSONDecoder.labelme.decode(DatasetImageUploadResponse.self, from: data)
    }

    func loadImage(for item: DatasetImageItem) async throws -> UIImage {
        guard let url = serverURL(from: item.imageUrl) else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 30)
        applyAccessHeaders(to: &request)
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
        applyAccessHeaders(to: &request)
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(data: data, response: response)
        return try JSONDecoder.labelme.decode(T.self, from: data)
    }

    private func applyAccessHeaders(to request: inout URLRequest) {
        guard cloudflareAccess.isConfigured else { return }
        request.setValue(cloudflareAccess.clientId, forHTTPHeaderField: "CF-Access-Client-Id")
        request.setValue(cloudflareAccess.clientSecret, forHTTPHeaderField: "CF-Access-Client-Secret")
    }

    private func multipartBody(for urls: [URL], boundary: String) throws -> Data {
        var body = Data()
        for url in urls {
            let filename = url.lastPathComponent.isEmpty ? "image.jpg" : url.lastPathComponent
            body.appendString("--\(boundary)\r\n")
            body.appendString("Content-Disposition: form-data; name=\"files\"; filename=\"\(filename.escapedMultipartValue)\"\r\n")
            body.appendString("Content-Type: \(mimeType(for: url))\r\n\r\n")
            body.append(try Data(contentsOf: url))
            body.appendString("\r\n")
        }
        body.appendString("--\(boundary)--\r\n")
        return body
    }

    private func mimeType(for url: URL) -> String {
        switch url.pathExtension.lowercased() {
        case "jpg", "jpeg":
            return "image/jpeg"
        case "png":
            return "image/png"
        case "gif":
            return "image/gif"
        case "webp":
            return "image/webp"
        case "bmp":
            return "image/bmp"
        case "tif", "tiff":
            return "image/tiff"
        default:
            return "application/octet-stream"
        }
    }

    private func makeURL(path: String, queryItems: [URLQueryItem]) -> URL? {
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
        components?.path = path
        components?.queryItems = queryItems.filter { $0.value != nil }
        return components?.url
    }

    private func serverURL(from rawValue: String) -> URL? {
        guard var components = URLComponents(string: rawValue) else { return nil }
        if cloudflareAccess.isConfigured, let baseHost = baseURL.host {
            components.scheme = baseURL.scheme
            components.host = baseHost
            components.port = baseURL.port
        }
        return components.url
    }

    private func validate(data: Data, response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else { return }
        guard (200...299).contains(http.statusCode) else {
            if let payload = try? JSONDecoder().decode(ServerErrorPayload.self, from: data) {
                throw LabelmeAPIError.server(payload.error)
            }
            if http.statusCode == 401 || http.statusCode == 403 {
                throw LabelmeAPIError.server("HTTP \(http.statusCode). Check server authentication or Cloudflare Access credentials.")
            }
            throw LabelmeAPIError.server("HTTP \(http.statusCode)")
        }
    }
}

struct CloudflareAccessCredentials: Equatable {
    var clientId: String
    var clientSecret: String

    var isConfigured: Bool {
        !clientId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !clientSecret.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    static let empty = CloudflareAccessCredentials(clientId: "", clientSecret: "")
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

private extension Data {
    mutating func appendString(_ value: String) {
        append(Data(value.utf8))
    }
}

private extension String {
    var escapedMultipartValue: String {
        replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }
}
