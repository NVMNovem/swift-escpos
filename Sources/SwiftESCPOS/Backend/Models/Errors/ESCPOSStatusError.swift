//
//  ESCPOSStatusError.swift
//  swift-escpos
//
//  Created by Damian Van de Kauter on 25/10/2026.
//

/// A status byte that does not have the shape `DLE EOT` answers have.
public struct ESCPOSStatusError: Error, Sendable, Hashable {
    public let byte: UInt8
    public let request: ESCPOSStatusRequest
}
