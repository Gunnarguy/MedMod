import SwiftUI
import PhotosUI
import SwiftData

struct ClinicalPhotoView: View {
    let patient: PatientProfile
    @Environment(\.modelContext) private var modelContext
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var selectedRegion: String = "unspecified"
    @State private var noteText: String = ""
    @State private var capturedImages: [UIImage] = []
    @State private var showCamera = false
    @State private var cameraImage: UIImage?

    private var photos: [ClinicalPhoto] {
        (patient.clinicalPhotos ?? []).sorted { $0.captureDate > $1.captureDate }
    }

    private let regions = [
        "forehead", "scalp", "left_cheek", "right_cheek", "chin",
        "facial_mesh_nose", "neck", "left_upper_extremity", "right_upper_extremity",
        "chest", "abdomen", "upper_back", "lower_back",
        "left_lower_extremity", "right_lower_extremity"
    ]

    var body: some View {
        List {
            // Capture section
            Section("Capture New Photo") {
                Picker("Anatomical Region", selection: $selectedRegion) {
                    Text("Unspecified").tag("unspecified")
                    ForEach(regions, id: \.self) { region in
                        Text(region.replacingOccurrences(of: "_", with: " ").capitalized)
                            .tag(region)
                    }
                }

                TextField("Clinical notes (optional)", text: $noteText, axis: .vertical)
                    .lineLimit(2...4)

                HStack(spacing: 12) {
                    PhotosPicker(selection: $selectedItems, maxSelectionCount: 5, matching: .images) {
                        Label("Photo Library", systemImage: "photo.on.rectangle")
                    }
                    .buttonStyle(.bordered)

                    Button {
                        showCamera = true
                    } label: {
                        Label("Camera", systemImage: "camera.fill")
                    }
                    .buttonStyle(.bordered)
                    .tint(.blue)
                }

                if !capturedImages.isEmpty {
                    ScrollView(.horizontal) {
                        HStack(spacing: 8) {
                            ForEach(capturedImages.indices, id: \.self) { idx in
                                Image(uiImage: capturedImages[idx])
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 80, height: 80)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                    }

                    Button {
                        savePhotos()
                    } label: {
                        Label("Save \(capturedImages.count) Photo\(capturedImages.count == 1 ? "" : "s")", systemImage: "square.and.arrow.down")
                    }
                    .buttonStyle(.borderedProminent)
                }
            }

            // Gallery section
            Section("Photo History (\(photos.count))") {
                if photos.isEmpty {
                    ContentUnavailableView("No Clinical Photos", systemImage: "camera.badge.clock",
                        description: Text("Capture dermatological photos to track lesion progression."))
                } else {
                    ForEach(photos) { photo in
                        photoRow(photo)
                    }
                }
            }
        }
        .navigationTitle("Clinical Photos")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        .listStyle(.insetGrouped)
        #endif
        .onChange(of: selectedItems) { _, newItems in
            Task {
                for item in newItems {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        capturedImages.append(image)
                    }
                }
                selectedItems = []
            }
        }
        .onChange(of: cameraImage) { _, newImage in
            if let img = newImage {
                capturedImages.append(img)
                cameraImage = nil
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraView(image: $cameraImage)
                .ignoresSafeArea()
        }
    }

    private func photoRow(_ photo: ClinicalPhoto) -> some View {
        HStack(spacing: 12) {
            if let image = loadImage(from: photo.filePath) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 60, height: 60)
                    .overlay(Image(systemName: "photo").foregroundColor(.gray))
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(photo.anatomicalRegion.replacingOccurrences(of: "_", with: " ").capitalized)
                    .font(.subheadline.bold())
                Text(photo.captureDate, format: .dateTime.month().day().year().hour().minute())
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .clinicalFinePrint()
                HStack(spacing: 6) {
                    ClinicalSourceBadge(descriptor: photo.sourceDescriptor)
                    SourceOfTruthBadge(authoritative: photo.sourceDescriptor.authoritative)
                }
                if let notes = photo.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .clinicalFinePrint()
                        .clinicalRowSummaryText(lines: 2)
                }
            }
        }
    }

    private func savePhotos() {
        let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let photosDir = documentsDir.appendingPathComponent("ClinicalPhotos", isDirectory: true)
        try? FileManager.default.createDirectory(at: photosDir, withIntermediateDirectories: true)

        for image in capturedImages {
            guard let data = image.jpegData(compressionQuality: 0.85) else { continue }
            let filename = "\(patient.medicalRecordNumber)_\(UUID().uuidString).jpg"
            let fileURL = photosDir.appendingPathComponent(filename)
            try? data.write(to: fileURL)

            let photo = ClinicalPhoto(
                anatomicalRegion: selectedRegion,
                notes: noteText.isEmpty ? nil : noteText,
                filePath: fileURL.path,
                sourceKind: ClinicalSourceKind.clinicianCaptured.rawValue,
                sourceSystemName: "MedMod Capture Workspace",
                sourceRecordIdentifier: filename,
                sourceLastSyncedAt: .now,
                sourceOfTruth: true
            )
            photo.patient = patient
            modelContext.insert(photo)
        }

        try? modelContext.save()
        capturedImages = []
        noteText = ""
    }

    private func loadImage(from path: String) -> UIImage? {
        UIImage(contentsOfFile: path)
    }
}

// MARK: - Camera UIKit Bridge

struct CameraView: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraView
        init(_ parent: CameraView) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            parent.image = info[.originalImage] as? UIImage
            parent.dismiss()
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
