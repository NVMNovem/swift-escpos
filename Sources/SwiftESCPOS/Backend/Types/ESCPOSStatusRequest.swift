//
//  ESCPOSStatusRequest.swift
//  swift-escpos
//
//  Created by Damian Van de Kauter on 25/10/2026.
//

/// A real-time status request (`DLE EOT n`), answered by the printer with one byte.
public enum ESCPOSStatusRequest: UInt8, Sendable, Hashable, CaseIterable {
    case printer = 1
    case offlineCause = 2
    case errorCause = 3
    case paperRollSensor = 4

    /// The three bytes that ask for this status.
    public var bytes: [UInt8] {
        [0x10, 0x04, rawValue]
    }
}
