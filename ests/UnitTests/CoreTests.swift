Section 12: Tests/UnitTests/CoreTests.swift

Below is a concrete Swift test file using XCTest that targets core, foundational behaviors of the system as described in Section 9 and Section 10. The tests focus on:
    Metric symmetry: verify that a simple distance-based metric yields symmetric results between two vectors
    Compression context validation: ensure a mock compression context reports expected properties and handles edge cases
    Node utility logic: validate basic utility calculations used for graph evolution and neighbor selection

You can export this file directly to Tests/UnitTests/CoreTests.swift in your repository and adapt imports and types to match your actual project structure.

12.1 Test file: CoreTests.swift
//
//  Tests/UnitTests/CoreTests.swift
//
import XCTest
@testable import YourProjectModule // Replace with your actual module name

// MARK: - Supporting lightweight mocks / helpers

// Mock metric context or utility if your project uses a separate context object
struct MockCompressionContext {
    let latentSize: Int
    let expectedNonZero: Int

    func isValid(vector: [Double]) -> Bool {
        // Basic validation: correct size and at least some non-zero elements
        guard vector.count == latentSize else { return false }
        let nonZero = vector.filter { $0 != 0.0 }.count
        return nonZero >= expectedNonZero
    }
}

// Simple helper to compare doubles with tolerance
func approxEqual(_ a: Double, _ b: Double, tolerance: Double = 1e-6) -> Bool {
    return abs(a - b) <= tolerance
}

// MARK: - Core Tests

final class CoreTests: XCTestCase {

    // 12.1 Metric symmetry
    func testMetricSymmetry_CosineSimilarity() {
        // Arrange
        let a = [1.0, 0.0, -1.0, 2.0]
        let b = [0.5, -0.5, -1.0, 2.0]

        // Use the CosineSimilarity from your project
        let sim = CosineSimilarity()

        // Act
        let scoreAB = sim.similarity(a, b)
        let scoreBA = sim.similarity(b, a)

        // Assert
        XCTAssertTrue(approxEqual(scoreAB, scoreBA), "Cosine similarity should be symmetric")
        // Additional sanity: score should be within [-1,1]
        XCTAssertTrue(scoreAB >= -1.0 && scoreAB <= 1.0, "Similarity should be bounded in [-1, 1]")
    }

    // 12.2 Compression context validation
    func testCompressionContextValidation() {
        // Arrange
        let ctx = MockCompressionContext(latentSize: 4, expectedNonZero: 1)

        // Valid vector
        let vec1 = [0.0, 1.2, 0.0, -0.3]
        XCTAssertTrue(ctx.isValid(vector: vec1), "Vector with required non-zero elements should be valid")

        // Invalid vector: wrong size
        let vec2 = [1.0, 0.0, 0.0]
        XCTAssertFalse(ctx.isValid(vector: vec2), "Vector of incorrect size should be invalid")

        // Invalid vector: no non-zero elements
        let vec3 = [0.0, 0.0, 0.0, 0.0]
        XCTAssertFalse(ctx.isValid(vector: vec3), "Vector with no non-zero elements should be invalid")
    }

    // 12.3 Node utility logic
    func testGraphNodeUtilityCalculation_basic() {
        // Arrange
        // Simple two vectors and a mock graph: we reuse CosineSimilarity
        let sim = CosineSimilarity()
        let nodeA = GraphNode(id: UUID(), vector: [1.0, 0.0, 0.0], neighbors: [])
        let nodeB = GraphNode(id: UUID(), vector: [0.0, 1.0, 0.0], neighbors: [])
        let nodeC = GraphNode(id: UUID(), vector: [1.0, 1.0, 0.0], neighbors: [])

        // Act
        let scoreAB = sim.similarity(nodeA.vector, nodeB.vector)
        let scoreAC = sim.similarity(nodeA.vector, nodeC.vector)

        // Assert: A should be more similar to C than to B
        XCTAssertTrue(scoreAC > scoreAB, "Utility (similarity) should reflect relative closeness between vectors")
    }

    func testGraphEvolutionNodeInsertion_updatesNeighbors() {
        // This test simulates a tiny graph insertion scenario using GraphEvolution
        let graph = GraphEvolution(k: 2, similarity: CosineSimilarity())

        // Insert first node
        let id1 = graph.insertNode(vector: [1.0, 0.0, 0.0])

        // Insert second node similar to first
        let id2 = graph.insertNode(vector: [0.9, 0.1, 0.0])

        // Retrieve nodes
        let n1 = graph.node(for: id1)
        let n2 = graph.node(for: id2)

        // Assert: at least one neighbor relation is established
        XCTAssertNotNil(n1)
        XCTAssertNotNil(n2)
        if let n1Neighbors = n1?.neighbors, let n2Neighbors = n2?.neighbors {
            // With k=2, both should have at least one neighbor
            XCTAssertGreaterThanOrEqual(n1Neighbors.count, 1, "Node 1 should have at least 1 neighbor")
            XCTAssertGreaterThanOrEqual(n2Neighbors.count, 1, "Node 2 should have at least 1 neighbor")
        } else {
            XCTFail("Neighbors not populated as expected")
        }
    }

    // 12.4 Safety: ensure no crashes on empty vectors in similarity
    func testSimilarityWithEmptyVectors() {
        let sim = CosineSimilarity()
        let a: [Double] = []
        let b: [Double] = []

        let score = sim.similarity(a, b)
        XCTAssertTrue(score == 0.0, "Similarity of empty vectors should yield 0.0")
    }
}
12.2 Notes and integration tips

    Replace import statement and module name (YourProjectModule) with the actual module name of your project.
    The tests assume the existence of the following types from your codebase:
        CosineSimilarity implementing GraphSimilarity
        GraphEvolution with insertNode(_:) and node(for:) methods
        GraphNode with id, vector, and neighbors properties
        NeighborLink type used by GraphEvolution
    If your GraphEvolution or GraphNode types live in a different namespace or module, adjust imports and type references accordingly.
    If your project uses a different testing strategy (e.g., Swift Package Manager with tests under Tests/), ensure the test target includes the corresponding module under test.

12.3 What to extend next
    Add tests for:
        Pruning logic in GraphEvolution pruneAll(threshold:) to ensure degenerate graphs are compacted as expected
        Edge cases for insertNode when vectors have varying lengths or NaN values
        Round-trip tests for the encryption path in Section 9 using a mock engine
        End-to-end workflow stubs that connect ingestion, compression, encryption, storage, and retrieval
