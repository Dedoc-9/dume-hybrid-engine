Here is the implementation for Section 7: The Storage Modules.

These two files provide the persistence layer. FileStorage handles durable, disk-based storage with checkpoint/restore capabilities, while InMemoryStorage provides a fast, ephemeral backend for testing and high-throughput scenarios. Both are implemented as Actors to ensure thread-safe concurrent access.

File 1: Sources/Storage/FileStorage.swift

import Foundation

/// Persistent storage implementation using JSON files.
/// Stores encrypted serialized envelopes as opaque Data.
/// Supports checkpointing and restoring state to survive process restarts.
public actor FileStorage: DUMEPersistentStorage {
    
    // MARK: - Internal Storage (opaque encrypted payloads)
    
    private var storage: [String: Data] = [:]
    
    private let fileURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    
    // MARK: - Init
    
    public init(fileURL: URL) {
        self.fileURL = fileURL
    }
    
    // MARK: - Write
    
    /// Stores encrypted serialized data under an ID.
    public func putData(id: String, data: Data) async throws {
        guard !id.isEmpty else {
            throw DUMEError.storageError("Cannot store data with empty ID")
        }
        storage[id] = data
    }
    
    // MARK: - Read
    
    /// Retrieves encrypted serialized data.
    public func getData(_ id: String) async throws -> Data? {
        return storage[id]
    }
    
    /// Retrieves all stored raw payloads.
    public func getAllData() async throws -> [Data] {
        return Array(storage.values)
    }
    
    // MARK: - Checkpointing
    
    /// Saves full encrypted storage map to disk.
    public func checkpoint() async throws {
        do {
            let data = try encoder.encode(storage)
            try data.write(to: fileURL)
        } catch {
            throw DUMEError.storageError("Checkpoint failed: \(error.localizedDescription)")
        }
    }
    
    /// Restores encrypted storage map from disk.
    public func restore() async throws {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return
        }
        
        do {
            let data = try Data(contentsOf: fileURL)
            let loaded = try decoder.decode([String: Data].self, from: data)
            storage = loaded
        } catch {
            throw DUMEError.storageError("Restore failed: \(error.localizedDescription)")
        }
    }
}
File 2: Sources/Storage/InMemoryStorage.swift

import Foundation

/// Ephemeral storage implementation for testing and high-throughput scenarios.
/// Stores encrypted serialized envelopes as opaque Data in memory.
/// Data is lost when the process exits.
public actor InMemoryStorage: DUMEPersistentStorage {
    
    // MARK: - Internal Storage
    
    private var storage: [String: Data] = [:]
    
    public init() {}
    
    // MARK: - Write
    
    public func putData(id: String, data: Data) async throws {
        guard !id.isEmpty else {
            throw DUMEError.storageError("Cannot store data with empty ID")
        }
        storage[id] = data
    }
    
    // MARK: - Read
    
    public func getData(_ id: String) async throws -> Data? {
        return storage[id]
    }
    
    public func getAllData() async throws -> [Data] {
        return Array(storage.values)
    }
    
    // MARK: - Lifecycle
    
    public func checkpoint() async throws {
        // No-op (in-memory only)
    }
    
    public func restore() async throws {
        // No-op (in-memory only)
    }
}
