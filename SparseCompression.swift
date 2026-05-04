Here is the implementation for Section 4: The Compression Module.

This module handles the adaptive sparsification logic. It determines which vector elements to keep based on entropy, drift, and burst mode status, ensuring optimal storage density while preserving data fidelity.
File: Sources/Compression/SparseCompression.swift
import Foundation

/// Handles adaptive sparse encoding of high-dimensional vectors.
/// Compresses vectors by retaining only elements above a dynamic threshold.
public struct SparseCompression {
    private let minThreshold: Float = 0.005
    private let maxThreshold: Float = 0.1
    
    public init() {}
    
    /// Compresses a vector by filtering out small values based on context.
    /// - Parameters:
    ///   - vector: The input vector to compress.
    ///   - entropy: Current system entropy [0, 1].
    ///   - drift: Current system drift [0, 1].
    ///   - isBurstMode: If true, disables compression for 100% fidelity.
    /// - Returns: A tuple of (values, indices) representing the sparse vector.
    /// - Throws: DUMEError.invalidVector if input is empty.
    public func compress(
        _ vector: [Float],
        entropy: Float,
        drift: Float,
        isBurstMode: Bool
    ) throws -> (values: [Float], indices: [Int]) {
        guard !vector.isEmpty else {
            throw DUMEError.invalidVector("Cannot compress empty vector")
        }
        
        let threshold = calculateThreshold(entropy: entropy, drift: drift, isBurst: isBurstMode)
        
        var values: [Float] = []
        var indices: [Int] = []
        
        for (i, value) in vector.enumerated() {
            if abs(value) > threshold {
                values.append(value)
                indices.append(i)
            }
        }
        
        return (values, indices)
    }
    
    /// Reconstructs the original vector from sparse data.
    /// - Parameters:
    ///   - values: The non-zero values.
    ///   - indices: The original indices of those values.
    ///   - originalSize: The expected size of the full vector.
    /// - Returns: The reconstructed dense vector.
    /// - Throws: DUMEError.compressionFailed if indices/values mismatch or out of bounds.
    public func decompress(
        values: [Float],
        indices: [Int],
        originalSize: Int
    ) throws -> [Float] {
        guard values.count == indices.count else {
            throw DUMEError.compressionFailed("Mismatched values and indices count")
        }
        
        var result = [Float](repeating: 0, count: originalSize)
        for (value, index) in zip(values, indices) {
            guard index < originalSize else {
                throw DUMEError.compressionFailed("Index out of bounds: \(index)")
            }
            result[index] = value
        }
        return result
    }
    
    /// Calculates the adaptive threshold based on system state.
    /// - Returns: 0.0 in burst mode, otherwise a value between min and max threshold.
    private func calculateThreshold(entropy: Float, drift: Float, isBurst: Bool) -> Float {
        guard !isBurst else { return 0.0 }
        
        // Higher entropy/drift -> higher threshold (more aggressive compression)
        let adaptiveThreshold = minThreshold + (maxThreshold - minThreshold) * (entropy + drift) / 2.0
        return min(maxThreshold, max(minThreshold, adaptiveThreshold))
    }
}
