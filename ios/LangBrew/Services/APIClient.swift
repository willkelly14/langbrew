import Foundation

// MARK: - API Errors

/// Matches the backend standard error format:
/// `{"error": {"code": "...", "message": "...", "details": {...}}}`
struct APIErrorResponse: Codable, Sendable {
    let error: APIErrorBody
}

struct APIErrorBody: Codable, Sendable {
    let code: String
    let message: String
    let details: [String: AnyCodableValue]?
}

/// A lightweight type-erased Codable value for arbitrary JSON in error details.
enum AnyCodableValue: Codable, Sendable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode(Int.self) {
            self = .int(value)
        } else if let value = try? container.decode(Double.self) {
            self = .double(value)
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if container.decodeNil() {
            self = .null
        } else {
            throw DecodingError.typeMismatch(
                AnyCodableValue.self,
                .init(codingPath: decoder.codingPath, debugDescription: "Unsupported value type")
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value): try container.encode(value)
        case .int(let value): try container.encode(value)
        case .double(let value): try container.encode(value)
        case .bool(let value): try container.encode(value)
        case .null: try container.encodeNil()
        }
    }
}

// MARK: - API Client Errors

enum APIError: Error, Sendable {
    /// Server returned an error in the standard format.
    case server(code: String, message: String)

    /// HTTP status code outside the 2xx range, without a parseable error body.
    case httpError(statusCode: Int, data: Data)

    /// Network-level failure.
    case network(underlying: Error)

    /// Response could not be decoded into the expected type.
    case decodingFailed(underlying: Error)

    /// No access token available -- user needs to authenticate.
    case unauthorized

    /// Free tier usage limit exceeded (HTTP 402).
    case usageLimitExceeded(resource: String, limit: Int, used: Int)
}

extension APIError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .server(_, let message):
            return message
        case .httpError(let statusCode, _):
            return "Request failed with status \(statusCode)."
        case .network(let underlying):
            return "Network error: \(underlying.localizedDescription)"
        case .decodingFailed(let underlying):
            return "Failed to parse response: \(underlying.localizedDescription)"
        case .unauthorized:
            return "Please sign in to continue."
        case .usageLimitExceeded(let resource, _, _):
            return "Monthly \(resource) limit reached. Upgrade to continue."
        }
    }
}

// MARK: - SSE Event

/// A single Server-Sent Event parsed from a streaming response.
struct SSEEvent: Sendable {
    let event: String?
    let data: String
}

// MARK: - HTTP Method

enum HTTPMethod: String, Sendable {
    case get = "GET"
    case post = "POST"
    case patch = "PATCH"
    case delete = "DELETE"
}

// MARK: - API Client

