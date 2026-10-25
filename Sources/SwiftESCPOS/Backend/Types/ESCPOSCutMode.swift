//
//  ESCPOSCutMode.swift
//  swift-escpos
//
//  Created by Damian Van de Kauter on 25/10/2026.
//

/// How the autocutter cuts the paper (`GS V m`).
public enum ESCPOSCutMode: UInt8, Sendable, Hashable, CaseIterable {
    /// Cuts through completely.
    case full = 0
    /// Leaves one point uncut, so the ticket hangs until it is torn off.
    case partial = 1
}
