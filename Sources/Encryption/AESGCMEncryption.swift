Section 9: Sources/Encryption/AESGCMEncryption.swift

Below is a concrete Swift implementation intended for export directly to repository. It provides a protocol-based encryption abstraction and two implementations:

    AES-256-GCM encryption using CryptoKit
    NoOpEncryption for testing and benchmarking

This design allows the engine to swap encryption implementations at construction time.
9.1 DUMEEncryption.swift (protocol)
//
//  Sources/Encryption/DUMEEncryption.swift
//
import Foundation

/// Protocol that abstracts the encryption/decryption operations
/// used by the DUME pipeline.
public protocol DUMEEncryption {
    /// Encrypts the given plaintext data and returns the sealed payload.
    /// - Parameter data: The plaintext data to encrypt.
    /// - Throws: An error if encryption fails.
    func encrypt(_ data: Data) throws -> Data

    /// Decrypts the given sealed payload and returns the plaintext data.
    /// - Parameter data: The sealed payload to decrypt.
    /// - Throws: An error if decryption fails.
    func decrypt(_ data: Data) throws -> Data
}
9.2 AESGCMEncryption.swift
//
//  Sources/Encryption/AESGCMEncryption.swift
//
import Foundation
import CryptoKit

/// AES-256-GCM encryption implementation conforming to DUMEEncryption.
public struct AESGCMEncryption: DUMEEncryption {
    /// 256-bit symmetric key used for AES-GCM
    private let key: SymmetricKey

    /// Nonce size used for AES-GCM (12 bytes is the recommended standard)
    private let nonceSize: Int = 12

    /// Initialize with a 256-bit key
    /// - Parameter key: A 32-byte key data or an existing SymmetricKey
    public init(key: SymmetricKey) {
        self.key = key
    }

    /// Convenience initializer from raw key bytes
    /// - Parameter keyData: 32-byte raw key material
    public init?(keyData: Data) {
        guard keyData.count == 32 else { return nil }
        self.key = SymmetricKey(data: keyData)
    }

    /// Encrypts data using AES-GCM
    public func encrypt(_ data: Data) throws -> Data {
        // Generate a fresh random nonce for each encryption
        let nonce = AES.GCM.Nonce()
        do {
            let sealed = try AES.GCM.seal(data, using: key, nonce: nonce)
            // Combine nonce + ciphertext + tag into a single payload
            // We'll store: [nonce][ciphertext][tag]
            // CryptoKit's combined representation is [ciphertext][tag], so we prepend nonce bytes.
            let nonceBytes = nonce.withUnsafeBytes { Data($0) }
            let combined = sealed.ciphertext + sealed.tag
            return nonceBytes + combined
        } catch {
            throw EncryptionError.encryptionFailed(underlyingError: error)
        }
    }

    /// Decrypts data previously encrypted with `encrypt(_:)`
    public func decrypt(_ data: Data) throws -> Data {
        // Validate enough bytes for nonce and tag
        guard data.count > nonceSize else {
            throw EncryptionError.invalidPayload
        }

        // Extract nonce
        let nonceData = data.subdata(in: 0..<nonceSize)
        let nonce = try AES.GCM.Nonce(data: nonceData)

        // The remaining payload is [ciphertext][tag]
        let payload = data.subdata(in: nonceSize..<data.count)
        // AES.GCM.SealedBox expects ciphertext + tag together
        // We need to split into ciphertext and tag sizes
        // For AES.GCM, tag is 16 bytes
        let tagSize = 16
        guard payload.count >= tagSize else {
            throw EncryptionError.invalidPayload
        }

        let ciphertext = payload.subdata(in: 0..<(payload.count - tagSize))
        let tag = payload.subdata(in: (payload.count - tagSize)..<payload.count)

        let sealedBoxData = ciphertext + tag

        do {
            let sealedBox = try AES.GCM.SealedBox(nonce: nonce, ciphertext: ciphertext, tag: tag)
            let decrypted = try AES.GCM.open(sealedBox, using: key)
            return decrypted
        } catch {
            throw EncryptionError.decryptionFailed(underlyingError: error)
        }
    }
}

/// Errors specific to the DUME encryption layer
public enum EncryptionError: Error {
    case encryptionFailed(underlyingError: Error)
    case decryptionFailed(underlyingError: Error)
    case invalidPayload
}
Notes:
    This implementation uses a fresh random nonce for every encryption to ensure semantic security.
    The sealed payload is constructed as a simple concatenation: [nonce][ciphertext][tag]. The nonce is 12 bytes and the tag is 16 bytes, which aligns with AES-GCM standards.
    If you prefer CryptoKit’s “combined” representation, you can instead store the nonce and the combined (ciphertext + tag) together and reconstruct accordingly.

9.3 NoOpEncryption.swift
//
//  Sources/Encryption/NoOpEncryption.swift
//
import Foundation

/// A no-op encryption implementation that passes data through unchanged.
/// Useful for testing, benchmarking, and environments where encryption is disabled.
public struct NoOpEncryption: DUMEEncryption {
    public init() {}

    public func encrypt(_ data: Data) throws -> Data {
        return data
    }

    public func decrypt(_ data: Data) throws -> Data {
        return data
    }
}
9.4 Example: Minimal usage in an engine initializer
//
// Example usage snippet (not a full integration test)
//
import Foundation
import CryptoKit

// Choose encryption strategy
let rawKey = Data("01234567890123456789012345678901".utf8) // 32 bytes for example
guard rawKey.count == 32 else { fatalError("Key must be 32 bytes") }

let aesKey = SymmetricKey(data: rawKey)
let aesEncryption = AESGCMEncryption(key: aesKey)
// Or switch to no-op for testing
// let aesEncryption = NoOpEncryption()

// Engine initialization (pseudo-code)
let engine = Engine(
    encryption: aesEncryption,
    // ... other config
)
9.5 Tests you might add (high level)

    AES-GCM Round-trip:
        Encrypt a random payload, then decrypt and assert equality.
    NoOp passthrough:
        Encrypt and decrypt with NoOpEncryption and assert the input equals output.
    Error propagation:
        Simulate a decryption failure by corrupting the payload and verify the error is surfaced as EncryptionError.decryptionFailed.
