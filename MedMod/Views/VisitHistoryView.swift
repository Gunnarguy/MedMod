import SwiftUI
import SwiftData

struct VisitHistoryView: View {
    @Query(sort: \LocalClinicalRecord.dateRecorded, order: .reverse) private var records: [LocalClinicalRecord]

    var body: some View {
        List {
            Section(header: Text("Clinical History")) {
                if records.isEmpty {
                    Text("No past clinical records found.")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(records) { record in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(record.conditionName)
                                    .font(.headline)
                                Spacer()
                                Text(record.status)
                                    .font(.caption)
                                    .padding(4)
                                    .background(record.status == "Final" ? Color.green.opacity(0.2) : Color.orange.opacity(0.2))
                                    .foregroundColor(record.status == "Final" ? .green : .orange)
                                    .cornerRadius(4)
                            }
                            Text(record.dateRecorded, format: .dateTime.month().day().year())
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .navigationTitle("Visits & Records")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        .listStyle(.insetGrouped)
        #endif
    }
}
