import SwiftUI
import SwiftData
import os

// MARK: - Agenda View — ModMod Daily Workflow Tracker
struct AgendaView: View {
    @Query(sort: \PatientProfile.lastName) private var patients: [PatientProfile]
    @State private var filterStatus: String?

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

    private var filteredSchedule: [(patient: PatientProfile, appointment: Appointment)] {
        guard let filterStatus else { return todaySchedule }
        return todaySchedule.filter { $0.appointment.status == filterStatus }
    }

    /// Group labels in EMA/gPM workflow order.
    private static let workflowOrder = [
        "Completed", "Ready for Checkout", "In Exam", "Roomed",
        "Checked In", "Waiting triage", "Confirmed", "Scheduled"
    ]

    private var groupedByStatus: [(status: String, items: [(patient: PatientProfile, appointment: Appointment)])] {
        var dict: [String: [(PatientProfile, Appointment)]] = [:]
        for pair in filteredSchedule {
            dict[pair.appointment.status, default: []].append((pair.patient, pair.appointment))
        }
        return Self.workflowOrder.compactMap { status in
            guard let items = dict[status], !items.isEmpty else { return nil }
            return (status, items)
        }
    }

    private var statsCompleted: Int { todaySchedule.filter { $0.appointment.status == "Completed" }.count }
    private var statsInExam: Int { todaySchedule.filter { $0.appointment.status == "In Exam" }.count }
    private var statsWaiting: Int { todaySchedule.filter { ["Checked In", "Waiting triage", "Roomed"].contains($0.appointment.status) }.count }
    private var statsTotal: Int { Set(todaySchedule.map(\.patient.id)).count }
    private var statsRemaining: Int { todaySchedule.filter { !["Completed", "Ready for Checkout"].contains($0.appointment.status) }.count }

