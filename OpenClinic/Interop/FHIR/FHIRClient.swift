import Foundation

enum FHIRClientError: LocalizedError {
    case missingAccessToken
    case invalidResponse
    case serverError(statusCode: Int, responseBody: String)

    var errorDescription: String? {
        switch self {
        case .missingAccessToken:
            return "A valid SMART access token is required before requesting FHIR resources."
        case .invalidResponse:
            return "The FHIR server returned an invalid response."
        case let .serverError(statusCode, responseBody):
            return "FHIR request failed with status \(statusCode): \(responseBody)"
        }
    }
}

final class FHIRClient {
    private let urlSession: URLSession
    private var accessToken: String?

    init(accessToken: String? = nil, urlSession: URLSession = .shared) {
        self.accessToken = accessToken
        self.urlSession = urlSession
    }

    func setAccessToken(_ accessToken: String?) {
        self.accessToken = accessToken
    }

    func fetchResource(resourceType: String, id: String, baseURL: URL) async throws -> Data {
        let resourceURL = baseURL.appending(path: resourceType).appending(path: id)
        return try await performRequest(url: resourceURL)
    }

    func search(resourceType: String, queryItems: [URLQueryItem] = [], baseURL: URL) async throws -> Data {
        var components = URLComponents(url: baseURL.appending(path: resourceType), resolvingAgainstBaseURL: false)
        components?.queryItems = queryItems.isEmpty ? nil : queryItems
        let resourceURL = components?.url ?? baseURL.appending(path: resourceType)
        return try await performRequest(url: resourceURL)
    }

    func fetchBundle(at url: URL) async throws -> Data {
        try await performRequest(url: url)
    }

    private func performRequest(url: URL) async throws -> Data {
        guard let accessToken else { throw FHIRClientError.missingAccessToken }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/fhir+json", forHTTPHeaderField: "Accept")

        let (data, response) = try await urlSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw FHIRClientError.invalidResponse
        }
        guard 200..<300 ~= httpResponse.statusCode else {
            throw FHIRClientError.serverError(
                statusCode: httpResponse.statusCode,
                responseBody: String(data: data, encoding: .utf8) ?? "<non-UTF8 body>"
            )
        }
        return data
    }
}
