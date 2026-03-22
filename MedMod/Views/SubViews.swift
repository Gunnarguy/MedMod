import SwiftUI
import SwiftData

// MARK: - Agenda View (Image 6 & 7)
struct AgendaView: View {
    @Query(sort: \PatientProfile.lastName) private var patients: [PatientProfile]

    var body: some View {
        NavigationStack {
            List {
                Section("Today's Schedule") {
                    ForEach(patients) { patient in
                        let upcoming = (patient.appointments ?? [])
                            .sorted { $0.scheduledTime < $1.scheduledTime }
                        ForEach(upcoming) { appt in
                            NavigationLink(destination: VisitHistoryView(patient: patient)) {
                                HStack(spacing: 12) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("\(patient.firstName) \(patient.lastName)")
                                            .font(.headline)
                                        Text(appt.reasonForVisit)
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    VStack(alignment: .trailing, spacing: 4) {
                                        Text(appt.scheduledTime, format: .dateTime.hour().minute())
                                            .font(.subheadline.monospacedDigit())
                                        Text(appt.status)
                                            .font(.caption2)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(appt.status == "Scheduled" ? Color.blue.opacity(0.15) : Color.gray.opacity(0.15))
                                            .foregroundColor(appt.status == "Scheduled" ? .blue : .gray)
                                            .cornerRadius(4)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                }

                Section("Quick Actions") {
                    ForEach(patients) { patient in
                        NavigationLink(destination: ClinicalExamView(patient: patient)) {
                            Label("New Exam: \(patient.firstName) \(patient.lastName)", systemImage: "waveform.path.ecg.rectangle")
                        }
                    }
                }
            }
            .navigationTitle("Agenda")
            #if os(iOS)
            .listStyle(.insetGrouped)
            #endif
        }
    }
}

// MARK: - IntraMail Inbox (Images 5 & 6)
struct InboxView: View {
    @State private var messages = InboxView.sampleMessages

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(messages) { message in
                        NavigationLink(destination: IntraMailDetailView(message: message)) {
                            HStack(spacing: 12) {
                                Circle()
                                    .fill(message.isRead ? Color.clear : Color.blue)
                                    .frame(width: 8, height: 8)

                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(message.sender)
                                            .font(message.isRead ? .subheadline : .subheadline.bold())
                                        Spacer()
                                        Text(message.date, format: .dateTime.month(.abbreviated).day())
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                    Text(message.subject)
                                        .font(.caption)
                                        .foregroundColor(.primary)
                                        .lineLimit(1)
                                    Text(message.preview)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                        .lineLimit(2)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
            }
            .navigationTitle("IntraMail")
            #if os(iOS)
            .listStyle(.insetGrouped)
            #endif
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {}) {
                        Image(systemName: "square.and.pencil")
                    }
                }
            }
        }
    }

    struct IntraMailMessage: Identifiable {
        let id = UUID()
        let sender: String
        let subject: String
        let preview: String
        let date: Date
        var isRead: Bool
    }

    static let sampleMessages: [IntraMailMessage] = [
        IntraMailMessage(sender: "Dr. Smith", subject: "Lab Results - Jane Doe",
                         preview: "Lipid panel results are back. Simvastatin appears effective, LDL down 22%.",
                         date: Date().addingTimeInterval(-3600), isRead: false),
        IntraMailMessage(sender: "Front Desk", subject: "Schedule Change - March 24",
                         preview: "Maria Santos rescheduled her follow-up to 3:00 PM on the 24th.",
                         date: Date().addingTimeInterval(-7200), isRead: false),
        IntraMailMessage(sender: "Dr. Jones", subject: "Referral: Mohs Surgery consult",
                         preview: "Referring Jane Doe for Mohs surgery evaluation on the BCC lesion, right upper extremity.",
                         date: Date().addingTimeInterval(-86400), isRead: false),
        IntraMailMessage(sender: "Lab", subject: "Pathology Report Available",
                         preview: "Biopsy results for specimen #2024-0847 are ready for review.",
                         date: Date().addingTimeInterval(-86400 * 2), isRead: true),
        IntraMailMessage(sender: "Admin", subject: "Compliance Training Due",
                         preview: "Annual HIPAA compliance training is due by end of month.",
                         date: Date().addingTimeInterval(-86400 * 3), isRead: true),
        IntraMailMessage(sender: "Dr. Patel", subject: "Re: Patient Transfer",
                         preview: "Confirmed receipt of transfer records. Will review and schedule intake.",
                         date: Date().addingTimeInterval(-86400 * 4), isRead: true),
        IntraMailMessage(sender: "Pharmacy", subject: "Prior Auth Required",
                         preview: "Prior authorization needed for cyclosporine 0.09% - insurance denied initial claim.",
                         date: Date().addingTimeInterval(-86400 * 5), isRead: true),
        IntraMailMessage(sender: "System", subject: "Chart Note Reminder",
                         preview: "You have 2 unsigned chart notes from last week's appointments.",
                         date: Date().addingTimeInterval(-86400 * 6), isRead: true),
        IntraMailMessage(sender: "Dr. Williams", subject: "Conference: Derm Grand Rounds",
                         preview: "Reminder: Grand Rounds presentation on advanced BCC management this Thursday.",
                         date: Date().addingTimeInterval(-86400 * 7), isRead: true),
    ]
}

struct IntraMailDetailView: View {
    let message: InboxView.IntraMailMessage

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text(message.sender)
                        .font(.headline)
                    Spacer()
                    Text(message.date, format: .dateTime.month().day().year().hour().minute())
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Text(message.subject)
                    .font(.title3.bold())

                Divider()

                Text(message.preview)
                    .font(.body)
            }
            .padding()
        }
        .navigationTitle("Message")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}
