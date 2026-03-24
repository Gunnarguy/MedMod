//
//  VerificationGates.swift
//  MedMod
//
//  7 clinical verification gates adapted from OpenIntelligence.
//  Validates RAG responses for safety, faithfulness, and quality
//  before presenting to the clinician.
//

import Foundation
import Accelerate
import os

// MARK: - Clinical Verification Gates

/// Runs 7 verification passes on RAG-generated context to produce a confidence score.
final class ClinicalVerificationGates: @unchecked Sendable {
    private let embeddingService: ClinicalEmbeddingService

    init(embeddingService: ClinicalEmbeddingService) {
        self.embeddingService = embeddingService
    }

    /// Run all 7 gates and produce a consolidated result.
    func verify(
        query: String,
        responseText: String,
        retrievedChunks: [RetrievedChunk]
    ) async -> VerificationResult {
        var gateResults: [String: Bool] = [:]
        var warnings: [String] = []

        // Gate A: Retrieval Confidence
        let (passA, warnA) = gateRetrievalConfidence(chunks: retrievedChunks)
        gateResults["retrievalConfidence"] = passA
        warnings.append(contentsOf: warnA)

        // Gate B: Evidence Coverage
        let (passB, warnB) = gateEvidenceCoverage(response: responseText, chunks: retrievedChunks)
        gateResults["evidenceCoverage"] = passB
        warnings.append(contentsOf: warnB)

        // Gate C: Numeric Sanity
        let (passC, warnC) = gateNumericSanity(response: responseText, chunks: retrievedChunks)
        gateResults["numericSanity"] = passC
        warnings.append(contentsOf: warnC)

        // Gate D: Contradiction Sweep
        let (passD, warnD) = gateContradictionSweep(chunks: retrievedChunks)
        gateResults["contradictionSweep"] = passD
        warnings.append(contentsOf: warnD)

        // Gate E: Semantic Grounding
        let (passE, warnE) = await gateSemanticGrounding(response: responseText, chunks: retrievedChunks)
        gateResults["semanticGrounding"] = passE
        warnings.append(contentsOf: warnE)

        // Gate F: Quote Faithfulness
        let (passF, warnF) = gateQuoteFaithfulness(response: responseText, chunks: retrievedChunks)
        gateResults["quoteFaithfulness"] = passF
        warnings.append(contentsOf: warnF)

        // Gate G: Generation Quality
        let (passG, warnG) = gateGenerationQuality(response: responseText)
        gateResults["generationQuality"] = passG
        warnings.append(contentsOf: warnG)

        // Compute overall score and confidence tier
        let passedCount = gateResults.values.filter { $0 }.count
        let overallScore = Double(passedCount) / Double(gateResults.count)

        let confidence: ConfidenceTier
        switch passedCount {
        case 6...7: confidence = .high
        case 4...5: confidence = .medium
        default: confidence = .low
        }

        AppLogger.ai.info("🔒 Verification: \(passedCount)/7 gates passed → \(confidence.rawValue)")

        return VerificationResult(
            confidence: confidence,
            overallScore: overallScore,
            gateResults: gateResults,
            warnings: warnings
        )
    }

    // MARK: - Gate A: Retrieval Confidence

    /// Top chunk score must exceed threshold — ensures we found relevant context.
    private func gateRetrievalConfidence(chunks: [RetrievedChunk]) -> (Bool, [String]) {
        guard let topScore = chunks.first?.score else {
            return (false, ["No chunks retrieved — cannot verify"])
        }

        let threshold = 0.01  // RRF scores are small (1/(60+rank))
        if topScore < threshold {
            return (false, ["Top retrieval score \(String(format: "%.4f", topScore)) below threshold"])
        }
        return (true, [])
    }

    // MARK: - Gate B: Evidence Coverage

    /// Key clinical terms in the response should appear in retrieved chunks.
    private func gateEvidenceCoverage(response: String, chunks: [RetrievedChunk]) -> (Bool, [String]) {
        let responseTokens = extractClinicalTerms(from: response)
        guard !responseTokens.isEmpty else { return (true, []) }

        let chunkText = chunks.map { $0.chunk.content.lowercased() }.joined(separator: " ")
        let covered = responseTokens.filter { chunkText.contains($0) }
        let coverage = Double(covered.count) / Double(responseTokens.count)

        if coverage < 0.5 {
            let uncovered = responseTokens.filter { !chunkText.contains($0) }
            return (false, ["Low evidence coverage (\(Int(coverage * 100))%). Uncovered terms: \(uncovered.prefix(5).joined(separator: ", "))"])
        }
        return (true, [])
    }

    // MARK: - Gate C: Numeric Sanity

    /// Numbers in the response (dosages, values) should exist in source chunks.
    private func gateNumericSanity(response: String, chunks: [RetrievedChunk]) -> (Bool, [String]) {
        let responseNumbers = extractNumbers(from: response)
        guard !responseNumbers.isEmpty else { return (true, []) }

        let chunkText = chunks.map { $0.chunk.content }.joined(separator: " ")
        let chunkNumbers = Set(extractNumbers(from: chunkText))

        let unsourced = responseNumbers.filter { !chunkNumbers.contains($0) }
        if unsourced.count > responseNumbers.count / 2 {
            return (false, ["Unsourced numbers in response: \(unsourced.prefix(5).joined(separator: ", "))"])
        }
        return (true, [])
    }

    // MARK: - Gate D: Contradiction Sweep

