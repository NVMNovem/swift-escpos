//
//  ESCPOSCapabilities.swift
//  swift-escpos
//
//  Created by Damian Van de Kauter on 25/10/2026.
//

/// What a printer does beyond the commands every ESC/POS printer is assumed to understand.
///
/// Initialising, text, bold, alignment, magnification and line feeds are the baseline. Everything
/// here must be listed in a profile before the encoder will emit it.
public struct ESCPOSCapabilities: OptionSet, Sendable, Hashable {
    public let rawValue: UInt32

    public init(rawValue: UInt32) {
        self.rawValue = rawValue
    }

    public static let underline = ESCPOSCapabilities(rawValue: 1 << 0)
    public static let inverted = ESCPOSCapabilities(rawValue: 1 << 1)
    public static let fontB = ESCPOSCapabilities(rawValue: 1 << 2)
    public static let fullCut = ESCPOSCapabilities(rawValue: 1 << 3)
    public static let partialCut = ESCPOSCapabilities(rawValue: 1 << 4)
    /// `DLE EOT n` real-time status over the same connection.
    public static let realtimeStatus = ESCPOSCapabilities(rawValue: 1 << 5)
    /// `GS v 0` raster bit images.
    public static let rasterImages = ESCPOSCapabilities(rawValue: 1 << 6)
    /// `GS ( k` QR codes, model 2.
    public static let qrCodes = ESCPOSCapabilities(rawValue: 1 << 7)
}
