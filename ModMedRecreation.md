Architectural Blueprint and Implementation Codebase for a Local-First, AI-Driven Electronic Health Record iOS ApplicationExecutive Summary and Strategic ArchitectureThe convergence of on-device artificial intelligence, spatial computing, localized health data persistence, and advanced rendering materials has initiated a profound paradigm shift in healthcare software architecture. Historically, Electronic Health Record (EHR) systems—such as the legacy interfaces presented in the visual assets (Images 1-10)—have relied heavily on cloud-based infrastructure to process clinical data, run predictive analytics, and serve user interfaces. While functional, this cloud-dependent architecture introduces critical vulnerabilities regarding data privacy, network latency, and offline availability.This comprehensive report and implementation specification outlines the architectural blueprint for a next-generation, local-first EHR application specifically engineered for iOS 26 and its accompanying hardware ecosystem. The primary objective is to replicate and modernize the functionality observed in the legacy application visual assets, transitioning the system to operate entirely on its own hardware without external cloud reliance.By leveraging the Apple Foundation Models framework (specifically the ~3B parameter on-device language model), the system processes complex natural language queries and diagnostic correlations entirely on-device, bypassing cloud transmission. Furthermore, the integration of HealthKit's FHIR (Fast Healthcare Interoperability Resources) capabilities with SwiftData establishes a resilient, offline-first clinical data repository. From a user interface perspective, the architecture replaces static 2D medical diagrams with an interactive, fully rendered 3D anatomical atlas powered by RealityKit , allowing dynamic highlighting of physiological structures based on real-time diagnostic data. The entire visual experience is wrapped in the iOS 26 Liquid Glass design language, utilizing complex lensing, materialization, and fluid container morphing to create a deeply intuitive, layered spatial interface.Interface Modernization MappingThe provided visual assets depict a comprehensive clinical workflow. The architecture translates these legacy views into localized, modern iOS 26 paradigms.Legacy Asset ReferenceOriginal FunctionalityiOS 26 Modernized ArchitectureImage 1 & 2App Store Ecosystem (ACE, gGastro, APPatient, EMA).Unified application bundle utilizing SwiftData for specialty-agnostic offline data access.Image 3 & 8iPad Patient Chart & Visit Settings (Notes, Rx, Exam grids).Liquid Glass modular grids utilizing GlassEffectContainer and glassEffectUnion for seamless data ingestion.Image 43D Anatomical UI (Head Model, Drawing Tools).RealityView integrating hierarchical USDZ models with spatial tap gestures and entity isolation.Image 5 & 6iPhone Tab Bar, Patient Dashboard, Inbox (IntraMail).iOS 26 Liquid Glass tab bar with .tabBarMinimizeBehavior(.onScrollDown) and edge-to-edge scrolling.Image 7iPad Agenda and Navigation.Translucent navigation layers leveraging the .regular Liquid Glass variant with .interactive() behaviors.Image 9 & 10Clinical PDF rendering and Prescription (Rx) lists.Automated local PDF generation and FHIR MedicationRequest parsing via HealthKit.1. Local-First Clinical Data Persistence Layer1.1 The HealthKit and FHIR InfrastructureTo provide a comprehensive medical profile, the application must access verified clinical records natively. Apple's HealthKit framework serves as the centralized, encrypted repository for this data. Beyond basic fitness metrics, HealthKit supports the ingestion and storage of Fast Healthcare Interoperability Resources (FHIR) via the HKClinicalRecord class.As observed in Image 10, the legacy application tracks specific pharmacological data (e.g., simvastatin 20 mg tablet, cyclosporine 0.09% eye drops). In a local-first architecture, this data is not pulled from a remote server but queried directly from the device's encrypted storage. HealthKit represents each FHIR record as an HKClinicalRecord sample that stores a single condition, procedure, or result.Accessing this highly sensitive data requires stringent adherence to privacy guidelines, including specialized entitlements and explicit user authorization. The underlying FHIR resource contains a raw JSON data payload and a specific fhirVersion (such as DSTU2 or R4). Utilizing the FHIRModels library, the architecture decodes this JSON payload into highly structured Swift classes.1.2 SwiftData and the Offline-First ArchitectureWhile HealthKit serves as the source of truth for raw clinical data, querying it continuously for UI state management is computationally expensive and introduces asynchronous friction. To resolve this, the architecture employs SwiftData to establish a robust, local-first persistence layer. Local-first architecture fundamentally differs from traditional client-server models; the local database (managed by SwiftData's underlying SQLite engine) is the primary interactive layer. Operations occur with zero network latency, ensuring the application remains entirely functional regardless of connectivity constraints.The following SwiftData schema provides the foundation for replacing the legacy databases seen in Images 3, 5, and 8.Swiftimport Foundation
import SwiftData
import HealthKit

