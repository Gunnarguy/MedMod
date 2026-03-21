import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var patients: [PatientProfile]

    var body: some View {
        EHRMainShellView()
            .onAppear {
                if patients.isEmpty {
                    addMockData()
                }
            }
    }

    private func addMockData() {
        let mockPatient = PatientProfile(
            firstName: "Jane",
            lastName: "Doe",
            dateOfBirth: Date(timeIntervalSince1970: 181872000), // ~ Oct 7, 1975
            gender: "Female",
            isSmoker: true
        )

        let localMed1 = LocalMedication(rxID: "RX-01", medicationName: "Simvastatin 20mg", writtenBy: "Dr. Smith", writtenDate: Date().addingTimeInterval(-86400 * 30), quantityInfo: "Take 1 pill daily", refills: 2)
        let localMed2 = LocalMedication(rxID: "RX-02", medicationName: "Cyclosporine 0.09%", writtenBy: "Dr. Jones", writtenDate: Date().addingTimeInterval(-86400 * 10), quantityInfo: "1 drop both eyes daily", refills: 0)

        let record1 = LocalClinicalRecord(recordID: "REC-01", dateRecorded: Date().addingTimeInterval(-86400 * 365), conditionName: "Basal Cell Carcinoma", status: "Final", isHiddenFromPortal: false)

        modelContext.insert(mockPatient)
        modelContext.insert(localMed1)
        modelContext.insert(localMed2)
        modelContext.insert(record1)

        mockPatient.medications?.append(localMed1)
        mockPatient.medications?.append(localMed2)
        mockPatient.clinicalRecords?.append(record1)

        try? modelContext.save()
    }
}

#Preview {
    ContentView()
        .modelContainer(for: PatientProfile.self, inMemory: true)
}
