import Foundation

struct ClinicalProblemSummary: Identifiable {
    let id: String
    let title: String
    let latestRecord: LocalClinicalRecord
    let occurrenceCount: Int
    let latestDate: Date
}

extension Sequence where Element == LocalClinicalRecord {
    func groupedProblemSummaries() -> [ClinicalProblemSummary] {
        let grouped = Dictionary(grouping: self) { record in
            record.problemGroupingKey
        }

        return grouped.values
            .compactMap { records in
                guard let latestRecord = records.max(by: { $0.dateRecorded < $1.dateRecorded }) else {
                    return nil
                }

                let title = latestRecord.conditionName.trimmingCharacters(in: .whitespacesAndNewlines)
                let resolvedTitle = title.isEmpty ? "Condition" : title

                return ClinicalProblemSummary(
                    id: latestRecord.problemGroupingKey,
                    title: resolvedTitle,
                    latestRecord: latestRecord,
                    occurrenceCount: records.count,
                    latestDate: latestRecord.dateRecorded
                )
            }
            .sorted { $0.latestDate > $1.latestDate }
    }
}

private extension LocalClinicalRecord {
    var problemGroupingKey: String {
        if let icd10Code {
            let cleanedICD = icd10Code
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()

            if !cleanedICD.isEmpty {
                return "icd:\(cleanedICD)"
            }
        }

        let cleanedName = conditionName
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .lowercased()

        return "name:\(cleanedName)"
    }
}