/// Represents the core Patient profile as seen in Image 5
@Model
final class PatientProfile {
    @Attribute(.unique) var id: UUID
    var firstName: String
    var lastName: String
    var dateOfBirth: Date
    var gender: String
    var isSmoker: Bool // Referenced in Image 8: "Patient is a habitual smoker"

    @Relationship(deleteRule:.cascade) var clinicalRecords:
    @Relationship(deleteRule:.cascade) var medications: [LocalMedication]
    @Relationship(deleteRule:.cascade) var appointments: [Appointment]

    init(id: UUID = UUID(), firstName: String, lastName: String, dateOfBirth: Date, gender: String, isSmoker: Bool = false) {
        self.id = id
        self.firstName = firstName
        self.lastName = lastName
        self.dateOfBirth = dateOfBirth
        self.gender = gender
        self.isSmoker = isSmoker
        self.clinicalRecords =
        self.medications =
        self.appointments =
    }
}

/// Represents the historical visit diagnoses seen in Image 3
@Model
final class LocalClinicalRecord {
    @Attribute(.unique) var recordID: String
    var dateRecorded: Date
    var conditionName: String
    var status: String // e.g., "Preliminary", "Final"
    var isHiddenFromPortal: Bool

    init(recordID: String, dateRecorded: Date, conditionName: String, status: String, isHiddenFromPortal: Bool) {
        self.recordID = recordID
        self.dateRecorded = dateRecorded
        self.conditionName = conditionName
        self.status = status
        self.isHiddenFromPortal = isHiddenFromPortal
    }
}

/// Represents the Rx data seen in Image 10
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

/// Represents the Agenda / Scheduling data seen in Image 6 and 7
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
1.3 Bridging HealthKit and SwiftDataTo operationalize the extraction of clinical records, a dedicated HealthKitFHIRService is implemented. This service requests authorization, executes HKSampleQuery for clinical records, decodes the FHIR JSON, and maps the data into the SwiftData models.Swiftimport HealthKit
import SwiftData
// Assume FHIRModels library is imported for R4/DSTU2 decoding

@MainActor
class HealthKitFHIRService: ObservableObject {
    private let healthStore = HKHealthStore()
    private var modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func requestAuthorizationAndFetch() async {
        guard HKHealthStore.isHealthDataAvailable() else { return }

        let conditionType = HKObjectType.clinicalType(forIdentifier:.conditionRecord)!
        let medicationType = HKObjectType.clinicalType(forIdentifier:.medicationRecord)!

        let typesToRead: Set<HKObjectType> =

        do {
            try await healthStore.requestAuthorization(toShare:, read: typesToRead)
            await fetchClinicalRecords(type: conditionType)
            await fetchMedicationRecords(type: medicationType)
        } catch {
            print("Authorization failed: \(error.localizedDescription)")
        }
    }

