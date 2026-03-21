import SwiftData
import Foundation

@Model
final class Appointment {
    @Attribute(.unique) var appointmentID: String
    var scheduledTime: Date
    var reasonForVisit: String
    var status: String

    init(appointmentID: String, scheduledTime: Date, reasonForVisit: String, status: String) {
        self.appointmentID = appointmentID
        self.scheduledTime = scheduledTime
        self.reasonForVisit = reasonForVisit
        self.status = status
    }
}
