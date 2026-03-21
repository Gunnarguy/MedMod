import SwiftUI
import SwiftData

struct ClinicalAssistantView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var intelligenceService = ClinicalIntelligenceService()

    @State private var queryText: String = "Does the patient have a history of Basal Cell Carcinoma?"
    @State private var chatHistory: [(isUser: Bool, text: String)] = [
        (isUser: false, text: "I am your local on-device Clinical Assistant. How can I help you query the patient's record?")
    ]
    @State private var isProcessing = false

    var body: some View {
        VStack {
            ScrollView {
                VStack(spacing: 16) {
                    ForEach(0..<chatHistory.count, id: \.self) { index in
                        let message = chatHistory[index]
                        HStack {
                            if message.isUser {
                                Spacer()
                                Text(message.text)
                                    .padding()
                                    #if os(iOS)
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    #else
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    #endif
                                    .cornerRadius(16)
                            } else {
                                Text(message.text)
                                    .padding()
                                    #if os(iOS)
                                    .background(Color(UIColor.secondarySystemBackground))
                                    .foregroundColor(Color(UIColor.label))
                                    #else
                                    .background(Color(NSColor.textBackgroundColor))
                                    .foregroundColor(Color(NSColor.labelColor))
                                    #endif
                                    .cornerRadius(16)
                                Spacer()
                            }
                        }
                        .padding(.horizontal)
                    }
                    if isProcessing {
                        HStack {
                            ProgressView()
                                .padding()
                                #if os(iOS)
                                .background(Color(UIColor.secondarySystemBackground))
                                #else
                                .background(Color(NSColor.textBackgroundColor))
                                #endif
                                .cornerRadius(16)
                            Spacer()
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.top)
            }

            HStack {
                TextField("Ask about patient history...", text: $queryText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal)

                Button(action: askAssistant) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title)
                        .foregroundColor(.blue)
                }
                .disabled(queryText.isEmpty || isProcessing)
                .padding(.trailing)
            }
            .padding(.bottom)
        }
        .navigationTitle("Clinical LLM Assistant")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private func askAssistant() {
        let currentQuery = queryText
        queryText = ""
        chatHistory.append((isUser: true, text: currentQuery))
        isProcessing = true

        Task {
            do {
                let response = try await intelligenceService.executeToolQuery(query: currentQuery, modelContext: modelContext)
                await MainActor.run {
                    chatHistory.append((isUser: false, text: response))
                    isProcessing = false
                }
            } catch {
                await MainActor.run {
                    chatHistory.append((isUser: false, text: "Error running tool: \(error.localizedDescription)"))
                    isProcessing = false
                }
            }
        }
    }
}
