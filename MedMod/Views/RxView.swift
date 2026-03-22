import SwiftUI
import SwiftData

// MARK: - Patient-scoped Rx List (Image 10)
struct RxListView: View {
    let patient: PatientProfile

    private var medications: [LocalMedication] {
        (patient.medications ?? []).sorted { $0.writtenDate > $1.writtenDate }
    }

    var body: some View {
        List {
            Section(header: Text("Active Prescriptions")) {
                if medications.isEmpty {
                    ContentUnavailableView(
                        "No Medications",
                        systemImage: "pills",
                        description: Text("Import clinical records via HealthKit or add medications through the exam workflow.")
                    )
                } else {
                    ForEach(medications) { rx in
                        RxRowView(rx: rx)
                    }
                }
            }

            Section {
                HStack {
                    Image(systemName: "info.circle")
                        .foregroundColor(.blue)
                    Text("Rx data sourced from local FHIR MedicationRequest records via HealthKit. Data never leaves this device.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle("Medications (Rx)")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        .listStyle(.insetGrouped)
        #endif
    }
}

struct RxRowView: View {
    let rx: LocalMedication

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(rx.medicationName)
                        .font(.headline)
                    Text(rx.quantityInfo)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(rx.refills) Refills")
                        .font(.caption.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(rx.refills > 0 ? Color.green.opacity(0.15) : Color.red.opacity(0.15))
                        .foregroundColor(rx.refills > 0 ? .green : .red)
                        .cornerRadius(6)
                }
            }
            HStack {
                Text("Prescribed: \(rx.writtenDate, format: .dateTime.month().day().year())")
                Spacer()
                Text("By: \(rx.writtenBy)")
            }
            .font(.caption2)
            .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

// (RxView removed — use patient-scoped RxListView instead)
