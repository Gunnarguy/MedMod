import SwiftData
import Foundation

@Model
final class LocalClinicalRecord {
    @Attribute(.unique) var recordID: String
    var dateRecorded: Date
    var conditionName: String
    var status: String // e.g., "Preliminary", "Final"
    var isHiddenFromPortal: Bool

    // Structured note fields (Section 2.2 / Image 8 / Image 9)
    var ccHPI: String?
    var reviewOfSystems: String?
    var examFindings: String?
    var impressionsAndPlan: String?
    var affectedAnatomicalZones: [String]?
    var providerSignature: String?

    init(recordID: String, dateRecorded: Date, conditionName: String, status: String, isHiddenFromPortal: Bool = false,
         ccHPI: String? = nil, reviewOfSystems: String? = nil, examFindings: String? = nil,
         impressionsAndPlan: String? = nil, affectedAnatomicalZones: [String]? = nil, providerSignature: String? = nil) {
        self.recordID = recordID
        self.dateRecorded = dateRecorded
        self.conditionName = conditionName
        self.status = status
        self.isHiddenFromPortal = isHiddenFromPortal
        self.ccHPI = ccHPI
        self.reviewOfSystems = reviewOfSystems
        self.examFindings = examFindings
        self.impressionsAndPlan = impressionsAndPlan
        self.affectedAnatomicalZones = affectedAnatomicalZones
        self.providerSignature = providerSignature
    }
}
