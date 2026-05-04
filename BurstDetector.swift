6: The Safety Module.

This module implements the Burst Detection mechanism. It monitors entropy fluctuations to detect sudden data spikes ("bursts"). When a burst is detected, the engine automatically disables compression and speculation to ensure zero data loss and maximum fidelity during unstable periods.

File: Sources/Safety/BurstDetector.swift

import Foundation

/// Monitors entropy levels to detect sudden data spikes (bursts).
/// When a burst is detected, the system switches to "Safe Mode" (full fidelity).
public struct BurstDetector {
    private var history: [Float] = []
    private let windowSize: Int
    private let threshold: Float
    
    /// Initializes the detector.
    /// - Parameters:
    ///   - windowSize: Number of recent entropy readings to track (default: 10).
    ///   - threshold: Minimum delta required to trigger burst mode (default: 0.3).
    public init(windowSize: Int = 10, threshold: Float = 0.3) {
        self.windowSize = windowSize
        self.threshold = threshold
    }
    
    /// Updates the detector with a new entropy reading.
    /// Maintains a sliding window of history.
    /// - Parameter entropy: The current entropy value [0, 1].
    public mutating func update(entropy: Float) {
        guard entropy >= 0 && entropy <= 1 else { return }
        
        history.append(entropy)
        if history.count > windowSize {
            history.removeFirst()
        }
    }
    
    /// Determines if the system is currently in Burst Mode.
    /// Triggered if the entropy delta between the last two readings exceeds the threshold.
    public var isBurstMode: Bool {
        guard history.count >= 2 else { return false }
        
        let recent = history.suffix(3)
let deltas = zip(recent.dropFirst(), recent).map { abs($0 - $1) }
let avgDelta = deltas.reduce(0, +) / Float(deltas.count)

return avgDelta > threshold
    }
    
    /// Calculates the current trend of entropy (positive = rising, negative = falling).
    public var entropyTrend: Float {
        guard history.count >= 2 else { return 0 }
        return history.last! - history[0]
    }
    
    /// Resets the history buffer. Useful for manual recovery or testing.
    public mutating func reset() {
        history.removeAll()
    }
}
