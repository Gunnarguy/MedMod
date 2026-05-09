import Foundation

/// Anatomical region display name mapping — used across clinical views and AI services.
enum AnatomicalRegion {
    static let regionNames: [String: String] = [
        "scalp": "Scalp", "facial_mesh_nose": "Nose", "left_cheek": "Left Cheek",
        "right_cheek": "Right Cheek", "forehead": "Forehead", "chin": "Chin",
        "lips": "Lips", "left_ear": "Left Ear", "right_ear": "Right Ear",
        "neck": "Neck", "torso": "Torso",
        "left_shoulder": "Left Shoulder", "right_shoulder": "Right Shoulder",
        "right_upper_extremity": "Right Upper Extremity",
        "left_upper_extremity": "Left Upper Extremity",
        "left_hand": "Left Hand", "right_hand": "Right Hand",
        "upper_abdomen": "Upper Abdomen",
        "skull": "Skull", "mandible": "Mandible", "cervical_spine": "Cervical Spine",
        "ribcage": "Rib Cage",
        "facial_muscles": "Facial Muscles", "neck_muscles": "Neck Muscles",
        "chest_muscles": "Pectoral Muscles",
        "left_deltoid": "Left Deltoid", "right_deltoid": "Right Deltoid",
        "lower_back": "Lower Back", "left_lower_extremity": "Left Lower Extremity",
        "right_lower_extremity": "Right Lower Extremity",
        "left_foot": "Left Foot", "right_foot": "Right Foot"
    ]

    /// Sorted region keys for picker display
    static let sortedRegions: [(key: String, label: String)] = regionNames
        .sorted { $0.value < $1.value }
        .map { (key: $0.key, label: $0.value) }

    static func displayName(for entityName: String) -> String {
        regionNames[entityName] ?? entityName
    }
}
