Section 10: Sources/Manifold/GraphEvolution.swift

Below is a concrete Swift implementation for managing a lightweight k-NN graph used by the engine. It focuses on:
    Inserting new nodes (with their latent vectors)
    Linking neighbors (k-NN connections) based on a simple utility metric
    Pruning and maintaining the graph using a utility-based heuristic to keep the graph compact and performant
    Basic utilities for traversal and neighbor retrieval

The design emphasizes simplicity and testability while remaining efficient for streaming ingestion workloads.
Design goals and assumptions:
    Each node is identified by a unique ID and holds a latent vector (array of Double).
    The graph maintains, for each node, up to k neighbor links.
    A lightweight utility function guides neighbor selection; typically, cosine similarity or Euclidean distance can be used in practice. Here we provide a pluggable utility function through a protocol to allow easy swapping.
    Insertion triggers local linking by comparing the new node to existing nodes and selecting up to k closest neighbors.
    Pruning reclaims links when a node becomes overloaded with candidates, relying on a simple utility threshold and a maximum degree per node.
    Thread safety: a minimal, lock-free approach is shown for clarity. In production, wrap mutations with synchronization primitives if accessed from multiple threads.

10.1 Utility protocol:
//
//  Sources/Manifold/GraphUtilities.swift
//
import Foundation

/// A strategy to compute the similarity/fitness between two latent vectors.
/// The higher the score, the more similar the vectors are.
public protocol GraphSimilarity {
    func similarity(_ a: [Double], _ b: [Double]) -> Double
}
10.2 Common similarity implementations:
//
//  Sources/Manifold/SimilarityStrategies.swift
//
import Foundation

/// Cosine similarity between two vectors
public struct CosineSimilarity: GraphSimilarity {
    public init() {}
    
    public func similarity(_ a: [Double], _ b: [Double]) -> Double {
        guard a.count == b.count && a.count > 0 else { return 0.0 }
        var dot: Double = 0
        var aNorm: Double = 0
        var bNorm: Double = 0
        for i in 0..<a.count {
            dot += a[i] * b[i]
            aNorm += a[i] * a[i]
            bNorm += b[i] * b[i]
        }
        let denom = sqrt(aNorm) * sqrt(bNorm)
        if denom == 0 { return 0.0 }
        return max(min(dot / denom, 1.0), -1.0)
    }
}

/// Euclidean distance complement (the higher, the closer)
public struct EuclideanProximity: GraphSimilarity {
    public init() {}
    
    public func similarity(_ a: [Double], _ b: [Double]) -> Double {
        guard a.count == b.count else { return 0.0 }
        var sum: Double = 0
        for i in 0..<a.count {
            let d = a[i] - b[i]
            sum += d * d
        }
        // Convert distance to a similarity-like score
        return 1.0 / (1.0 + sqrt(sum))
    }
}
10.3 GraphEvolution.swift:
//
//  Sources/Manifold/GraphEvolution.swift
//
import Foundation

/// Node representation in the lightweight k-NN graph.
public struct GraphNode {
    public let id: UUID
    public let vector: [Double]
    // Maintain a small, fixed-size neighbor list
    public var neighbors: [NeighborLink]
    
    public init(id: UUID = UUID(), vector: [Double], neighbors: [NeighborLink] = []) {
        self.id = id
        self.vector = vector
        self.neighbors = neighbors
    }
}

/// A lightweight neighbor link referencing another node and its similarity score
public struct NeighborLink {
    public let nodeId: UUID
    public let score: Double
    
    public init(nodeId: UUID, score: Double) {
        self.nodeId = nodeId
        self.score = score
    }
}

/// GraphEvolution manages a lightweight k-NN graph
public final class GraphEvolution {
    // Public configuration
    public private(set) var k: Int
    public private(set) var similarity: GraphSimilarity
    
    // Internal storage
    private var nodes: [UUID: GraphNode] = [:]
    private let queue = DispatchQueue(label: "com.example.GraphEvolution", attributes: .concurrent)
    
    // Initialization
    public init(k: Int = 6, similarity: GraphSimilarity = CosineSimilarity()) {
        self.k = max(1, k)
        self.similarity = similarity
    }
    
    // MARK: - Node management
    
    /// Insert a new node into the graph and opportunistically link to up to k neighbors.
    public func insertNode(vector: [Double]) -> UUID {
        let nodeId = UUID()
        var newNode = GraphNode(id: nodeId, vector: vector, neighbors: [])
        
        // Compute similarities to existing nodes and select top-k
        var candidates: [(UUID, Double)] = []
        queue.sync(flags: .barrier) { // barrier to read current snapshot
            for (otherId, otherNode) in nodes {
                if otherNode.vector.isEmpty { continue }
                let score = similarity.similarity(vector, otherNode.vector)
                candidates.append((otherId, score))
            }
        }
        // sort by highest similarity
        candidates.sort { $0.1 > $1.1 }
        let topK = candidates.prefix(k)
        newNode.neighbors = topK.map { NeighborLink(nodeId: $0.0, score: $0.1) }
        
        // Store the new node
        queue.async(flags: .barrier) { [weak self] in
            self?.nodes[nodeId] = newNode
        }
        
        // Optionally, update neighbors of existing nodes to include mutual connections
        // Simple approach: for each candidate neighbor, if not already connected, consider adding.
        // We keep it lightweight to avoid O(n^2) behavior.
        for (neighborId, score) in topK {
            addMutualLink(from: nodeId, to: neighborId, score: score)
        }
        
        return nodeId
    }
    
