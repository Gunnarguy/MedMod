import SwiftUI
import SwiftData

struct RxView: View {
    @Query(sort: \LocalMedication.writtenDate, order: .reverse) private var medications: [LocalMedication]

    var body: some View {
        List {
            Section(header: Text("Active Prescriptions")) {
                if medications.isEmpty {
                    Text("No active medications.")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(medications) { rx in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(rx.medicationName)
                                    .font(.headline)
                                Spacer()
                                Text("\(rx.refills) Refills")
                                    .font(.caption)
                                    .padding(4)
                                    .background(Color.purple.opacity(0.1))
                                    .foregroundColor(.purple)
                                    .cornerRadius(4)
                            }
                            Text(rx.quantityInfo)
                                .font(.subheadline)
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
            }
        }
        .navigationTitle("Medications (Rx)")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        .listStyle(.insetGrouped)
        #endif
    }
}
