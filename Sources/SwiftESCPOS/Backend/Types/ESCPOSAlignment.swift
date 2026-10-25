//
//  ESCPOSAlignment.swift
//  swift-escpos
//
//  Created by Damian Van de Kauter on 25/10/2026.
//

/// Horizontal justification of the lines that follow (`ESC a n`).
public enum ESCPOSAlignment: UInt8, Sendable, Hashable, CaseIterable {
    case leading = 0
    case center = 1
    case trailing = 2
}
