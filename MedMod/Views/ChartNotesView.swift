import SwiftUI
import SwiftData

/// Chart Notes view — shows all clinical records with full structured note data (Image 3 / Image 9)
struct ChartNotesView: View {
    let patient: PatientProfile

    private var records: [LocalClinicalRecord] {
        (patient.clinicalRecords ?? []).sorted { $0.dateRecorded > $1.dateRecorded }
    }

    var body: some View {
        List {
            if records.isEmpty {
                ContentUnavailableView(
                    "No Chart Notes",
                    systemImage: "folder",
                    description: Text("Complete an exam workflow to generate structured chart notes via the on-device AI.")
                )
            } else {
                ForEach(records) { record in
                    NavigationLink(destination: VisitRecordDetailView(record: record, patient: patient)) {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(record.conditionName)
                                        .font(.headline)
                                    if let visitType = record.visitType {
                                        Text(visitType)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    Text(record.dateRecorded, format: .dateTime.month().day().year())
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 4) {
                                    Text(record.status)
                                        .font(.caption2.bold())
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(record.status == "Final" ? Color.green.opacity(0.15) : Color.orange.opacity(0.15))
                                        .foregroundColor(record.status == "Final" ? .green : .orange)
                                        .cornerRadius(4)
                                    if record.ccHPI != nil {
                                        Image(systemName: "doc.text.fill")
                                            .font(.caption)
                                            .foregroundColor(.purple)
                                    }
                                }
                            }

                            if let ccHPI = record.ccHPI, !ccHPI.isEmpty {
                                Text(ccHPI)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(2)
                            }

                            if let followUpPlan = record.followUpPlan, !followUpPlan.isEmpty {
                                Text(followUpPlan)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .navigationTitle("Chart Notes")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        .listStyle(.insetGrouped)
        #endif
    }
}
