import SwiftUI
import SwiftData

struct ClinicalExamView: View {
    let patient: PatientProfile
    @StateObject private var workflowState = ClinicalWorkflowState()

    var body: some View {
        ClinicalExamWorkspace(patient: patient, workflowState: workflowState)
            .navigationTitle("3D Clinical Exam")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
    }
}

struct ClinicalExamWorkspace: View {
    let patient: PatientProfile
    @ObservedObject var workflowState: ClinicalWorkflowState

    @Environment(\.modelContext) private var modelContext
    @StateObject private var intelligenceService = ClinicalIntelligenceService()
    @State private var dictationText = ""
    @State private var showAtlas = true

    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var sizeClass
    private var isCompact: Bool { sizeClass == .compact }
    #else
    private var isCompact: Bool { false }
    #endif

    var body: some View {
        Group {
            if isCompact {
                compactLayout
            } else {
                regularLayout
            }
        }
    }

    // MARK: - iPad / Wide Layout

    private var regularLayout: some View {
        HStack(spacing: 0) {
            // Left: 3D Atlas
            MedicalAtlasView(selectedAnatomy: $workflowState.selectedAnatomy)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Right: Intelligence panel
            ScrollView {
                intelligencePanel
            }
            .frame(width: 380)
            #if os(iOS)
            .background(Color(UIColor.secondarySystemBackground))
            #else
            .background(Color(NSColor.windowBackgroundColor))
            #endif
        }
    }

    // MARK: - iPhone / Compact Layout

    private var compactLayout: some View {
        VStack(spacing: 0) {
            // Atlas lives OUTSIDE ScrollView so RealityKit gestures aren't stolen
            DisclosureGroup(isExpanded: $showAtlas) {
                MedicalAtlasView(selectedAnatomy: $workflowState.selectedAnatomy)
                    .frame(height: 340)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } label: {
                Label("3D Anatomical Atlas", systemImage: "cube.transparent")
                    .font(.headline)
            }
            .padding(.horizontal)
            .padding(.top, 8)

            // Only the intelligence panel scrolls
            ScrollView {
                intelligencePanel
            }
        }
    }

    // MARK: - Shared Intelligence Panel

    private var intelligencePanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Spatial focus
            if let part = workflowState.selectedAnatomy {
                HStack(spacing: 6) {
                    Image(systemName: "scope")
                        .foregroundColor(.red)
                    Text(AnatomicalRealityView.displayName(for: part))
                        .fontWeight(.medium)
                }
                .font(.subheadline)
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.purple.opacity(0.1))
                .cornerRadius(8)
            }

            // Dictation
            VStack(alignment: .leading, spacing: 6) {
                Text("Dictation")
                    .font(.headline)
                Text("Describe your clinical findings")
                    .font(.caption)
                    .foregroundColor(.secondary)
                #if os(iOS)
                TextEditor(text: $dictationText)
                    .frame(minHeight: 80, maxHeight: 140)
                    .padding(4)
                    .background(Color(UIColor.tertiarySystemBackground))
                    .cornerRadius(8)
                #else
                TextEditor(text: $dictationText)
                    .frame(minHeight: 80, maxHeight: 140)
                    .padding(4)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
                #endif
            }

            // Process button
            Button(action: runAIWorkflow) {
                HStack {
                    if workflowState.isProcessing {
                        ProgressView()
                            .padding(.trailing, 4)
                    } else {
                        Image(systemName: "waveform.circle.fill")
                    }
                    Text(workflowState.isProcessing ? "Processing..." : "Process Diagnostics")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .foregroundColor(.white)
                .background(dictationText.isEmpty && workflowState.selectedAnatomy == nil ? Color.gray : Color.purple)
                .cornerRadius(12)
            }
            .disabled(workflowState.isProcessing || (dictationText.isEmpty && workflowState.selectedAnatomy == nil))

            // Structured output
            if let note = workflowState.generatedNote {
                Divider()

                VStack(alignment: .leading, spacing: 10) {
                    Text("AI Structured Output")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)

                    clinicalDataRow(title: "CC / HPI", value: note.ccHPI)
                    clinicalDataRow(title: "Review of Systems", value: note.reviewOfSystems)
                    clinicalDataRow(title: "Exam Findings", value: note.examFindings)
                    clinicalDataRow(title: "Impression & Plan", value: note.impressionsAndPlan)

                    if !note.affectedAnatomicalZones.isEmpty {
                        clinicalDataRow(title: "Anatomical Zones", value: note.affectedAnatomicalZones.map { AnatomicalRealityView.displayName(for: $0) }.joined(separator: ", "))
                    }
                }

                // PDF generation
                Button(action: { generateAndSaveDocument(note: note) }) {
                    Label("Sign & Generate PDF", systemImage: "signature")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .foregroundColor(.white)
                        .background(Color.blue)
                        .cornerRadius(12)
                }
            }

            if let url = workflowState.generatedPDFURL {
                HStack {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundColor(.green)
                    Text(url.lastPathComponent)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
    }

    // MARK: - Actions

    private func runAIWorkflow() {
        workflowState.isProcessing = true
        var prompt = dictationText
        if let part = workflowState.selectedAnatomy {
            prompt = "[Anatomical Focus: \(part)] " + prompt
        }

        Task {
            do {
                let note = try await intelligenceService.generateStructuredNote(from: prompt)
                workflowState.generatedNote = note
                workflowState.isProcessing = false
            } catch {
                workflowState.isProcessing = false
            }
        }
    }

    private func generateAndSaveDocument(note: ClinicalVisitNote) {
        let record = LocalClinicalRecord(
            recordID: UUID().uuidString,
            dateRecorded: Date(),
            conditionName: note.impressionsAndPlan,
            status: "Final",
            isHiddenFromPortal: false,
            ccHPI: note.ccHPI,
            reviewOfSystems: note.reviewOfSystems,
            examFindings: note.examFindings,
            impressionsAndPlan: note.impressionsAndPlan,
            affectedAnatomicalZones: note.affectedAnatomicalZones,
            providerSignature: "\(patient.firstName) \(patient.lastName) Provider"
        )
        modelContext.insert(record)
        patient.clinicalRecords?.append(record)
        try? modelContext.save()

        if let url = generatePDFLocally(patient: patient, record: record, details: note) {
            workflowState.generatedPDFURL = url
        }
    }

    private func clinicalDataRow(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.caption.bold()).foregroundColor(.purple)
            Text(value).font(.callout)
        }
    }
}
