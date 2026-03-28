import SwiftData
import Foundation

@Model
final class LocalClinicalRecord {
    @Attribute(.unique) var recordID: String
    var dateRecorded: Date
    var conditionName: String
    var status: String // e.g., "Preliminary", "Final"
    var isHiddenFromPortal: Bool
    var visitType: String?
    var severity: String?

    // Structured note fields (Section 2.2 / Image 8 / Image 9)
    var ccHPI: String?
    var reviewOfSystems: String?
    var examFindings: String?
    var impressionsAndPlan: String?
    var affectedAnatomicalZones: [String]?
    var providerSignature: String?
    var patientInstructions: String?
    var followUpPlan: String?
    var recommendedOrders: [String]?
    var carePlanSummary: String?
    var icd10Code: String?
    var clinicalPhotoPaths: [String]?
    var patient: PatientProfile?

    init(recordID: String, dateRecorded: Date, conditionName: String, status: String, isHiddenFromPortal: Bool = false,
         visitType: String? = nil, severity: String? = nil,
         ccHPI: String? = nil, reviewOfSystems: String? = nil, examFindings: String? = nil,
         impressionsAndPlan: String? = nil, affectedAnatomicalZones: [String]? = nil, providerSignature: String? = nil,
         patientInstructions: String? = nil, followUpPlan: String? = nil, recommendedOrders: [String]? = nil,
         carePlanSummary: String? = nil, icd10Code: String? = nil, clinicalPhotoPaths: [String]? = nil) {
        self.recordID = recordID
        self.dateRecorded = dateRecorded
        self.conditionName = conditionName
        self.status = status
        self.isHiddenFromPortal = isHiddenFromPortal
        self.visitType = visitType
        self.severity = severity
        self.ccHPI = ccHPI
        self.reviewOfSystems = reviewOfSystems
        self.examFindings = examFindings
        self.impressionsAndPlan = impressionsAndPlan
        self.affectedAnatomicalZones = affectedAnatomicalZones
        self.providerSignature = providerSignature
        self.patientInstructions = patientInstructions
        self.followUpPlan = followUpPlan
        self.recommendedOrders = recommendedOrders
        self.carePlanSummary = carePlanSummary
        self.icd10Code = icd10Code
        self.clinicalPhotoPaths = clinicalPhotoPaths
    }
}
