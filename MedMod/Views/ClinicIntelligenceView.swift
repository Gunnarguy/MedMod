import SwiftUI
import SwiftData
import os

// MARK: - Chat Message

private struct ChatMessage: Identifiable {
    let id: UUID
    let isUser: Bool
    let text: String
    let metadata: ResponseMetadata?
    let thinkingSteps: [ThinkingStep]

    init(id: UUID = UUID(), isUser: Bool, text: String, metadata: ResponseMetadata? = nil, thinkingSteps: [ThinkingStep] = []) {
        self.id = id
        self.isUser = isUser
        self.text = text
        self.metadata = metadata
        self.thinkingSteps = thinkingSteps
    }
}

// MARK: - Clinic Intelligence View

struct ClinicIntelligenceView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PatientProfile.lastName) private var patients: [PatientProfile]
    @StateObject private var intelligenceService = ClinicalIntelligenceService()
    @ObservedObject private var ragService = ClinicalRAGService.shared

    @State private var queryText = ""
    @State private var chatHistory: [ChatMessage] = []
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
                // Context bar: engine status + RAG + Deep Think + patient picker
                HStack(spacing: 8) {
                    HStack(spacing: 5) {
                        Circle()
                            .fill(ragService.indexedChunkCount > 0 ? .green : .orange)
                            .frame(width: 6, height: 6)
                        Text(intelligenceService.engineStatusLabel)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer()

                    // Deep Think toggle
                    Button {
                        deepThinkEnabled.toggle()
                        intelligenceService.deepThinkEnabled = deepThinkEnabled
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: deepThinkEnabled ? "brain.head.profile.fill" : "brain.head.profile")
                                .symbolEffect(.bounce, value: deepThinkEnabled)
                            Text(deepThinkEnabled ? "Deep Think" : "Standard")
                                .font(.caption2.bold())
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
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
                        .font(.caption)
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
                        LazyVStack(spacing: 16) {
                            ForEach(chatHistory) { message in
                                if message.isUser {
                                    UserBubble(text: message.text)
                                } else {
                                    AIResponseView(message: message)
                                }
                            }
                            if isProcessing {
                                ThinkingStreamView(
                                    steps: ragService.thinkingSteps,
                                    deepThinkEnabled: deepThinkEnabled
                                )
                                .id("thinking")
                            }
                        }
                        .padding(.top, 8)
                        .padding(.bottom, 12)
                    }
                    .onChange(of: chatHistory.count) {
                        withAnimation {
                            if let last = chatHistory.last {
                                proxy.scrollTo(last.id, anchor: .bottom)
                            }
                        }
                    }
                    .onChange(of: ragService.thinkingSteps.count) {
                        if isProcessing {
                            withAnimation {
                                proxy.scrollTo("thinking", anchor: .bottom)
                            }
                        }
                    }
                }

                // Input bar
                VStack(spacing: 0) {
                    Divider()
                    HStack(spacing: 12) {
                        TextField(selectedPatient == nil ? "Ask about your patient panel…" : "Ask about \(selectedPatient!.firstName)…", text: $queryText)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Color(UIColor.secondarySystemBackground).opacity(0.8))
                            .clipShape(Capsule())
                            .onSubmit { sendMessage(queryText) }

                        Button(action: { sendMessage(queryText) }) {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 28))
                                .symbolRenderingMode(.hierarchical)
                                .foregroundColor(queryText.isEmpty ? .secondary.opacity(0.5) : .purple)
                        }
                        .disabled(queryText.isEmpty || isProcessing)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                    .background(.ultraThinMaterial)
                }
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
            chatHistory.append(ChatMessage(isUser: false, text: "Focused on \(p.fullName)'s chart — \(recordCount) records, \(medCount) medications. Ask me anything about their history, meds, appointments, risks, or care plan."))
        } else {
            let recordCount = patients.reduce(0) { $0 + ($1.clinicalRecords?.count ?? 0) }
            let medCount = patients.reduce(0) { $0 + ($1.medications?.count ?? 0) }
            let ragLabel = ragService.indexedChunkCount > 0 ? " RAG: \(ragService.indexedChunkCount) chunks indexed." : ""
            chatHistory.append(ChatMessage(isUser: false, text: "Panel intelligence ready — \(patients.count) patients, \(recordCount) records, \(medCount) medications.\(ragLabel) Ask about schedules, conditions, medications, risks, or patterns across your panel."))
        }
    }

    private func sendMessage(_ text: String) {
        let q = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return }
        queryText = ""
        chatHistory.append(ChatMessage(isUser: true, text: q))
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
                chatHistory.append(ChatMessage(
                    isUser: false,
                    text: response,
                    metadata: intelligenceService.ragMetadata,
                    thinkingSteps: ragService.thinkingSteps
                ))
            } catch {
                AppLogger.intel.error("❌ Query failed: \(error.localizedDescription)")
                chatHistory.append(ChatMessage(isUser: false, text: "Error: \(error.localizedDescription)"))
            }
            isProcessing = false
        }
    }
}

