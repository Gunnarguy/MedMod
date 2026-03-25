import SwiftUI
import SwiftData

struct PatientDashboardView: View {
    @Query(sort: \PatientProfile.lastName) var patients: [PatientProfile]
    @State private var selectedPatient: PatientProfile?
    private var initialPatient: PatientProfile?

    init(patient: PatientProfile? = nil) {
        self.initialPatient = patient
    }

    private var activePatient: PatientProfile? {
        selectedPatient ?? patients.first
    }

    var body: some View {
        NavigationStack {
            Group {
                if let patient = activePatient {
                    patientContent(patient)
                } else {
                    ContentUnavailableView("No Patients", systemImage: "person.crop.circle.badge.questionmark", description: Text("Add a patient to get started."))
                }
            }
            .navigationTitle(activePatient?.fullName ?? "Patients")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
            .toolbar {
                if patients.count > 1 {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            ForEach(patients) { p in
                                Button {
                                    selectedPatient = p
                                } label: {
                                    Label(p.fullName, systemImage: p.id == activePatient?.id ? "checkmark.circle.fill" : "person.crop.circle")
                                }
                            }
                        } label: {
                            Label("Switch Patient", systemImage: "person.2.circle")
                        }
                    }
                }
            }
            .onAppear {
                if selectedPatient == nil {
                    selectedPatient = initialPatient ?? patients.first
                }
            }
        }
    }

    // MARK: - Patient Content

    private func clinicalAlerts(for patient: PatientProfile) -> [ClinicalAlert] {
        var alerts: [ClinicalAlert] = []
        let meds = patient.medications ?? []
        let medNames = meds.map { $0.medicationName.lowercased() }

        if medNames.contains(where: { $0.contains("methotrexate") }) {
            alerts.append(ClinicalAlert(
                icon: "pills.circle.fill", color: .red, title: "Methotrexate Monitoring",
                message: "Patient on methotrexate — verify CBC and LFTs within last 30 days."
            ))
        }
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
        if !patient.riskFlags.isEmpty {
            alerts.append(ClinicalAlert(
                icon: "flag.fill", color: .purple, title: "Risk Flags",
                message: patient.riskFlags.joined(separator: " • ")
            ))
        }
        return alerts
    }

    @ViewBuilder
    private func patientContent(_ patient: PatientProfile) -> some View {
        ScrollView {
            VStack(spacing: 16) {
                // Header card
                patientHeader(patient)

                // CDS Alerts (smart clinical decision support)
                let cdsAlerts = clinicalAlerts(for: patient)
                if !cdsAlerts.isEmpty {
                    cdsAlertsCard(cdsAlerts)
                }

                // Basic alerts: allergies + risk flags
                if !patient.allergies.isEmpty || !patient.riskFlags.isEmpty {
                    alertsCard(patient)
                }

                // Key metrics
                metricsRow(patient)

                // Care plan
                if let plan = patient.carePlanSummary, !plan.isEmpty {
                    carePlanCard(plan)
                }

                // Chart navigation
                chartLinksCard(patient)

                // Clinical AI
                aiLinksCard(patient)
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Header

    private func patientHeader(_ patient: PatientProfile) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 14) {
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.purple)

                VStack(alignment: .leading, spacing: 4) {
                    Text(patient.fullName)
                        .font(.title2.bold())
                    Text("\(patient.gender) · Age \(patient.age) · DOB \(patient.dateOfBirth.formatted(date: .abbreviated, time: .omitted))")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }

            Divider()

            Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 6) {
                GridRow {
                    detailLabel("MRN", value: patient.medicalRecordNumber)
                    detailLabel("Blood Type", value: patient.bloodType ?? "—")
                }
                GridRow {
                    detailLabel("Clinician", value: patient.primaryClinician ?? "Unassigned")
                    detailLabel("Smoking", value: patient.isSmoker ? "Yes" : "No")
                }
                GridRow {
                    detailLabel("Pharmacy", value: patient.preferredPharmacy ?? "—")
                    Spacer()
                }
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    private func detailLabel(_ label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.subheadline)
        }
    }

    // MARK: - CDS Alerts

    private func cdsAlertsCard(_ alerts: [ClinicalAlert]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Clinical Decision Support", systemImage: "brain.head.profile")
                .font(.subheadline.bold())
                .foregroundColor(.primary)
            ForEach(alerts, id: \.title) { alert in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: alert.icon)
                        .foregroundColor(alert.color)
                        .frame(width: 22)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(alert.title)
                            .font(.caption.bold())
                        Text(alert.message)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.red.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Alerts

    private func alertsCard(_ patient: PatientProfile) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(patient.allergies, id: \.self) { allergy in
                Label(allergy, systemImage: "exclamationmark.triangle.fill")
                    .font(.subheadline)
                    .foregroundColor(.orange)
            }
            ForEach(patient.riskFlags, id: \.self) { flag in
                Label(flag, systemImage: "flag.fill")
                    .font(.subheadline)
                    .foregroundColor(.red)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Metrics

    private func metricsRow(_ patient: PatientProfile) -> some View {
        HStack(spacing: 12) {
            metricTile(label: "Records", value: "\(patient.clinicalRecords?.count ?? 0)", icon: "doc.text", color: .blue)
            metricTile(label: "Active Rx", value: "\(patient.medications?.count ?? 0)", icon: "pills", color: .green)
            metricTile(label: "Appointments", value: "\(patient.appointments?.count ?? 0)", icon: "calendar", color: .purple)
        }
    }

    private func metricTile(label: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
            Text(value)
                .font(.title2.bold().monospacedDigit())
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Care Plan

    private func carePlanCard(_ plan: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Care Plan", systemImage: "heart.text.clipboard")
                .font(.subheadline.bold())
            Text(plan)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Chart Links

    private func chartLinksCard(_ patient: PatientProfile) -> some View {
        VStack(spacing: 0) {
            NavigationLink(destination: VisitHistoryView(patient: patient)) {
                chartRow(label: "Visit History", icon: "bed.double", color: .blue)
            }
            Divider().padding(.leading, 44)
            NavigationLink(destination: ChartNotesView(patient: patient)) {
                chartRow(label: "Chart Notes", icon: "folder", color: .indigo)
            }
            Divider().padding(.leading, 44)
            NavigationLink(destination: RxListView(patient: patient)) {
                chartRow(label: "Medications", icon: "pills", color: .green)
            }
            Divider().padding(.leading, 44)
            NavigationLink(destination: ClinicalPhotoView(patient: patient)) {
                chartRow(label: "Clinical Photos", icon: "camera.fill", color: .orange)
            }
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    private func chartRow(label: String, icon: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundColor(color)
                .frame(width: 28)
            Text(label)
                .font(.subheadline)
                .foregroundColor(.primary)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
    }

    // MARK: - AI Links

    private func aiLinksCard(_ patient: PatientProfile) -> some View {
        VStack(spacing: 0) {
            NavigationLink(destination: ClinicalExamView(patient: patient)) {
                chartRow(label: "3D Clinical Exam", icon: "waveform.path.ecg.rectangle", color: .purple)
            }
            Divider().padding(.leading, 44)
            NavigationLink(destination: ClinicIntelligenceView(patient: patient)) {
                chartRow(label: "AI Assistant", icon: "brain.head.profile", color: .blue)
            }
            Divider().padding(.leading, 44)
            NavigationLink(destination: LesionTrackingView(patient: patient)) {
                chartRow(label: "Lesion Tracking", icon: "chart.line.uptrend.xyaxis", color: .teal)
            }
            Divider().padding(.leading, 44)
            NavigationLink(destination: AnatomicalRealityView(patient: patient)) {
                chartRow(label: "Body Map", icon: "figure.stand", color: .red)
            }
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
    }
}
