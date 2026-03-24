import SwiftUI
import SwiftData
import os

struct ClinicIntelligenceView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PatientProfile.lastName) private var patients: [PatientProfile]
    @StateObject private var intelligenceService = ClinicalIntelligenceService()
    @ObservedObject private var ragService = ClinicalRAGService.shared

    @State private var queryText = ""
    @State private var chatHistory: [(isUser: Bool, text: String, metadata: ResponseMetadata?)] = []
    @State private var isProcessing = false
    @State private var selectedPatient: PatientProfile?
    @State private var deepThinkEnabled = false

    private var initialPatient: PatientProfile?

    init(patient: PatientProfile? = nil) {
        self.initialPatient = patient
    }

    private var contextLabel: String {
        selectedPatient?.fullName ?? "All Patients"
    }

    private var quickPrompts: [String] {
        if let p = selectedPatient {
            return [
                "Summarize \(p.firstName)'s chart",
                "What medications is \(p.firstName) on?",
                "Any upcoming appointments?",
                "Allergy and risk flag review",
                "History of skin cancer?",
            ]
        }
        return [
            "Who's on today's schedule?",
            "Which patients have melanoma history?",
            "Who is on biologics or immunosuppressants?",
            "Smokers with high UV exposure risk?",
            "Patients with follow-ups this week",
            "Panel-wide allergy overview",
        ]
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Context bar: engine status + RAG + patient picker
                HStack(spacing: 10) {
                    Image(systemName: "cpu")
                        .foregroundStyle(.secondary)
                    Text(intelligenceService.engineStatusLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()

                    // Deep Think toggle
                    Button {
                        deepThinkEnabled.toggle()
                        intelligenceService.deepThinkEnabled = deepThinkEnabled
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: deepThinkEnabled ? "brain.head.profile.fill" : "brain.head.profile")
                            Text("Deep")
                                .font(.caption2)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(deepThinkEnabled ? Color.orange.opacity(0.2) : Color(.tertiarySystemBackground), in: Capsule())
                        .foregroundStyle(deepThinkEnabled ? .orange : .secondary)
                    }
                    .buttonStyle(.plain)

                    Menu {
                        Button {
                            switchContext(to: nil)
                        } label: {
                            Label("All Patients (\(patients.count))", systemImage: "person.3")
                        }
                        Divider()
                        ForEach(patients) { patient in
                            Button {
                                switchContext(to: patient)
                            } label: {
                                Label(patient.fullName, systemImage: selectedPatient?.id == patient.id ? "checkmark.circle.fill" : "person.crop.circle")
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: selectedPatient == nil ? "person.3.fill" : "person.crop.circle.fill")
                            Text(contextLabel)
                                .fontWeight(.medium)
                            Image(systemName: "chevron.down")
                                .font(.caption2)
                        }
                        .font(.subheadline)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(.purple.opacity(0.12), in: Capsule())
                        .foregroundStyle(.purple)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)

                // Quick prompts
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(quickPrompts, id: \.self) { prompt in
                            Button {
                                sendMessage(prompt)
                            } label: {
                                Text(prompt)
                                    .font(.caption)
                                    .lineLimit(2)
                            }
                            .buttonStyle(.bordered)
                            .tint(.purple)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }

                Divider()

                // Chat messages
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(Array(chatHistory.enumerated()), id: \.offset) { idx, message in
                                ChatBubble(message: (isUser: message.isUser, text: message.text), metadata: message.metadata)
                                    .id(idx)
                            }
                            if isProcessing {
                                HStack {
                                    ProgressView()
                                        .padding(10)
                                        .background(Color(.secondarySystemBackground))
                                        .cornerRadius(14)
                                    Spacer()
                                }
                                .padding(.horizontal)
                                .id("loading")
                            }
                        }
                        .padding(.top, 8)
                    }
                    .onChange(of: chatHistory.count) {
                        withAnimation {
                            if isProcessing {
                                proxy.scrollTo("loading", anchor: .bottom)
                            } else {
                                proxy.scrollTo(chatHistory.count - 1, anchor: .bottom)
                            }
                        }
                    }
                }

                // Input bar
                HStack(spacing: 8) {
                    TextField(selectedPatient == nil ? "Ask about your patient panel…" : "Ask about \(selectedPatient!.firstName)…", text: $queryText)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { sendMessage(queryText) }

                    Button(action: { sendMessage(queryText) }) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title2)
                            .foregroundColor(.purple)
                    }
                    .disabled(queryText.isEmpty || isProcessing)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }
            .navigationTitle("Clinical Intelligence")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        Task { await ragService.indexAllData(modelContext: modelContext) }
                    } label: {
                        if ragService.isIndexing {
                            ProgressView()
                        } else {
                            Image(systemName: "arrow.triangle.2.circlepath")
                        }
                    }
                    .disabled(ragService.isIndexing)
                    .help("Reindex RAG pipeline")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        chatHistory.removeAll()
                        intelligenceService.resetSessions()
                        addWelcome()
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                    }
                }
            }
            .onAppear {
                if chatHistory.isEmpty {
                    if let p = initialPatient { selectedPatient = p }
                    addWelcome()
                }
            }
        }
    }

    // MARK: - Helpers

    private func switchContext(to patient: PatientProfile?) {
        selectedPatient = patient
        chatHistory.removeAll()
        intelligenceService.resetSessions()
        addWelcome()
        AppLogger.intel.info("🔀 Context switched to: \(patient?.fullName ?? "All Patients")")
    }

    private func addWelcome() {
        if let p = selectedPatient {
            let medCount = p.medications?.count ?? 0
            let recordCount = p.clinicalRecords?.count ?? 0
            chatHistory.append((isUser: false, text: "Focused on \(p.fullName)'s chart — \(recordCount) records, \(medCount) medications. Ask me anything about their history, meds, appointments, risks, or care plan.", metadata: nil))
        } else {
            let recordCount = patients.reduce(0) { $0 + ($1.clinicalRecords?.count ?? 0) }
            let medCount = patients.reduce(0) { $0 + ($1.medications?.count ?? 0) }
            let ragLabel = ragService.indexedChunkCount > 0 ? " RAG: \(ragService.indexedChunkCount) chunks indexed." : ""
            chatHistory.append((isUser: false, text: "Panel intelligence ready — \(patients.count) patients, \(recordCount) records, \(medCount) medications.\(ragLabel) Ask about schedules, conditions, medications, risks, or patterns across your panel.", metadata: nil))
        }
    }

    private func sendMessage(_ text: String) {
        let q = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return }
        queryText = ""
        chatHistory.append((isUser: true, text: q, metadata: nil))
        isProcessing = true

        if let patient = selectedPatient {
            AppLogger.intel.info("💬 Patient query [\(patient.fullName)]: \(q.prefix(80))")
        } else {
            AppLogger.intel.info("🧠 Panel query: \(q.prefix(80))")
        }

        Task {
            do {
                let response: String
                if let patient = selectedPatient {
                    response = try await intelligenceService.executeToolQuery(query: q, modelContext: modelContext, patient: patient)
                } else {
                    response = try await intelligenceService.executePanelQuery(query: q, modelContext: modelContext)
                }
                AppLogger.intel.info("✅ Response: \(response.count) chars")
                chatHistory.append((isUser: false, text: response, metadata: intelligenceService.ragMetadata))
            } catch {
                AppLogger.intel.error("❌ Query failed: \(error.localizedDescription)")
                chatHistory.append((isUser: false, text: "Error: \(error.localizedDescription)", metadata: nil))
            }
            isProcessing = false
        }
    }
}

