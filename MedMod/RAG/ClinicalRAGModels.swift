//
//  ClinicalRAGModels.swift
//  MedMod
//
//  Core data models for the Clinical RAG pipeline.
//  All types are Sendable + Codable for thread safety and persistence.
//

import Foundation

// MARK: - Source Type

/// Identifies the origin of a clinical chunk.
enum ClinicalSourceType: String, Codable, Sendable {
    case patientProfile
    case clinicalRecord
    case medication
    case appointment
}

// MARK: - Clinical Category

/// Broad clinical category for filtering and boost scoring.
enum ClinicalCategory: String, Codable, Sendable {
    case demographics
    case allergiesAndRisks
    case carePlan
    case chiefComplaint
    case reviewOfSystems
    case examFindings
    case assessmentAndPlan
    case patientInstructions
    case followUp
    case orders
    case medication
    case appointment
    case fullRecord
}

// MARK: - Chunk Metadata

/// Rich metadata attached to every indexed chunk.
struct ChunkMetadata: Codable, Sendable {
    let chunkIndex: Int
    let sourceType: ClinicalSourceType
    let sectionTitle: String
    let dateRecorded: Date?
    let clinicalCategory: ClinicalCategory
    let patientName: String
    let wordCount: Int
}

// MARK: - Clinical Chunk

/// A segment of clinical text ready for embedding and indexing.
struct ClinicalChunk: Identifiable, Codable, Sendable {
    let id: UUID
    let patientId: UUID
    let content: String
    let contextualPrefix: String
    let metadata: ChunkMetadata

    init(
        id: UUID = UUID(),
        patientId: UUID,
        content: String,
        contextualPrefix: String,
        metadata: ChunkMetadata
    ) {
        self.id = id
        self.patientId = patientId
        self.content = content
        self.contextualPrefix = contextualPrefix
        self.metadata = metadata
    }

    /// Full text used for embedding: prefix + content.
    var embeddableText: String {
        contextualPrefix.isEmpty ? content : "\(contextualPrefix) \(content)"
    }
}

// MARK: - RAG Query

/// Encapsulates a RAG search request.
struct RAGQuery: Sendable {
    let text: String
    let patientScope: UUID?
    let topK: Int
    let includeVerification: Bool
    let deepThinkPasses: Int

    init(
        text: String,
        patientScope: UUID? = nil,
        topK: Int = 10,
        includeVerification: Bool = false,
        deepThinkPasses: Int = 1
    ) {
        self.text = text
        self.patientScope = patientScope
        self.topK = topK
        self.includeVerification = includeVerification
        self.deepThinkPasses = deepThinkPasses
    }
}

// MARK: - Retrieved Chunk

/// A chunk returned by hybrid search with its fusion score.
struct RetrievedChunk: Sendable {
    let chunk: ClinicalChunk
    var score: Double
    let vectorRank: Int?
    let keywordRank: Int?
}

// MARK: - Confidence Tier

enum ConfidenceTier: String, Codable, Sendable {
    case high
    case medium
    case low
}

// MARK: - Verification Result

/// Output from the verification gates.
struct VerificationResult: Sendable {
    let confidence: ConfidenceTier
    let overallScore: Double
    let gateResults: [String: Bool]
    let warnings: [String]
}

// MARK: - Thinking Phase

/// Phases of the RAG pipeline for thinking visualization.
enum ThinkingPhase: String, Sendable {
    case queryAnalysis
    case embedding
    case vectorSearch
    case keywordSearch
    case rrfFusion
    case reranking
    case mmrDiversity
    case tokenBudget
    case lostInMiddle
    case contextAssembly
    case verification
    case deepThinkPass
    case followUpExtraction
    case generation
    case complete
}

// MARK: - Thinking Step

/// A single step in the RAG pipeline's thinking process.
struct ThinkingStep: Identifiable, Sendable {
    let id: UUID
    let phase: ThinkingPhase
    let title: String
    let detail: String
    let timestamp: Date
    let icon: String
    let metrics: [String: String]

    init(phase: ThinkingPhase, title: String, detail: String = "", icon: String = "circle.fill", metrics: [String: String] = [:]) {
        self.id = UUID()
        self.phase = phase
        self.title = title
        self.detail = detail
        self.timestamp = Date()
        self.icon = icon
        self.metrics = metrics
    }
}

// MARK: - Chunk Summary

/// Lightweight UI-friendly summary of a retrieved chunk.
struct ChunkSummary: Identifiable, Sendable {
    let id: UUID
    let patientName: String
    let sectionTitle: String
    let category: ClinicalCategory
    let score: Double
    let vectorRank: Int?
    let keywordRank: Int?
    let preview: String
    let dateRecorded: Date?

    init(from retrieved: RetrievedChunk) {
        self.id = retrieved.chunk.id
        self.patientName = retrieved.chunk.metadata.patientName
        self.sectionTitle = retrieved.chunk.metadata.sectionTitle
        self.category = retrieved.chunk.metadata.clinicalCategory
        self.score = retrieved.score
        self.vectorRank = retrieved.vectorRank
        self.keywordRank = retrieved.keywordRank
        self.preview = String(retrieved.chunk.content.prefix(150))
        self.dateRecorded = retrieved.chunk.metadata.dateRecorded
    }
}

// MARK: - Response Metadata

/// Metadata about the RAG response generation.
struct ResponseMetadata: Sendable {
    let retrievedChunkCount: Int
    let usedChunkCount: Int
    let embeddingTimeMs: Double
    let searchTimeMs: Double
    let totalTimeMs: Double
    let verification: VerificationResult?
    let deepThinkPassesUsed: Int
    let thinkingSteps: [ThinkingStep]
    let sourceChunks: [ChunkSummary]

    init(
        retrievedChunkCount: Int,
        usedChunkCount: Int,
        embeddingTimeMs: Double,
        searchTimeMs: Double,
        totalTimeMs: Double,
        verification: VerificationResult?,
        deepThinkPassesUsed: Int,
        thinkingSteps: [ThinkingStep] = [],
        sourceChunks: [ChunkSummary] = []
    ) {
        self.retrievedChunkCount = retrievedChunkCount
        self.usedChunkCount = usedChunkCount
        self.embeddingTimeMs = embeddingTimeMs
        self.searchTimeMs = searchTimeMs
        self.totalTimeMs = totalTimeMs
        self.verification = verification
        self.deepThinkPassesUsed = deepThinkPassesUsed
        self.thinkingSteps = thinkingSteps
        self.sourceChunks = sourceChunks
    }
}

// MARK: - RAG Response

/// Complete response from the RAG pipeline.
struct RAGResponse: Sendable {
    let context: String
    let retrievedChunks: [RetrievedChunk]
    let metadata: ResponseMetadata
}
