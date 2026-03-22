import SwiftUI
import SwiftData

struct iPadClinicalDashboard: View {
    @Query(sort: \PatientProfile.lastName) private var patients: [PatientProfile]
    @State private var selectedPatientID: UUID?
    @StateObject private var workflowState = ClinicalWorkflowState()
    @State private var showInspector = false

    private var selectedPatient: PatientProfile? {
        if let selectedPatientID {
            return patients.first(where: { $0.id == selectedPatientID })
        }
        return patients.first
    }

    var body: some View {
        NavigationSplitView {
            PatientAgendaList(patients: patients, selection: $selectedPatientID)
                .navigationTitle("Patients")
        } detail: {
            if let patient = selectedPatient {
                PatientChartDetail(patient: patient, workflowState: workflowState, showInspector: $showInspector)
            } else {
                ContentUnavailableView(
                    "Select a Patient",
                    systemImage: "person.crop.circle.badge.questionmark",
                    description: Text("Choose a patient from the sidebar to view their chart.")
                )
            }
        }
        .inspector(isPresented: $showInspector) {
            VisitSettingsInspector(patient: selectedPatient, workflowState: workflowState)
        }
        .onChange(of: selectedPatientID) { _, _ in
            workflowState.reset()
        }
    }
}

// MARK: - Patient List Sidebar

struct PatientAgendaList: View {
    let patients: [PatientProfile]
    @Binding var selection: UUID?

    var body: some View {
        List(selection: $selection) {
            ForEach(patients) { patient in
                NavigationLink(value: patient.id) {
                    PatientAgendaRow(patient: patient)
                }
            }
        }
        #if os(iOS)
        .listStyle(.sidebar)
        #endif
        .onAppear {
            if selection == nil {
                selection = patients.first?.id
            }
        }
    }
}

struct PatientAgendaRow: View {
    let patient: PatientProfile

