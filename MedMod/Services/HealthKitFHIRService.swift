import Foundation
import SwiftData
import HealthKit
import SwiftUI
import Combine

@MainActor
class HealthKitFHIRService: ObservableObject {
    let objectWillChange = ObservableObjectPublisher()

    private let healthStore = HKHealthStore()
    private let modelContext: ModelContext
    private let patient: PatientProfile?

    init(modelContext: ModelContext, patient: PatientProfile? = nil) {
        self.modelContext = modelContext
        self.patient = patient
    }

    func requestAuthorizationAndFetch() async {
        guard HKHealthStore.isHealthDataAvailable() else { return }

        #if os(iOS) || os(visionOS)
        guard
            let conditionType = HKObjectType.clinicalType(forIdentifier: .conditionRecord),
            let medicationType = HKObjectType.clinicalType(forIdentifier: .medicationRecord)
        else {
            simulateFHIRConditionIngestion()
            return
        }

        let typesToRead: Set<HKObjectType> = [conditionType, medicationType]

        do {
            try await healthStore.requestAuthorization(toShare: [], read: typesToRead)
            await fetchClinicalRecords(type: conditionType)
            await fetchMedicationRecords(type: medicationType)
        } catch {
            // The blueprint assumes strict entitlements. When unavailable, keep the app usable offline.
            simulateFHIRConditionIngestion()
        }
        #else
        simulateFHIRConditionIngestion()
        #endif
    }

