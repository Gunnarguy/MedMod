import SwiftUI
import SwiftData

struct InteroperabilityWorkspaceView: View {
    @EnvironmentObject private var smartController: SMARTConnectionController
    @Environment(\.openURL) private var openURL
    @Environment(\.modelContext) private var modelContext

    private let discoveryColumns = [GridItem(.adaptive(minimum: 96), spacing: 8)]

    private var hasClientID: Bool {
        !smartController.clientID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var hasManualToken: Bool {
        !smartController.manualAccessToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var hasBaseURL: Bool {
        smartController.fhirBaseURL != nil
    }

    var body: some View {
        Form {
            Section("SMART Sandbox") {
                Picker("Preset", selection: $smartController.selectedPreset) {
                    ForEach(SMARTSandboxPreset.all) { preset in
                        Text(preset.name).tag(preset)
                    }
                }
                #if os(iOS)
                .pickerStyle(.navigationLink)
                #endif

                settingsField("FHIR Base URL") {
                    TextField("https://example.com/fhir", text: $smartController.baseURLText)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                }

                settingsField("SMART Client ID") {
                    TextField("Enter SMART client ID", text: $smartController.clientID)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }

                settingsField("Client Secret") {
                    SecureField("Optional", text: $smartController.clientSecret)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }

                settingsField("Launch Token") {
                    TextField("Optional", text: $smartController.launchToken)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }

                identifierRow("Redirect URI", value: smartController.redirectURI.absoluteString, monospaced: true)

                Text(smartController.selectedPreset.notes)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .clinicalFinePrint()

                Button {
                    Task { await smartController.discoverConfiguration() }
                } label: {
                    HStack(spacing: 8) {
                        if smartController.isDiscovering {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "network")
                        }
                        Text(smartController.isDiscovering ? "Discovering…" : "Discover SMART Configuration")
                    }
                }
                .disabled(smartController.isDiscovering || !hasBaseURL)

                Button("Connect via SMART") {
                    Task {
                        do {
                            let url = try await smartController.beginAuthorization()
                            openURL(url)
                        } catch {
                            smartController.setError(error.localizedDescription)
                        }
                    }
                }
                .disabled(smartController.isAuthorizing || !hasClientID)
            }

            Section("Discovery") {
                if smartController.isDiscovering {
                    HStack(alignment: .top, spacing: 10) {
                        ProgressView()
                            .controlSize(.small)
                            .padding(.top, 2)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Inspecting SMART and FHIR endpoints")
                                .font(.subheadline.weight(.semibold))
                            Text("Fetching SMART well-known configuration and base FHIR metadata from the server.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .clinicalFinePrint()
                        }
                    }
                } else if let summary = smartController.lastDiscoverySummary {
                    LazyVGrid(columns: discoveryColumns, alignment: .leading, spacing: 8) {
                        supportChip(
                            title: "SMART",
                            value: summary.hasSMARTConfiguration ? "Found" : "Missing",
                            color: summary.hasSMARTConfiguration ? .green : .orange
                        )
                        supportChip(
                            title: "FHIR Metadata",
                            value: summary.hasFHIRMetadata ? "Found" : "Missing",
                            color: summary.hasFHIRMetadata ? .blue : .secondary
                        )
                        supportChip(
                            title: "PKCE S256",
                            value: summary.supportsPKCES256 ? "Ready" : "Unknown",
                            color: summary.supportsPKCES256 ? .green : .secondary
                        )
                        supportChip(
                            title: "Registration",
                            value: summary.supportsDynamicRegistration ? "Yes" : "No",
                            color: summary.supportsDynamicRegistration ? .purple : .secondary
                        )
                    }
                    .padding(.vertical, 2)

                    identifierRow("SMART Config URL", value: summary.configurationURL.absoluteString)
                    identifierRow("FHIR Metadata URL", value: summary.metadataURL.absoluteString)

                    if let configuration = summary.configuration {
                        identifierRow("Authorize Endpoint", value: configuration.authorizationEndpoint.absoluteString)
                        identifierRow("Token Endpoint", value: configuration.tokenEndpoint.absoluteString)
                        if let registrationEndpoint = configuration.registrationEndpoint {
                            identifierRow("Registration Endpoint", value: registrationEndpoint.absoluteString)
                        }

                        LabeledContent("Scopes Advertised") {
                            Text("\(summary.scopeCount)")
                        }
                        LabeledContent("Response Types") {
                            Text("\(summary.responseTypeCount)")
                        }

                        if !summary.capabilities.isEmpty {
                            chipGrid(title: "SMART Capabilities", items: summary.capabilities, color: .purple)
                        }

                        if !summary.pkceMethods.isEmpty {
                            chipGrid(title: "PKCE Methods", items: summary.pkceMethods, color: .green)
                        }
                    }

                    if let metadata = summary.capabilityStatement {
                        if let fhirVersion = metadata.fhirVersion, !fhirVersion.isEmpty {
                            LabeledContent("FHIR Version") {
                                Text(fhirVersion)
                            }
                        }
                        if let software = metadata.softwareLabel, !software.isEmpty {
                            LabeledContent("Software") {
                                Text(software)
                                    .multilineTextAlignment(.trailing)
                                    .clinicalFinePrint()
                            }
                        }
                        if let implementation = metadata.implementationLabel, !implementation.isEmpty {
                            identifierRow("Implementation", value: implementation)
                        }
                        if let publisher = metadata.publisher, !publisher.isEmpty {
                            LabeledContent("Publisher") {
                                Text(publisher)
                                    .multilineTextAlignment(.trailing)
                                    .clinicalFinePrint()
                            }
                        }
                        if !metadata.securityServiceLabels.isEmpty {
                            chipGrid(title: "Security Services", items: metadata.securityServiceLabels, color: .blue)
                        }
                    }

                    LabeledContent("Discovered") {
                        Text(summary.discoveredAt.formatted(date: .abbreviated, time: .shortened))
                            .clinicalFinePrint()
                    }

                    if !summary.warnings.isEmpty {
                        ForEach(summary.warnings, id: \.self) { warning in
                            messageRow(warning, color: .orange, icon: "exclamationmark.triangle.fill")
                        }
                    }
                } else {
                    Text("Run discovery to inspect SMART endpoints, PKCE support, advertised capabilities, and the base FHIR server metadata before connecting.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .clinicalFinePrint()
                }
            }

            Section("Manual Token") {
                settingsField("Sandbox Access Token") {
                    TextField("Paste token", text: $smartController.manualAccessToken, axis: .vertical)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .lineLimit(2...4)
                }

                Button("Apply Manual Token") {
                    smartController.applyManualAccessToken()
                }
                .disabled(!hasManualToken)
            }

            Section("Connection State") {
                LabeledContent("Authorized") {
                    Text(smartController.session.isAuthorized ? "Yes" : "No")
                        .foregroundStyle(smartController.session.isAuthorized ? .green : .secondary)
                }
                if let configuration = smartController.session.configuration {
                    identifierRow("Auth Endpoint", value: configuration.authorizationEndpoint.host() ?? configuration.authorizationEndpoint.absoluteString)
                }
                if let token = smartController.session.tokenResponse {
                    LabeledContent("Token Type") {
                        Text(token.tokenType)
                    }
                    if let patient = token.patient {
                        identifierRow("Launch Patient", value: patient, monospaced: true)
                    }
                }
                if let statusMessage = smartController.statusMessage {
                    messageRow(statusMessage, color: .secondary, icon: "info.circle")
                }
                if let errorMessage = smartController.lastErrorMessage {
                    messageRow(errorMessage, color: .red, icon: "exclamationmark.triangle.fill")
                }
            }

            Section("Patient Import") {
                settingsField("FHIR Patient ID") {
                    TextField("Optional patient override", text: $smartController.patientIDText)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }

                Button("Import Launch Patient") {
                    Task { await smartController.importLaunchPatient(modelContext: modelContext) }
                }
                .disabled(smartController.isImporting)

                Button("Import Entered Patient") {
                    Task { await smartController.importTypedPatient(modelContext: modelContext) }
                }
                .disabled(smartController.isImporting)
            }

            if let summary = smartController.lastImportSummary {
                Section("Last Import") {
                    LabeledContent("Patient") {
                        Text(summary.patientName)
                    }
                    identifierRow("FHIR ID", value: summary.patientID, monospaced: true)
                    LabeledContent("Patient Record") {
                        Text(summary.createdNewPatient ? "Created" : "Updated")
                    }
                    LabeledContent("Conditions") {
                        Text("\(summary.conditionCount)")
                    }
                    LabeledContent("Medications") {
                        Text("\(summary.medicationCount)")
                    }
                    LabeledContent("Appointments") {
                        Text("\(summary.appointmentCount)")
                    }
                    if !summary.warnings.isEmpty {
                        ForEach(summary.warnings, id: \.self) { warning in
                            Text(warning)
                                .font(.caption)
                                .foregroundStyle(.orange)
                                .clinicalFinePrint()
                        }
                    }
                }
            }
        }
        .navigationTitle("EHR Connectivity")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private func settingsField<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .foregroundStyle(.secondary)
                .clinicalFinePrint(weight: .semibold)
            content()
        }
    }

    private func identifierRow(_ title: String, value: String, monospaced: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .foregroundStyle(.secondary)
                .clinicalFinePrint(weight: .semibold)
            if monospaced {
                Text(value)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .clinicalFinePrintMonospaced()
            } else {
                Text(value)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .clinicalFinePrint()
            }
        }
    }

    private func messageRow(_ message: String, color: Color, icon: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)
                .padding(.top, 1)
            Text(message)
                .font(.caption)
                .foregroundStyle(color)
                .clinicalFinePrint()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 2)
    }

    private func chipGrid(title: String, items: [String], color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .foregroundStyle(.secondary)
                .clinicalFinePrint(weight: .semibold)
            LazyVGrid(columns: discoveryColumns, alignment: .leading, spacing: 8) {
                ForEach(items, id: \.self) { item in
                    Text(item)
                        .clinicalPillText(weight: .medium)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(color.opacity(0.12), in: Capsule())
                        .foregroundStyle(color)
                }
            }
        }
    }

    private func supportChip(title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .clinicalFinePrint(weight: .semibold)
                .foregroundStyle(.secondary)
            Text(value)
                .clinicalPillText(weight: .bold)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(color.opacity(0.12), in: Capsule())
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 2)
    }
}
