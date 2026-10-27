//
//  ESCPOSTransmission.swift
//  swift-escpos
//
//  Created by Damian Van de Kauter on 25/10/2026.
//

/// A job that was handed over completely.
///
/// Every byte was accepted by the operating system and the connection closed cleanly. That is
/// all it says: it does not mean the printer printed. Whether paper came out is only known from a
/// printer that reports completion.
public struct ESCPOSTransmission: Sendable, Hashable {
    public let bytesSent: Int
    public let duration: Duration
}