    private var nextUpPair: (patient: PatientProfile, appointment: Appointment)? {
        todaySchedule.first { $0.appointment.status == "Checked In" || $0.appointment.status == "Waiting triage" || $0.appointment.status == "Roomed" }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // ── Context bar (mirrors Intelligence) ──
                HStack(spacing: 8) {
                    HStack(spacing: 5) {
                        Circle()
                            .fill(todaySchedule.isEmpty ? .orange : .green)
                            .frame(width: 6, height: 6)
                        Text(Date.now, format: .dateTime.weekday(.wide).month(.abbreviated).day())
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer()

                    if let filterStatus {
                        Button {
                            withAnimation { self.filterStatus = nil }
                        } label: {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(Self.workflowColor(for: filterStatus))
                                    .frame(width: 6, height: 6)
                                Text(filterStatus)
                                    .font(.caption2.bold())
                                Image(systemName: "xmark")
                                    .font(.system(size: 8, weight: .bold))
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Self.workflowColor(for: filterStatus).opacity(0.15), in: Capsule())
                            .foregroundStyle(Self.workflowColor(for: filterStatus))
                        }
                        .buttonStyle(.plain)
                    }

                    HStack(spacing: 4) {
                        Image(systemName: "calendar.badge.clock")
                        Text("\(todaySchedule.count) today")
                            .fontWeight(.medium)
                    }
                    .font(.caption)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(.purple.opacity(0.12), in: Capsule())
                    .foregroundStyle(.purple)
                }
                .padding(.horizontal)
                .padding(.top, 8)

                // ── Quick-filter status pills (horizontal scroll) ──
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Self.workflowOrder.reversed(), id: \.self) { status in
                            let count = todaySchedule.filter { $0.appointment.status == status }.count
                            if count > 0 {
                                Button {
                                    withAnimation {
                                        filterStatus = filterStatus == status ? nil : status
                                    }
                                } label: {
                                    HStack(spacing: 4) {
                                        Circle()
                                            .fill(Self.workflowColor(for: status))
                                            .frame(width: 6, height: 6)
                                        Text("\(status) (\(count))")
                                            .font(.caption)
                                            .lineLimit(1)
                                    }
                                }
                                .buttonStyle(.bordered)
                                .tint(filterStatus == status ? Self.workflowColor(for: status) : .secondary)
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }

                Divider()

                // ── Metric tiles ──
                HStack(spacing: 10) {
                    AgendaMetricTile(label: "Patients", value: "\(statsTotal)", icon: "person.2", color: .purple)
                    AgendaMetricTile(label: "In Exam", value: "\(statsInExam)", icon: "stethoscope", color: .orange)
                    AgendaMetricTile(label: "Waiting", value: "\(statsWaiting)", icon: "clock", color: .blue)
                    AgendaMetricTile(label: "Done", value: "\(statsCompleted)", icon: "checkmark.circle", color: .green)
                }
                .padding(.horizontal)
                .padding(.vertical, 10)

                // ── Next Up card ──
                if let nextUp = nextUpPair {
                    HStack(spacing: 12) {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.purple)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Next Up")
                                .font(.caption2.bold())
                                .foregroundStyle(.purple)
                            Text("\(nextUp.patient.firstName) \(nextUp.patient.lastName) — \(nextUp.appointment.reasonForVisit)")
                                .font(.subheadline.weight(.medium))
                                .lineLimit(1)
                        }
                        Spacer()
                        Text(nextUp.appointment.scheduledTime, format: .dateTime.hour().minute())
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                        Text(nextUp.appointment.status)
                            .font(.caption2.weight(.medium))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Self.workflowColor(for: nextUp.appointment.status).opacity(0.15), in: Capsule())
                            .foregroundStyle(Self.workflowColor(for: nextUp.appointment.status))
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.secondarySystemGroupedBackground))
                            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.purple.opacity(0.15), lineWidth: 1))
                    )
                    .padding(.horizontal)
                    .padding(.bottom, 6)
                }

                // ── Workflow Groups (List for swipe support) ──
                List {
                    if todaySchedule.isEmpty {
                        ContentUnavailableView(
                            "No Appointments Today",
                            systemImage: "calendar.badge.exclamationmark",
                            description: Text("Today's schedule is empty. Appointments will appear here on clinic days.")
                        )
                        .listRowBackground(Color.clear)
                    }

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
                                    .fill(Self.workflowColor(for: group.status))
                                    .frame(width: 8, height: 8)
                                Text(group.status.uppercased())
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text("\(group.items.count)")
                                    .font(.caption2.weight(.medium).monospacedDigit())
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Self.workflowColor(for: group.status).opacity(0.12), in: Capsule())
                                    .foregroundStyle(Self.workflowColor(for: group.status))
                            }
                        }
                    }
                }
                #if os(iOS)
                .listStyle(.insetGrouped)
                #endif
            }
            .navigationTitle("Today's Schedule")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 4) {
                        Text("\(statsRemaining) left")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        // Progress ring
                        ZStack {
                            Circle()
                                .stroke(Color(.tertiarySystemFill), lineWidth: 2.5)
                            Circle()
                                .trim(from: 0, to: todaySchedule.isEmpty ? 0 : Double(statsCompleted) / Double(todaySchedule.count))
                                .stroke(Color.green, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                                .rotationEffect(.degrees(-90))
                        }
                        .frame(width: 20, height: 20)
                    }
                }
            }
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

// MARK: - Agenda Metric Tile
private struct AgendaMetricTile: View {
    let label: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 5) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)
            Text(value)
                .font(.title3.bold().monospacedDigit())
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.tertiarySystemGroupedBackground))
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(color.opacity(0.12), lineWidth: 1))
        )
    }
}

// MARK: - Agenda Row
private struct AgendaRow: View {
    let patient: PatientProfile
    let appointment: Appointment

    private var activeMedCount: Int {
        (patient.medications ?? []).filter { ($0.status ?? "Active") == "Active" }.count
    }

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
                .frame(width: 3, height: 44)

            // Patient details
            VStack(alignment: .leading, spacing: 4) {
                Text("\(patient.firstName) \(patient.lastName)")
                    .font(.subheadline.weight(.semibold))
                Text(appointment.reasonForVisit)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                HStack(spacing: 8) {
                    if let type = appointment.encounterType {
                        Text(type)
                            .font(.system(size: 9).weight(.medium))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color(.tertiarySystemFill), in: Capsule())
                            .foregroundStyle(.secondary)
                    }
                    if activeMedCount > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "pills")
                                .font(.system(size: 8))
                            Text("\(activeMedCount)")
                                .font(.system(size: 9))
                        }
                        .foregroundStyle(.green)
                    }
                    if patient.isSmoker {
                        Image(systemName: "smoke")
                            .font(.system(size: 8))
                            .foregroundStyle(.orange)
                    }
                }
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
        .padding(.vertical, 3)
    }
}