    private func fetchClinicalRecords(type: HKClinicalType) async {
        let predicate = HKQuery.predicateForSamples(withStart: Date.distantPast, end: Date(), options:.strictEndDate)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { [weak self] _, samples, error in
                guard let self = self, let records = samples as? else {
                    continuation.resume()
                    return
                }

                for record in records {
                    self.processFHIRCondition(record: record)
                }
                continuation.resume()
            }
            healthStore.execute(query)
        }
    }

    private func processFHIRCondition(record: HKClinicalRecord) {
        guard let fhirResource = record.fhirResource else { return }

        // Simulating FHIR parsing logic for brevity.
        // In a production environment, FHIRModels library is used to strongly type the JSON.
        let parsedConditionName = extractConditionName(from: fhirResource.data)

        let localRecord = LocalClinicalRecord(
            recordID: fhirResource.identifier,
            dateRecorded: record.startDate,
            conditionName: parsedConditionName,
            status: "Final",
            isHiddenFromPortal: false
        )

        modelContext.insert(localRecord)
        try? modelContext.save()
    }

    private func extractConditionName(from data: Data) -> String {
        // Implementation of JSON parsing to extract "code.text" from FHIR Condition Resource
        return "Basal Cell Carcinoma" // Placeholder aligning with Image 3
    }
}
2. On-Device Artificial Intelligence Engine2.1 The ~3B Parameter Foundation ModelAt the core of this offline EHR architecture is Apple's ~3B parameter on-device language model, accessible via the FoundationModels framework. Designed specifically for text understanding, entity extraction, refinement, and summarization, this model operates entirely on local Apple Silicon, ensuring that sensitive Protected Health Information (PHI) never leaves the device.The integration of a local LLM fundamentally alters the diagnostic workflow observed in Image 8 and 9. Instead of a physician manually typing out the entire CC/HPI (Chief Complaint / History of Present Illness) and Review of Systems, the physician can dictate free-form audio. The device's neural engine processes the semantic weight of the transcription locally. The OS daemon managing the model employs highly optimized implementations of constrained decoding and speculative decoding. Speculative decoding drastically accelerates inference speed by utilizing a smaller draft model to predict tokens, which the 3B model then verifies in parallel. Constrained decoding guarantees that the model's output strictly adheres to a predefined structural format, which is paramount in medical applications where parsing errors can lead to clinical misinterpretations.2.2 Structured Outputs via Guided GenerationMedical data requires strict adherence to schemas. Free-form text generation is insufficient for programmatic EHR updates. The FoundationModels framework provides a mechanism known as Guided Generation, utilizing Swift compiler macros to enforce output structures.By tagging a Swift structure with the @Generable macro, developers define the exact JSON-like schema the model must populate. The framework injects this specification into the system prompt, and because the 3B model has been post-trained on a specialized dataset designed for structured output, it reliably populates the fields. The following implementation demonstrates how to extract the clinical data structure shown in the Visit Settings grids of Image 8.Swiftimport Foundation
import FoundationModels

/// Translates the unstructured dictation into the structured grids seen in Image 8
@Generable
struct ClinicalVisitNote {
    @Guide(description: "The Chief Complaint and History of Present Illness.")
    let ccHPI: String

    @Guide(description: "The Review of Systems findings. Must note notable symptoms like fever, weight loss, etc.")
    let reviewOfSystems: String

    @Guide(description: "Findings from the physical examination, detailing anatomical locations.")
    let examFindings: String

    @Guide(description: "The medical impression or diagnosis, and the planned treatment.")
    let impressionsAndPlan: String

    @Guide(description: "An array of identified anatomical zones (e.g., 'scalp', 'right upper extremity').")
    let affectedAnatomicalZones:
}

@MainActor
class ClinicalIntelligenceService: ObservableObject {
    private let instructions = """
    You are an expert clinical documentation assistant.
    Your task is to take a physician's raw unstructured dictation and
    extract the information strictly into the provided ClinicalVisitNote format.
    Do not invent information. If a system is not reviewed, do not include it.
    """

