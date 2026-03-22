import SwiftUI
import RealityKit

struct AnatomicalRealityView: View {
    @State private var anatomicalModel: Entity?
    @Binding var selectedAnatomy: String?
    @State private var showSkinLayer = true
    @State private var showMuscleLayer = true
    @State private var showSkeletonLayer = true
    @State private var previousSelection: String?

    // Stored original materials so we can un-highlight
    @State private var originalMaterials: [String: [any RealityKit.Material]] = [:]

    var body: some View {
        RealityView { content in
            do {
                let model = try await Entity(named: "FemaleHeadModel")
                model.position = SIMD3<Float>(0, -0.2, -0.5)
                model.generateCollisionShapes(recursive: true)
                addInputTargets(to: model)
                content.add(model)
                Task { @MainActor in
                    self.anatomicalModel = model
                }
            } catch {
                let root = buildFallbackAnatomicalModel()
                content.add(root)
                Task { @MainActor in
                    self.anatomicalModel = root
                }
            }
        } update: { content in
            guard let model = anatomicalModel else { return }
            applyLayerVisibility(scene: model)
            applyHighlight(scene: model)
        }
        .simultaneousGesture(
            SpatialTapGesture()
                .targetedToAnyEntity()
                .onEnded { value in
                    selectedAnatomy = value.entity.name
                }
        )
        .overlay(alignment: .top) {
            if let part = selectedAnatomy {
                HStack(spacing: 6) {
                    Image(systemName: "scope")
                    Text(AnatomicalRealityView.displayName(for: part))
                        .fontWeight(.medium)
                }
                .font(.caption)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial)
                .cornerRadius(8)
                .padding(.top, 8)
                .allowsHitTesting(false)
            }
        }
        .overlay(alignment: .bottomTrailing) {
            AnatomyToolSidebar(
                showSkinLayer: $showSkinLayer,
                showMuscleLayer: $showMuscleLayer,
                showSkeletonLayer: $showSkeletonLayer,
                selectedAnatomy: $selectedAnatomy
            )
        }
    }

    // MARK: - Fallback Model Builder

    /// Helper to create a tappable ModelEntity with InputTarget + Collision
    private func makePart(
        name: String,
        mesh: MeshResource,
        material: any RealityKit.Material,
        position: SIMD3<Float>,
        collision: ShapeResource,
        scale: SIMD3<Float> = SIMD3<Float>(1, 1, 1),
        orientation: simd_quatf = simd_quatf(angle: 0, axis: SIMD3<Float>(0, 1, 0))
    ) -> ModelEntity {
        let entity = ModelEntity(mesh: mesh, materials: [material])
        entity.name = name
        entity.position = position
        entity.scale = scale
        entity.orientation = orientation
        var input = InputTargetComponent(allowedInputTypes: .all)
        entity.components.set(input)
        entity.components.set(CollisionComponent(shapes: [collision]))
        return entity
    }

    /// Builds a recognizable anatomical mannequin with head, face, neck, torso, and arms.
    private func buildFallbackAnatomicalModel() -> Entity {
        let root = Entity()
        root.name = "AnatomicalRoot"
        root.position = SIMD3<Float>(0, 0.05, -0.6)

        // ── Materials ──
        #if os(macOS)
        let skinTone = NSColor(red: 0.91, green: 0.78, blue: 0.65, alpha: 1.0)
        let darkerSkin = NSColor(red: 0.85, green: 0.72, blue: 0.60, alpha: 1.0)
        let lipColor = NSColor(red: 0.82, green: 0.52, blue: 0.50, alpha: 1.0)
        let muscleColor = NSColor(red: 0.72, green: 0.28, blue: 0.28, alpha: 0.92)
        let boneColor = NSColor(white: 0.92, alpha: 1.0)
        let torsoSkin = NSColor(red: 0.89, green: 0.76, blue: 0.64, alpha: 1.0)
        #else
        let skinTone = UIColor(red: 0.91, green: 0.78, blue: 0.65, alpha: 1.0)
        let darkerSkin = UIColor(red: 0.85, green: 0.72, blue: 0.60, alpha: 1.0)
        let lipColor = UIColor(red: 0.82, green: 0.52, blue: 0.50, alpha: 1.0)
        let muscleColor = UIColor(red: 0.72, green: 0.28, blue: 0.28, alpha: 0.92)
        let boneColor = UIColor(white: 0.92, alpha: 1.0)
        let torsoSkin = UIColor(red: 0.89, green: 0.76, blue: 0.64, alpha: 1.0)
        #endif

        let skinMat = SimpleMaterial(color: skinTone, isMetallic: false)
        let darkerMat = SimpleMaterial(color: darkerSkin, isMetallic: false)
        let lipMat = SimpleMaterial(color: lipColor, isMetallic: false)
        let muscleMat = SimpleMaterial(color: muscleColor, isMetallic: false)
        let boneMat = SimpleMaterial(color: boneColor, isMetallic: false)
        let torsoMat = SimpleMaterial(color: torsoSkin, isMetallic: false)

        // ════════════════════════════════════════════
        // SKELETON LAYER
        // ════════════════════════════════════════════
        let skeletonLayer = Entity()
        skeletonLayer.name = "Skeleton_Layer"

        // Skull — slightly tall sphere
        skeletonLayer.addChild(makePart(
            name: "skull",
            mesh: .generateSphere(radius: 0.09),
            material: boneMat,
            position: SIMD3<Float>(0, 0.28, 0),
            collision: .generateSphere(radius: 0.09),
            scale: SIMD3<Float>(1, 1.12, 0.95)))

        // Mandible (jawbone)
        skeletonLayer.addChild(makePart(
            name: "mandible",
            mesh: .generateBox(size: SIMD3<Float>(0.075, 0.025, 0.05), cornerRadius: 0.01),
            material: boneMat,
            position: SIMD3<Float>(0, 0.175, 0.015),
            collision: .generateBox(size: SIMD3<Float>(0.075, 0.025, 0.05))))

        // Cervical spine
        skeletonLayer.addChild(makePart(
            name: "cervical_spine",
            mesh: .generateBox(size: SIMD3<Float>(0.02, 0.10, 0.02), cornerRadius: 0.005),
            material: boneMat,
            position: SIMD3<Float>(0, 0.10, -0.01),
            collision: .generateBox(size: SIMD3<Float>(0.02, 0.10, 0.02))))

        // Rib cage (upper thorax)
        skeletonLayer.addChild(makePart(
            name: "ribcage",
            mesh: .generateBox(size: SIMD3<Float>(0.16, 0.18, 0.09), cornerRadius: 0.035),
            material: boneMat,
            position: SIMD3<Float>(0, -0.05, 0),
            collision: .generateBox(size: SIMD3<Float>(0.16, 0.18, 0.09))))

        root.addChild(skeletonLayer)

        // ════════════════════════════════════════════
        // MUSCLE LAYER
        // ════════════════════════════════════════════
        let muscleLayer = Entity()
        muscleLayer.name = "Muscle_Layer"

        // Facial muscles
        muscleLayer.addChild(makePart(
            name: "facial_muscles",
            mesh: .generateSphere(radius: 0.096),
            material: muscleMat,
            position: SIMD3<Float>(0, 0.28, 0.003),
            collision: .generateSphere(radius: 0.096),
            scale: SIMD3<Float>(1, 1.12, 0.96)))

        // Neck muscles (sternocleidomastoid area)
        muscleLayer.addChild(makePart(
            name: "neck_muscles",
            mesh: .generateBox(size: SIMD3<Float>(0.07, 0.10, 0.06), cornerRadius: 0.025),
            material: muscleMat,
            position: SIMD3<Float>(0, 0.10, 0),
            collision: .generateBox(size: SIMD3<Float>(0.07, 0.10, 0.06))))

        // Pectorals / chest muscles
        muscleLayer.addChild(makePart(
            name: "chest_muscles",
            mesh: .generateBox(size: SIMD3<Float>(0.19, 0.10, 0.10), cornerRadius: 0.04),
            material: muscleMat,
            position: SIMD3<Float>(0, 0.0, 0.005),
            collision: .generateBox(size: SIMD3<Float>(0.19, 0.10, 0.10))))

        // Deltoids — left
        muscleLayer.addChild(makePart(
            name: "left_deltoid",
            mesh: .generateSphere(radius: 0.032),
            material: muscleMat,
            position: SIMD3<Float>(-0.12, 0.04, 0),
            collision: .generateSphere(radius: 0.032)))

        // Deltoids — right
        muscleLayer.addChild(makePart(
            name: "right_deltoid",
            mesh: .generateSphere(radius: 0.032),
            material: muscleMat,
            position: SIMD3<Float>(0.12, 0.04, 0),
            collision: .generateSphere(radius: 0.032)))

        root.addChild(muscleLayer)

        // ════════════════════════════════════════════
        // SKIN LAYER (outermost — the visible mannequin)
        // ════════════════════════════════════════════
        let skinLayer = Entity()
        skinLayer.name = "Skin_Layer"

        // Head (cranium) — egg shape via scale
        skinLayer.addChild(makePart(
            name: "scalp",
            mesh: .generateSphere(radius: 0.10),
            material: skinMat,
            position: SIMD3<Float>(0, 0.28, 0),
            collision: .generateSphere(radius: 0.10),
            scale: SIMD3<Float>(0.92, 1.10, 0.95)))

        // Forehead — subtle ridge
        skinLayer.addChild(makePart(
            name: "forehead",
            mesh: .generateBox(size: SIMD3<Float>(0.10, 0.035, 0.015), cornerRadius: 0.015),
            material: skinMat,
            position: SIMD3<Float>(0, 0.34, 0.085),
            collision: .generateBox(size: SIMD3<Float>(0.10, 0.035, 0.02))))

        // Nose — a little protruding wedge
        skinLayer.addChild(makePart(
            name: "facial_mesh_nose",
            mesh: .generateBox(size: SIMD3<Float>(0.022, 0.040, 0.030), cornerRadius: 0.010),
            material: darkerMat,
            position: SIMD3<Float>(0, 0.265, 0.10),
            collision: .generateBox(size: SIMD3<Float>(0.028, 0.045, 0.035))))

        // Left cheek
        skinLayer.addChild(makePart(
            name: "left_cheek",
            mesh: .generateSphere(radius: 0.032),
            material: skinMat,
            position: SIMD3<Float>(-0.058, 0.245, 0.07),
            collision: .generateSphere(radius: 0.035)))

        // Right cheek
        skinLayer.addChild(makePart(
            name: "right_cheek",
            mesh: .generateSphere(radius: 0.032),
            material: skinMat,
            position: SIMD3<Float>(0.058, 0.245, 0.07),
            collision: .generateSphere(radius: 0.035)))

        // Chin
        skinLayer.addChild(makePart(
            name: "chin",
            mesh: .generateBox(size: SIMD3<Float>(0.04, 0.025, 0.03), cornerRadius: 0.012),
            material: darkerMat,
            position: SIMD3<Float>(0, 0.19, 0.075),
            collision: .generateBox(size: SIMD3<Float>(0.045, 0.03, 0.035))))

        // Lips
        skinLayer.addChild(makePart(
            name: "lips",
            mesh: .generateBox(size: SIMD3<Float>(0.038, 0.012, 0.015), cornerRadius: 0.006),
            material: lipMat,
            position: SIMD3<Float>(0, 0.215, 0.09),
            collision: .generateBox(size: SIMD3<Float>(0.042, 0.016, 0.018))))

        // Ears — left
        skinLayer.addChild(makePart(
            name: "left_ear",
            mesh: .generateBox(size: SIMD3<Float>(0.012, 0.035, 0.020), cornerRadius: 0.006),
            material: darkerMat,
            position: SIMD3<Float>(-0.092, 0.275, 0.0),
            collision: .generateBox(size: SIMD3<Float>(0.016, 0.04, 0.024))))

        // Ears — right
        skinLayer.addChild(makePart(
            name: "right_ear",
            mesh: .generateBox(size: SIMD3<Float>(0.012, 0.035, 0.020), cornerRadius: 0.006),
            material: darkerMat,
            position: SIMD3<Float>(0.092, 0.275, 0.0),
            collision: .generateBox(size: SIMD3<Float>(0.016, 0.04, 0.024))))

        // Neck
        skinLayer.addChild(makePart(
            name: "neck",
            mesh: .generateBox(size: SIMD3<Float>(0.065, 0.08, 0.060), cornerRadius: 0.028),
            material: skinMat,
            position: SIMD3<Float>(0, 0.14, 0),
            collision: .generateBox(size: SIMD3<Float>(0.065, 0.08, 0.060))))

        // Torso (upper body)
        skinLayer.addChild(makePart(
            name: "torso",
            mesh: .generateBox(size: SIMD3<Float>(0.20, 0.22, 0.10), cornerRadius: 0.04),
            material: torsoMat,
            position: SIMD3<Float>(0, -0.01, 0),
            collision: .generateBox(size: SIMD3<Float>(0.20, 0.22, 0.10))))

        // Left shoulder
        skinLayer.addChild(makePart(
            name: "left_shoulder",
            mesh: .generateSphere(radius: 0.038),
            material: skinMat,
            position: SIMD3<Float>(-0.13, 0.06, 0),
            collision: .generateSphere(radius: 0.038)))

        // Right shoulder
        skinLayer.addChild(makePart(
            name: "right_shoulder",
            mesh: .generateSphere(radius: 0.038),
            material: skinMat,
            position: SIMD3<Float>(0.13, 0.06, 0),
            collision: .generateSphere(radius: 0.038)))

        // Right upper arm
        skinLayer.addChild(makePart(
            name: "right_upper_extremity",
            mesh: .generateBox(size: SIMD3<Float>(0.045, 0.16, 0.045), cornerRadius: 0.020),
            material: skinMat,
            position: SIMD3<Float>(0.14, -0.06, 0),
            collision: .generateBox(size: SIMD3<Float>(0.045, 0.16, 0.045))))

        // Left upper arm
        skinLayer.addChild(makePart(
            name: "left_upper_extremity",
            mesh: .generateBox(size: SIMD3<Float>(0.045, 0.16, 0.045), cornerRadius: 0.020),
            material: skinMat,
            position: SIMD3<Float>(-0.14, -0.06, 0),
            collision: .generateBox(size: SIMD3<Float>(0.045, 0.16, 0.045))))

        root.addChild(skinLayer)

        // Belt-and-suspenders: regenerate collision shapes for the whole tree
        root.generateCollisionShapes(recursive: true)

        return root
    }

    // MARK: - Highlighting

    private func applyHighlight(scene: Entity) {
        // Un-highlight previous selection
        if let prev = previousSelection, prev != selectedAnatomy,
           let prevEntity = scene.findEntity(named: prev) as? ModelEntity,
           let saved = originalMaterials[prev] {
            prevEntity.model?.materials = saved
        }

        // Highlight current selection
        if let partName = selectedAnatomy,
           let entity = scene.findEntity(named: partName) as? ModelEntity {
            // Save original if not already saved
            if originalMaterials[partName] == nil, let mats = entity.model?.materials {
                originalMaterials[partName] = mats
            }
            var highlight = SimpleMaterial(color: .red, isMetallic: false)
            #if os(macOS)
            highlight.color.tint = NSColor.red.withAlphaComponent(0.6)
            #else
            highlight.color.tint = UIColor.red.withAlphaComponent(0.6)
            #endif
            entity.model?.materials = [highlight]
        }

        Task { @MainActor in
            previousSelection = selectedAnatomy
        }
    }

    private func applyLayerVisibility(scene: Entity) {
        scene.findEntity(named: "Skin_Layer")?.isEnabled = showSkinLayer
        scene.findEntity(named: "Muscle_Layer")?.isEnabled = showMuscleLayer
        scene.findEntity(named: "Skeleton_Layer")?.isEnabled = showSkeletonLayer
    }

    // MARK: - Display Names

    static let regionNames: [String: String] = [
        "scalp": "Scalp", "facial_mesh_nose": "Nose", "left_cheek": "Left Cheek",
        "right_cheek": "Right Cheek", "forehead": "Forehead", "chin": "Chin",
        "lips": "Lips", "left_ear": "Left Ear", "right_ear": "Right Ear",
        "neck": "Neck", "torso": "Torso",
        "left_shoulder": "Left Shoulder", "right_shoulder": "Right Shoulder",
        "right_upper_extremity": "Right Upper Extremity",
        "left_upper_extremity": "Left Upper Extremity",
        "skull": "Skull", "mandible": "Mandible", "cervical_spine": "Cervical Spine",
        "ribcage": "Rib Cage",
        "facial_muscles": "Facial Muscles", "neck_muscles": "Neck Muscles",
        "chest_muscles": "Pectoral Muscles",
        "left_deltoid": "Left Deltoid", "right_deltoid": "Right Deltoid"
    ]

    static func displayName(for entityName: String) -> String {
        regionNames[entityName] ?? entityName
    }

    /// Recursively adds InputTargetComponent to all ModelEntities (needed for loaded .usdz models)
    private func addInputTargets(to entity: Entity) {
        if entity is ModelEntity {
            entity.components.set(InputTargetComponent(allowedInputTypes: .all))
        }
        for child in entity.children {
            addInputTargets(to: child)
        }
    }
}