// MARK: - IntraMail Inbox (Images 5 & 6)
struct InboxView: View {
    @State private var messages = InboxView.sampleMessages
    @State private var filterCategory: MessageCategory?

    private var unreadCount: Int { messages.filter { !$0.isRead }.count }

    private var filteredMessages: [IntraMailMessage] {
        guard let filterCategory else { return messages }
        return messages.filter { $0.category == filterCategory }
    }

    enum MessageCategory: String, CaseIterable {
        case clinical = "Clinical"
        case lab = "Lab"
        case admin = "Admin"
        case pharmacy = "Pharmacy"
        case scheduling = "Scheduling"

        var icon: String {
            switch self {
            case .clinical: return "stethoscope"
            case .lab: return "flask"
            case .admin: return "building.2"
            case .pharmacy: return "pills"
            case .scheduling: return "calendar"
            }
        }

        var color: Color {
            switch self {
            case .clinical: return .purple
            case .lab: return .blue
            case .admin: return .gray
            case .pharmacy: return .green
            case .scheduling: return .orange
            }
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Context bar
                HStack(spacing: 8) {
                    HStack(spacing: 5) {
                        Circle()
                            .fill(unreadCount > 0 ? .blue : .green)
                            .frame(width: 6, height: 6)
                        Text(unreadCount > 0 ? "\(unreadCount) unread" : "All read")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if let filterCategory {
                        Button {
                            withAnimation { self.filterCategory = nil }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: filterCategory.icon)
                                    .font(.system(size: 9))
                                Text(filterCategory.rawValue)
                                    .font(.caption2.bold())
                                Image(systemName: "xmark")
                                    .font(.system(size: 8, weight: .bold))
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(filterCategory.color.opacity(0.15), in: Capsule())
                            .foregroundStyle(filterCategory.color)
                        }
                        .buttonStyle(.plain)
                    }

                    HStack(spacing: 4) {
                        Image(systemName: "envelope.fill")
                        Text("\(messages.count) messages")
                            .fontWeight(.medium)
                    }
                    .font(.caption)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(.purple.opacity(0.12), in: Capsule())
                    .foregroundStyle(.purple)
                }
                .padding(.horizontal)
                .padding(.top, 8)

                // Category filter pills
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(MessageCategory.allCases, id: \.self) { cat in
                            let count = messages.filter { $0.category == cat }.count
                            if count > 0 {
                                Button {
                                    withAnimation {
                                        filterCategory = filterCategory == cat ? nil : cat
                                    }
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: cat.icon)
                                            .font(.system(size: 9))
                                        Text("\(cat.rawValue) (\(count))")
                                            .font(.caption)
                                    }
                                }
                                .buttonStyle(.bordered)
                                .tint(filterCategory == cat ? cat.color : .secondary)
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }

                Divider()

