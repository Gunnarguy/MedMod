import Foundation
import Combine
import SwiftData

struct SMARTSandboxPreset: Identifiable, Hashable {
    let name: String
    let baseURL: String
    let notes: String
    let suggestedPatientID: String?

    var id: String { name }

    static let smartR4 = SMARTSandboxPreset(
        name: "SMART R4 Sandbox",
        baseURL: "https://launch.smarthealthit.org/v/r4/fhir",
        notes: "Register a SMART client ID for the MedMod redirect URI before launching authorization.",
        suggestedPatientID: nil
    )

    static let custom = SMARTSandboxPreset(
        name: "Custom Server",
        baseURL: "",
        notes: "Use a SMART-compatible authorization server or paste a sandbox access token for manual import.",
        suggestedPatientID: nil
    )

    static let all: [SMARTSandboxPreset] = [.smartR4, .custom]
}

enum SMARTConnectionControllerError: LocalizedError {
    case missingClientID
    case invalidBaseURL
    case noPendingAuthorization
    case stateMismatch
    case missingPatientContext
    case missingAccessToken

    var errorDescription: String? {
        switch self {
        case .missingClientID:
            return "A SMART client ID is required before starting authorization."
        case .invalidBaseURL:
            return "Enter a valid FHIR base URL before connecting."
        case .noPendingAuthorization:
            return "There is no pending SMART authorization request to complete."
        case .stateMismatch:
            return "The SMART redirect state did not match the pending authorization request."
        case .missingPatientContext:
            return "No patient context is available yet. Enter a patient ID or launch with a patient context."
        case .missingAccessToken:
            return "Authorize with SMART or paste an access token before importing data."
        }
    }
}

@MainActor
final class SMARTConnectionController: ObservableObject {
    @Published var selectedPreset: SMARTSandboxPreset = .smartR4 {
        didSet {
            if oldValue != selectedPreset, !selectedPreset.baseURL.isEmpty {
                baseURLText = selectedPreset.baseURL
            }
        }
    }
    @Published var baseURLText: String = SMARTSandboxPreset.smartR4.baseURL
    @Published var clientID: String = ""
    @Published var clientSecret: String = ""
    @Published var launchToken: String = ""
    @Published var patientIDText: String = ""
    @Published var manualAccessToken: String = ""
    @Published private(set) var pendingAuthorizationRequest: SMARTAuthorizationRequest?
    @Published private(set) var lastImportSummary: FHIRImportSummary?
    @Published private(set) var lastDiscoverySummary: SMARTDiscoverySummary?
    @Published private(set) var lastErrorMessage: String?
    @Published private(set) var statusMessage: String?
    @Published private(set) var isDiscovering = false
    @Published private(set) var isAuthorizing = false
    @Published private(set) var isImporting = false

    let session: SMARTSession

    private let fhirClient: FHIRClient
    private let importService: FHIRImportService
    private var cancellables: Set<AnyCancellable> = []

    init(session: SMARTSession? = nil, fhirClient: FHIRClient? = nil) {
        self.session = session ?? SMARTSession()
        let resolvedFHIRClient = fhirClient ?? FHIRClient()
        self.fhirClient = resolvedFHIRClient
        self.importService = FHIRImportService(client: resolvedFHIRClient)

        self.session.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }

    var redirectURI: URL {
        URL(string: "medmod://smart-callback")!
    }

