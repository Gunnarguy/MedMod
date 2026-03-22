import Foundation
import SwiftData
import SwiftUI
import Combine

// MARK: - FoundationModels Mock (iOS 26 Concept)

struct ClinicalVisitNote: Codable {
    let ccHPI: String
    let reviewOfSystems: String
    let examFindings: String
    let impressionsAndPlan: String
    let affectedAnatomicalZones: [String]
}

@MainActor
class ClinicalIntelligenceService: ObservableObject {
    let objectWillChange = ObservableObjectPublisher()

    func generateStructuredNote(from dictation: String) async throws -> ClinicalVisitNote {
        // Simulate local on-device 3B parameter model processing
        try await Task.sleep(nanoseconds: 1_000_000_000)

        // Parse dictation for contextual response
        let lower = dictation.lowercased()

        // Extract anatomical focus from context tag
        var zones: [String] = []
        if let range = lower.range(of: "\\[anatomical focus: ([^\\]]+)\\]", options: .regularExpression) {
            let tag = String(lower[range])
                .replacingOccurrences(of: "[anatomical focus: ", with: "")
                .replacingOccurrences(of: "]", with: "")
                .trimmingCharacters(in: .whitespaces)
            zones.append(tag)
        }

        // Detect condition keywords
        let conditionMap: [(keywords: [String], name: String, plan: String)] = [
            (["basal cell", "bcc", "carcinoma"], "Basal Cell Carcinoma", "surgical excision with clear margins"),
            (["melanoma"], "Melanoma", "wide local excision, sentinel lymph node biopsy"),
            (["acne", "comedone", "pimple"], "Acne Vulgaris", "topical retinoid, benzoyl peroxide, follow-up 6 weeks"),
            (["eczema", "dermatitis", "atopic"], "Atopic Dermatitis", "emollients, topical corticosteroid, avoid triggers"),
            (["psoriasis", "plaque"], "Psoriasis", "topical steroid, phototherapy evaluation"),
            (["rash", "eruption"], "Skin Eruption", "monitor and reassess, consider biopsy if persistent"),
            (["wart", "verruca"], "Verruca Vulgaris", "cryotherapy, follow-up in 2 weeks"),
            (["mole", "nevus", "nevi"], "Atypical Nevus", "monitor with dermoscopy, consider excisional biopsy"),
        ]

        var conditionName = "Skin Lesion NOS"
        var planText = "further evaluation needed, consider biopsy"

        for entry in conditionMap {
            if entry.keywords.contains(where: { lower.contains($0) }) {
                conditionName = entry.name
                planText = entry.plan
                break
            }
        }

        // Extract size if present
        var sizeStr = ""
        if let sizeRange = lower.range(of: "\\d+\\s*mm", options: .regularExpression) {
            sizeStr = String(lower[sizeRange])
        }

        // Build contextual findings
        let zoneName = zones.first.map { AnatomicalRealityView.displayName(for: $0) } ?? "unspecified region"
        let findingsDetail = sizeStr.isEmpty ?
            "Lesion observed on the \(zoneName)" :
            "\(sizeStr) lesion observed on the \(zoneName)"

        // Detect symptoms
        var symptoms: [String] = []
        if lower.contains("bleed") { symptoms.append("bleeding") }
        if lower.contains("itch") { symptoms.append("itching") }
        if lower.contains("pain") || lower.contains("tender") { symptoms.append("tenderness") }
        if lower.contains("grow") || lower.contains("enlarg") { symptoms.append("growth") }

        // Build duration
        var duration = ""
        if let durRange = lower.range(of: "(\\d+\\s*(week|month|day|year)s?)", options: .regularExpression) {
            duration = " for \(String(lower[durRange]))"
        }

        let hpi = symptoms.isEmpty ?
            "Patient presents with \(conditionName.lowercased()) on the \(zoneName)\(duration)." :
            "Patient presents with \(conditionName.lowercased()) on the \(zoneName)\(duration). Reports \(symptoms.joined(separator: ", "))."

        return ClinicalVisitNote(
            ccHPI: hpi,
            reviewOfSystems: "No systemic symptoms reported. Denies fever, chills, weight loss.",
            examFindings: findingsDetail + ". Surrounding skin appears normal.",
            impressionsAndPlan: "\(conditionName). Plan: \(planText).",
            affectedAnatomicalZones: zones
        )
    }

