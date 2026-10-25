//
//  ESCPOSPrinterStatus.swift
//  swift-escpos
//
//  Created by Damian Van de Kauter on 25/10/2026.
//

/// What the printer reported about itself. A field is `nil` when no answer covered it.
public struct ESCPOSPrinterStatus: Sendable, Hashable {
    public var isOnline: Bool?
    public var isCoverOpen: Bool?
    /// Paper is being fed with the feed button.
    public var isFeedingByButton: Bool?
    /// Printing stopped because the paper ran out.
    public var hasStoppedOnPaperEnd: Bool?
    public var hasError: Bool?
    public var hasMechanicalError: Bool?
    public var hasAutocutterError: Bool?
    public var hasUnrecoverableError: Bool?
    public var hasAutomaticallyRecoverableError: Bool?
    public var isPaperNearEnd: Bool?
    public var isPaperOut: Bool?

    public init() {}

    /// Whether a job sent now would print: `false` when anything known blocks it, `true` when the
    /// printer said it is online and nothing known blocks it, `nil` when there is no answer to go on.
    public var isReady: Bool? {
        if isOnline == false || isCoverOpen == true || isPaperOut == true
            || hasStoppedOnPaperEnd == true || hasError == true {
            return false
        }
        return isOnline
    }
}
