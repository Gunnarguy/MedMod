import Foundation
import Combine
import CryptoKit

enum SMARTSessionError: LocalizedError {
    case missingConfiguration
    case invalidAuthorizationURL
    case tokenExchangeFailed
    case redirectMissingCode
    case invalidBaseURL
    case invalidResponse
    case requestFailed(statusCode: Int, responseBody: String)
    case capabilityStatementInvalid

    var errorDescription: String? {
        switch self {
        case .missingConfiguration:
            return "SMART configuration has not been loaded yet."
        case .invalidAuthorizationURL:
            return "Unable to construct a valid SMART authorization URL."
        case .tokenExchangeFailed:
            return "SMART token exchange failed."
        case .redirectMissingCode:
            return "The SMART redirect did not contain an authorization code."
        case .invalidBaseURL:
            return "A valid FHIR server base URL is required."
        case .invalidResponse:
            return "The SMART discovery endpoint returned an invalid response."
        case let .requestFailed(statusCode, responseBody):
            return "SMART discovery failed with status \(statusCode): \(responseBody)"
        case .capabilityStatementInvalid:
            return "The FHIR metadata endpoint returned an unsupported CapabilityStatement payload."
        }
    }
}

@MainActor
final class SMARTSession: ObservableObject {
    @Published private(set) var configuration: SMARTConfiguration?
    @Published private(set) var tokenResponse: SMARTTokenResponse?
    @Published private(set) var launchContext = SMARTLaunchContext()
    @Published private(set) var lastAuthorizedAt: Date?

    private let urlSession: URLSession

    init(urlSession: URLSession = .shared) {
        self.urlSession = urlSession
    }

    var isAuthorized: Bool {
        guard let tokenResponse else { return false }
        return !tokenResponse.isExpired
    }

    func smartConfigurationURL(for baseURL: URL) -> URL {
        baseURL
            .appending(path: ".well-known")
            .appending(path: "smart-configuration")
    }

    func capabilityStatementURL(for baseURL: URL) -> URL {
        baseURL.appending(path: "metadata")
    }

    func discoverConfiguration(baseURL: URL) async throws -> SMARTConfiguration {
        let configURL = smartConfigurationURL(for: baseURL)
        let data = try await requestData(from: configURL, accept: "application/json")
        let configuration = try JSONDecoder().decode(SMARTConfiguration.self, from: data)
        self.configuration = configuration
        return configuration
    }

    func fetchCapabilityStatement(baseURL: URL) async throws -> FHIRCapabilityStatementSummary {
        let metadataURL = capabilityStatementURL(for: baseURL)
        let data = try await requestData(from: metadataURL, accept: "application/fhir+json, application/json")

        do {
            return try JSONDecoder().decode(FHIRCapabilityStatementSummary.self, from: data)
        } catch {
            throw SMARTSessionError.capabilityStatementInvalid
        }
    }

    func makeAuthorizationRequest(
        clientID: String,
        redirectURI: URL,
        fhirBaseURL: URL,
        scope: [String]? = nil,
        launch: String? = nil,
        state: String = UUID().uuidString
    ) throws -> SMARTAuthorizationRequest {
        guard let configuration else { throw SMARTSessionError.missingConfiguration }

        let codeVerifier = Self.makeCodeVerifier()
        let codeChallenge = Self.makeCodeChallenge(from: codeVerifier)
        let requestedScope = (scope ?? SMARTScopeSet.providerRead).joined(separator: " ")

        var components = URLComponents(url: configuration.authorizationEndpoint, resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "redirect_uri", value: redirectURI.absoluteString),
            URLQueryItem(name: "scope", value: requestedScope),
            URLQueryItem(name: "aud", value: fhirBaseURL.absoluteString),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "code_challenge", value: codeChallenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
        ]

        if let launch {
            components?.queryItems?.append(URLQueryItem(name: "launch", value: launch))
        }

        guard let url = components?.url else { throw SMARTSessionError.invalidAuthorizationURL }
        return SMARTAuthorizationRequest(
            url: url,
            state: state,
            codeVerifier: codeVerifier,
            codeChallenge: codeChallenge,
            requestedScope: requestedScope
        )
    }

    func exchangeCodeForToken(
        code: String,
        codeVerifier: String,
        clientID: String,
        redirectURI: URL,
        clientSecret: String? = nil
    ) async throws -> SMARTTokenResponse {
        guard let configuration else { throw SMARTSessionError.missingConfiguration }

        var request = URLRequest(url: configuration.tokenEndpoint)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let fields: [String: String] = [
            "grant_type": "authorization_code",
            "code": code,
            "redirect_uri": redirectURI.absoluteString,
            "client_id": clientID,
            "code_verifier": codeVerifier,
        ]

        request.httpBody = Self.formEncodedData(fields.merging(clientSecret.map { ["client_secret": $0] } ?? [:]) { current, _ in current })

        let (data, _) = try await urlSession.data(for: request)
        let token = try JSONDecoder().decode(SMARTTokenResponse.self, from: data)
        applyTokenResponse(token)
        return token
    }

    func handleRedirectURL(_ url: URL) throws -> String {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let code = components.queryItems?.first(where: { $0.name == "code" })?.value else {
            throw SMARTSessionError.redirectMissingCode
        }
        return code
    }

    func applyTokenResponse(_ tokenResponse: SMARTTokenResponse) {
        self.tokenResponse = tokenResponse
        self.lastAuthorizedAt = .now
        self.launchContext = SMARTLaunchContext(
            patientID: tokenResponse.patient,
            encounterID: tokenResponse.encounter,
            practitionerID: launchContext.practitionerID,
            needPatientBanner: launchContext.needPatientBanner
        )
    }

    func updateLaunchContext(_ launchContext: SMARTLaunchContext) {
        self.launchContext = launchContext
    }

    func reset() {
        configuration = nil
        tokenResponse = nil
        launchContext = SMARTLaunchContext()
        lastAuthorizedAt = nil
    }

    private static func makeCodeVerifier() -> String {
        let charset = Array("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~")
        return String((0..<64).compactMap { _ in charset.randomElement() })
    }

    private static func makeCodeChallenge(from verifier: String) -> String {
        let data = Data(verifier.utf8)
        let hash = SHA256.hash(data: data)
        return Data(hash).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private static func formEncodedData(_ fields: [String: String]) -> Data? {
        let body = fields
            .sorted(by: { $0.key < $1.key })
            .map { key, value in
                let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-._~"))
                let encodedKey = key.addingPercentEncoding(withAllowedCharacters: allowed) ?? key
                let encodedValue = value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
                return "\(encodedKey)=\(encodedValue)"
            }
            .joined(separator: "&")

        return body.data(using: .utf8)
    }

    private func requestData(from url: URL, accept: String) async throws -> Data {
        var request = URLRequest(url: url)
        request.setValue(accept, forHTTPHeaderField: "Accept")

        let (data, response) = try await urlSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SMARTSessionError.invalidResponse
        }
        guard 200..<300 ~= httpResponse.statusCode else {
            throw SMARTSessionError.requestFailed(
                statusCode: httpResponse.statusCode,
                responseBody: String(data: data, encoding: .utf8) ?? "<non-UTF8 body>"
            )
        }

        return data
    }
}
