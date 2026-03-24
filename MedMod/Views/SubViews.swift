import SwiftUI
import SwiftData
import os

// MARK: - Agenda View — ModMod Daily Workflow Tracker
struct AgendaView: View {
    @Query(sort: \PatientProfile.lastName) private var patients: [PatientProfile]

    /// Flattened today-only appointments paired with their patient, sorted by time.
    private var todaySchedule: [(patient: PatientProfile, appointment: Appointment)] {
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

    /// Group labels in EMA/gPM workflow order.
    private static let workflowOrder = [
        "Completed", "Ready for Checkout", "In Exam", "Roomed",
        "Checked In", "Waiting triage", "Confirmed", "Scheduled"
    ]

    private var groupedByStatus: [(status: String, items: [(patient: PatientProfile, appointment: Appointment)])] {
        var dict: [String: [(PatientProfile, Appointment)]] = [:]
        for pair in todaySchedule {
            dict[pair.appointment.status, default: []].append((pair.patient, pair.appointment))
        }
        return Self.workflowOrder.compactMap { status in
            guard let items = dict[status], !items.isEmpty else { return nil }
            return (status, items)
        }
    }

    private var statsCompleted: Int { todaySchedule.filter { $0.appointment.status == "Completed" }.count }
    private var statsTotal: Int { todaySchedule.count }

    var body: some View {
        NavigationStack {
            List {
                // ── Clinic Snapshot ──
                Section {
                    HStack(spacing: 16) {
                        StatPill(label: "Patients", value: "\(statsTotal)")
                        StatPill(label: "Completed", value: "\(statsCompleted)")
                        StatPill(label: "Remaining", value: "\(statsTotal - statsCompleted)")
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                }

                // ── Workflow Groups ──
                ForEach(groupedByStatus, id: \.status) { group in
                    Section {
                        ForEach(group.items, id: \.appointment.id) { pair in
                            NavigationLink(destination: PatientDashboardView(patient: pair.patient)) {
                                AgendaRow(patient: pair.patient, appointment: pair.appointment)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                if let next = Self.nextStatus(after: pair.appointment.status) {
                                    Button {
                                        AppLogger.agenda.info("➡️ Swipe advance: \(pair.patient.fullName) \(pair.appointment.status) → \(next)")
                                        withAnimation { pair.appointment.status = next }
                                    } label: {
                                        Label(next, systemImage: "chevron.right.circle.fill")
                                    }
                                    .tint(Self.workflowColor(for: next))
                                }
                            }
                            .swipeActions(edge: .leading, allowsFullSwipe: false) {
                                if let prev = Self.previousStatus(before: pair.appointment.status) {
                                    Button {
                                        AppLogger.agenda.info("⬅️ Swipe regress: \(pair.patient.fullName) \(pair.appointment.status) → \(prev)")
                                        withAnimation { pair.appointment.status = prev }
                                    } label: {
                                        Label(prev, systemImage: "chevron.left.circle.fill")
                                    }
                                    .tint(.secondary)
                                }
                            }
                        }
                    } header: {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(workflowColor(for: group.status))
                                .frame(width: 8, height: 8)
                            Text(group.status.uppercased())
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("\(group.items.count)")
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
            }
            .navigationTitle("Today's Schedule")
            #if os(iOS)
            .listStyle(.insetGrouped)
            #endif
        }
    }

    // MARK: Workflow Status Progression (swipe to advance/regress)
    private static let statusProgression = [
        "Scheduled", "Confirmed", "Checked In", "Waiting triage",
        "Roomed", "In Exam", "Ready for Checkout", "Completed"
    ]

    static func nextStatus(after current: String) -> String? {
        guard let idx = statusProgression.firstIndex(of: current),
              idx + 1 < statusProgression.count else { return nil }
        return statusProgression[idx + 1]
    }

    static func previousStatus(before current: String) -> String? {
        guard let idx = statusProgression.firstIndex(of: current),
              idx > 0 else { return nil }
        return statusProgression[idx - 1]
    }

    // MARK: Workflow Status Colors (mirrors ModMed EMA status chips)
    static func workflowColor(for status: String) -> Color {
        switch status {
        case "Completed":           return .green
        case "Ready for Checkout":  return .mint
        case "In Exam":             return .orange
        case "Roomed":              return .yellow
        case "Checked In":          return .blue
        case "Waiting triage":      return .purple
        case "Confirmed":           return .teal
        case "Scheduled":           return .gray
        default:                    return .secondary
        }
    }

    private func workflowColor(for status: String) -> Color {
        Self.workflowColor(for: status)
    }
}

// MARK: - Agenda Row
private struct AgendaRow: View {
    let patient: PatientProfile
    let appointment: Appointment

    var body: some View {
        HStack(spacing: 12) {
            // Time column
            VStack(spacing: 2) {
                Text(appointment.scheduledTime, format: .dateTime.hour().minute())
                    .font(.subheadline.monospacedDigit().weight(.medium))
                if let dur = appointment.durationMinutes {
                    Text("\(dur)m")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .frame(width: 52, alignment: .trailing)

            // Vertical accent bar
            RoundedRectangle(cornerRadius: 2)
                .fill(AgendaView.workflowColor(for: appointment.status))
                .frame(width: 3, height: 38)

            // Patient details
            VStack(alignment: .leading, spacing: 3) {
                Text("\(patient.firstName) \(patient.lastName)")
                    .font(.subheadline.weight(.semibold))
                Text(appointment.reasonForVisit)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            // Status chip
            Text(appointment.status)
                .font(.caption2.weight(.medium))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(AgendaView.workflowColor(for: appointment.status).opacity(0.15))
                .foregroundStyle(AgendaView.workflowColor(for: appointment.status))
                .clipShape(Capsule())
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Stat Pill
private struct StatPill: View {
    let label: String
    let value: String
    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.title2.weight(.bold).monospacedDigit())
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
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
        IntraMailMessage(sender: "Dr. Smith", subject: "Lab Results - Catherine Hartley",
                         preview: "Lipid panel results are back. Simvastatin appears effective, LDL down 22%.",
                         date: Date().addingTimeInterval(-3600), isRead: false),
        IntraMailMessage(sender: "Front Desk", subject: "Schedule Change - March 24",
                         preview: "Maria Santos rescheduled her follow-up to 3:00 PM on the 24th.",
                         date: Date().addingTimeInterval(-7200), isRead: false),
        IntraMailMessage(sender: "Dr. Jones", subject: "Referral: Mohs Surgery consult",
                         preview: "Referring Catherine Hartley for Mohs surgery evaluation on the BCC lesion, right upper extremity.",
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
