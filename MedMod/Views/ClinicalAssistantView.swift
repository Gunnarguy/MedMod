import SwiftUI
import SwiftData

struct ClinicalAssistantView: View {
    let patient: PatientProfile
    @Environment(\.modelContext) private var modelContext
    @StateObject private var intelligenceService = ClinicalIntelligenceService()

    @State private var queryText = ""
    @State private var chatHistory: [(isUser: Bool, text: String)] = []
    @State private var isProcessing = false

    private var quickPrompts: [String] {
        [
            "Does \(patient.firstName) have a history of Basal Cell Carcinoma?",
            "What medications are on file for \(patient.firstName)?"
        ]
    }

    var body: some View {
        VStack(spacing: 0) {
            // Quick prompts
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(quickPrompts, id: \.self) { prompt in
                        Button(prompt) {
                            askAssistant(with: prompt)
                        }
                        .buttonStyle(.bordered)
                        .font(.caption)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }

            Divider()

            // Chat messages
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(Array(chatHistory.enumerated()), id: \.offset) { _, message in
                        HStack {
                            if message.isUser {
                                Spacer()
                                Text(message.text)
                                    .padding(10)
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(14)
                            } else {
                                Text(message.text)
                                    .padding(10)
                                    #if os(iOS)
                                    .background(Color(UIColor.secondarySystemBackground))
                                    #else
                                    .background(Color(NSColor.textBackgroundColor))
                                    #endif
                                    .cornerRadius(14)
                                Spacer()
                            }
                        }
                        .padding(.horizontal)
                    }
                    if isProcessing {
                        HStack {
                            ProgressView()
                                .padding(10)
                                #if os(iOS)
                                .background(Color(UIColor.secondarySystemBackground))
                                #else
                                .background(Color(NSColor.textBackgroundColor))
                                #endif
                                .cornerRadius(14)
                            Spacer()
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.top, 8)
            }

            // Input bar
            HStack(spacing: 8) {
                TextField("Ask about \(patient.firstName)'s history...", text: $queryText)
                    .textFieldStyle(.roundedBorder)

                Button(action: askAssistant) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
                .disabled(queryText.isEmpty || isProcessing)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .navigationTitle("AI Assistant")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .onAppear {
            if chatHistory.isEmpty {
                chatHistory.append((isUser: false, text: "I'm your on-device clinical assistant for \(patient.firstName) \(patient.lastName). Ask me anything about their records."))
            }
        }
    }

    private func askAssistant() {
        let q = queryText
        queryText = ""
        askAssistant(with: q)
    }

    private func askAssistant(with query: String) {
        guard !query.isEmpty else { return }
        chatHistory.append((isUser: true, text: query))
        isProcessing = true

        Task {
            do {
                let response = try await intelligenceService.executeToolQuery(query: query, modelContext: modelContext, patient: patient)
                chatHistory.append((isUser: false, text: response))
                isProcessing = false
            } catch {
                chatHistory.append((isUser: false, text: "Error: \(error.localizedDescription)"))
                isProcessing = false
            }
        }
    }
}