// MARK: - User Bubble

private struct UserBubble: View {
    let text: String

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            Spacer(minLength: 60)
            Text(text)
                .font(.subheadline)
                .lineSpacing(2)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.purple)
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .textSelection(.enabled)
        }
        .padding(.horizontal)
    }
}

private struct ChatFormattedText: View {
    let text: String

    private var lines: [String] {
        text.replacingOccurrences(of: "\r\n", with: "\n").components(separatedBy: "\n")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(lines.enumerated()), id: \.offset) { index, rawLine in
                let line = rawLine.trimmingCharacters(in: .whitespaces)

                if line.isEmpty {
                    Color.clear.frame(height: index == 0 ? 0 : 2)
                } else if line.hasPrefix("- ") {
                    HStack(alignment: .top, spacing: 8) {
                        Circle()
                            .fill(Color.secondary)
                            .frame(width: 5, height: 5)
                            .padding(.top, 7)
                        Text(String(line.dropFirst(2)))
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                } else if line.hasSuffix(":") && line.count < 40 {
                    Text(line)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .padding(.top, index == 0 ? 0 : 2)
                } else {
                    Text(line)
                        .font(.subheadline)
                        .lineSpacing(2)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .textSelection(.enabled)
    }
}

// MARK: - Thinking Stream View (live during processing)

private struct ThinkingStreamView: View {
    let steps: [ThinkingStep]
    let deepThinkEnabled: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: deepThinkEnabled ? "brain.head.profile.fill" : "brain")
                    .foregroundStyle(deepThinkEnabled ? .orange : .purple)
                    .symbolEffect(.pulse, options: .repeating)
                Text(deepThinkEnabled ? "Deep Think" : "Thinking")
                    .font(.subheadline.bold())
                    .foregroundStyle(deepThinkEnabled ? .orange : .purple)
                Spacer()
            }
            .padding(.bottom, 10)

            ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                HStack(alignment: .top, spacing: 10) {
                    VStack(spacing: 0) {
                        Image(systemName: step.phase == .complete ? "checkmark.circle.fill" : step.icon)
                            .font(.system(size: 10))
                            .foregroundStyle(stepColor(step))
                            .frame(width: 12, height: 12)
                        if index < steps.count - 1 {
                            Rectangle()
                                .fill(Color(.separator))
                                .frame(width: 1)
                                .frame(minHeight: 16)
                        }
                    }
                    .frame(width: 12)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(step.title)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(step.phase == .complete ? .green : .primary)
                        if !step.detail.isEmpty {
                            Text(step.detail)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(3)
                        }
                    }
                    .padding(.bottom, 6)

                    Spacer()
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .leading).combined(with: .opacity),
                    removal: .opacity
                ))
            }

            HStack(spacing: 8) {
                ProgressView()
                    .scaleEffect(0.7)
                Text(steps.last?.phase == .complete ? "Generating response…" : "Processing…")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 2)
            .padding(.leading, 22)
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
        .animation(.easeInOut(duration: 0.3), value: steps.count)
    }

    private func stepColor(_ step: ThinkingStep) -> Color {
        switch step.phase {
        case .complete: return .green
        case .verification: return step.icon == "checkmark.shield.fill" ? .green : .orange
        case .deepThinkPass, .followUpExtraction: return .orange
        case .generation: return .purple
        default: return .blue
        }
    }
}

// MARK: - AI Response View

