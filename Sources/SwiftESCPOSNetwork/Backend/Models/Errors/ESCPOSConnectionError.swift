//
//  ESCPOSConnectionError.swift
//  swift-escpos
//
//  Created by Damian Van de Kauter on 25/10/2026.
//

import SwiftESCPOS

/// Why talking to a printer failed, and — the part a caller must act on — whether any of the job
/// may have reached it.
public struct ESCPOSConnectionError: Error, Sendable, Hashable {
    /// How far the job's bytes got before the failure.
    public enum Delivery: Sendable, Hashable {
        /// No byte was handed to the network. Sending again cannot print the job twice.
        case notSent
        /// Writing had started. `confirmedBytes` were accepted by the operating system; more may
        /// have left. The printer may have printed part, all or none of the job.
        case partiallySent(confirmedBytes: Int)
    }

    /// The step that failed.
    public enum Phase: Sendable, Hashable {
        case connecting
        case writing
        case readingStatus
    }

    public enum Reason: Sendable, Hashable {
        /// Nothing accepts connections at the address and port.
        case connectionRefused
        /// The connection could not be made, for the reason described.
        case connectionFailed(String)
        case timedOut(Phase)
        case cancelled(Phase)
        /// The connection closed or broke before the step finished.
        case disconnected(Phase)
        /// The printer answered a status request with a byte that is not a status answer.
        case malformedStatus(ESCPOSStatusError)
    }

    public let delivery: Delivery
    public let reason: Reason

    public init(delivery: Delivery, reason: Reason) {
        self.delivery = delivery
        self.reason = reason
    }
}
