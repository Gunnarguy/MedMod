import SwiftUI
import RealityKit

struct AnatomicalRealityView: View {
    @State private var anatomicalModel: Entity?
    @Binding var selectedAnatomy: String?

    var body: some View {
        ZStack {
            RealityView { content in
                // Set up a basic fallback entity if USDZ isn't present
                let mesh = MeshResource.generateSphere(radius: 0.2)
                var material = SimpleMaterial(color: .gray, isMetallic: false)
                let model = ModelEntity(mesh: mesh, materials: [material])

                model.name = "facial_mesh_nose" // For testing spatial tap
                model.position = SIMD3<Float>(0, -0.2, -0.5)
                model.generateCollisionShapes(recursive: true)
                content.add(model)

                DispatchQueue.main.async {
                    self.anatomicalModel = model
                }

                // Blueprint original logic for hierarchical USDZ loading:
                /*
                do {
                    let model = try await Entity(named: "FemaleHeadModel")
                    model.position = SIMD3<Float>(0, -0.2, -0.5)
                    model.generateCollisionShapes(recursive: true)
                    content.add(model)
                    DispatchQueue.main.async {
                        self.anatomicalModel = model
                    }
                } catch {
                    print("Failed to load USDZ model: \(error)")
                }
                */
            } update: { content in
                if let partName = selectedAnatomy, let model = anatomicalModel {
                    highlightAnatomy(scene: model, partName: partName)
                }
            }
            .gesture(
                SpatialTapGesture()
                    .targetedToAnyEntity()
                    .onEnded { value in
                        let tappedEntityName = value.entity.name
                        selectedAnatomy = tappedEntityName
                        print("Tapped anatomical region: \(tappedEntityName)")
                        // Trigger AI dictation flow here
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

    func highlightAnatomy(scene: Entity, partName: String) {
        if let anatomicalPart = scene.findEntity(named: partName) as? ModelEntity {
            var highlightMaterial = SimpleMaterial(color: .red, isMetallic: false)
            #if os(macOS)
            highlightMaterial.color.tint = NSColor.red.withAlphaComponent(0.6)
            #else
            highlightMaterial.color.tint = UIColor.red.withAlphaComponent(0.6)
            #endif
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

            Image(systemName: "figure.stand").resizable().frame(width: 30, height: 30)
            Text("Skin AP").font(.caption2)

            Image(systemName: "face.smiling").resizable().frame(width: 30, height: 30)
            Text("Head").font(.caption2)
        }
        .padding()
        .background(.ultraThinMaterial) // Liquid Glass equivalent
        .cornerRadius(12)
        .padding()
    }
}
