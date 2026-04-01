import SwiftUI
import SwiftData

/// Interactive 2D anatomical body map showing regions with clinical data
struct AnatomicalRealityView: View {
    let patient: PatientProfile
    @State private var selectedRegion: String?
    @State private var showRegionDetail = false

    private var records: [LocalClinicalRecord] {
        (patient.clinicalRecords ?? [])
    }
    private var photos: [ClinicalPhoto] {
        (patient.clinicalPhotos ?? [])
    }

    /// Regions that have at least one record or photo
    private var activeRegions: Set<String> {
        var set = Set<String>()
        for r in records {
            for zone in r.affectedAnatomicalZones ?? [] {
                set.insert(zone)
            }
        }
        for p in photos {
            set.insert(p.anatomicalRegion)
        }
        return set
    }

    /// Count of records per region
    private func recordCount(for region: String) -> Int {
        records.filter { ($0.affectedAnatomicalZones ?? []).contains(region) }.count
    }
    private func photoCount(for region: String) -> Int {
        photos.filter { $0.anatomicalRegion == region }.count
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Summary
                HStack(spacing: 16) {
                    summaryCard(value: "\(activeRegions.count)", label: "Active Regions", icon: "mappin.and.ellipse", color: .purple)
                    summaryCard(value: "\(records.count)", label: "Records", icon: "doc.text", color: .blue)
                    summaryCard(value: "\(photos.count)", label: "Photos", icon: "camera", color: .orange)
                }
                .padding(.horizontal)

                // Body map
                bodyMapView
                    .padding(.horizontal)

                // Active region list
                if !activeRegions.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Regions with Clinical Data")
                            .font(.headline)
                            .padding(.horizontal)
                        ForEach(activeRegions.sorted(), id: \.self) { region in
                            regionRow(region)
                        }
                    }
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("Body Map")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .sheet(isPresented: $showRegionDetail) {
            if let region = selectedRegion {
                NavigationStack {
                    regionDetailView(region)
                }
            }
        }
    }

    // MARK: - Body Map

    private var bodyMapView: some View {
        VStack(spacing: 0) {
            Text("Tap a region to view clinical data")
                .font(.caption)
                .foregroundColor(.secondary)
                .clinicalFinePrint()
                .padding(.bottom, 8)

            // Head
            HStack(spacing: 4) {
                regionButton("scalp", label: "Scalp", width: 50, height: 25)
            }

            HStack(spacing: 2) {
                regionButton("left_ear", label: "L Ear", width: 20, height: 30)
                VStack(spacing: 1) {
                    regionButton("forehead", label: "Forehead", width: 56, height: 20)
                    HStack(spacing: 1) {
                        regionButton("left_cheek", label: "L", width: 18, height: 22)
                        regionButton("facial_mesh_nose", label: "Nose", width: 18, height: 22)
                        regionButton("right_cheek", label: "R", width: 18, height: 22)
                    }
                    HStack(spacing: 1) {
                        regionButton("lips", label: "Lips", width: 28, height: 14)
                        regionButton("chin", label: "Chin", width: 28, height: 14)
                    }
                }
                regionButton("right_ear", label: "R Ear", width: 20, height: 30)
            }

            // Neck
            regionButton("neck", label: "Neck", width: 40, height: 20)

            // Torso + Arms
            HStack(alignment: .top, spacing: 2) {
                VStack(spacing: 2) {
                    regionButton("left_shoulder", label: "L Shldr", width: 36, height: 24)
                    regionButton("left_upper_extremity", label: "L Arm", width: 30, height: 70)
                    regionButton("left_hand", label: "L Hand", width: 26, height: 28)
                }
                VStack(spacing: 2) {
                    regionButton("torso", label: "Chest", width: 80, height: 50)
                    regionButton("upper_abdomen", label: "Abdomen", width: 80, height: 40)
                    regionButton("lower_back", label: "Lower Back", width: 80, height: 30)
                }
                VStack(spacing: 2) {
                    regionButton("right_shoulder", label: "R Shldr", width: 36, height: 24)
                    regionButton("right_upper_extremity", label: "R Arm", width: 30, height: 70)
                    regionButton("right_hand", label: "R Hand", width: 26, height: 28)
                }
            }

            // Legs
            HStack(spacing: 8) {
                VStack(spacing: 2) {
                    regionButton("left_lower_extremity", label: "L Leg", width: 36, height: 80)
                    regionButton("left_foot", label: "L Foot", width: 32, height: 20)
                }
                VStack(spacing: 2) {
                    regionButton("right_lower_extremity", label: "R Leg", width: 36, height: 80)
                    regionButton("right_foot", label: "R Foot", width: 32, height: 20)
                }
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func regionButton(_ region: String, label: String, width: CGFloat, height: CGFloat) -> some View {
        let isActive = activeRegions.contains(region)
        let rCount = recordCount(for: region)
        let pCount = photoCount(for: region)

        return Button {
            selectedRegion = region
            if isActive { showRegionDetail = true }
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 4)
                    .fill(isActive ? Color.red.opacity(0.3) : Color(.systemGray5))
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .strokeBorder(isActive ? Color.red : Color.clear, lineWidth: 1.5)
                    )
                VStack(spacing: 0) {
                    Text(label)
                        .font(.system(size: 7, weight: isActive ? .bold : .regular))
                        .clinicalMicroLabel(weight: isActive ? .bold : .regular)
                        .foregroundColor(isActive ? .red : .secondary)
                    if isActive {
                        Text("\(rCount)R \(pCount)P")
                            .font(.system(size: 6, weight: .medium).monospacedDigit())
                            .clinicalMicroMonospaced()
                            .foregroundColor(.red.opacity(0.8))
                    }
                }
            }
            .frame(width: width, height: height)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Region Detail

    private func regionDetailView(_ region: String) -> some View {
        let regionRecords = records.filter { ($0.affectedAnatomicalZones ?? []).contains(region) }
            .sorted { $0.dateRecorded > $1.dateRecorded }
        let regionPhotos = photos.filter { $0.anatomicalRegion == region }
            .sorted { $0.captureDate > $1.captureDate }

        return List {
            Section(header: Text("Records (\(regionRecords.count))")) {
                ForEach(regionRecords) { record in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(record.conditionName).font(.subheadline.bold())
                        Text(record.dateRecorded, format: .dateTime.month().day().year())
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .clinicalFinePrint()
                        if let icd10 = record.icd10Code {
                            Text(icd10)
                                .font(.caption2.monospaced())
                                .foregroundColor(.blue)
                                .clinicalFinePrintMonospaced()
                        }
                    }
                }
            }
            Section(header: Text("Photos (\(regionPhotos.count))")) {
                if regionPhotos.isEmpty {
                    Text("No photos for this region")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(regionPhotos) { photo in
                        HStack {
                            if let img = UIImage(contentsOfFile: photo.filePath) {
                                Image(uiImage: img)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 50, height: 50)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                            }
                            VStack(alignment: .leading) {
                                Text(photo.captureDate, format: .dateTime.month().day().year())
                                    .font(.caption)
                                    .clinicalFinePrint()
                                if let notes = photo.notes {
                                    Text(notes)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                        .clinicalFinePrint()
                                        .clinicalRowSummaryText(lines: 2)
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(AnatomicalRegion.displayName(for: region))
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") { showRegionDetail = false }
            }
        }
    }

    // MARK: - Helpers

    private func summaryCard(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
            Text(value)
                .font(.title2.bold().monospacedDigit())
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
                .clinicalMicroLabel()
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
    }

    private func regionRow(_ region: String) -> some View {
        Button {
            selectedRegion = region
            showRegionDetail = true
        } label: {
            HStack(spacing: 12) {
                Circle()
                    .fill(Color.red.opacity(0.3))
                    .frame(width: 32, height: 32)
                    .overlay(Image(systemName: "mappin").font(.caption).foregroundColor(.red))
                VStack(alignment: .leading, spacing: 2) {
                    Text(AnatomicalRegion.displayName(for: region))
                        .font(.subheadline.bold())
                        .foregroundColor(.primary)
                    Text("\(recordCount(for: region)) records · \(photoCount(for: region)) photos")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .clinicalFinePrint()
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }
}
