//
//  MedModApp.swift
//  MedMod
//
//  Created by Gunnar Hostetler on 3/20/26.
//

import SwiftUI
import SwiftData
import os

@main
struct MedModApp: App {
    let container: ModelContainer

    init() {
        AppLogger.app.info("⚡ MedModApp init — building SwiftData schema")
        let schema = Schema([
            PatientProfile.self,
            LocalClinicalRecord.self,
            LocalMedication.self,
            Appointment.self,
            ClinicalPhoto.self
        ])
        let config = ModelConfiguration(schema: schema)

        do {
            container = try ModelContainer(for: schema, configurations: [config])
            AppLogger.app.info("✅ ModelContainer created successfully")
        } catch {
            AppLogger.app.error("❌ Schema migration failed: \(error.localizedDescription) — resetting database")
            let url = config.url
            let fm = FileManager.default
            for suffix in ["", "-wal", "-shm"] {
                try? fm.removeItem(at: suffix.isEmpty ? url : URL(fileURLWithPath: url.path + suffix))
            }
            do {
                container = try ModelContainer(for: schema, configurations: [config])
                AppLogger.app.info("✅ ModelContainer recreated after reset")
            } catch {
                AppLogger.app.fault("💥 FATAL: Could not create ModelContainer after reset: \(error.localizedDescription)")
                fatalError("Could not create ModelContainer after reset: \(error)")
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .task {
                    // Reindex RAG pipeline on every launch
                    AppLogger.app.info("🔄 Triggering RAG reindex on launch")
                    await ClinicalRAGService.shared.indexAllData(modelContext: container.mainContext)
                }
                // HealthKit FHIR sync removed — this is an HCP app.
                // HealthKit only surfaces the *device owner's* records, not the patient's.
                // Patient data comes from EHR integrations / FHIR server, not the clinician's Apple Health.
        }
        .modelContainer(container)
    }
}
