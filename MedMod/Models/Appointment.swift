import SwiftData
import Foundation

@Model
final class Appointment {
    @Attribute(.unique) var appointmentID: String
    var scheduledTime: Date
    var reasonForVisit: String
    var status: String
    var encounterType: String?
    var clinicianName: String?
    var location: String?
    var durationMinutes: Int?
    var checkInStatus: String?
    var prepInstructions: String?
    var linkedDiagnoses: [String]?

    init(
        appointmentID: String,
        scheduledTime: Date,
        reasonForVisit: String,
        status: String,
        encounterType: String? = nil,
        clinicianName: String? = nil,
        location: String? = nil,
        durationMinutes: Int? = nil,
        checkInStatus: String? = nil,
        prepInstructions: String? = nil,
        linkedDiagnoses: [String]? = nil
    ) {
        self.appointmentID = appointmentID
        self.scheduledTime = scheduledTime
        self.reasonForVisit = reasonForVisit
        self.status = status
        self.encounterType = encounterType
        self.clinicianName = clinicianName
        self.location = location
        self.durationMinutes = durationMinutes
        self.checkInStatus = checkInStatus
        self.prepInstructions = prepInstructions
        self.linkedDiagnoses = linkedDiagnoses
    }
}
