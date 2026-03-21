import SwiftData
import Foundation

@Model
final class LocalMedication {
    @Attribute(.unique) var rxID: String
    var medicationName: String
    var writtenBy: String
    var writtenDate: Date
    var quantityInfo: String
    var refills: Int

    init(rxID: String, medicationName: String, writtenBy: String, writtenDate: Date, quantityInfo: String, refills: Int) {
        self.rxID = rxID
        self.medicationName = medicationName
        self.writtenBy = writtenBy
        self.writtenDate = writtenDate
        self.quantityInfo = quantityInfo
        self.refills = refills
    }
}