// MARK: - Sidebar

struct AnatomyToolSidebar: View {
    @Binding var showSkinLayer: Bool
    @Binding var showMuscleLayer: Bool
    @Binding var showSkeletonLayer: Bool
    @Binding var selectedAnatomy: String?

    private let quickRegions = [
        ("scalp", "Scalp", "brain.head.profile"),
        ("forehead", "Forehead", "rectangle.portrait.and.arrow.forward"),
        ("facial_mesh_nose", "Nose", "nose"),
        ("left_cheek", "L. Cheek", "face.smiling"),
        ("right_cheek", "R. Cheek", "face.smiling"),
        ("neck", "Neck", "figure.stand"),
        ("torso", "Torso", "figure.arms.open"),
        ("right_upper_extremity", "R. Arm", "hand.raised"),
        ("left_upper_extremity", "L. Arm", "hand.raised.fill"),
    ]

    var body: some View {
        VStack(spacing: 12) {
            Text("Layers")
                .font(.caption.bold())
                .foregroundColor(.secondary)
            Toggle("Skin", isOn: $showSkinLayer).font(.caption)
            Toggle("Muscle", isOn: $showMuscleLayer).font(.caption)
            Toggle("Skeleton", isOn: $showSkeletonLayer).font(.caption)

            Divider()

            Text("Quick Select")
                .font(.caption.bold())
                .foregroundColor(.secondary)

            ForEach(quickRegions, id: \.0) { region in
                Button {
                    selectedAnatomy = region.0
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: region.2)
                            .frame(width: 16)
                        Text(region.1)
                            .font(.caption)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                .foregroundColor(selectedAnatomy == region.0 ? .red : .primary)
            }
        }
        .padding(12)
        .frame(width: 140)
        .background(.ultraThinMaterial)
        .cornerRadius(12)
        .padding(8)
    }
}
