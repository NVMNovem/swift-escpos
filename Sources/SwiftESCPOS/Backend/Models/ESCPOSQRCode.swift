//
//  ESCPOSQRCode.swift
//  swift-escpos
//
//  Created by Damian Van de Kauter on 25/10/2026.
//

/// A QR code (model 2) printed by the printer itself (`GS ( k`).
public struct ESCPOSQRCode: Sendable, Hashable {
    /// The share of the symbol that may be damaged and still read.
    public enum ErrorCorrection: UInt8, Sendable, Hashable, CaseIterable {
        case low = 48
        case medium = 49
        case quartile = 50
        case high = 51
    }

    /// The largest payload a model 2 symbol can store in bytes.
    public static let maximumPayloadSize = 7089

    public let payload: [UInt8]
    /// Dots per module, 1…16.
    public let moduleSize: UInt8
    public let errorCorrection: ErrorCorrection

    public init(payload: [UInt8], moduleSize: UInt8 = 6, errorCorrection: ErrorCorrection = .medium) {
        self.payload = payload
        self.moduleSize = moduleSize
        self.errorCorrection = errorCorrection
    }

    /// A QR code holding text, such as a URL, as UTF-8.
    public init(_ text: String, moduleSize: UInt8 = 6, errorCorrection: ErrorCorrection = .medium) {
        self.init(payload: Array(text.utf8), moduleSize: moduleSize, errorCorrection: errorCorrection)
    }
}