    func generateStructuredNote(from dictation: String) async throws -> ClinicalVisitNote {
        let session = LanguageModelSession(instructions: instructions)

        let prompt = Prompt {
            "Process the following physician dictation into a structured clinical note:"
            "--- Dictation Start ---"
            dictation
            "--- Dictation End ---"
        }

        // The model generates data strictly adhering to the @Generable struct
        let response = try await session.respond(to: prompt, generating: ClinicalVisitNote.self)
        return response.content
    }
}
When a physician dictates, "Patient is here for acne on the face. Did a full skin exam of the scalp, face, chest, and arms. Found a basal cell carcinoma on the right upper extremity. Planning a chemical peel," the LanguageModelSession processes the string and returns a fully instantiated ClinicalVisitNote object. This structured data is immediately saved to SwiftData and can be seamlessly passed into the RealityKit engine to visually highlight the "right upper extremity" on the 3D anatomical atlas.2.3 Expanding Capabilities with Tool CallingWhile the 3B model possesses strong reasoning capabilities, it lacks real-time knowledge of the user's historical health metrics stored in the SwiftData repository. To bridge this gap, the architecture leverages the framework's Tool Calling paradigm.A custom tool is defined by conforming to the Tool Swift protocol, which requires a name, a description, an @Generable arguments structure, and an asynchronous call(arguments:) function. The description is injected into the model's context window, allowing the model to autonomously determine when to invoke the tool based on the user's prompt.Swiftimport FoundationModels
import SwiftData

struct FetchClinicalHistoryTool: Tool {
    let name = "fetchClinicalHistory"
    let description = "Retrieves the patient's past medical conditions and diagnoses from the local database."

    var modelContext: ModelContext // Injected dependency to access SwiftData

    @Generable
    struct Arguments {
        @Guide(description: "The specific condition to search for, or 'All' for a complete history.")
        let conditionQuery: String
    }

    func call(arguments: Arguments) async throws -> {
        let descriptor = FetchDescriptor<LocalClinicalRecord>()
        let records = try modelContext.fetch(descriptor)

        if arguments.conditionQuery.lowercased() == "all" {
            return records.map { "\($0.dateRecorded): \($0.conditionName) [\($0.status)]" }
        } else {
            let filtered = records.filter { $0.conditionName.localizedCaseInsensitiveContains(arguments.conditionQuery) }
            return filtered.map { "\($0.dateRecorded): \($0.conditionName) [\($0.status)]" }
        }
    }
}
If a user asks the AI assistant, "Does the patient have a history of Basal Cell Carcinoma?", the model recognizes its inability to answer directly and generates the arguments required to invoke the FetchClinicalHistoryTool. The tool executes, queries SwiftData, and returns a serialized string of matching records. The model then resumes generation, synthesizing the newly acquired data into a coherent, natural language response. This establishes a localized, intelligent loop where the model acts as an orchestrator, securely querying the device's encrypted health repository without exposing the data to external networks.3. iOS 26 Liquid Glass Design Implementation3.1 Principles of Liquid Glass InterfaceThe aesthetic and interactive philosophy of iOS 26 is defined by "Liquid Glass," a revolutionary design language that replaces legacy translucency blurs with a dynamic material that reflects, refracts, and bends light. Introduced at WWDC 2025, Liquid Glass represents a shift from static frosted panels to a gel-like, morphing medium that responds to device motion, adaptive shadows, and underlying content.The core characteristic of Liquid Glass is "lensing"—the real-time concentration and bending of light passing through the interface, as opposed to the traditional UI blur that merely scatters light. This creates profound depth, establishing a clear Z-axis hierarchy. According to design guidelines, Liquid Glass is strictly reserved for the navigation and control layer (e.g., floating toolbars, bottom tabs, AI assistant overlays) that float above the primary application content.The legacy UI depicted in Images 5, 6, and 7 features opaque, solid purple headers and stark white backgrounds. Modernizing this involves stretching the content edge-to-edge and floating Liquid Glass navigation components above the content layer.3.2 Main Application Shell and Tab Bar ModernizationImages 5 and 6 display a bottom tab bar with three items: "Agenda", "Patient", and "IntraMail" (with a notification badge of 9). In iOS 26, the TabView automatically adopts the Liquid Glass aesthetic. Furthermore, implementing the new .tabBarMinimizeBehavior(.onScrollDown) view modifier allows the tab bar to fluidly shrink and tuck away when the user reviews long medical documents, maximizing screen real estate.Swiftimport SwiftUI

struct EHRMainShellView: View {
    @State private var activeTab: TabSelection =.patient

    enum TabSelection {
        case agenda, patient, inbox
    }

