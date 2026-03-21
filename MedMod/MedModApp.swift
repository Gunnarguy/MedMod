//
//  MedModApp.swift
//  MedMod
//
//  Created by Gunnar Hostetler on 3/20/26.
//

import SwiftUI
import SwiftData

@main
struct MedModApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [
            PatientProfile.self,
            LocalClinicalRecord.self,
            LocalMedication.self,
            Appointment.self
        ])
    }
}
