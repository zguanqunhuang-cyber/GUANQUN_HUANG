import Foundation

enum FriendRequestRole {
    case incoming
    case outgoing
}

enum FriendServiceError: LocalizedError {
    case invalidURL
    case server(String)
    case decoding(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Backend 地址无效"
        case .server(let message):
            return message
        case .decoding(let message):
            return "解析失败: \(message)"
        }
    }
}

struct FriendService {
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    private let baseURL: URL

    init(session: URLSession = .shared) {
        self.session = session
        guard let url = URL(string: AppConfig.backendBaseURL) else {
            fatalError("BACKEND_BASE_URL 配置无效")
        }
        baseURL = url
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        encoder = JSONEncoder()
    }

    func fetchFriends(for userID: UUID) async throws -> [UserProfile] {
        var components = URLComponents(url: baseURL.appendingPathComponent("/social/friends/list"), resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "user_id", value: userID.uuidString)]
        guard let url = components?.url else { throw FriendServiceError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        let data = try await perform(request)
        let response = try decode(FriendsResponse.self, from: data)
        return response.friends.map { $0.toDomain() }
    }

    func sendFriendRequest(byPhone phone: String, requesterID: UUID) async throws {
        let url = baseURL.appendingPathComponent("/social/friends/request")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        let payload = FriendRequestPayload(phone: phone, requester_id: requesterID)
        request.httpBody = try encoder.encode(payload)

        _ = try await perform(request)
    }

    func fetchFriendRequests(for userID: UUID, role: FriendRequestRole) async throws -> [FriendRequest] {
        var components = URLComponents(url: baseURL.appendingPathComponent("/social/friends/requests"), resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "user_id", value: userID.uuidString),
            URLQueryItem(name: "role", value: role == .incoming ? "incoming" : "outgoing"),
        ]
        guard let url = components?.url else { throw FriendServiceError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        let data = try await perform(request)
        let response = try decode(FriendRequestsResponse.self, from: data)
        return response.requests.map { $0.toDomain() }
    }

    func respondToFriendRequest(_ requestID: UUID, accept: Bool, responderID: UUID) async throws {
        let url = baseURL.appendingPathComponent("/social/friends/respond")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        let payload = FriendRespondPayload(request_id: requestID, accept: accept, responder_id: responderID)
        request.httpBody = try encoder.encode(payload)

        _ = try await perform(request)
    }

    private func perform(_ request: URLRequest) async throws -> Data {
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw FriendServiceError.server("无效的服务器响应")
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            if let apiError = try? decoder.decode(APIErrorResponse.self, from: data) {
                throw FriendServiceError.server(apiError.detail)
            }
            throw FriendServiceError.server("服务器错误：\(httpResponse.statusCode)")
        }
        return data
    }

    private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw FriendServiceError.decoding(error.localizedDescription)
        }
    }
}

private struct FriendRequestPayload: Encodable {
    let phone: String
    let requester_id: UUID
}

private struct FriendRespondPayload: Encodable {
    let request_id: UUID
    let accept: Bool
    let responder_id: UUID
}

private struct FriendsResponse: Decodable {
    let friends: [ProfileRecord]
}

private struct FriendRequestsResponse: Decodable {
    let requests: [FriendRequestRecord]
}

private struct APIErrorResponse: Decodable {
    let detail: String
}