    var body: some View {
        TabView(selection: $activeTab) {
            AgendaView()
               .tabItem {
                    Label("Agenda", systemImage: "calendar")
                }
               .tag(TabSelection.agenda)

            PatientDashboardView()
               .tabItem {
                    Label("Patient", systemImage: "person.crop.circle")
                }
               .tag(TabSelection.patient)

            InboxView()
               .tabItem {
                    Label("IntraMail", systemImage: "envelope")
                }
               .badge(9) // Maps to the red badge '9' in Images 5 and 6
               .tag(TabSelection.inbox)
        }
        // iOS 26 Liquid Glass behavior: fluidly hides when scrolling
       .tabBarMinimizeBehavior(.onScrollDown)
       .tint(.purple) // Maintains the brand color seen in the legacy app
    }
}
3.3 Recreating the Patient Dashboard (Image 5)Image 5 shows a detailed patient view (Jane Doe, DOB 10/07/75) with a list of navigable sections: Patient Clipboard, Patient Data, Visits, Chart Notes, Rx, Sticky Note, Attachments. This is modernized using a SwiftUI List with an edge-to-edge background, overlaid with a custom Liquid Glass floating header.To implement custom Liquid Glass components, the .glassEffect() view modifier is utilized. The system provides variants such as .regular (adaptable to any content), .clear (for media-rich backgrounds), and .identity (for conditional toggling).Swiftimport SwiftUI
import SwiftData

struct PatientDashboardView: View {
    @Query var patients: [PatientProfile]

    var body: some View {
        NavigationStack {
            ZStack(alignment:.top) {
                // Background Layer: Edge-to-edge content
                List {
                    // Spacer to prevent content from hiding behind the floating header
                    Spacer().frame(height: 100).listRowBackground(Color.clear)

                    Section {
                        NavigationLink(destination: Text("Clipboard")) {
                            Label("Patient Clipboard", systemImage: "doc.clipboard")
                        }
                        NavigationLink(destination: Text("Data")) {
                            Label("Patient Data", systemImage: "chart.xyaxis.line")
                        }
                        NavigationLink(destination: VisitHistoryView()) {
                            Label("Visits", systemImage: "bed.double")
                        }
                        NavigationLink(destination: Text("Chart Notes")) {
                            Label("Chart Notes", systemImage: "folder")
                        }
                        NavigationLink(destination: RxView()) {
                            Label("Rx", systemImage: "pills")
                        }
                        NavigationLink(destination: Text("Sticky Note")) {
                            Label("Sticky Note", systemImage: "note.text")
                        }
                        NavigationLink(destination: Text("Attachments")) {
                            Label("Attachments", systemImage: "paperclip")
                        }
                    }
                }
               .listStyle(.insetGrouped)

                // Foreground Layer: Custom Liquid Glass Header replacing the solid purple bar
                if let patient = patients.first {
                    LiquidGlassPatientHeader(patient: patient)
                }
            }
           .navigationBarHidden(true)
        }
    }
}

struct LiquidGlassPatientHeader: View {
    let patient: PatientProfile

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: "person.crop.circle.fill")
               .resizable()
               .frame(width: 60, height: 60)
               .foregroundColor(.gray)

            VStack(alignment:.leading, spacing: 4) {
                Text("\(patient.firstName) \(patient.lastName)")
                   .font(.headline)
                   .foregroundColor(.primary)
                Text(patient.dateOfBirth, format:.dateTime.month().day().year())
                   .font(.subheadline)
                   .foregroundColor(.secondary)
            }
            Spacer()

            Button(action: { /* Share Action */ }) {
                Image(systemName: "square.and.arrow.up")
                   .font(.title2)
            }
        }
       .padding()
        // Applying the iOS 26 Liquid Glass material with a subtle brand tint
       .glassEffect(.regular.tint(.purple.opacity(0.1)))
       .padding(.horizontal)
       .padding(.top, 10)
    }
}
3.4 Advanced Composition: GlassEffectContainer and Unions (Image 7)Image 7 displays a complex top navigation bar on the iPad interface, featuring discrete tabs for "Tasks", "Docs", "Rx", "Compliance", "Home", "Mail", and "Settings". To modernize this into a cohesive, structured Liquid Glass toolbar, the .glassEffectUnion modifier is utilized.Placing these discrete buttons inside a GlassEffectContainer fundamentally alters their rendering behavior. When elements within this container are animated close to one another, their edges organically merge and separate, mimicking the surface tension of liquid drops. For the glassEffectUnion to successfully fuse the elements into a single contiguous shape, all elements must share the exact same string ID, utilize the identical glass style, and apply the exact same tinting.Swiftimport SwiftUI