    private func addMutualLink(from: UUID, to: UUID, score: Double) {
        queue.async(flags: .barrier) { [weak self] in
            guard var fromNode = self?.nodes[from], var toNode = self?.nodes[to] else { return }
            // Check if link already exists
            if fromNode.neighbors.contains(where: { $0.nodeId == to }) {
                // Optional: update score if higher
                if let idx = fromNode.neighbors.firstIndex(where: { $0.nodeId == to }) {
                    var updated = fromNode.neighbors
                    updated[idx] = NeighborLink(nodeId: to, score: max(updated[idx].score, score))
                    fromNode.neighbors = updated
                    self?.nodes[from] = fromNode
                }
                return
            }
            // Append mutual link if under limit
            if fromNode.neighbors.count < self?.k ?? 1 {
                fromNode.neighbors.append(NeighborLink(nodeId: to, score: score))
                self?.nodes[from] = fromNode
            }
            // Symmetric link for the neighbor side
            if toNode.neighbors.count < self?.k ?? 1 {
                toNode.neighbors.append(NeighborLink(nodeId: from, score: score))
                self?.nodes[to] = toNode
            }
        }
    }
    
    /// Retrieve a node by ID
    public func node(for id: UUID) -> GraphNode? {
        var result: GraphNode?
        queue.sync {
            result = self.nodes[id]
        }
        return result
    }
    
    /// Retrieve neighbors for a given node, ordered by score descending
    public func neighbors(of id: UUID) -> [NeighborLink]? {
        var result: [NeighborLink]?
        queue.sync {
            result = self.nodes[id]?.neighbors.sorted { $0.score > $1.score }
        }
        return result
    }
    
    // MARK: - Pruning and maintenance
    
    /// Prune neighbor lists that exceed the maximum degree or underperform by a threshold.
    /// This can be invoked periodically to keep the graph compact.
    public func pruneAll(threshold: Double = 0.0) {
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            for (id, var node) in self.nodes {
                // Sort neighbors by score descending
                node.neighbors.sort { $0.score > $1.score }
                // Apply simple pruning: keep top-k, optionally filter by threshold
                let kept = node.neighbors.filter { $0.score >= threshold }.prefix(self.k)
                node.neighbors = Array(kept)
                self.nodes[id] = node
            }
        }
    }
    
    /// Rebuild neighbor links for all nodes using a fresh pass (useful after bulk insertions)
    public func rebuildAllLinks() {
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            // Snapshot existing vectors
            let currentNodes = self.nodes
            self.nodes.removeAll()
            // Re-insert in an order-insensitive way
            for (id, node) in currentNodes {
                _ = self.insertNode(vector: node.vector)
            }
        }
    }
    
    // MARK: - Configuration updates
    
    /// Update the k-parameter (max neighbors)
    public func updateK(_ newK: Int) {
        queue.async(flags: .barrier) { [weak self] in
            self?.k = max(1, newK)
            // Optional: prune all after changing k
            self?.pruneAll()
        }
    }
    
    /// Update the similarity strategy
    public func updateSimilarity(_ strategy: GraphSimilarity) {
        queue.async(flags: .barrier) { [weak self] in
            self?.similarity = strategy
        }
    }
}
10.4 Example usage:
//
//  Example usage snippet (not a full test)
//
import Foundation

// Create a graph with k = 4 neighbors per node
let graph = GraphEvolution(k: 4, similarity: CosineSimilarity())

// Insert a few example latent vectors
let v1 = [0.2, 0.5, -0.1, 0.9]
let v2 = [0.1, 0.4, -0.2, 0.85]
let v3 = [-0.3, 0.8, 0.0, 0.2]

let id1 = graph.insertNode(vector: v1)
let id2 = graph.insertNode(vector: v2)
let id3 = graph.insertNode(vector: v3)

// Retrieve neighbors for a node
if let neighbors = graph.neighbors(of: id1) {
    print("Node \(id1) neighbors:")
    for n in neighbors {
        print(" - \(n.nodeId) (score: \(n.score))")
    }
}
10.5 Tests you might add (high level):
    Insertion populates up to k neighbors with reasonable similarity
    Mutual linking is created when appropriate
    Neighbor retrieval returns correctly ordered results
    Pruning removes low-scoring links and respects the k bound
    Rebuild path preserves graph connectivity after bulk insertions
