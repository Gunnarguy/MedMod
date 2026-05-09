import Foundation
import Combine
import CryptoKit
import os

enum SMARTSessionError: LocalizedError {
    case missingConfiguration
    case invalidAuthorizationURL
    case redirectMissingCode
    case invalidBaseURL
    case invalidResponse
    case requestFailed(statusCode: Int, responseBody: String)
    case capabilityStatementInvalid
    case tokenExchangeRejected(statusCode: Int, error: String, errorDescription: String?)
    case tokenResponseInvalid(responseBody: String)

    var errorDescription: String? {
        switch self {
        case .missingConfiguration:
            return "SMART configuration has not been loaded yet."
        case .invalidAuthorizationURL:
            return "Unable to construct a valid SMART authorization URL."
        case .redirectMissingCode:
            return "The SMART redirect did not contain an authorization code."
        case .invalidBaseURL:
            return "A valid FHIR server base URL is required."
        case .invalidResponse:
            return "The SMART discovery endpoint returned an invalid response."
        case let .requestFailed(statusCode, responseBody):
            return "SMART request failed with status \(statusCode): \(responseBody)"
        case .capabilityStatementInvalid:
            return "The FHIR metadata endpoint returned an unsupported CapabilityStatement payload."
        case let .tokenExchangeRejected(statusCode, error, errorDescription):
            if let errorDescription, !errorDescription.isEmpty {
                return "SMART token exchange was rejected with status \(statusCode) (\(error)): \(errorDescription)"
            }
            return "SMART token exchange was rejected with status \(statusCode) (\(error))."
        case let .tokenResponseInvalid(responseBody):
            return "SMART token exchange returned an unreadable response: \(responseBody)"
        }
    }
}

private struct SMARTTokenErrorResponse: Decodable, Sendable {
    let error: String
    let errorDescription: String?

    enum CodingKeys: String, CodingKey {
        case error
        case errorDescription = "error_description"
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
        AppLogger.smart.info("Discovering SMART configuration from \(configURL.absoluteString)")
        let data = try await requestData(from: configURL, accept: "application/json")
        let configuration = try JSONDecoder().decode(SMARTConfiguration.self, from: data)
        self.configuration = configuration
        AppLogger.smart.info("Loaded SMART configuration with authorization host \(configuration.authorizationEndpoint.host() ?? "unknown")")
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
        AppLogger.smart.info("Prepared SMART authorization request for \(configuration.authorizationEndpoint.host() ?? "unknown"); launch token attached: \(launch != nil)")
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

        AppLogger.smart.info("Exchanging SMART authorization code against \(configuration.tokenEndpoint.absoluteString)")
        let (data, response) = try await urlSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SMARTSessionError.invalidResponse
        }
        guard 200..<300 ~= httpResponse.statusCode else {
            if let oauthError = try? JSONDecoder().decode(SMARTTokenErrorResponse.self, from: data) {
                AppLogger.smart.error("SMART token exchange rejected [\(httpResponse.statusCode)] \(oauthError.error): \(oauthError.errorDescription ?? "<no description>")")
                throw SMARTSessionError.tokenExchangeRejected(
                    statusCode: httpResponse.statusCode,
                    error: oauthError.error,
                    errorDescription: oauthError.errorDescription
                )
            }

            let responseBody = String(data: data, encoding: .utf8) ?? "<non-UTF8 body>"
            AppLogger.smart.error("SMART token exchange failed [\(httpResponse.statusCode)] \(responseBody)")
            throw SMARTSessionError.requestFailed(statusCode: httpResponse.statusCode, responseBody: responseBody)
        }

        let token: SMARTTokenResponse
        do {
            token = try JSONDecoder().decode(SMARTTokenResponse.self, from: data)
        } catch {
            let responseBody = String(data: data, encoding: .utf8) ?? "<non-UTF8 body>"
            AppLogger.smart.error("SMART token response could not be decoded: \(responseBody)")
            throw SMARTSessionError.tokenResponseInvalid(responseBody: responseBody)
        }

        applyTokenResponse(token)
        AppLogger.smart.info("SMART token exchange completed successfully")
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
        AppLogger.smart.info("SMART session authorized. Launch patient present: \(tokenResponse.patient != nil)")
    }

    func updateLaunchContext(_ launchContext: SMARTLaunchContext) {
        self.launchContext = launchContext
    }

    func reset() {
        configuration = nil
        tokenResponse = nil
        launchContext = SMARTLaunchContext()
        lastAuthorizedAt = nil
        AppLogger.smart.info("SMART session reset")
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
