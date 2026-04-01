import SwiftUI
import SwiftData
import os

struct iPadClinicalDashboard: View {
    @Query(sort: \PatientProfile.lastName) private var patients: [PatientProfile]
    @State private var selectedPatientID: UUID?

    private var selectedPatient: PatientProfile? {
        if let selectedPatientID {
            return patients.first(where: { $0.id == selectedPatientID })
        }
        return patients.first
    }

    var body: some View {
        NavigationSplitView {
            PatientAgendaList(patients: patients, selection: $selectedPatientID)
                .navigationTitle("Today’s Patients")
                .onAppear { AppLogger.dashboard.info("📋 Patient sidebar loaded — \(patients.count) patients") }
        } detail: {
            if let patient = selectedPatient {
                NavigationStack {
                    PatientChartPageView(patient: patient)
                }
            } else {
                ContentUnavailableView(
                    "Select a Patient",
                    systemImage: "person.crop.circle.badge.questionmark",
                    description: Text("Choose a patient from the sidebar to view their chart.")
                )
            }
        }
        .onChange(of: selectedPatientID) { oldVal, newVal in
            AppLogger.dashboard.info("👤 Patient selection changed: \(String(describing: oldVal)) → \(String(describing: newVal))")
        }
    }
}

// MARK: - Patient List Sidebar

struct PatientAgendaList: View {
    let patients: [PatientProfile]
    @Binding var selection: UUID?
    @State private var searchText = ""

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
        let sorted = pairs.sorted { $0.appointment.scheduledTime < $1.appointment.scheduledTime }
        guard !searchText.isEmpty else { return sorted }
        let needle = searchText.lowercased()
        return sorted.filter { pair in
            pair.patient.fullName.lowercased().contains(needle)
                || pair.patient.medicalRecordNumber.lowercased().contains(needle)
                || pair.appointment.reasonForVisit.lowercased().contains(needle)
        }
    }

    private var rosterPatients: [PatientProfile] {
        guard !searchText.isEmpty else { return patients }
        let needle = searchText.lowercased()
        return patients.filter { patient in
            patient.fullName.lowercased().contains(needle)
                || patient.medicalRecordNumber.lowercased().contains(needle)
                || (patient.primaryClinician?.lowercased().contains(needle) ?? false)
        }
    }

    var body: some View {
        List(selection: $selection) {
            if !todayPatients.isEmpty {
                Section("Today") {
                    ForEach(todayPatients, id: \.appointment.id) { pair in
                        NavigationLink(value: pair.patient.id) {
                            PatientAgendaRow(patient: pair.patient, appointment: pair.appointment)
                        }
                    }
                }
            }

            Section(todayPatients.isEmpty ? "Patients" : "All Patients") {
                ForEach(rosterPatients, id: \.id) { patient in
                    NavigationLink(value: patient.id) {
                        PatientRosterRow(patient: patient)
                    }
                }
            }
        }
        #if os(iOS)
        .listStyle(.sidebar)
        #endif
        .searchable(text: $searchText, prompt: "Search patient, MRN, visit reason")
        .onAppear {
            if selection == nil {
                selection = todayPatients.first?.patient.id ?? rosterPatients.first?.id
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
                        .clinicalFinePrintMonospaced()
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                }
                HStack {
                    Text(appointment.reasonForVisit)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .clinicalFinePrint()
                        .clinicalRowSummaryText()
                    Spacer()
                    Text(AgendaView.workflowPillLabel(for: appointment.status))
                        .clinicalPillText(weight: .medium)
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

private struct PatientRosterRow: View {
    let patient: PatientProfile

    private var nextAppointment: Appointment? {
        (patient.appointments ?? []).sorted { $0.scheduledTime < $1.scheduledTime }.first
    }

    private var activeMedicationCount: Int {
        (patient.medications ?? []).filter { ($0.status ?? "Active") == "Active" }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(patient.fullName)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("MRN \(patient.medicalRecordNumber)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .clinicalFinePrint()
            }

            HStack(spacing: 10) {
                Text("\(patient.age)y")
                Text(patient.gender)
                Text("\(activeMedicationCount) active Rx")
                Text("\(patient.clinicalRecords?.count ?? 0) records")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .clinicalFinePrint()

            if let nextAppointment {
                Text("Next: \(nextAppointment.scheduledTime.formatted(date: .abbreviated, time: .shortened)) • \(nextAppointment.reasonForVisit)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .clinicalFinePrint()
                    .clinicalRowSummaryText()
            }
        }
        .padding(.vertical, 3)
    }
}

// MARK: - Clinical Alert Model

struct ClinicalAlert {
    let icon: String
    let color: Color
    let title: String
    let message: String
}
