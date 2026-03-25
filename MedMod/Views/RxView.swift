import SwiftUI
import SwiftData

// MARK: - Patient-scoped Rx List (Image 10)
struct RxListView: View {
    let patient: PatientProfile
    @State private var searchText = ""
    @State private var refillRequestedIDs: Set<String> = []

    private var medications: [LocalMedication] {
        (patient.medications ?? []).sorted { $0.writtenDate > $1.writtenDate }
    }

    private var filteredMedications: [LocalMedication] {
        guard !searchText.isEmpty else { return medications }
        let query = searchText.lowercased()
        return medications.filter {
            $0.medicationName.lowercased().contains(query)
            || ($0.genericName?.lowercased().contains(query) ?? false)
            || ($0.indication?.lowercased().contains(query) ?? false)
        }
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
                    ForEach(filteredMedications) { rx in
                        RxRowView(rx: rx, refillRequested: refillRequestedIDs.contains(rx.rxID)) {
                            withAnimation { _ = refillRequestedIDs.insert(rx.rxID) }
                        }
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
        .searchable(text: $searchText, prompt: "Search medications…")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        .listStyle(.insetGrouped)
        #endif
    }
}

struct RxRowView: View {
    let rx: LocalMedication
    var refillRequested: Bool = false
    var onRequestRefill: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(rx.medicationName)
                        .font(.headline)
                    Text(rx.genericName ?? rx.quantityInfo)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(rx.status ?? "Active")
                        .font(.caption.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(rx.status == "Active" ? Color.green.opacity(0.15) : Color.gray.opacity(0.15))
                        .foregroundColor(rx.status == "Active" ? .green : .gray)
                        .cornerRadius(6)
                }
            }
            Text([rx.dose, rx.route, rx.frequency].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " | "))
                .font(.caption)
                .foregroundColor(.secondary)
            if let indication = rx.indication {
                Text("Indication: \(indication)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            HStack {
                Text("Prescribed: \(rx.writtenDate, format: .dateTime.month().day().year())")
                Spacer()
                Text("By: \(rx.writtenBy)")
            }
            .font(.caption2)
            .foregroundColor(.secondary)
            if let lastFilledDate = rx.lastFilledDate {
                HStack {
                    Text("Last Filled: \(lastFilledDate, format: .dateTime.month().day().year())")
                    Spacer()
                    Text("Refills: \(rx.refills)")
                }
                .font(.caption2)
                .foregroundColor(.secondary)
            }
            if let nextRefillEligibleDate = rx.nextRefillEligibleDate {
                Text("Next Refill Eligible: \(nextRefillEligibleDate, format: .dateTime.month().day().year())")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            if let pharmacyName = rx.pharmacyName {
                Text("Pharmacy: \(pharmacyName)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            if let safetyNotes = rx.safetyNotes, !safetyNotes.isEmpty {
                Text("Safety: \(safetyNotes.joined(separator: "; "))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            // Refill request button
            if rx.hasRefillsRemaining {
                if refillRequested {
                    Label("Refill Requested", systemImage: "checkmark.circle.fill")
                        .font(.caption.bold())
                        .foregroundColor(.green)
                        .transition(.scale.combined(with: .opacity))
                } else {
                    Button {
                        onRequestRefill?()
                    } label: {
                        Label("Request Refill", systemImage: "arrow.clockwise")
                            .font(.caption.bold())
                    }
                    .buttonStyle(.bordered)
                    .tint(.blue)
                }
            } else if rx.refills == 0 {
                Label("No Refills — Contact Provider", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
        }
        .padding(.vertical, 4)
    }
}

// (RxView removed - use patient-scoped RxListView instead)