private struct AIResponseView: View {
    let message: ChatMessage
    @State private var showSources = false
    @State private var showGates = false
    @State private var showThinking = false
    @State private var showMetrics = false

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.purple)
                .frame(width: 3)
                .padding(.vertical, 6)

            VStack(alignment: .leading, spacing: 12) {
                ChatFormattedText(text: message.text)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(.quaternary, lineWidth: 0.5)
                    )

                if let meta = message.metadata {
                    HStack(spacing: 12) {
                        if let verif = meta.verification {
                            HStack(spacing: 3) {
                                Image(systemName: confidenceIcon(verif.confidence))
                                    .font(.caption2)
                                Text(verif.confidence.rawValue.capitalized)
                                    .font(.caption2.bold())
                            }
                            .foregroundStyle(confidenceColor(verif.confidence))
                        }

                        Text("\(meta.usedChunkCount) sources")
                            .font(.caption2)
                            .foregroundStyle(.secondary)

                        Text("·").foregroundStyle(.tertiary)

                        Text(String(format: "%.0fms", meta.totalTimeMs))
                            .font(.caption2)
                            .foregroundStyle(.secondary)

                        if meta.deepThinkPassesUsed > 1 {
                            HStack(spacing: 2) {
                                Image(systemName: "brain.head.profile")
                                    .font(.caption2)
                                Text("\(meta.deepThinkPassesUsed) passes")
                                    .font(.caption2)
                            }
                            .foregroundStyle(.orange)
                        }
                    }
                    .font(.caption2)
                    .padding(.horizontal, 6)

                    VStack(spacing: 6) {
                        if !message.thinkingSteps.isEmpty {
                            expandableSection(title: "Thought Process", icon: "brain", count: message.thinkingSteps.count, isExpanded: $showThinking) {
                                ThinkingStepsReplayView(steps: message.thinkingSteps)
                            }
                        }

                        if !meta.sourceChunks.isEmpty {
                            expandableSection(title: "Sources", icon: "doc.text", count: meta.sourceChunks.count, isExpanded: $showSources) {
                                SourcesListView(chunks: meta.sourceChunks)
                            }
                        }

                        if let verif = meta.verification {
                            expandableSection(title: "Verification Gates", icon: "checkmark.shield", count: nil, isExpanded: $showGates) {
                                GatesGridView(verification: verif)
                            }
                        }

                        expandableSection(title: "Pipeline Metrics", icon: "gauge", count: nil, isExpanded: $showMetrics) {
                            PipelineMetricsView(meta: meta)
                        }
                    }
                    .padding(.horizontal, 4)
                }
            }
            Spacer(minLength: 40)
        }
        .padding(.horizontal)
    }

    @ViewBuilder
    private func expandableSection<Content: View>(title: String, icon: String, count: Int?, isExpanded: Binding<Bool>, @ViewBuilder content: @escaping () -> Content) -> some View {
        DisclosureGroup(isExpanded: isExpanded) {
            content()
                .padding(.top, 4)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption2)
                Text(title)
                    .font(.caption2.bold())
                if let count {
                    Text("(\(count))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .foregroundStyle(.purple)
        }
        .font(.caption2)
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

// MARK: - Thinking Steps Replay (per-message)

private struct ThinkingStepsReplayView: View {
    let steps: [ThinkingStep]

    private var baseTime: Date { steps.first?.timestamp ?? Date() }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(steps) { step in
                HStack(alignment: .top, spacing: 8) {
                    Text(String(format: "+%.0fms", step.timestamp.timeIntervalSince(baseTime) * 1000))
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.tertiary)
                        .frame(width: 55, alignment: .trailing)

                    Image(systemName: step.icon)
                        .font(.caption2)
                        .foregroundStyle(phaseColor(step.phase))
                        .frame(width: 12)

                    VStack(alignment: .leading, spacing: 1) {
                        Text(step.title)
                            .font(.caption2)
                            .fontWeight(.medium)
                        if !step.detail.isEmpty {
                            Text(step.detail)
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                    }
                    Spacer()
                }
            }
        }
    }

    private func phaseColor(_ phase: ThinkingPhase) -> Color {
        switch phase {
        case .complete: return .green
        case .verification: return .blue
        case .deepThinkPass, .followUpExtraction: return .orange
        case .generation: return .purple
        default: return .secondary
        }
    }
}

