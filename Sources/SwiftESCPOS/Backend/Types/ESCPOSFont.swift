//
//  ESCPOSFont.swift
//  swift-escpos
//
//  Created by Damian Van de Kauter on 25/10/2026.
//

/// The printer's built-in character fonts (`ESC M n`).
///
/// Font A is the standard cell (12 × 24 dots on most 80 mm printers), Font B the condensed one.
public enum ESCPOSFont: UInt8, Sendable, Hashable, CaseIterable {
    case a = 0
    case b = 1
}