    func executeToolQuery(query: String, modelContext: ModelContext, patient: PatientProfile? = nil) async throws -> String {
        try await Task.sleep(nanoseconds: 600_000_000)

        if query.localizedCaseInsensitiveContains("medication") || query.localizedCaseInsensitiveContains("prescription") || query.localizedCaseInsensitiveContains("rx") {
            let tool = FetchFHIRDataTool(modelContext: modelContext, patient: patient)
            let toolResult = try await tool.call(arguments: FetchFHIRDataTool.Arguments(recordType: "medicationRecord", searchText: query))
            if toolResult.isEmpty {
                return "No medications found on file for this patient."
            }
            return "Medications on file:\n\n\(toolResult.joined(separator: "\n"))"
        }

        let tool = FetchClinicalHistoryTool(modelContext: modelContext, patient: patient)
        let conditionQuery = query.lowercased().contains("carcinoma") ? "carcinoma" :
                             query.lowercased().contains("acne") ? "acne" : "all"
        let toolResult = try tool.call(arguments: FetchClinicalHistoryTool.Arguments(conditionQuery: conditionQuery))

        if toolResult.isEmpty {
            return "No matching records found in this patient's local history."
        }
        return "Clinical history results:\n\n\(toolResult.joined(separator: "\n"))"
    }
}

// MARK: - Tool Calling

protocol AIDiscoverableTool {
    var name: String { get }
    var description: String { get }
}

struct FetchFHIRDataTool: AIDiscoverableTool {
    let name = "fetchFHIRData"
    let description = "Queries HealthKit for specific clinical records"
    var modelContext: ModelContext
    var patient: PatientProfile?

    struct Arguments: Codable {
        let recordType: String
        let searchText: String
    }

    func call(arguments: Arguments) async throws -> [String] {
        if arguments.recordType == "medicationRecord" {
            // Use patient-scoped meds if patient provided
            if let patient, let meds = patient.medications, !meds.isEmpty {
                return meds.map {
                    "\($0.medicationName) | Qty: \($0.quantityInfo) | Refills: \($0.refills)"
                }
            }

            // Fallback to global query
            var medications = try modelContext.fetch(FetchDescriptor<LocalMedication>())
            if medications.isEmpty {
                await HealthKitFHIRService(modelContext: modelContext).requestAuthorizationAndFetch()
                medications = try modelContext.fetch(FetchDescriptor<LocalMedication>())
            }
            return medications.map {
                "\($0.medicationName) | Qty: \($0.quantityInfo) | Refills: \($0.refills)"
            }
        } else {
            // Patient-scoped records
            if let patient, let records = patient.clinicalRecords, !records.isEmpty {
                return records.map { "\($0.conditionName) [\($0.status)] — \($0.dateRecorded.formatted(date: .abbreviated, time: .omitted))" }
            }
            let records = try modelContext.fetch(FetchDescriptor<LocalClinicalRecord>())
            return records.map { "\($0.conditionName) [\($0.status)]" }
        }
    }
}

struct FetchClinicalHistoryTool: AIDiscoverableTool {
    let name = "fetchClinicalHistory"
    let description = "Retrieves patient's past medical conditions from local database"
    var modelContext: ModelContext
    var patient: PatientProfile?

    struct Arguments: Codable {
        let conditionQuery: String
    }

    func call(arguments: Arguments) throws -> [String] {
        let records: [LocalClinicalRecord]
        if let patient, let patientRecords = patient.clinicalRecords {
            records = patientRecords
        } else {
            records = try modelContext.fetch(FetchDescriptor<LocalClinicalRecord>())
        }

        let filtered: [LocalClinicalRecord]
        if arguments.conditionQuery.lowercased() == "all" {
            filtered = records
        } else {
            filtered = records.filter { $0.conditionName.localizedCaseInsensitiveContains(arguments.conditionQuery) }
        }

        return filtered.map { "\($0.dateRecorded.formatted(date: .abbreviated, time: .omitted)): \($0.conditionName) [\($0.status)]" }
    }
}
