//
//  ESCPOSEncodingError.swift
//  swift-escpos
//
//  Created by Damian Van de Kauter on 25/10/2026.
//

/// Why a command could not be encoded for a profile.
public enum ESCPOSEncodingError: Error, Sendable, Hashable {
    /// The profile does not list the capability the command needs.
    case unsupported(ESCPOSCommand, missing: ESCPOSCapabilities)
    /// The profile does not hold the code page.
    case unsupportedCodePage(ESCPOSCodePage)
    /// A magnification factor is zero or above the profile's maximum.
    case textSizeOutOfRange(ESCPOSTextSize)
    /// The QR payload is empty or longer than ``ESCPOSQRCode/maximumPayloadSize``.
    case qrPayloadSizeOutOfRange(Int)
    /// The QR module size is outside 1…16.
    case qrModuleSizeOutOfRange(UInt8)
    /// The raster image is wider than `GS v 0` can address.
    case rasterImageTooWide(Int)
}
