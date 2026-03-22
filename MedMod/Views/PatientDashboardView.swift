import SwiftUI
import SwiftData

struct PatientDashboardView: View {
    @Query(sort: \PatientProfile.lastName) var patients: [PatientProfile]
    @State private var selectedPatient: PatientProfile?

    private var activePatient: PatientProfile? {
        selectedPatient ?? patients.first
    }

    var body: some View {
        NavigationStack {
            List {
                // Patient selector (if multiple)
                if patients.count > 1 {
                    Section {
                        ForEach(patients) { patient in
                            Button {
                                selectedPatient = patient
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "person.crop.circle.fill")
                                        .font(.title2)
                                        .foregroundColor(.purple)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("\(patient.firstName) \(patient.lastName)")
                                            .font(.headline)
                                        Text("\(patient.gender) • \(patient.dateOfBirth, format: .dateTime.month().day().year())")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    if patient.id == activePatient?.id {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.purple)
                                    }
                                }
                            }
                            .tint(.primary)
                        }
                    } header: {
                        Text("Patients")
                    }
                }

                // Demographics
                if let patient = activePatient {
                    Section("Demographics") {
                        LabeledContent("Name", value: "\(patient.firstName) \(patient.lastName)")
                        LabeledContent("DOB", value: patient.dateOfBirth.formatted(date: .abbreviated, time: .omitted))
                        LabeledContent("Gender", value: patient.gender)
                        LabeledContent("Smoking", value: patient.isSmoker ? "Yes" : "No")
                        LabeledContent("Records", value: "\(patient.clinicalRecords?.count ?? 0)")
                        LabeledContent("Active Rx", value: "\(patient.medications?.count ?? 0)")
                    }
                }

                // Navigation
                if let patient = activePatient {
                    Section("Chart") {
                        NavigationLink(destination: VisitHistoryView(patient: patient)) {
                            Label("Visit History", systemImage: "bed.double")
                        }
                        NavigationLink(destination: ChartNotesView(patient: patient)) {
                            Label("Chart Notes", systemImage: "folder")
                        }
                        NavigationLink(destination: RxListView(patient: patient)) {
                            Label("Medications", systemImage: "pills")
                        }
                    }

                    Section("Clinical AI") {
                        NavigationLink(destination: ClinicalExamView(patient: patient)) {
                            Label("3D Clinical Exam", systemImage: "waveform.path.ecg.rectangle")
                                .foregroundColor(.purple)
                        }
                        NavigationLink(destination: ClinicalAssistantView(patient: patient)) {
                            Label("AI Assistant", systemImage: "brain.head.profile")
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
            .navigationTitle(activePatient.map { "\($0.firstName) \($0.lastName)" } ?? "Patients")
            #if os(iOS)
            .listStyle(.insetGrouped)
            .navigationBarTitleDisplayMode(.large)
            #endif
        }
        .onAppear {
            if selectedPatient == nil {
                selectedPatient = patients.first
            }
        }
    }
}
