import SwiftData
import Foundation

@Model
final class LocalClinicalRecord {
    @Attribute(.unique) var recordID: String
    var dateRecorded: Date
    var conditionName: String
    var status: String // e.g., "Preliminary", "Final"
    var isHiddenFromPortal: Bool

    init(recordID: String, dateRecorded: Date, conditionName: String, status: String, isHiddenFromPortal: Bool = false) {
        self.recordID = recordID
        self.dateRecorded = dateRecorded
        self.conditionName = conditionName
        self.status = status
        self.isHiddenFromPortal = isHiddenFromPortal
    }
}
