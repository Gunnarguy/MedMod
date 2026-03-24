import Foundation
import os

/// Centralized logger factory for the entire MedMod app.
/// Every subsystem gets its own `os.Logger` category so you can filter
/// in Console.app or Xcode with:  `subsystem:com.medmod` + `category:AI`
enum AppLogger {
    private nonisolated static let subsystem = Bundle.main.bundleIdentifier ?? "com.medmod"

    /// App launch, SwiftData container, schema migration
    nonisolated static let app       = Logger(subsystem: subsystem, category: "App")

    /// Root view, mock data seeding
    nonisolated static let data      = Logger(subsystem: subsystem, category: "Data")

    /// Tab bar, navigation events
    nonisolated static let nav       = Logger(subsystem: subsystem, category: "Nav")

    /// iPad dashboard, patient selection, inspector, toolbar
    nonisolated static let dashboard = Logger(subsystem: subsystem, category: "Dashboard")

    /// Voice dictation, speech recognition
    nonisolated static let speech    = Logger(subsystem: subsystem, category: "Speech")

    /// Clinical exam workspace, note signing, PDF generation
    nonisolated static let exam      = Logger(subsystem: subsystem, category: "Exam")

    /// Foundation Models, fallback AI, tool queries, panel queries
    nonisolated static let ai        = Logger(subsystem: subsystem, category: "AI")

    /// Workflow state machine transitions
    nonisolated static let workflow  = Logger(subsystem: subsystem, category: "Workflow")

    /// Chat assistant
    nonisolated static let assistant = Logger(subsystem: subsystem, category: "Assistant")

    /// Agenda, swipe actions, schedule computation
    nonisolated static let agenda    = Logger(subsystem: subsystem, category: "Agenda")

    /// HealthKit / FHIR
    nonisolated static let health    = Logger(subsystem: subsystem, category: "HealthKit")

    /// Clinic Intelligence cross-patient panel
    nonisolated static let intel     = Logger(subsystem: subsystem, category: "Intel")
}