/// Centralized HTTP client for all LangBrew API calls.
/// Injects the JWT from `AuthManager` into every request.
actor APIClient {
    static let shared = APIClient()

    #if DEBUG
    private let baseURL = URL(string: "http://localhost:8000/v1")!
    #else
    private let baseURL = URL(string: "https://api.langbrew.app/v1")!
    #endif

    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 120
        self.session = URLSession(configuration: config)

        self.decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601

        self.encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .iso8601
    }

    // MARK: - Public Interface

    /// Performs a GET request and decodes the response.
    func get<T: Decodable & Sendable>(
        _ path: String,
        query: [String: String]? = nil
    ) async throws -> T {
        try await request(method: .get, path: path, query: query)
    }

    /// Performs a POST request with an encodable body and decodes the response.
    func post<T: Decodable & Sendable, B: Encodable & Sendable>(
        _ path: String,
        body: B
    ) async throws -> T {
        try await request(method: .post, path: path, body: body)
    }

    /// Performs a POST request with no response body expected.
    func post<B: Encodable & Sendable>(
        _ path: String,
        body: B
    ) async throws {
        let _: EmptyResponse = try await request(method: .post, path: path, body: body)
    }

    /// Performs a PATCH request with an encodable body and decodes the response.
    func patch<T: Decodable & Sendable, B: Encodable & Sendable>(
        _ path: String,
        body: B
    ) async throws -> T {
        try await request(method: .patch, path: path, body: body)
    }

    /// Performs a DELETE request.
    func delete(_ path: String) async throws {
        let _: EmptyResponse = try await request(method: .delete, path: path)
    }

    /// Performs a DELETE request with a body.
    func delete<B: Encodable & Sendable>(
        _ path: String,
        body: B
    ) async throws {
        let _: EmptyResponse = try await request(method: .delete, path: path, body: body)
    }

    // MARK: - SSE Streaming

    /// Streams Server-Sent Events from a POST endpoint.
    /// Used for passage generation and other streaming responses.
    func stream(
        _ path: String,
        body: some Encodable & Sendable
    ) -> AsyncThrowingStream<SSEEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let url = baseURL.appendingPathComponent(path)
                    let bodyData = try encoder.encode(body)

                    func buildRequest() async throws -> URLRequest {
                        var req = URLRequest(url: url)
                        req.httpMethod = HTTPMethod.post.rawValue
                        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
                        req.setValue("text/event-stream", forHTTPHeaderField: "Accept")
                        let token = try await AuthManager.shared.validAccessToken()
                        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                        req.httpBody = bodyData
                        return req
                    }

                    var urlRequest: URLRequest
                    do {
                        urlRequest = try await buildRequest()
                    } catch {
                        continuation.finish(throwing: APIError.unauthorized)
                        return
                    }

                    var (bytes, response) = try await session.bytes(for: urlRequest)

                    guard var httpResponse = response as? HTTPURLResponse else {
                        continuation.finish(throwing: APIError.network(underlying: URLError(.badServerResponse)))
                        return
                    }

                    // Retry once on 401 after refreshing token
                    if httpResponse.statusCode == 401 {
                        do {
                            try await AuthManager.shared.refreshToken()
                            urlRequest = try await buildRequest()
                            (bytes, response) = try await session.bytes(for: urlRequest)
                            guard let retryResponse = response as? HTTPURLResponse else {
                                continuation.finish(throwing: APIError.network(underlying: URLError(.badServerResponse)))
                                return
                            }
                            httpResponse = retryResponse
                        } catch {
                            continuation.finish(throwing: APIError.unauthorized)
                            return
                        }
                    }

                    guard (200..<300).contains(httpResponse.statusCode) else {
                        // For non-streaming error responses, collect the body.
                        var errorData = Data()
                        for try await byte in bytes {
                            errorData.append(byte)
                        }
                        if httpResponse.statusCode == 402,
                           let errorResponse = try? decoder.decode(APIErrorResponse.self, from: errorData),
                           let details = errorResponse.error.details {
                            let resource: String
                            let limit: Int
                            let used: Int
                            if case .string(let r) = details["resource"] { resource = r } else { resource = "unknown" }
                            if case .int(let l) = details["limit"] { limit = l } else { limit = 0 }
                            if case .int(let u) = details["used"] { used = u } else { used = 0 }
                            continuation.finish(throwing: APIError.usageLimitExceeded(
                                resource: resource, limit: limit, used: used
                            ))
                        } else if let errorResponse = try? decoder.decode(APIErrorResponse.self, from: errorData) {
                            continuation.finish(throwing: APIError.server(
                                code: errorResponse.error.code,
                                message: errorResponse.error.message
                            ))
                        } else {
                            continuation.finish(throwing: APIError.httpError(
                                statusCode: httpResponse.statusCode, data: errorData
                            ))
                        }
                        return
                    }

                    // Parse SSE format line by line.
                    var currentEvent: String?
                    var currentData: String = ""

                    for try await line in bytes.lines {
                        if line.hasPrefix("event:") {
                            currentEvent = String(line.dropFirst(6)).trimmingCharacters(in: .whitespaces)
                        } else if line.hasPrefix("data:") {
                            let data = String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces)
                            currentData = data
                        } else if line.isEmpty {
                            // Blank line signals end of event.
                            if !currentData.isEmpty {
                                let sseEvent = SSEEvent(event: currentEvent, data: currentData)
                                continuation.yield(sseEvent)
                                currentEvent = nil
                                currentData = ""
                            }
                        }
                    }

                    // Yield any trailing event without a final blank line.
                    if !currentData.isEmpty {
                        let sseEvent = SSEEvent(event: currentEvent, data: currentData)
                        continuation.yield(sseEvent)
                    }

                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    // MARK: - Multipart Upload

    /// Performs a multipart/form-data POST request with a file and optional form fields.
    /// Used for audio transcription uploads and similar binary data endpoints.
    func uploadMultipart<T: Decodable & Sendable>(
        _ path: String,
        fileData: Data,
        fileName: String,
        mimeType: String,
        fields: [String: String] = [:],
        isRetry: Bool = false
    ) async throws -> T {
        let url = baseURL.appendingPathComponent(path)

        let boundary = "Boundary-\(UUID().uuidString)"

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = HTTPMethod.post.rawValue
        urlRequest.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")

        // Inject JWT from AuthManager
        do {
            let token = try await AuthManager.shared.validAccessToken()
            urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        } catch {
            throw APIError.unauthorized
        }

        // Build multipart body
        var body = Data()

        // Add form fields
        for (key, value) in fields {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(value)\r\n".data(using: .utf8)!)
        }

        // Add file part
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(fileData)
        body.append("\r\n".data(using: .utf8)!)

        // Closing boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        urlRequest.httpBody = body

        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await session.data(for: urlRequest)
        } catch {
            throw APIError.network(underlying: error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.network(underlying: URLError(.badServerResponse))
        }

        // On 401, refresh token and retry once
        if httpResponse.statusCode == 401 && !isRetry {
            do {
                try await AuthManager.shared.refreshToken()
                return try await uploadMultipart(
                    path,
                    fileData: fileData,
                    fileName: fileName,
                    mimeType: mimeType,
                    fields: fields,
                    isRetry: true
                )
            } catch {
                throw APIError.unauthorized
            }
        }

        // Check for server errors
        guard (200..<300).contains(httpResponse.statusCode) else {
            if httpResponse.statusCode == 402,
               let errorResponse = try? decoder.decode(APIErrorResponse.self, from: data),
               let details = errorResponse.error.details {
                let resource: String
                let limit: Int
                let used: Int
                if case .string(let r) = details["resource"] { resource = r } else { resource = "unknown" }
                if case .int(let l) = details["limit"] { limit = l } else { limit = 0 }
                if case .int(let u) = details["used"] { used = u } else { used = 0 }
                throw APIError.usageLimitExceeded(resource: resource, limit: limit, used: used)
            }
            if let errorResponse = try? decoder.decode(APIErrorResponse.self, from: data) {
                throw APIError.server(
                    code: errorResponse.error.code,
                    message: errorResponse.error.message
                )
            }
            throw APIError.httpError(statusCode: httpResponse.statusCode, data: data)
        }

        if data.isEmpty || httpResponse.statusCode == 204 {
            if let empty = EmptyResponse() as? T {
                return empty
            }
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decodingFailed(underlying: error)
        }
    }

    // MARK: - Core Request

    private func request<T: Decodable & Sendable>(
        method: HTTPMethod,
        path: String,
        query: [String: String]? = nil,
        body: (any Encodable & Sendable)? = nil,
        isRetry: Bool = false
    ) async throws -> T {
        var urlComponents = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)

        if let query {
            urlComponents?.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
        }

        guard let url = urlComponents?.url else {
            throw APIError.network(underlying: URLError(.badURL))
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = method.rawValue
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")

        // Inject JWT from AuthManager (auto-refreshes if expired)
        do {
            let token = try await AuthManager.shared.validAccessToken()
            urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        } catch {
            throw APIError.unauthorized
        }

        if let body {
            urlRequest.httpBody = try encoder.encode(body)
        }

        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await session.data(for: urlRequest)
        } catch {
            throw APIError.network(underlying: error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.network(underlying: URLError(.badServerResponse))
        }

        // On 401, refresh token and retry once
        if httpResponse.statusCode == 401 && !isRetry {
            do {
                try await AuthManager.shared.refreshToken()
                return try await request(
                    method: method, path: path, query: query,
                    body: body, isRetry: true
                )
            } catch {
                throw APIError.unauthorized
            }
        }

        // Check for server errors
        guard (200..<300).contains(httpResponse.statusCode) else {
            // Check for usage limit exceeded (402)
            if httpResponse.statusCode == 402,
               let errorResponse = try? decoder.decode(APIErrorResponse.self, from: data),
               let details = errorResponse.error.details {
                let resource: String
                let limit: Int
                let used: Int
                if case .string(let r) = details["resource"] { resource = r } else { resource = "unknown" }
                if case .int(let l) = details["limit"] { limit = l } else { limit = 0 }
                if case .int(let u) = details["used"] { used = u } else { used = 0 }
                throw APIError.usageLimitExceeded(resource: resource, limit: limit, used: used)
            }
            // Try to parse the standard error format
            if let errorResponse = try? decoder.decode(APIErrorResponse.self, from: data) {
                throw APIError.server(
                    code: errorResponse.error.code,
                    message: errorResponse.error.message
                )
            }
            throw APIError.httpError(statusCode: httpResponse.statusCode, data: data)
        }

        // Handle empty responses (204 No Content, etc.)
        if data.isEmpty || httpResponse.statusCode == 204 {
            if let empty = EmptyResponse() as? T {
                return empty
            }
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decodingFailed(underlying: error)
        }
    }
}

// MARK: - Empty Response

/// Placeholder for endpoints that return no body.
struct EmptyResponse: Decodable, Sendable {
    init() {}
}
