import SwiftUI
import SwiftData

struct MedModSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var smartController: SMARTConnectionController
    @ObservedObject private var ragService = ClinicalRAGService.shared
    @StateObject private var intelligenceService = ClinicalIntelligenceService()
    @Query private var patients: [PatientProfile]

    private var recordCount: Int {
        patients.reduce(0) { $0 + ($1.clinicalRecords?.count ?? 0) }
    }

    private var medicationCount: Int {
        patients.reduce(0) { $0 + ($1.medications?.count ?? 0) }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Workspace") {
                    LabeledContent("Patients") {
                        Text("\(patients.count)")
                    }
                    LabeledContent("Records") {
                        Text("\(recordCount)")
                    }
                    LabeledContent("Medications") {
                        Text("\(medicationCount)")
                    }
                    LabeledContent("Text Layout") {
                        Text("Compact rows, wrapped narratives")
                            .multilineTextAlignment(.trailing)
                            .clinicalFinePrint()
                    }
                }

                Section("Intelligence") {
                    Text(intelligenceService.engineStatusLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .clinicalFinePrint()
                    LabeledContent("Indexed Chunks") {
                        Text("\(ragService.indexedChunkCount)")
                    }
                    Button(ragService.isIndexing ? "Reindexing…" : "Reindex Clinical Data") {
                        Task { await ragService.indexAllData(modelContext: modelContext) }
                    }
                    .disabled(ragService.isIndexing)
                }

                Section("Connectivity") {
                    NavigationLink(destination: InteroperabilityWorkspaceView()) {
                        Label("EHR Connectivity", systemImage: "network")
                    }

                    if let token = smartController.session.tokenResponse {
                        LabeledContent("SMART Token") {
                            Text(token.tokenType)
                        }
                        if let patientID = token.patient, !patientID.isEmpty {
                            LabeledContent("Launch Patient") {
                                Text(patientID)
                                    .font(.caption.monospaced())
                                    .clinicalFinePrintMonospaced()
                            }
                        }
                    } else {
                        Text("No SMART session connected.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .clinicalFinePrint()
                    }
                }

                Section("About") {
                    LabeledContent("App") {
                        Text("MedMod")
                    }
                    LabeledContent("Mode") {
                        Text("Demo + provider workflow prototype")
                            .multilineTextAlignment(.trailing)
                            .clinicalFinePrint()
                    }
                }
            }
            .navigationTitle("Settings")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
        }
    }
}
