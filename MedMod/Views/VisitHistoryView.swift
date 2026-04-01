import SwiftUI
import SwiftData

struct VisitHistoryView: View {
    let patient: PatientProfile
    @State private var searchText = ""

    private var records: [LocalClinicalRecord] {
        (patient.clinicalRecords ?? []).sorted { $0.dateRecorded > $1.dateRecorded }
    }

    private var filteredRecords: [LocalClinicalRecord] {
        guard !searchText.isEmpty else { return records }
        let query = searchText.lowercased()
        return records.filter {
            $0.conditionName.lowercased().contains(query)
            || ($0.ccHPI?.lowercased().contains(query) ?? false)
            || ($0.icd10Code?.lowercased().contains(query) ?? false)
            || ($0.visitType?.lowercased().contains(query) ?? false)
        }
    }

    private var filteredAppointments: [Appointment] {
        let appts = (patient.appointments ?? []).sorted { $0.scheduledTime > $1.scheduledTime }
        guard !searchText.isEmpty else { return appts }
        let query = searchText.lowercased()
        return appts.filter {
            $0.reasonForVisit.lowercased().contains(query)
            || $0.status.lowercased().contains(query)
            || ($0.clinicianName?.lowercased().contains(query) ?? false)
        }
    }

    var body: some View {
        List {
            Section(header: Text("Clinical History")) {
                if filteredRecords.isEmpty {
                    Text(searchText.isEmpty ? "No past clinical records found." : "No records matching \"\(searchText)\"")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(filteredRecords) { record in
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
                                                .clinicalFinePrint()
                                        }
                                    }
                                    Spacer()
                                    VStack(alignment: .trailing, spacing: 4) {
                                        Text(record.status)
                                            .clinicalPillText(weight: .medium)
                                            .padding(.horizontal, 5)
                                            .padding(.vertical, 2)
                                            .background(record.status == "Final" ? Color.green.opacity(0.2) : Color.orange.opacity(0.2))
                                            .foregroundColor(record.status == "Final" ? .green : .orange)
                                            .cornerRadius(4)
                                        if let severity = record.severity {
                                            Text(severity)
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                                .clinicalFinePrint()
                                        }
                                    }
                                }
                                Text(record.dateRecorded, format: .dateTime.month().day().year())
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .clinicalFinePrint()
                                HStack(spacing: 6) {
                                    DocumentationStatusBadge(status: record.documentationLifecycle)
                                    ClinicalSourceBadge(descriptor: record.sourceDescriptor)
                                }
                                if let ccHPI = record.ccHPI, !ccHPI.isEmpty {
                                    Text(ccHPI)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .clinicalFinePrint()
                                        .clinicalRowSummaryText(lines: 2)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }

            Section(header: Text("Appointments")) {
                let appointments = filteredAppointments
                if appointments.isEmpty {
                    Text(searchText.isEmpty ? "No appointments scheduled." : "No appointments matching \"\(searchText)\"")
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
                                        .clinicalPillText(weight: .medium)
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 2)
                                        .background(appt.status == "Scheduled" ? Color.blue.opacity(0.2) : Color.gray.opacity(0.2))
                                        .foregroundColor(appt.status == "Scheduled" ? .blue : .gray)
                                        .cornerRadius(4)
                                    Text(appt.checkInStatus ?? "")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                        .clinicalFinePrint()
                                }
                            }
                            Text(appt.scheduledTime, format: .dateTime.month().day().year().hour().minute())
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .clinicalFinePrint()
                            Text("\(appt.encounterType ?? "Follow-up") | \(appt.clinicianName ?? "")")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .clinicalFinePrint()
                            Text(appt.location ?? "")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .clinicalFinePrint()
                            HStack(spacing: 6) {
                                ClinicalSourceBadge(descriptor: appt.sourceDescriptor)
                                SourceOfTruthBadge(authoritative: appt.sourceDescriptor.authoritative)
                            }
                            if let linkedDiagnoses = appt.linkedDiagnoses, !linkedDiagnoses.isEmpty {
                                Text("Linked: \(linkedDiagnoses.joined(separator: ", "))")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .clinicalFinePrint()
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .navigationTitle("Visits & Records")
        .searchable(text: $searchText, prompt: "Search diagnoses, visits, ICD-10…")
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
    @Environment(\.modelContext) private var modelContext
    @State private var pdfURL: URL?
    @State private var showShareSheet = false
    @State private var lifecycleUpdateMessage: String?

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
                        .clinicalFinePrint()
                }

                HStack(spacing: 6) {
                    DocumentationStatusBadge(status: record.documentationLifecycle)
                    ClinicalSourceBadge(descriptor: record.sourceDescriptor)
                    SourceOfTruthBadge(authoritative: record.sourceDescriptor.authoritative)
                }

                ClinicalSourceSummaryRow(descriptor: record.sourceDescriptor, showAuthority: false)

                documentationWorkflowCard

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

                    if let icd10 = record.icd10Code, !icd10.isEmpty {
                        HStack(spacing: 6) {
                            Image(systemName: "tag.fill")
                                .font(.caption)
                                .foregroundColor(.blue)
                            Text("ICD-10: \(icd10)")
                                .font(.caption.monospaced())
                                .foregroundColor(.blue)
                                .clinicalFinePrintMonospaced()
                        }
                        .padding(6)
                        .background(Color.blue.opacity(0.08))
                        .cornerRadius(6)
                    }

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

                // Patient Education
                let educationLinks = PatientEducation.links(for: record.conditionName, icd10: record.icd10Code)
                if !educationLinks.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Patient Education", systemImage: "book.fill")
                            .font(.subheadline.bold())
                            .foregroundColor(.teal)
                        ForEach(educationLinks, id: \.title) { link in
                            HStack(spacing: 8) {
                                Image(systemName: link.icon)
                                    .foregroundColor(.teal)
                                    .frame(width: 20)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(link.title)
                                        .font(.caption.bold())
                                        .clinicalFinePrint(weight: .bold)
                                    Text(link.description)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                        .clinicalFinePrint()
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .clinicalMicroLabel()
                            }
                            .padding(8)
                            .background(Color.teal.opacity(0.06))
                            .cornerRadius(8)
                        }
                    }
                }

                Divider()

                HStack {
                    Text("Status: \(record.status)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .clinicalFinePrint()
                    Spacer()
                    if let sig = record.providerSignature, !sig.isEmpty {
                        Text("Signed by: \(sig)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .clinicalFinePrint()
                    }
                }
            }
            .padding()
        }
        .navigationTitle(record.conditionName)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if let url = pdfURL {
                    ShareLink(item: url) {
                        Label("Share PDF", systemImage: "square.and.arrow.up")
                    }
                } else {
                    Button {
                        pdfURL = generatePDFLocally(
                            patient: patient,
                            record: record,
                            details: ClinicalVisitNote(
                                primaryDiagnosis: record.conditionName,
                                ccHPI: record.ccHPI ?? record.conditionName,
                                reviewOfSystems: record.reviewOfSystems ?? "",
                                examFindings: record.examFindings ?? "",
                                impressionsAndPlan: record.impressionsAndPlan ?? record.conditionName,
                                patientInstructions: record.patientInstructions ?? "",
                                followUpPlan: record.followUpPlan ?? "",
                                recommendedOrders: record.recommendedOrders ?? [],
                                medicationChanges: [],
                                affectedAnatomicalZones: record.affectedAnatomicalZones ?? []
                            )
                        )
                    } label: {
                        Label("Export PDF", systemImage: "doc.richtext")
                    }
                }
            }
        }
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

    private var documentationWorkflowCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Documentation Workflow", systemImage: "signature")
                .font(.subheadline.bold())
                .foregroundColor(.indigo)

            HStack(spacing: 8) {
                workflowButton(title: "Draft", lifecycle: .draft, tint: .orange)
                workflowButton(title: "Reviewed", lifecycle: .reviewed, tint: .blue)
                workflowButton(title: "Sign", lifecycle: .signed, tint: .green)
            }

            if let signedAt = record.documentationSignedAt {
                Text("Signed at \(signedAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let lifecycleUpdateMessage {
                Text(lifecycleUpdateMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.secondarySystemGroupedBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
                )
        )
    }

    private func workflowButton(title: String, lifecycle: DocumentationLifecycleStatus, tint: Color) -> some View {
        Button(title) {
            updateDocumentationLifecycle(to: lifecycle)
        }
        .buttonStyle(.borderedProminent)
        .tint(tint)
        .disabled(record.documentationLifecycle == lifecycle)
    }

    private func updateDocumentationLifecycle(to lifecycle: DocumentationLifecycleStatus) {
        record.documentationStatus = lifecycle.rawValue
        record.status = lifecycle == .signed ? "Final" : "Preliminary"
        record.documentationSignedAt = lifecycle == .signed ? .now : nil
        record.providerSignature = lifecycle == .signed ? (patient.primaryClinician ?? record.providerSignature ?? "\(patient.fullName) Care Team") : nil
        record.sourceLastSyncedAt = .now

        try? modelContext.save()

        if lifecycle == .signed {
            pdfURL = generatePDFLocally(
                patient: patient,
                record: record,
                details: ClinicalVisitNote(
                    primaryDiagnosis: record.conditionName,
                    ccHPI: record.ccHPI ?? record.conditionName,
                    reviewOfSystems: record.reviewOfSystems ?? "",
                    examFindings: record.examFindings ?? "",
                    impressionsAndPlan: record.impressionsAndPlan ?? record.conditionName,
                    patientInstructions: record.patientInstructions ?? "",
                    followUpPlan: record.followUpPlan ?? "",
                    recommendedOrders: record.recommendedOrders ?? [],
                    medicationChanges: [],
                    affectedAnatomicalZones: record.affectedAnatomicalZones ?? []
                )
            )
        } else {
            pdfURL = nil
        }

        lifecycleUpdateMessage = "Documentation status updated to \(lifecycle.label)."
    }
}

private extension String {
    var withLeadingDash: String {
        isEmpty ? self : "- \(self)"
    }
}