    private var nextAppointment: Appointment? {
        patient.appointments?
            .sorted(by: { $0.scheduledTime < $1.scheduledTime })
            .first
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(patient.firstName) \(patient.lastName)")
                .font(.headline)
            if let appt = nextAppointment {
                Text(appt.reasonForVisit)
                    .font(.subheadline)
                Text(appt.scheduledTime, format: .dateTime.month().day().hour().minute())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("No upcoming visits")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Chart Detail (no more inline atlas — atlas lives in exam workspace only)

struct PatientChartDetail: View {
    let patient: PatientProfile
    @ObservedObject var workflowState: ClinicalWorkflowState
    @Binding var showInspector: Bool
    @Environment(\.modelContext) private var modelContext
    @State private var isImportingHealthData = false
    @State private var showingExamWorkspace = false

    private var records: [LocalClinicalRecord] {
        (patient.clinicalRecords ?? []).sorted { $0.dateRecorded > $1.dateRecorded }
    }
    private var medications: [LocalMedication] {
        (patient.medications ?? []).sorted { $0.writtenDate > $1.writtenDate }
    }

    var body: some View {
        List {
            // Patient header
            Section {
                HStack(spacing: 14) {
                    Image(systemName: "person.crop.circle.fill")
                        .resizable()
                        .frame(width: 50, height: 50)
                        .foregroundColor(.purple)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(patient.firstName) \(patient.lastName)")
                            .font(.title3.bold())
                        HStack(spacing: 12) {
                            Text(patient.dateOfBirth, format: .dateTime.month().day().year())
                            Text(patient.gender)
                            if patient.isSmoker {
                                Label("Smoker", systemImage: "smoke")
                                    .foregroundColor(.orange)
                            }
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                }
            }

            // Clinical actions
            Section("Clinical Workflow") {
                Button {
                    showingExamWorkspace = true
                } label: {
                    Label("Open 3D Clinical Exam", systemImage: "waveform.path.ecg.rectangle")
                }
                .tint(.purple)

                NavigationLink(destination: ClinicalAssistantView(patient: patient)) {
                    Label("Clinical AI Assistant", systemImage: "brain.head.profile")
                }

                Button {
                    importClinicalRecords()
                } label: {
                    Label(isImportingHealthData ? "Importing..." : "Import HealthKit Records", systemImage: "heart.text.square")
                }
                .disabled(isImportingHealthData)
            }

            // Recent records
            Section("Recent Records") {
                if records.isEmpty {
                    Text("No clinical records yet")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(records.prefix(5)) { record in
                        NavigationLink(destination: VisitRecordDetailView(record: record, patient: patient)) {
                            VStack(alignment: .leading, spacing: 3) {
                                HStack {
                                    Text(record.conditionName).font(.subheadline.weight(.medium))
                                    Spacer()
                                    Text(record.status)
                                        .font(.caption2)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(record.status == "Final" ? Color.green.opacity(0.15) : Color.orange.opacity(0.15))
                                        .foregroundColor(record.status == "Final" ? .green : .orange)
                                        .cornerRadius(4)
                                }
                                Text(record.dateRecorded, format: .dateTime.month().day().year())
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }

            // Medications
            Section("Medications") {
                if medications.isEmpty {
                    Text("No medications loaded")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(medications) { rx in
                        RxRowView(rx: rx)
                    }
                }
            }

            // AI draft summary (if workflow active)
            if let note = workflowState.generatedNote {
                Section("Current AI Draft") {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(note.impressionsAndPlan)
                            .font(.subheadline.weight(.semibold))
                        Text(note.examFindings)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    if let url = workflowState.generatedPDFURL {
                        Label(url.lastPathComponent, systemImage: "doc.fill")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
            }
        }
        .navigationTitle("Patient Chart")
        #if os(iOS)
        .listStyle(.insetGrouped)
        #endif
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showInspector.toggle()
                } label: {
                    Image(systemName: "sidebar.trailing")
                }
            }
        }
        .sheet(isPresented: $showingExamWorkspace) {
            NavigationStack {
                ClinicalExamWorkspace(patient: patient, workflowState: workflowState)
                    .navigationTitle("3D Clinical Exam")
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Done") { showingExamWorkspace = false }
                        }
                    }
            }
        }
    }

    private func importClinicalRecords() {
        isImportingHealthData = true
        Task {
            await HealthKitFHIRService(modelContext: modelContext, patient: patient).requestAuthorizationAndFetch()
            isImportingHealthData = false
        }
    }
}

// MARK: - Inspector

struct VisitSettingsInspector: View {
    let patient: PatientProfile?
    @ObservedObject var workflowState: ClinicalWorkflowState

    var body: some View {
        Group {
            if let patient {
                Form {
                    Section("Patient") {
                        LabeledContent("Name", value: "\(patient.firstName) \(patient.lastName)")
                        LabeledContent("DOB", value: patient.dateOfBirth.formatted(date: .abbreviated, time: .omitted))
                        LabeledContent("Gender", value: patient.gender)
                        LabeledContent("Smoking", value: patient.isSmoker ? "Yes" : "No")
                    }

                    Section("AI Draft") {
                        if let note = workflowState.generatedNote {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(note.ccHPI)
                                Text(note.examFindings).font(.caption).foregroundStyle(.secondary)
                                Text(note.impressionsAndPlan).font(.caption).foregroundStyle(.secondary)
                            }
                        } else {
                            Text("Run the 3D exam to generate").foregroundStyle(.secondary)
                        }
                    }

                    Section("Rx") {
                        let meds = patient.medications ?? []
                        if meds.isEmpty {
                            Text("No medications").foregroundStyle(.secondary)
                        } else {
                            ForEach(meds) { rx in
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(rx.medicationName)
                                    Text(rx.quantityInfo).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }

                    if let anatomy = workflowState.selectedAnatomy {
                        Section("Anatomical Focus") {
                            Text(AnatomicalRealityView.displayName(for: anatomy))
                                .font(.body.monospaced())
                        }
                    }

                    Section("PDF Output") {
                        if let url = workflowState.generatedPDFURL {
                            Label(url.lastPathComponent, systemImage: "doc.fill").font(.caption)
                        } else {
                            Text("Not generated yet").foregroundStyle(.secondary)
                        }
                    }
                }
                .navigationTitle("Visit Settings")
            } else {
                ContentUnavailableView("No patient selected", systemImage: "sidebar.trailing")
            }
        }
    }
}

// MARK: - Atlas wrapper (used from exam workspace)

struct MedicalAtlasView: View {
    @Binding var selectedAnatomy: String?

    var body: some View {
        AnatomicalRealityView(selectedAnatomy: $selectedAnatomy)
            .background(.black.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