    var fhirBaseURL: URL? {
        URL(string: baseURLText.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    func discoverConfiguration() async {
        guard let baseURL = fhirBaseURL else {
            setError(SMARTConnectionControllerError.invalidBaseURL.localizedDescription)
            return
        }

        isDiscovering = true
        lastErrorMessage = nil
        statusMessage = "Discovering SMART configuration and FHIR metadata…"
        defer { isDiscovering = false }

        let configurationURL = session.smartConfigurationURL(for: baseURL)
        let metadataURL = session.capabilityStatementURL(for: baseURL)
        var warnings: [String] = []
        var capabilityStatement: FHIRCapabilityStatementSummary?

        do {
            capabilityStatement = try await session.fetchCapabilityStatement(baseURL: baseURL)
        } catch {
            warnings.append("FHIR metadata unavailable: \(error.localizedDescription)")
        }

        do {
            let configuration = try await session.discoverConfiguration(baseURL: baseURL)
            let summary = SMARTDiscoverySummary(
                baseURL: baseURL,
                configurationURL: configurationURL,
                metadataURL: metadataURL,
                discoveredAt: .now,
                configuration: configuration,
                capabilityStatement: capabilityStatement,
                warnings: warnings
            )
            lastDiscoverySummary = summary
            statusMessage = "Discovered SMART endpoints from \(configuration.authorizationEndpoint.host() ?? baseURL.host() ?? "server")."
        } catch {
            warnings.append("SMART well-known discovery failed: \(error.localizedDescription)")
            lastDiscoverySummary = SMARTDiscoverySummary(
                baseURL: baseURL,
                configurationURL: configurationURL,
                metadataURL: metadataURL,
                discoveredAt: .now,
                configuration: nil,
                capabilityStatement: capabilityStatement,
                warnings: warnings
            )
            setError(error.localizedDescription)
        }
    }

    func beginAuthorization() async throws -> URL {
        guard let baseURL = fhirBaseURL else {
            throw SMARTConnectionControllerError.invalidBaseURL
        }
        guard !clientID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw SMARTConnectionControllerError.missingClientID
        }

        lastErrorMessage = nil
        statusMessage = nil
        isAuthorizing = true

        do {
            if session.configuration == nil {
                _ = try await session.discoverConfiguration(baseURL: baseURL)
            }

            let authorizationRequest = try session.makeAuthorizationRequest(
                clientID: clientID.trimmingCharacters(in: .whitespacesAndNewlines),
                redirectURI: redirectURI,
                fhirBaseURL: baseURL,
                scope: SMARTScopeSet.providerRead,
                launch: launchToken.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
            )

            pendingAuthorizationRequest = authorizationRequest
            statusMessage = "Opening SMART authorization flow…"
            return authorizationRequest.url
        } catch {
            isAuthorizing = false
            throw error
        }
    }

    func handleOpenURL(_ url: URL) async {
        guard url.scheme == redirectURI.scheme else { return }

        defer { isAuthorizing = false }

        do {
            guard let pendingAuthorizationRequest else {
                throw SMARTConnectionControllerError.noPendingAuthorization
            }

            let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            if let returnedState = components?.queryItems?.first(where: { $0.name == "state" })?.value,
               returnedState != pendingAuthorizationRequest.state {
                throw SMARTConnectionControllerError.stateMismatch
            }

            if let authorizationError = components?.queryItems?.first(where: { $0.name == "error" })?.value {
                throw NSError(domain: "SMARTAuthorization", code: 1, userInfo: [NSLocalizedDescriptionKey: authorizationError])
            }

            let code = try session.handleRedirectURL(url)
            let token = try await session.exchangeCodeForToken(
                code: code,
                codeVerifier: pendingAuthorizationRequest.codeVerifier,
                clientID: clientID.trimmingCharacters(in: .whitespacesAndNewlines),
                redirectURI: redirectURI,
                clientSecret: clientSecret.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
            )

            fhirClient.setAccessToken(token.accessToken)
            if patientIDText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                patientIDText = token.patient ?? ""
            }
            statusMessage = "SMART authorization completed. Access token ready for FHIR import."
            lastErrorMessage = nil
            self.pendingAuthorizationRequest = nil
        } catch {
            setError(error.localizedDescription)
        }
    }

    func applyManualAccessToken() {
        let trimmedToken = manualAccessToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedToken.isEmpty else {
            setError(SMARTConnectionControllerError.missingAccessToken.localizedDescription)
            return
        }

        fhirClient.setAccessToken(trimmedToken)
        let token = SMARTTokenResponse(
            accessToken: trimmedToken,
            tokenType: "Bearer",
            patient: patientIDText.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        )
        session.applyTokenResponse(token)
        lastErrorMessage = nil
        statusMessage = "Manual access token applied for sandbox import."
    }

    func importLaunchPatient(modelContext: ModelContext) async {
        let patientID = session.launchContext.patientID
            ?? session.tokenResponse?.patient
            ?? patientIDText.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        await importPatient(patientID: patientID, modelContext: modelContext)
    }

    func importTypedPatient(modelContext: ModelContext) async {
        let patientID = patientIDText.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        await importPatient(patientID: patientID, modelContext: modelContext)
    }

    private func importPatient(patientID: String?, modelContext: ModelContext) async {
        guard let baseURL = fhirBaseURL else {
            setError(SMARTConnectionControllerError.invalidBaseURL.localizedDescription)
            return
        }
        guard let patientID else {
            setError(SMARTConnectionControllerError.missingPatientContext.localizedDescription)
            return
        }
        guard session.tokenResponse != nil || !manualAccessToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            setError(SMARTConnectionControllerError.missingAccessToken.localizedDescription)
            return
        }

        isImporting = true
        lastErrorMessage = nil
        defer { isImporting = false }

        do {
            let summary = try await importService.importPatientContext(patientID: patientID, baseURL: baseURL, modelContext: modelContext)
            lastImportSummary = summary
            statusMessage = "Imported sandbox data for \(summary.patientName)."
        } catch {
            setError(error.localizedDescription)
        }
    }

    func setError(_ message: String?) {
        lastErrorMessage = message
        if message != nil {
            statusMessage = nil
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