// MARK: - Chat Bubble

private struct ChatBubble: View {
    let message: (isUser: Bool, text: String)
    var metadata: ResponseMetadata?

    var body: some View {
        HStack {
            if message.isUser { Spacer(minLength: 60) }
            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 4) {
                Text(message.text)
                    .padding(10)
                    .background(message.isUser ? Color.purple : Color(.secondarySystemBackground))
                    .foregroundColor(message.isUser ? .white : .primary)
                    .cornerRadius(14)
                    .textSelection(.enabled)

                // RAG metadata badge
                if let meta = metadata, !message.isUser {
                    HStack(spacing: 6) {
                        if let verif = meta.verification {
                            Label(verif.confidence.rawValue.capitalized, systemImage: confidenceIcon(verif.confidence))
                                .font(.caption2)
                                .foregroundStyle(confidenceColor(verif.confidence))
                        }

                        Text("\(meta.usedChunkCount) chunks · \(String(format: "%.0f", meta.totalTimeMs))ms")
                            .font(.caption2)
                            .foregroundStyle(.secondary)

                        if meta.deepThinkPassesUsed > 1 {
                            Label("\(meta.deepThinkPassesUsed) passes", systemImage: "brain.head.profile")
                                .font(.caption2)
                                .foregroundStyle(.orange)
                        }
                    }
                    .padding(.horizontal, 4)
                }
            }
            if !message.isUser { Spacer(minLength: 60) }
        }
        .padding(.horizontal)
    }

    private func confidenceIcon(_ tier: ConfidenceTier) -> String {
        switch tier {
        case .high: return "checkmark.shield.fill"
        case .medium: return "exclamationmark.triangle"
        case .low: return "xmark.shield"
        }
    }

    private func confidenceColor(_ tier: ConfidenceTier) -> Color {
        switch tier {
        case .high: return .green
        case .medium: return .orange
        case .low: return .red
        }
    }
}
