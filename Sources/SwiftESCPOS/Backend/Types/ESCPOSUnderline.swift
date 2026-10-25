//
//  ESCPOSUnderline.swift
//  swift-escpos
//
//  Created by Damian Van de Kauter on 25/10/2026.
//

/// Underline mode (`ESC - n`).
public enum ESCPOSUnderline: UInt8, Sendable, Hashable, CaseIterable {
    case none = 0
    case single = 1
    case double = 2
}
