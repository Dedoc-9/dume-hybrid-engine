Here is the implementation for Section 7: The Storage Modules.

These two files provide the persistence layer. FileStorage handles durable, disk-based storage with checkpoint/restore capabilities, while InMemoryStorage provides a fast, ephemeral backend for testing and high-throughput scenarios. Both are implemented as Actors to ensure thread-safe concurrent access.

File 1: Sources/Storage/FileStorage.swift

import Foundation

/// Persistent storage implementation using JSON files.
/// Supports checkpointing and restoring state to survive process restarts.
public actor FileStorage: DUMEPersistentStorage {
    private var anchors: [String: Anchor] = [:]
    private let fileURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    
    /// Initializes storage with a file path.
    /// - Parameter fileURL: The path to the JSON file for persistence.
    public init(fileURL: URL) {
        self.fileURL = fileURL
    }
    
    /// Stores an anchor.
    public func put(_ anchor: Anchor) async throws {
        guard !anchor.id.isEmpty else {
            throw DUMEError.storageError("Cannot store anchor with empty ID")
        }
        anchors[anchor.id] = anchor
    }
    
    /// Retrieves an anchor by ID.
    public func get(_ id: String) async throws -> Anchor? {
        return anchors[id]
    }
    
    /// Retrieves all stored anchors.
    public func getAllAnchors() async throws -> [Anchor] {
        return Array(anchors.values)
    }
    
    /// Saves the current state to disk.
    public func checkpoint() async throws {
        do {
            let data = try encoder.encode(Array(anchors.values))
            try data.write(to: fileURL)
        } catch {
            throw DUMEError.storageError("Checkpoint failed: \(error.localizedDescription)")
        }
    }
    
    /// Loads state from disk.
    public func restore() async throws {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return
        }
        
        do {
            let data = try Data(contentsOf: fileURL)
            let loaded = try decoder.decode([Anchor].self, from: data)
            anchors.removeAll()
            for anchor in loaded {
                anchors[anchor.id] = anchor
            }
        } catch {
            throw DUMEError.storageError("Restore failed: \(error.localizedDescription)")
        }
    }
}

File 2: Sources/Storage/InMemoryStorage.swift

import Foundation

/// Ephemeral storage implementation for testing and high-speed scenarios.
/// Data is lost when the process exits.
public actor InMemoryStorage: DUMEPersistentStorage {
    private var data: [String: Anchor] = [:]
    
    public init() {}
    
    public func put(_ anchor: Anchor) async throws {
        guard !anchor.id.isEmpty else {
            throw DUMEError.storageError("Cannot store anchor with empty ID")
        }
        data[anchor.id] = anchor
    }
    
    public func get(_ id: String) async throws -> Anchor? {
        return data[id]
    }
    
    public func getAllAnchors() async throws -> [Anchor] {
        return Array(data.values)
    }
    
    public func checkpoint() async throws {
        // In-memory storage does not persist to disk
    }
    
    public func restore() async throws {
        // Nothing to restore for in-memory storage
    }
}