// MARK: - Sources List

private struct SourcesListView: View {
    let chunks: [ChunkSummary]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(chunks.enumerated()), id: \.element.id) { index, chunk in
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text("\(index + 1).")
                            .font(.caption2.bold())
                            .foregroundStyle(.purple)
                        Text(chunk.patientName)
                            .font(.caption2.bold())
                        Text("— \(chunk.sectionTitle)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }

                    HStack(spacing: 6) {
                        Text(String(format: "%.4f", chunk.score))
                            .font(.system(.caption2, design: .monospaced))
                        if let vr = chunk.vectorRank {
                            Text("V:#\(vr)")
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundStyle(.blue)
                        }
                        if let kr = chunk.keywordRank {
                            Text("K:#\(kr)")
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundStyle(.green)
                        }
                        if let date = chunk.dateRecorded {
                            Text(date, style: .date)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Text(chunk.preview)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .italic()
                }
                .padding(8)
                .background(Color(.tertiarySystemBackground))
                .cornerRadius(8)
            }
        }
    }
}

// MARK: - Verification Gates Grid

private struct GatesGridView: View {
    let verification: VerificationResult

    private let gateNames: [(key: String, label: String, icon: String)] = [
        ("retrievalConfidence", "Retrieval Confidence", "magnifyingglass"),
        ("evidenceCoverage", "Evidence Coverage", "doc.text.magnifyingglass"),
        ("numericSanity", "Numeric Sanity", "number"),
        ("contradictionSweep", "Contradiction Sweep", "arrow.left.arrow.right"),
        ("semanticGrounding", "Semantic Grounding", "brain"),
        ("quoteFaithfulness", "Quote Faithfulness", "quote.bubble"),
        ("generationQuality", "Generation Quality", "text.badge.checkmark"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(String(format: "Overall: %.0f%%", verification.overallScore * 100))
                    .font(.caption2.bold())
                Spacer()
                Text("\(verification.gateResults.values.filter { $0 }.count)/7 passed")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            ForEach(gateNames, id: \.key) { gate in
                let passed = verification.gateResults[gate.key] ?? false
                HStack(spacing: 6) {
                    Image(systemName: passed ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.caption2)
                        .foregroundStyle(passed ? .green : .red)
                    Image(systemName: gate.icon)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(width: 14)
                    Text(gate.label)
                        .font(.caption2)
                    Spacer()
                }
            }

            if !verification.warnings.isEmpty {
                Divider()
                ForEach(verification.warnings, id: \.self) { warning in
                    HStack(alignment: .top, spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                        Text(warning)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

// MARK: - Pipeline Metrics

private struct PipelineMetricsView: View {
    let meta: ResponseMetadata

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            metricRow("Total Time", String(format: "%.0fms", meta.totalTimeMs), icon: "clock")
            metricRow("Search Time", String(format: "%.0fms", meta.searchTimeMs), icon: "magnifyingglass")
            metricRow("Retrieved", "\(meta.retrievedChunkCount) chunks", icon: "square.stack.3d.up")
            metricRow("Used", "\(meta.usedChunkCount) chunks", icon: "checkmark.square")
            metricRow("Deep Think Passes", "\(meta.deepThinkPassesUsed)", icon: "brain.head.profile")

            if meta.totalTimeMs > 0 && meta.searchTimeMs > 0 {
                GeometryReader { geometry in
                    let searchFrac = min(meta.searchTimeMs / meta.totalTimeMs, 1.0)
                    HStack(spacing: 1) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(.blue)
                            .frame(width: max(geometry.size.width * searchFrac, 2))
                        RoundedRectangle(cornerRadius: 2)
                            .fill(.purple)
                    }
                }
                .frame(height: 6)

                HStack(spacing: 12) {
                    Label("Search", systemImage: "circle.fill")
                        .font(.system(size: 8))
                        .foregroundStyle(.blue)
                    Label("Processing", systemImage: "circle.fill")
                        .font(.system(size: 8))
                        .foregroundStyle(.purple)
                }
            }
        }
    }

    private func metricRow(_ label: String, _ value: String, icon: String) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(width: 14)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(.caption2, design: .monospaced))
        }
    }
}
