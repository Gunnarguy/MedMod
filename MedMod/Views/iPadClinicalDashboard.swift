import SwiftUI
import SwiftData
import os

struct iPadClinicalDashboard: View {
    @Query(sort: \PatientProfile.lastName) private var patients: [PatientProfile]
    @State private var selectedPatientID: UUID?
    @StateObject private var workflowState = ClinicalWorkflowState()
    @State private var showInspector = false
    @State private var activeToolbarSection = "Chart"
    @State private var showExamFromToolbar = false

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
                .onAppear { AppLogger.dashboard.info("📋 Patient sidebar loaded — \(patients.count) patients") }
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
        .overlay(alignment: .bottom) {
            iPadClinicalToolbar(activeSection: $activeToolbarSection) { section in
                handleToolbarAction(section)
            }
            .padding(.bottom, 8)
        }
        .sheet(isPresented: $showExamFromToolbar) {
            if let patient = selectedPatient {
                NavigationStack {
                    ClinicalExamWorkspace(patient: patient, workflowState: workflowState)
                        .navigationTitle("Clinical Encounter")
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button("Done") { showExamFromToolbar = false }
                            }
                        }
                }
            }
        }
        .onChange(of: selectedPatientID) { oldVal, newVal in
            AppLogger.dashboard.info("👤 Patient selection changed: \(String(describing: oldVal)) → \(String(describing: newVal))")
            workflowState.reset()
        }
    }

    private func handleToolbarAction(_ section: String) {
        AppLogger.dashboard.info("🔧 Toolbar action: \(section)")
        switch section {
        case "Encounter":
            AppLogger.dashboard.info("🩺 Opening Clinical Encounter sheet")
            showExamFromToolbar = true
        case "Settings":
            AppLogger.dashboard.info("⚙️ Toggling inspector: \(!showInspector)")
            showInspector.toggle()
        default: break
        }
    }
}

// MARK: - Patient List Sidebar

struct PatientAgendaList: View {
    let patients: [PatientProfile]
    @Binding var selection: UUID?

    /// Today's patients sorted by appointment time (workflow order)
    private var todayPatients: [(patient: PatientProfile, appointment: Appointment)] {
        let cal = Calendar.current
        var pairs: [(patient: PatientProfile, appointment: Appointment)] = []
        for patient in patients {
            for appt in patient.appointments ?? [] {
                if cal.isDateInToday(appt.scheduledTime) {
                    pairs.append((patient, appt))
                }
            }
        }
        return pairs.sorted { $0.appointment.scheduledTime < $1.appointment.scheduledTime }
    }

    var body: some View {
        List(selection: $selection) {
            ForEach(todayPatients, id: \.appointment.id) { pair in
                NavigationLink(value: pair.patient.id) {
                    PatientAgendaRow(patient: pair.patient, appointment: pair.appointment)
                }
            }
        }
        #if os(iOS)
        .listStyle(.sidebar)
        #endif
        .onAppear {
            if selection == nil {
                selection = todayPatients.first?.patient.id
            }
        }
    }
}

struct PatientAgendaRow: View {
    let patient: PatientProfile
    let appointment: Appointment