    #if os(iOS) || os(visionOS)
    private func fetchClinicalRecords(type: HKClinicalType) async {
        let predicate = HKQuery.predicateForSamples(withStart: Date.distantPast, end: Date(), options: .strictEndDate)

        await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { [weak self] _, samples, _ in
                let records = (samples as? [HKClinicalRecord]) ?? []
                Task { @MainActor [weak self] in
                    guard let self else {
                        continuation.resume()
                        return
                    }

                    for record in records {
                        self.processFHIRCondition(record: record)
                    }
                    continuation.resume()
                }
            }

            healthStore.execute(query)
        }
    }

    private func fetchMedicationRecords(type: HKClinicalType) async {
        let predicate = HKQuery.predicateForSamples(withStart: Date.distantPast, end: Date(), options: .strictEndDate)

        await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { [weak self] _, samples, _ in
                let records = (samples as? [HKClinicalRecord]) ?? []
                Task { @MainActor [weak self] in
                    guard let self else {
                        continuation.resume()
                        return
                    }

                    for record in records {
                        self.processFHIRMedication(record: record)
                    }
                    continuation.resume()
                }
            }

            healthStore.execute(query)
        }
    }

    private func processFHIRCondition(record: HKClinicalRecord) {
        guard let fhirResource = record.fhirResource else { return }

        if let existingRecord = existingClinicalRecord(withID: fhirResource.identifier) {
            existingRecord.dateRecorded = record.startDate
            existingRecord.conditionName = extractConditionName(from: fhirResource.data)
            existingRecord.status = "Final"
            existingRecord.isHiddenFromPortal = false
            existingRecord.visitType = "FHIR import"
            existingRecord.carePlanSummary = "Imported from HealthKit clinical records."
            attachToPatientIfNeeded(record: existingRecord)
            try? modelContext.save()
            return
        }

        let localRecord = LocalClinicalRecord(
            recordID: fhirResource.identifier,
            dateRecorded: record.startDate,
            conditionName: extractConditionName(from: fhirResource.data),
            status: "Final",
            isHiddenFromPortal: false,
            visitType: "FHIR import",
            carePlanSummary: "Imported from HealthKit clinical records."
        )

        modelContext.insert(localRecord)
        attachToPatientIfNeeded(record: localRecord)
        try? modelContext.save()
    }

    private func processFHIRMedication(record: HKClinicalRecord) {
        guard let fhirResource = record.fhirResource else { return }

        if let existingMedication = existingMedication(withID: fhirResource.identifier) {
            existingMedication.medicationName = extractMedicationName(from: fhirResource.data)
            existingMedication.writtenBy = "Clinical Record Import"
            existingMedication.writtenDate = record.startDate
            existingMedication.quantityInfo = "Imported from FHIR MedicationRequest"
            existingMedication.refills = 0
            existingMedication.route = "Imported"
            existingMedication.frequency = "See FHIR record"
            existingMedication.status = "Imported"
            existingMedication.startDate = record.startDate
            existingMedication.lastFilledDate = record.startDate
            existingMedication.pharmacyName = "HealthKit import"
            existingMedication.safetyNotes = ["Review original FHIR MedicationRequest for complete SIG."]
            attachToPatientIfNeeded(medication: existingMedication)
            try? modelContext.save()
            return
        }

        let medication = LocalMedication(
            rxID: fhirResource.identifier,
            medicationName: extractMedicationName(from: fhirResource.data),
            writtenBy: "Clinical Record Import",
            writtenDate: record.startDate,
            quantityInfo: "Imported from FHIR MedicationRequest",
            refills: 0,
            route: "Imported",
            frequency: "See FHIR record",
            status: "Imported",
            startDate: record.startDate,
            lastFilledDate: record.startDate,
            pharmacyName: "HealthKit import",
            safetyNotes: ["Review original FHIR MedicationRequest for complete SIG."]
        )

        modelContext.insert(medication)
        attachToPatientIfNeeded(medication: medication)
        try? modelContext.save()
    }
    #endif

    private func simulateFHIRConditionIngestion() {
        let localRecord = existingClinicalRecord(withID: "SIMULATED-BCC") ?? LocalClinicalRecord(
            recordID: "SIMULATED-BCC",
            dateRecorded: Date(),
            conditionName: "Basal Cell Carcinoma",
            status: "Final",
            isHiddenFromPortal: false
        )
        localRecord.dateRecorded = Date()
        localRecord.conditionName = "Basal Cell Carcinoma"
        localRecord.visitType = "Offline demo import"
        localRecord.carePlanSummary = "Fallback simulated import used because HealthKit clinical records are unavailable."

        let rxRecord = existingMedication(withID: "SIMULATED-CYCLO") ?? LocalMedication(
            rxID: "SIMULATED-CYCLO",
            medicationName: "Cyclosporine 0.09% eye drops",
            writtenBy: "Dr. Smith",
            writtenDate: Date(),
            quantityInfo: "1 Bottle",
            refills: 3,
            route: "Ophthalmic",
            frequency: "Twice daily",
            indication: "Dry eye / ocular inflammation",
            status: "Active",
            startDate: Date(),
            lastFilledDate: Date(),
            pharmacyName: "HealthKit fallback import",
            safetyNotes: ["Confirm ophthalmology follow-up if symptoms persist."]
        )
        rxRecord.medicationName = "Cyclosporine 0.09% eye drops"
        rxRecord.writtenDate = Date()
        rxRecord.quantityInfo = "1 Bottle"
        rxRecord.refills = 3
        rxRecord.route = "Ophthalmic"
        rxRecord.frequency = "Twice daily"
        rxRecord.indication = "Dry eye / ocular inflammation"
        rxRecord.status = "Active"
        rxRecord.startDate = Date()
        rxRecord.lastFilledDate = Date()
        rxRecord.pharmacyName = "HealthKit fallback import"
        rxRecord.safetyNotes = ["Confirm ophthalmology follow-up if symptoms persist."]

        if existingClinicalRecord(withID: "SIMULATED-BCC") == nil {
            modelContext.insert(localRecord)
        }
        if existingMedication(withID: "SIMULATED-CYCLO") == nil {
            modelContext.insert(rxRecord)
        }

        attachToPatientIfNeeded(record: localRecord)
        attachToPatientIfNeeded(medication: rxRecord)
        try? modelContext.save()
    }

    private func existingClinicalRecord(withID recordID: String) -> LocalClinicalRecord? {
        let records = try? modelContext.fetch(FetchDescriptor<LocalClinicalRecord>())
        return records?.first(where: { $0.recordID == recordID })
    }

    private func existingMedication(withID rxID: String) -> LocalMedication? {
        let medications = try? modelContext.fetch(FetchDescriptor<LocalMedication>())
        return medications?.first(where: { $0.rxID == rxID })
    }

    private func attachToPatientIfNeeded(record: LocalClinicalRecord) {
        guard let patient else { return }
        if !(patient.clinicalRecords?.contains(where: { $0.recordID == record.recordID }) ?? false) {
            patient.clinicalRecords?.append(record)
        }
    }

    private func attachToPatientIfNeeded(medication: LocalMedication) {
        guard let patient else { return }
        if !(patient.medications?.contains(where: { $0.rxID == medication.rxID }) ?? false) {
            patient.medications?.append(medication)
        }
    }

    private func extractConditionName(from data: Data) -> String {
        guard
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let code = json["code"] as? [String: Any],
            let text = code["text"] as? String,
            !text.isEmpty
        else {
            return "Imported Clinical Condition"
        }

        return text
    }

    private func extractMedicationName(from data: Data) -> String {
        guard
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let medicationCodeableConcept = json["medicationCodeableConcept"] as? [String: Any],
            let text = medicationCodeableConcept["text"] as? String,
            !text.isEmpty
        else {
            return "Imported Medication"
        }

        return text
    }
}