struct iPadClinicalToolbar: View {
    @Namespace private var unionNamespace
    @State private var activeSection = "Home"

    let tools =

    var body: some View {
        GlassEffectContainer {
            HStack(spacing: 0) {
                ForEach(tools, id: \.0) { tool in
                    Button(action: {
                        withAnimation { activeSection = tool.0 }
                    }) {
                        VStack(spacing: 4) {
                            Image(systemName: tool.1)
                               .font(.system(size: 20))
                            Text(tool.0)
                               .font(.caption)
                        }
                       .padding(.vertical, 10)
                       .padding(.horizontal, 16)
                       .foregroundColor(activeSection == tool.0?.white :.purple)
                    }
                    // Fusing all buttons into a single Liquid Glass capsule
                   .glassEffectUnion(id: "mainToolbar", namespace: unionNamespace)
                }
            }
            // Mandatory grouping conditions for unions
           .buttonStyle(.glassProminent)
           .tint(Color.white.opacity(0.8))
           .interactive()
        }
    }
}
4. Interactive 3D Anatomical Atlas via RealityKit4.1 Transitioning from 2D Models to Spatial 3D (Image 4)Image 4 prominently displays a 3D rendering of a female head, surrounded by interface tabs (Exam, Impressions, Plans) and tools (Draw, Camera, Morph, Ddx). Legacy applications have relied on 2D vector-based silhouettes to map patient symptoms. While effective for basic hit-testing, 2D representations fail to convey the depth, layering, and complex musculoskeletal relationships critical in specialties like dermatology and plastic surgery.To replicate and vastly improve this interface, the architecture incorporates RealityKit to render a fully interactive, 3D anatomical atlas directly within the iOS application. RealityKit, Apple's high-performance 3D rendering framework, utilizes the Metal API to deliver physics-based rendering, custom shaders, and spatial interaction without requiring a heavy third-party game engine.4.2 Handling USDZ Assets and Entity HierarchiesThe anatomical models are sourced as high-fidelity USDZ files. A complete human head model is a highly complex asset comprising distinct meshes (e.g., epidermal, muscular, skeletal).To manipulate these individual anatomical components programmatically, the USDZ file must be loaded while strictly preserving its entity hierarchy. Utilizing deprecated methods like loadModel flattens the asset into a singular mesh, destroying the ability to interact with specific body parts. Instead, the framework dictates the use of Entity.load(named:in:) or Entity.loadAsync, which maintains the intricate tree of parent and child nodes.The RealityView  is used to bridge RealityKit and SwiftUI. It accepts closures to add entities and update them based on SwiftUI state changes.Swiftimport SwiftUI
import RealityKit

struct AnatomicalRealityView: View {
    @State private var anatomicalModel: Entity?
    @State private var selectedAnatomy: String?