                List {
                    ForEach(filteredMessages) { message in
                        NavigationLink(destination: IntraMailDetailView(message: message)) {
                            InboxMessageRow(message: message)
                        }
                    }
                }
                #if os(iOS)
                .listStyle(.insetGrouped)
                #endif
            }
            .navigationTitle("IntraMail")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {}) {
                        Image(systemName: "square.and.pencil")
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    if unreadCount > 0 {
                        Button {
                            withAnimation {
                                for i in messages.indices { messages[i].isRead = true }
                            }
                        } label: {
                            Text("Read All")
                                .font(.caption)
                        }
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
        var category: MessageCategory

        var priorityColor: Color {
            if !isRead { return .blue }
            return .clear
        }
    }

    static let sampleMessages: [IntraMailMessage] = [
        IntraMailMessage(sender: "Dr. Smith", subject: "Lab Results - Catherine Hartley",
                         preview: "Lipid panel results are back. Simvastatin appears effective, LDL down 22%.",
                         date: Date().addingTimeInterval(-3600), isRead: false, category: .lab),
        IntraMailMessage(sender: "Front Desk", subject: "Schedule Change - March 24",
                         preview: "Maria Santos rescheduled her follow-up to 3:00 PM on the 24th.",
                         date: Date().addingTimeInterval(-7200), isRead: false, category: .scheduling),
        IntraMailMessage(sender: "Dr. Jones", subject: "Referral: Mohs Surgery consult",
                         preview: "Referring Catherine Hartley for Mohs surgery evaluation on the BCC lesion, right upper extremity.",
                         date: Date().addingTimeInterval(-86400), isRead: false, category: .clinical),
        IntraMailMessage(sender: "Lab", subject: "Pathology Report Available",
                         preview: "Biopsy results for specimen #2024-0847 are ready for review.",
                         date: Date().addingTimeInterval(-86400 * 2), isRead: true, category: .lab),
        IntraMailMessage(sender: "Admin", subject: "Compliance Training Due",
                         preview: "Annual HIPAA compliance training is due by end of month.",
                         date: Date().addingTimeInterval(-86400 * 3), isRead: true, category: .admin),
        IntraMailMessage(sender: "Dr. Patel", subject: "Re: Patient Transfer",
                         preview: "Confirmed receipt of transfer records. Will review and schedule intake.",
                         date: Date().addingTimeInterval(-86400 * 4), isRead: true, category: .clinical),
        IntraMailMessage(sender: "Pharmacy", subject: "Prior Auth Required",
                         preview: "Prior authorization needed for cyclosporine 0.09% - insurance denied initial claim.",
                         date: Date().addingTimeInterval(-86400 * 5), isRead: true, category: .pharmacy),
        IntraMailMessage(sender: "System", subject: "Chart Note Reminder",
                         preview: "You have 2 unsigned chart notes from last week's appointments.",
                         date: Date().addingTimeInterval(-86400 * 6), isRead: true, category: .admin),
        IntraMailMessage(sender: "Dr. Williams", subject: "Conference: Derm Grand Rounds",
                         preview: "Reminder: Grand Rounds presentation on advanced BCC management this Thursday.",
                         date: Date().addingTimeInterval(-86400 * 7), isRead: true, category: .clinical),
    ]
}

// MARK: - Inbox Message Row
private struct InboxMessageRow: View {
    let message: InboxView.IntraMailMessage

    var body: some View {
        HStack(spacing: 12) {
            // Category icon with colored background
            Image(systemName: message.category.icon)
                .font(.caption)
                .foregroundStyle(message.category.color)
                .frame(width: 30, height: 30)
                .background(message.category.color.opacity(0.12), in: RoundedRectangle(cornerRadius: 7))

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    if !message.isRead {
                        Circle()
                            .fill(.blue)
                            .frame(width: 7, height: 7)
                    }
                    Text(message.sender)
                        .font(message.isRead ? .subheadline : .subheadline.bold())
                    Spacer()
                    Text(message.date, format: .dateTime.month(.abbreviated).day())
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Text(message.subject)
                    .font(.caption)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(message.preview)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
        }
        .padding(.vertical, 3)
    }
}

struct IntraMailDetailView: View {
    let message: InboxView.IntraMailMessage

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header card
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 10) {
                        Image(systemName: message.category.icon)
                            .font(.body)
                            .foregroundStyle(message.category.color)
                            .frame(width: 34, height: 34)
                            .background(message.category.color.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(message.sender)
                                .font(.headline)
                            Text(message.date, format: .dateTime.month().day().year().hour().minute())
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(message.category.rawValue)
                            .font(.caption2.weight(.medium))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(message.category.color.opacity(0.15), in: Capsule())
                            .foregroundStyle(message.category.color)
                    }

                    Text(message.subject)
                        .font(.title3.bold())
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.secondarySystemGroupedBackground))
                        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.primary.opacity(0.06), lineWidth: 1))
                )

                // Body
                Text(message.preview)
                    .font(.body)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.secondarySystemGroupedBackground))
                            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.primary.opacity(0.06), lineWidth: 1))
                    )
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Message")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}
