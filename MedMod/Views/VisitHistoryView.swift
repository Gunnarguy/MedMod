import SwiftUI
import SwiftData

struct VisitHistoryView: View {
    let patient: PatientProfile

    private var records: [LocalClinicalRecord] {
        (patient.clinicalRecords ?? []).sorted { $0.dateRecorded > $1.dateRecorded }
    }

    var body: some View {
        List {
            Section(header: Text("Clinical History")) {
                if records.isEmpty {
                    Text("No past clinical records found.")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(records) { record in
                        NavigationLink(destination: VisitRecordDetailView(record: record, patient: patient)) {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(record.conditionName)
                                            .font(.headline)
                                        if let visitType = record.visitType {
                                            Text(visitType)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    Spacer()
                                    VStack(alignment: .trailing, spacing: 4) {
                                        Text(record.status)
                                            .font(.caption)
                                            .padding(4)
                                            .background(record.status == "Final" ? Color.green.opacity(0.2) : Color.orange.opacity(0.2))
                                            .foregroundColor(record.status == "Final" ? .green : .orange)
                                            .cornerRadius(4)
                                        if let severity = record.severity {
                                            Text(severity)
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                                Text(record.dateRecorded, format: .dateTime.month().day().year())
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                if let ccHPI = record.ccHPI, !ccHPI.isEmpty {
                                    Text(ccHPI)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .lineLimit(2)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }

            Section(header: Text("Appointments")) {
                let appointments = (patient.appointments ?? []).sorted { $0.scheduledTime > $1.scheduledTime }
                if appointments.isEmpty {
                    Text("No appointments scheduled.")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(appointments) { appt in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(appt.reasonForVisit)
                                    .font(.headline)
                                Spacer()
                                VStack(alignment: .trailing, spacing: 4) {
                                    Text(appt.status)
                                        .font(.caption)
                                        .padding(4)
                                        .background(appt.status == "Scheduled" ? Color.blue.opacity(0.2) : Color.gray.opacity(0.2))
                                        .foregroundColor(appt.status == "Scheduled" ? .blue : .gray)
                                        .cornerRadius(4)
                                    Text(appt.checkInStatus ?? "")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                            Text(appt.scheduledTime, format: .dateTime.month().day().year().hour().minute())
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Text("\(appt.encounterType ?? "Follow-up") | \(appt.clinicianName ?? "")")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(appt.location ?? "")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            if let linkedDiagnoses = appt.linkedDiagnoses, !linkedDiagnoses.isEmpty {
                                Text("Linked: \(linkedDiagnoses.joined(separator: ", "))")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
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

// MARK: - Visit Record Detail (Image 9 style)
struct VisitRecordDetailView: View {
    let record: LocalClinicalRecord
    let patient: PatientProfile

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                HStack {
                    Text("Visit Note")
                        .font(.title2.bold())
                        .foregroundColor(.purple)
                    Spacer()
                    Text(record.dateRecorded, format: .dateTime.month().day().year())
                        .foregroundColor(.secondary)
                }

                Divider()

                Group {
                    if let ccHPI = record.ccHPI, !ccHPI.isEmpty {
                        noteSection(title: "Chief Complaint / HPI", content: ccHPI)
                    }

                    if let ros = record.reviewOfSystems, !ros.isEmpty {
                        noteSection(title: "Review of Systems", content: ros)
                    }

                    if let exam = record.examFindings, !exam.isEmpty {
                        noteSection(title: "Exam Findings", content: exam)
                    }

                    noteSection(title: "Diagnosis / Condition", content: record.conditionName)

                    if let plan = record.impressionsAndPlan, !plan.isEmpty {
                        noteSection(title: "Impression & Plan", content: plan)
                    }

                    if let instructions = record.patientInstructions, !instructions.isEmpty {
                        noteSection(title: "Patient Instructions", content: instructions)
                    }

                    if let followUpPlan = record.followUpPlan, !followUpPlan.isEmpty {
                        noteSection(title: "Follow-Up", content: followUpPlan)
                    }

                    if let recommendedOrders = record.recommendedOrders, !recommendedOrders.isEmpty {
                        noteSection(title: "Orders / Referrals", content: recommendedOrders.joined(separator: "\n- ").withLeadingDash)
                    }

                    if let carePlanSummary = record.carePlanSummary, !carePlanSummary.isEmpty {
                        noteSection(title: "Care Plan Summary", content: carePlanSummary)
                    }

                    if let zones = record.affectedAnatomicalZones, !zones.isEmpty {
                        noteSection(title: "Affected Anatomical Zones", content: zones.map { AnatomicalRegion.displayName(for: $0) }.joined(separator: ", "))
                    }
                }

                Divider()

                HStack {
                    Text("Status: \(record.status)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    if let sig = record.providerSignature, !sig.isEmpty {
                        Text("Signed by: \(sig)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
        }
        .navigationTitle(record.conditionName)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private func noteSection(title: String, content: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline.bold())
                .foregroundColor(.purple)
            Text(content)
                .font(.body)
        }
    }
}

private extension String {
    var withLeadingDash: String {
        isEmpty ? self : "- \(self)"
    }
}