    var body: some View {
        ZStack {
            RealityView { content in
                // Asynchronously load the hierarchical USDZ file
                do {
                    // Assuming "FemaleHeadModel.usdz" exists in the main bundle
                    let model = try await Entity(named: "FemaleHeadModel")

                    // Position the model in front of the camera
                    model.position = SIMD3<Float>(0, -0.2, -0.5)

                    // Ensure collision components are generated for hit-testing
                    model.generateCollisionShapes(recursive: true)

                    content.add(model)
                    DispatchQueue.main.async {
                        self.anatomicalModel = model
                    }
                } catch {
                    print("Failed to load USDZ model: \(error)")
                }
            } update: { content in
                // Update logic: if the AI or user selects a specific part, highlight it
                if let partName = selectedAnatomy, let model = anatomicalModel {
                    highlightAnatomy(scene: model, partName: partName)
                }
            }
           .gesture(
                SpatialTapGesture()
                   .targetedToAnyEntity()
                   .onEnded { value in
                        // Extract the name of the specific mesh that was tapped
                        let tappedEntityName = value.entity.name
                        selectedAnatomy = tappedEntityName
                        print("Tapped anatomical region: \(tappedEntityName)")
                        // This name can now be passed to the Foundation Model for dictation context
                    }
            )

            // UI Overlay mapping to the sidebar in Image 4
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    AnatomyToolSidebar()
                }
            }
        }
    }

    /// Traverses the preserved hierarchy to find the specific anatomical entity and apply a highlight
    func highlightAnatomy(scene: Entity, partName: String) {
        // Reset all materials first (omitted for brevity)

        // Find the specific node by name
        if let anatomicalPart = scene.findEntity(named: partName) as? ModelEntity {
            // Retain the original topology but modify the material for visual highlighting
            var highlightMaterial = SimpleMaterial(color:.red, isMetallic: false)
            // Apply a translucent red tint over the existing texture
            highlightMaterial.color.tint = UIColor.red.withAlphaComponent(0.6)

            anatomicalPart.model?.materials = [highlightMaterial]
        }
    }
}

struct AnatomyToolSidebar: View {
    var body: some View {
        VStack(spacing: 20) {
            Button(action: {}) { Text("Morph").font(.caption) }
            Button(action: {}) { Text("Ddx").font(.caption) }
            Button(action: {}) { Text("Assoc. Dx").font(.caption) }

            // Image icons for body regions (Skin, Genitals, Head) as seen in Image 4
            Image(systemName: "figure.stand").resizable().frame(width: 30, height: 30)
            Text("Skin AP").font(.caption2)

            Image(systemName: "face.smiling").resizable().frame(width: 30, height: 30)
            Text("Head").font(.caption2)
        }
       .padding()
       .glassEffect(.regular.tint(.white.opacity(0.8)))
       .padding()
    }
}
4.3 Layer Manipulation and Medical ContextA foundational feature of advanced clinical software is the ability to "peel back" layers of the body to reveal underlying structures. In RealityKit, this is achieved by managing the .isEnabled property on hierarchical parent entities. If a user taps a "Show Muscular Layer" toggle, the update closure of the RealityView triggers the RealityKit engine to find the epidermal entity group (scene.findEntity(named: "Skin_Layer")) and set its .isEnabled property to false, instantly revealing the muscular meshes beneath.5. Clinical Workflows and Automated Document Generation5.1 Integrating the AI and RealityKitThe true architectural triumph lies in the seamless synthesis of the Foundation Model, HealthKit/SwiftData, Liquid Glass, and RealityKit. The interplay of these systems creates an autonomous, multimodal clinical loop capable of sophisticated reasoning.Consider the workflow generated from Image 4 and Image 8. The physician taps the "nose" mesh on the 3D AnatomicalRealityView. The SpatialTapGesture captures the entity name: "facial_mesh_nose". The physician then dictates: "Found a 2mm basal cell carcinoma here. Patient states it has been bleeding for two weeks."The ClinicalIntelligenceService (detailed in Section 2) is invoked. The prompt passed to the 3B Foundation Model includes the dictated text and the spatial context: [Anatomical Focus: facial_mesh_nose].The local LLM synthesizes this into the structured @Generable ClinicalVisitNote:ccHPI: "Patient presents with a lesion on the nose that has been bleeding for two weeks."examFindings: "2mm lesion observed on the nose."impressionsAndPlan: "Basal Cell Carcinoma. Plan for surgical excision."affectedAnatomicalZones: ["facial_mesh_nose"]This structured data is immediately synchronized to the SwiftData repository.5.2 PDF Generation (Image 9)Image 9 displays a final PDF output of the Visit Note (April 10, 2019), detailing the Social History, Chief Complaint, Exam, Impression/Plan, and Follow Up. In a local-first application, this document cannot be generated by a cloud rendering engine. Instead, SwiftUI views are converted directly into PDF documents using native iOS rendering APIs (such as ImageRenderer introduced in iOS 16).Swiftimport SwiftUI