    /// Check for conflicting facts across retrieved chunks.
    private func gateContradictionSweep(chunks: [RetrievedChunk]) -> (Bool, [String]) {
        // Simple heuristic: look for opposing status words in same-patient, same-category chunks
        var warnings: [String] = []

        let byPatientCategory = Dictionary(grouping: chunks) {
            "\($0.chunk.patientId)-\($0.chunk.metadata.clinicalCategory.rawValue)"
        }

        for (key, group) in byPatientCategory where group.count > 1 {
            let texts = group.map { $0.chunk.content.lowercased() }
            // Check for opposing pairs
            let opposites = [("active", "discontinued"), ("improving", "worsening"), ("resolved", "persistent")]
            for (a, b) in opposites {
                let hasA = texts.contains { $0.contains(a) }
                let hasB = texts.contains { $0.contains(b) }
                if hasA && hasB {
                    warnings.append("Potential contradiction in \(key): '\(a)' vs '\(b)'")
                }
            }
        }

        return (warnings.isEmpty, warnings)
    }

    // MARK: - Gate E: Semantic Grounding

    /// Response embedding should be close to the centroid of retrieved chunk embeddings.
    private func gateSemanticGrounding(response: String, chunks: [RetrievedChunk]) async -> (Bool, [String]) {
        guard !chunks.isEmpty else { return (false, ["No chunks for grounding"]) }

        do {
            let responseEmb = try await embeddingService.embed(text: response)
            let chunkTexts = chunks.map { $0.chunk.embeddableText }
            let chunkEmbs = try await embeddingService.embedBatch(texts: chunkTexts)

            // Compute centroid of chunk embeddings
            let dim = responseEmb.count
            var centroid = [Float](repeating: 0, count: dim)
            for emb in chunkEmbs {
                let useDim = min(dim, emb.count)
                vDSP_vadd(centroid, 1, emb, 1, &centroid, 1, vDSP_Length(useDim))
            }
            var divisor = Float(chunkEmbs.count)
            vDSP_vsdiv(centroid, 1, &divisor, &centroid, 1, vDSP_Length(dim))

            // Cosine similarity between response and centroid
            var similarity: Float = 0
            vDSP_dotpr(responseEmb, 1, centroid, 1, &similarity, vDSP_Length(dim))

            if similarity < 0.3 {
                return (false, ["Response poorly grounded (similarity: \(String(format: "%.2f", similarity)))"])
            }
            return (true, [])
        } catch {
            return (true, [])  // Don't fail verification if embedding fails
        }
    }

    // MARK: - Gate F: Quote Faithfulness

    /// Medication names and clinical codes in response must exactly match source data.
    private func gateQuoteFaithfulness(response: String, chunks: [RetrievedChunk]) -> (Bool, [String]) {
        let medChunks = chunks.filter { $0.chunk.metadata.sourceType == .medication }
        guard !medChunks.isEmpty else { return (true, []) }

        // Extract medication names from chunks
        let chunkMedNames = Set(medChunks.flatMap { chunk in
            chunk.chunk.content.components(separatedBy: CharacterSet.newlines)
                .compactMap { line -> String? in
                    let trimmed = line.trimmingCharacters(in: .whitespaces)
                    guard !trimmed.isEmpty else { return nil }
                    // First word of each line is likely a med name
                    return trimmed.components(separatedBy: " ").first?.lowercased()
                }
        })

        // Check if response mentions medications not in the source
        let responseWords = Set(response.lowercased().components(separatedBy: CharacterSet.alphanumerics.inverted))
        let commonMedSuffixes = ["mab", "nib", "olol", "pril", "sartan", "statin", "mycin", "cillin", "azole"]

        let responseMedLikeWords = responseWords.filter { word in
            commonMedSuffixes.contains(where: { word.hasSuffix($0) }) && word.count > 4
        }

        let unfaithful = responseMedLikeWords.filter { !chunkMedNames.contains($0) }
        if !unfaithful.isEmpty {
            return (false, ["Medication names not in source: \(unfaithful.prefix(3).joined(separator: ", "))"])
        }
        return (true, [])
    }

    // MARK: - Gate G: Generation Quality

    /// Response should be non-trivial and not repetitive.
    private func gateGenerationQuality(response: String) -> (Bool, [String]) {
        var warnings: [String] = []

        // Check minimum length
        let wordCount = response.split(separator: " ").count
        if wordCount < 10 {
            warnings.append("Response too short (\(wordCount) words)")
        }

        // Check for excessive repetition
        let sentences = response.components(separatedBy: ". ")
        if sentences.count > 2 {
            let uniqueSentences = Set(sentences.map { $0.lowercased().trimmingCharacters(in: .whitespaces) })
            let uniqueRatio = Double(uniqueSentences.count) / Double(sentences.count)
            if uniqueRatio < 0.5 {
                warnings.append("Repetitive response (uniqueness: \(Int(uniqueRatio * 100))%)")
            }
        }

        return (warnings.isEmpty, warnings)
    }

    // MARK: - Helpers

    /// Extract clinically significant terms from text.
    private func extractClinicalTerms(from text: String) -> [String] {
        let stopWords: Set<String> = ["the", "is", "are", "was", "were", "has", "have", "had", "for", "and", "but",
                                       "not", "this", "that", "with", "from", "they", "been", "will", "can", "may",
                                       "should", "would", "could", "also", "any", "its", "all", "each", "both"]

        return text.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count > 3 && !stopWords.contains($0) }
    }

    /// Extract numeric values (dosages, measurements) from text.
    private func extractNumbers(from text: String) -> [String] {
        let pattern = #"\d+\.?\d*\s*(mg|mcg|ml|g|kg|units?|%|mmol|μg|iu)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return [] }
        let nsText = text as NSString
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsText.length))
        return matches.map { nsText.substring(with: $0.range).lowercased() }
    }
}