    var body: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 2)
                .fill(AgendaView.workflowColor(for: appointment.status))
                .frame(width: 3, height: 36)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("\(patient.firstName) \(patient.lastName)")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Text(appointment.scheduledTime, format: .dateTime.hour().minute())
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text(appointment.reasonForVisit)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Spacer()
                    Text(appointment.status)
                        .font(.caption2.weight(.medium))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(AgendaView.workflowColor(for: appointment.status).opacity(0.15))
                        .foregroundStyle(AgendaView.workflowColor(for: appointment.status))
                        .clipShape(Capsule())
                }
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Chart Detail (no more inline atlas - atlas lives in exam workspace only)

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

    private var clinicalAlerts: [ClinicalAlert] {
        var alerts: [ClinicalAlert] = []
        let meds = patient.medications ?? []
        let medNames = meds.map { $0.medicationName.lowercased() }

        // Drug interaction: Methotrexate + NSAIDs
        if medNames.contains(where: { $0.contains("methotrexate") }) {
            alerts.append(ClinicalAlert(
                icon: "pills.circle.fill", color: .red, title: "Methotrexate Monitoring",
                message: "Patient on methotrexate — verify CBC and LFTs within last 30 days."
            ))
        }

        // Biologics monitoring
        if medNames.contains(where: { $0.contains("dupixent") || $0.contains("dupilumab") }) {
            alerts.append(ClinicalAlert(
                icon: "syringe.fill", color: .orange, title: "Biologic Therapy",
                message: "Dupixent patient — assess for conjunctivitis and injection site reactions."
            ))
        }

        if medNames.contains(where: { $0.contains("humira") || $0.contains("adalimumab") }) {
            alerts.append(ClinicalAlert(
                icon: "syringe.fill", color: .orange, title: "TNF Inhibitor",
                message: "Humira patient — screen for TB and monitor for infection signs."
            ))
        }

        // Smoker + skin cancer risk
        if patient.isSmoker && (patient.clinicalRecords ?? []).contains(where: {
            $0.conditionName.lowercased().contains("melanoma") || $0.conditionName.lowercased().contains("carcinoma")
        }) {
            alerts.append(ClinicalAlert(
                icon: "exclamationmark.triangle.fill", color: .red, title: "High-Risk Patient",
                message: "Current smoker with skin cancer history — prioritize full-body skin exam."
            ))
        } else if patient.isSmoker {
            alerts.append(ClinicalAlert(
                icon: "smoke.fill", color: .orange, title: "Smoking Status",
                message: "Current smoker — consider cessation counseling and wound healing implications."
            ))
        }

        // Allergy warnings
        let highRiskAllergies = patient.allergies.filter { a in
            let lower = a.lowercased()
            return lower.contains("penicillin") || lower.contains("sulfa") || lower.contains("latex") || lower.contains("nsaid")
        }
        if !highRiskAllergies.isEmpty {
            alerts.append(ClinicalAlert(
                icon: "allergens.fill", color: .yellow, title: "Allergy Alert",
                message: "Documented allergies: \(highRiskAllergies.joined(separator: ", "))"
            ))
        }

        // Risk flags
        if !patient.riskFlags.isEmpty {
            alerts.append(ClinicalAlert(
                icon: "flag.fill", color: .purple, title: "Risk Flags",
                message: patient.riskFlags.joined(separator: " • ")
            ))
        }

        return alerts
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

            // Clinical Decision Support Alerts
            if !clinicalAlerts.isEmpty {
                Section {
                    ForEach(clinicalAlerts, id: \.message) { alert in
                        HStack(spacing: 10) {
                            Image(systemName: alert.icon)
                                .foregroundColor(alert.color)
                                .font(.body.weight(.semibold))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(alert.title)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundColor(alert.color)
                                Text(alert.message)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                } header: {
                    Label("CLINICAL ALERTS", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.red)
                }
            }

            // Clinical actions
            Section("Clinical Workflow") {
                Button {
                    showingExamWorkspace = true
                } label: {
                    Label("Open Clinical Encounter", systemImage: "waveform.path.ecg.rectangle")
                }
                .tint(.purple)

                NavigationLink(destination: ClinicIntelligenceView(patient: patient)) {
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
                    .navigationTitle("Clinical Encounter")
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

// MARK: - Clinical Alert Model

struct ClinicalAlert {
    let icon: String
    let color: Color
    let title: String
    let message: String
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
                        LabeledContent("Name", value: patient.fullName)
                        LabeledContent("MRN", value: patient.medicalRecordNumber)
                        LabeledContent("DOB", value: patient.dateOfBirth.formatted(date: .abbreviated, time: .omitted))
                        LabeledContent("Age", value: "\(patient.age)")
                        LabeledContent("Gender", value: patient.gender)
                        LabeledContent("Smoking", value: patient.isSmoker ? "Yes" : "No")
                        LabeledContent("Clinician", value: patient.primaryClinician ?? "Not assigned")
                        LabeledContent("Pharmacy", value: patient.preferredPharmacy ?? "Not documented")
                    }

                    Section("AI Draft") {
                        if let note = workflowState.generatedNote {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(note.primaryDiagnosis).font(.headline)
                                Text(note.ccHPI)
                                Text(note.examFindings).font(.caption).foregroundStyle(.secondary)
                                Text(note.impressionsAndPlan).font(.caption).foregroundStyle(.secondary)
                                Text(note.followUpPlan).font(.caption).foregroundStyle(.secondary)
                            }
                        } else {
                            Text("Open Clinical Encounter to generate").foregroundStyle(.secondary)
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
                                    Text([rx.dose, rx.route, rx.frequency].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " | "))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    if let indication = rx.indication {
                                        Text(indication).font(.caption2).foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }

                    if let anatomy = workflowState.selectedAnatomy {
                        Section("Anatomical Focus") {
                            Text(AnatomicalRegion.displayName(for: anatomy))
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

// MedicalAtlasView removed — clinical encounters now use voice dictation + region picker