/// Represents the UI layout of the PDF document seen in Image 9
struct ClinicalPDFDocumentView: View {
    let patient: PatientProfile
    let visitNote: LocalClinicalRecord
    let clinicalDetails: ClinicalVisitNote // The data generated by the Foundation Model

    var body: some View {
        VStack(alignment:.leading, spacing: 20) {
            // Header
            HStack {
                Text("Visit Note - \(visitNote.dateRecorded, format:.dateTime.month().day().year())")
                   .foregroundColor(.purple)
                Spacer()
                Text("\(patient.lastName), \(patient.firstName)")
                   .font(.title3).bold().foregroundColor(.purple)
            }
            Divider()

            // Body Content mirroring Image 9
            VStack(alignment:.leading, spacing: 12) {
                Text("Chief Complaint:").bold()
                Text(clinicalDetails.ccHPI)

                Text("Exam:").bold()
                Text(clinicalDetails.examFindings)

                Text("Impression/Plan:").bold()
                Text(clinicalDetails.impressionsAndPlan)

                Text("Follow up in 1 year").bold()
            }
           .font(.system(size: 12))

            Spacer()

            // Footer
            VStack(alignment:.center) {
                Text("Electronically Signed By: \(patient.firstName) \(patient.lastName) Provider")
                   .font(.caption)
                   .underline()
            }
           .frame(maxWidth:.infinity)
        }
       .padding(40)
       .frame(width: 612, height: 792) // Standard US Letter size at 72 DPI
       .background(Color.white)
    }
}

/// Function to render the SwiftUI View into a PDF Data blob locally
@MainActor
func generatePDFLocally(patient: PatientProfile, record: LocalClinicalRecord, details: ClinicalVisitNote) -> URL? {
    let pdfView = ClinicalPDFDocumentView(patient: patient, visitNote: record, clinicalDetails: details)
    let renderer = ImageRenderer(content: pdfView)

    let url = FileManager.default.temporaryDirectory.appendingPathComponent("VisitNote_\(record.recordID).pdf")

    renderer.render { size, context in
        var box = CGRect(x: 0, y: 0, width: size.width, height: size.height)
        guard let cgContext = CGContext(url as CFURL, mediaBox: &box, nil) else { return }

        cgContext.beginPDFPage(nil)
        context(cgContext)
        cgContext.endPDFPage()
        cgContext.closePDF()
    }

    return url
}
This local rendering pipeline ensures that the final clinical artifact is generated instantly, without requiring external network calls, perfectly aligning with the local-first mandate.6. Strategic Implications and ConclusionsThe recreation of an enterprise-grade, visually complex Electronic Health Record interface—historically the domain of massive web applications and cloud servers—is now wholly achievable as an autonomous, on-device iOS application. By meticulously translating the legacy visual layouts into modernized frameworks, the application provides a vastly superior user experience while enforcing absolute data sovereignty.By strategically synthesizing iOS 26 technologies, this architecture redefines the capabilities of personal health software. The Foundation Models framework transcends traditional chatbots, serving instead as a deterministic, tool-wielding orchestrator capable of parsing complex clinical relationships from dictation and producing structured schemas. HealthKit and SwiftData liberate the application from network dependency, ensuring instantaneous access to vital FHIR health histories. RealityKit transforms static diagrammatic data into an interactive, 3D spatial experience, preserving entity hierarchies for precise diagnostic mapping. Finally, the Liquid Glass design language establishes a fluid, hierarchical aesthetic utilizing advanced lensing mechanics, preventing informational overload while modernizing the interface.This paradigm moves the medical software industry beyond mere data digitization. It establishes a sovereign computational environment where advanced artificial intelligence, spatial rendering, and highly secure medical data converge locally, offering patients and practitioners an intelligent, private, and exceptionally resilient diagnostic tool.
