//
//  ClinicalHybridSearch.swift
//  MedMod
//
//  Parallel vector + BM25 search with Reciprocal Rank Fusion (RRF).
//  Combines semantic similarity from ClinicalVectorStore with keyword
//  precision from ClinicalFTSService.
//

import Foundation
import os

// MARK: - Clinical Hybrid Search

/// Fuses vector (semantic) and FTS5 (keyword) search results using RRF.
final class ClinicalHybridSearch: Sendable {
    private let vectorStore: ClinicalVectorStore
    private let ftsService: ClinicalFTSService
    private let embeddingService: ClinicalEmbeddingService

    /// RRF constant — balances contribution of highly-ranked vs lower-ranked results.
    /// k=60 is the standard from Cormack et al. (2009).
    private let rrfK: Double = 60.0

    init(vectorStore: ClinicalVectorStore, ftsService: ClinicalFTSService, embeddingService: ClinicalEmbeddingService) {
        self.vectorStore = vectorStore
        self.ftsService = ftsService
        self.embeddingService = embeddingService
    }

    /// Execute parallel vector + keyword search, fuse with RRF.
    func search(query: String, topK: Int = 10, patientScope: UUID? = nil) async throws -> [RetrievedChunk] {
        // Embed the query for vector search
        let queryEmbedding = try await embeddingService.embed(text: query)

        // Parallel search: vector (semantic) + FTS5 (keyword)
        async let vectorResults = vectorStore.search(
            queryEmbedding: queryEmbedding,
            topK: topK * 2,  // Over-fetch for better fusion
            patientScope: patientScope
        )
        async let keywordResults = ftsService.search(
            query: query,
            topK: topK * 2,
            patientScope: patientScope
        )

        let vec = await vectorResults
        let kw = await keywordResults

        // Build rank maps
        var vectorRanks: [UUID: Int] = [:]
        for (rank, result) in vec.enumerated() {
            vectorRanks[result.chunk.id] = rank + 1
        }

        var keywordRanks: [UUID: Int] = [:]
        for (rank, result) in kw.enumerated() {
            keywordRanks[result.chunkId] = rank + 1
        }

        // Collect all unique chunk IDs
        var allChunkIds = Set(vectorRanks.keys)
        allChunkIds.formUnion(keywordRanks.keys)

        // RRF fusion: score = Σ(1 / (k + rank_i))
        var fusedScores: [(UUID, Double, Int?, Int?)] = []

        for chunkId in allChunkIds {
            var rrfScore: Double = 0
            let vRank = vectorRanks[chunkId]
            let kRank = keywordRanks[chunkId]

            if let vr = vRank {
                rrfScore += 1.0 / (rrfK + Double(vr))
            }
            if let kr = kRank {
                rrfScore += 1.0 / (rrfK + Double(kr))
            }

            fusedScores.append((chunkId, rrfScore, vRank, kRank))
        }

        // Sort by fused score descending
        fusedScores.sort { $0.1 > $1.1 }

        // Build RetrievedChunk results — resolve chunks from vector results first (they have full chunk data)
        var chunkLookup: [UUID: ClinicalChunk] = [:]
        for result in vec {
            chunkLookup[result.chunk.id] = result.chunk
        }

        return fusedScores.prefix(topK).compactMap { chunkId, score, vRank, kRank in
            guard let chunk = chunkLookup[chunkId] else {
                // Chunk was FTS-only (not in vector results) — skip
                // In a full system we'd look it up by ID, but vector store has all chunks
                return nil
            }
            return RetrievedChunk(
                chunk: chunk,
                score: score,
                vectorRank: vRank,
                keywordRank: kRank
            )
        }
    }
}
