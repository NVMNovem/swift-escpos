//
//  ESCPOSPaperWidth.swift
//  swift-escpos
//
//  Created by Damian Van de Kauter on 25/10/2026.
//

/// The width of the paper roll loaded in the printer.
public enum ESCPOSPaperWidth: Int, Sendable, Hashable, CaseIterable {
    case millimeters58 = 58
    case millimeters80 = 80
}
