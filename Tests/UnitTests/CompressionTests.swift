ection 13: Tests/UnitTests/CompressionTests.swift

Below is a concrete Swift test file using XCTest that targets compression-related aspects described in Section 9 and Section 12. The tests focus on:
    Compression context validation and edge cases
    Basic round-tripping of a mock compressor to ensure data integrity
    Handling of empty inputs and mismatched sizes

You can export this file directly to Tests/UnitTests/CompressionTests.swift in your repository and adapt imports and types to match your actual project structure.

13.1 Test file: CompressionTests.swift
//
//  Tests/UnitTests/CompressionTests.swift
//
import XCTest
@testable import YourProjectModule // Replace with your actual module name

// MARK: - Supporting lightweight mocks / helpers

// A minimal compression protocol used by the engine.
// This mirrors the idea of a compression context used in the DUME pipeline.
protocol CompressionContext {
    // Compresses input data and returns compressed data
    func compress(_ input: [Double]) throws -> Data
    // Decompresses previously compressed data back to original vector
    func decompress(_ data: Data) throws -> [Double]
}

// A simple in-memory mock compressor for unit tests
struct MockPassThroughCompression: CompressionContext {
    func compress(_ input: [Double]) throws -> Data {
        // Simple representation: encode as CSV-like string bytes
        let payload = input.map { String($0) }.joined(separator: ",")
        return payload.data(using: .utf8) ?? Data()
    }

    func decompress(_ data: Data) throws -> [Double] {
        guard let string = String(data: data, encoding: .utf8) else {
            throw CompressionError.invalidData
        }
        if string.isEmpty { return [] }
        let parts = string.split(separator: ",")
        return parts.compactMap { Double($0) }
    }
}

// Custom errors for compression tests
enum CompressionError: Error {
    case invalidData
    case unsupported
}

// Simple helper to compare doubles with tolerance for test assertions
func approxEqual(_ a: Double, _ b: Double, tolerance: Double = 1e-6) -> Bool {
    return abs(a - b) <= tolerance
}

// MARK: - Core Compression Tests

final class CompressionTests: XCTestCase {

    // 13.1 Round-trip with mock compressor
    func testCompressionRoundTrip_PassThrough() {
        // Arrange
        let compressor = MockPassThroughCompression()
        let original: [Double] = [0.0, 1.5, -2.25, 3.14159]

        // Act
        do {
            let compressed = try compressor.compress(original)
            let decompressed = try compressor.decompress(compressed)

            // Assert
            XCTAssertEqual(decompressed.count, original.count, "Decompressed vector should have same length as original")
            for i in 0..<original.count {
                XCTAssertTrue(approxEqual(decompressed[i], original[i]),
                              "Element \(i) should match after round-trip")
            }
        } catch {
            XCTFail("Compression round-trip threw an error: \(error)")
        }
    }

    // 13.2 Empty input handling
    func testCompressionWithEmptyInput() {
        let compressor = MockPassThroughCompression()
        let original: [Double] = []

        do {
            let compressed = try compressor.compress(original)
            let decompressed = try compressor.decompress(compressed)

            XCTAssertEqual(decompressed.count, 0, "Decompressed empty input should be empty")
        } catch {
            XCTFail("Compression handling for empty input failed with error: \(error)")
        }
    }

    // 13.3 Mismatched data or invalid payload
    func testDecompressionWithInvalidPayload() {
        let compressor = MockPassThroughCompression()
        // Create invalid Data that cannot be decoded as UTF-8 string
        let invalidData = Data([0xFF, 0xFE, 0xFD])

        XCTAssertThrowsError(try compressor.decompress(invalidData)) { error in
            // Expect a CompressionError or a generic error
            // We simply verify that an error is thrown
            // You can refine with type checks if you expose specific error types
        }
    }

    // 13.4 Numeric stability under small vectors
    func testCompressionSmallVectorNumericStability() {
        let compressor = MockPassThroughCompression()
        let original: [Double] = [1e-10, -1e-10, 0.0]

        do {
            let compressed = try compressor.compress(original)
            let decompressed = try compressor.decompress(compressed)
            XCTAssertEqual(decompressed.count, original.count)
            for i in 0..<original.count {
                XCTAssertTrue(approxEqual(decompressed[i], original[i]),
                              "Element \(i) should remain stable after compression")
            }
        } catch {
            XCTFail("Compression failed on small vector with error: \(error)")
        }
    }
}
// MARK: - Notes and integration tips
13.2 Notes and integration tips:
    Replace the module import with your actual module name to access real types from your codebase.
    If your project uses a more complex compression pipeline (e.g., delta encoding, quantization, or entropy coding), adapt the tests to reflect the actual API surface and error semantics.
    If you maintain a Swift Package Manager test layout, ensure the test target includes the module under test and that the test suite is wired in your package manifest.

13.3 What to extend next:
    Add integration tests that couple CompressionContext with the encryption and storage components from Section 9 and Section 11.
    Include performance benchmarks for compression and decompression if you have a dedicated benchmarking strategy.
    Validate edge cases such as extremely large vectors, NaNs, and infinities if your pipeline requires strict numeric handling.

// - Replace import statement and module name (YourProjectModule) with the actual module name of your project.
// - If your project uses a real compression context (e.g., zlib, lz4, or a custom encoder), replace MockPassThroughCompression with your real implementation in tests.
// - Extend tests to cover error propagation from compression and decompression, memory pressure scenarios, and performance benchmarks if needed.
