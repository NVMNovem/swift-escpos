//
//  ESCPOSTextSize.swift
//  swift-escpos
//
//  Created by Damian Van de Kauter on 25/10/2026.
//

/// Character magnification (`GS ! n`): how many times wider and taller than the cell.
///
/// Both factors are 1…8 by the command's definition; a profile may allow less, and the encoder
/// refuses what the profile does not allow.
public struct ESCPOSTextSize: Sendable, Hashable {
    public var width: UInt8
    public var height: UInt8

    public init(width: UInt8 = 1, height: UInt8 = 1) {
        self.width = width
        self.height = height
    }

    public static let normal = ESCPOSTextSize()
    public static let doubleWidth = ESCPOSTextSize(width: 2)
    public static let doubleHeight = ESCPOSTextSize(height: 2)
    public static let double = ESCPOSTextSize(width: 2, height: 2)
}
