Section 11: Sources/Engine/DUMEHybridFactory.swift

Below is a concrete Swift implementation for a factory that constructs the DUME engine with a variety of configuration flags. The goal is to provide a single entry point that can be configured for encryption, graph settings, persistence options, and performance modes.
11.1 Overview and design:
  The factory is implemented as a Swift enum with static methods, offering a single entry point to create a fully initialized engine instance.
    It supports multiple configuration flags such as:
        Encryption strategy (AES-GCM, No-Op)
        Graph evolution parameters (k, similarity metric)
        Checkpointing and storage options
        Safety/policy toggles (burst detection, entropy tracking)
    The resulting Engine type (pseudo-code below) represents the core orchestration that ingests data, compresses, encrypts, stores, and retrieves.
    The factory is designed to be easily extended with new configurations as the project evolves.

    Note: The exact types for Engine, CheckpointStore, and StorageBackends are placeholders here. Replace with your actual types from your codebase or adjust as needed.

11.2 File: Sources/Engine/DUMEHybridFactory.swift
//
//  Sources/Engine/DUMEHybridFactory.swift
//
import Foundation

// MARK: - Placeholder types (replace with your actual project types)
// These are here to illustrate the factory wiring. In your repo, substitute with real types.
public protocol EngineProtocol {
    func ingest(_ vector: [Double], metadata: [String: Any]?)
    func retrieve(_ id: UUID) -> [Double]?
    func shutdown()
}

public protocol CheckpointStore {
    func save(_ state: Data) throws
    func load() throws -> Data
}

public enum StorageBackend {
    case inMemory
    case disk(url: URL)
}

// MARK: - Factory configuration structs

public struct DUMEEncryptionConfig {
    public let useEncryption: Bool
    public let encryption: DUMEEncryption

    public init(useEncryption: Bool, encryption: DUMEEncryption) {
        self.useEncryption = useEncryption
        self.encryption = encryption
    }
}

public struct GraphConfig {
    public let k: Int
    public let similarity: GraphSimilarity

    public init(k: Int, similarity: GraphSimilarity) {
        self.k = max(1, k)
        self.similarity = similarity
    }
}

public struct SafetyConfig {
    public let burstThreshold: Double
    public let entropyWindow: Int

    public init(burstThreshold: Double, entropyWindow: Int) {
        self.burstThreshold = burstThreshold
        self.entropyWindow = max(1, entropyWindow)
    }
}

// MARK: - DUMEHybridFactory

public enum DUMEHybridFactory {
    /// Build a default engine with sensible defaults
    public static func makeDefaultEngine(
        encryptionConfig: DUMEEncryptionConfig? = nil,
        graphConfig: GraphConfig? = nil,
        storage: StorageBackend = .inMemory,
        checkpointStore: CheckpointStore? = nil,
        safetyConfig: SafetyConfig? = nil
    ) -> EngineProtocol {
        // Encryption
        let encryption: DUMEEncryption
        let encryptionEnabled: Bool
        if let encCfg = encryptionConfig {
            encryptionEnabled = encCfg.useEncryption
            encryption = encCfg.encryption
        } else {
            // Default: No encryption
            encryptionEnabled = false
            encryption = NoOpEncryption()
        }

        // Graph
        let graphK = graphConfig?.k ?? 6
        let similarity = graphConfig?.similarity ?? CosineSimilarity()
        let graph = GraphEvolution(k: graphK, similarity: similarity)

        // Storage backend
        let storageBackend: StorageBackend = storage
        let store: CheckpointStore? = checkpointStore

        // Safety
        let safety = safetyConfig ?? SafetyConfig(burstThreshold: 0.8, entropyWindow: 10)

        // Build the engine with the assembled components
        let engine = EngineImpl(
            encryption: encryptionEnabled ? encryption : NoOpEncryption(),
            graph: graph,
            storage: storageBackend,
            checkpointStore: store,
            safety: safety
        )
        return engine
    }

    /// Build a customized engine with explicit components
    public static func makeEngine(
        encryption: DUMEEncryption?,
        graph: GraphEvolution,
        storage: StorageBackend,
        checkpointStore: CheckpointStore?,
        safety: SafetyConfig
    ) -> EngineProtocol {
        let enc = encryption ?? NoOpEncryption()
        return EngineImpl(
            encryption: enc,
            graph: graph,
            storage: storage,
            checkpointStore: checkpointStore,
            safety: safety
        )
    }
}

// MARK: - Minimal Engine Implementation (Placeholder)

// You should replace this with your real Engine class/struct.
// This is a minimal scaffold to illustrate wiring between components.

private final class EngineImpl: EngineProtocol {
    private let encryption: DUMEEncryption
    private let graph: GraphEvolution
    private let storage: StorageBackend
    private let checkpointStore: CheckpointStore?
    private let safety: SafetyConfig

    init(
        encryption: DUMEEncryption,
        graph: GraphEvolution,
        storage: StorageBackend,
        checkpointStore: CheckpointStore?,
        safety: SafetyConfig
    ) {
        self.encryption = encryption
        self.graph = graph
        self.storage = storage
        self.checkpointStore = checkpointStore
        self.safety = safety
    }

    // Ingest: placeholder implementation
    func ingest(_ vector: [Double], metadata: [String: Any]? = nil) {
        // 1) compress latent vector (not shown)
        // 2) optionally encrypt
        // 3) store
        // 4) update graph
        // This is a placeholder to show wiring
    }

    func retrieve(_ id: UUID) -> [Double]? {
        // Placeholder
        return nil
    }

    func shutdown() {
        // Clean up resources if needed
    }
}
11.3 How to integrate with your project:
    Replace placeholder EngineProtocol and EngineImpl with your actual engine type and initialization logic.
    If your engine has a dedicated builder or configuration object, adapt the factory to produce that type instead of a generic EngineProtocol.
    Ensure the encryption instance is thread-safe and that the key material is protected in memory.
    If you support hot-swapping configuration flags at runtime, consider exposing a variant of the factory that returns a builder object rather than a fully initialized engine.

11.4 Example usage:
// Example: build a default engine with AES-GCM encryption and cosine similarity
let keyData = Data((0..<32).map { _ in UInt8.random(in: 0...255) })
let aesKey = SymmetricKey(data: keyData)
let aesEncryption = AESGCMEncryption(key: aesKey)

let defaultEngine = DUMEHybridFactory.makeDefaultEngine(
    encryptionConfig: DUMEEncryptionConfig(useEncryption: true, encryption: aesEncryption),
    graphConfig: GraphConfig(k: 8, similarity: CosineSimilarity()),
    storage: .disk(url: URL(fileURLWithPath: "/tmp/dume")),
    checkpointStore: nil,
    safetyConfig: SafetyConfig(burstThreshold: 0.75, entropyWindow: 20)
)

// Use the engine via EngineProtocol
defaultEngine.ingest([0.1, 0.2, 0.3], metadata: ["source": "demo"])

11.5 Tests you might add (high level):
    Verify that a default engine can be constructed with and without encryption.
    Validate that graph links are created during node insertion.
    Ensure that checkpointStore integration is wired correctly and can save/load state.
    Test that the engine can ingest and retrieve data through the configured storage backend.
