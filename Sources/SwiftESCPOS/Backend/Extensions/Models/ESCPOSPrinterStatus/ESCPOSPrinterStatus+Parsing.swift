//
//  ESCPOSPrinterStatus+Parsing.swift
//  swift-escpos
//
//  Created by Damian Van de Kauter on 25/10/2026.
//

extension ESCPOSPrinterStatus {
    /// Reads one `DLE EOT` answer into the status.
    ///
    /// Every answer has bit 1 and bit 4 set and bit 0 and bit 7 clear. A byte without that shape is
    /// not a status answer, and is refused rather than misread.
    public mutating func apply(_ byte: UInt8, for request: ESCPOSStatusRequest) throws(ESCPOSStatusError) {
        guard byte & 0b1001_0011 == 0b0001_0010 else {
            throw ESCPOSStatusError(byte: byte, request: request)
        }
        func isSet(_ mask: UInt8) -> Bool { byte & mask != 0 }

        switch request {
        case .printer:
            isOnline = !isSet(0x08)
        case .offlineCause:
            isCoverOpen = isSet(0x04)
            isFeedingByButton = isSet(0x08)
            hasStoppedOnPaperEnd = isSet(0x20)
            hasError = isSet(0x40)
        case .errorCause:
            hasMechanicalError = isSet(0x04)
            hasAutocutterError = isSet(0x08)
            hasUnrecoverableError = isSet(0x20)
            hasAutomaticallyRecoverableError = isSet(0x40)
        case .paperRollSensor:
            isPaperNearEnd = isSet(0x0C)
            isPaperOut = isSet(0x60)
        }
    }

    /// A status read from answers given in the same order as the requests.
    public init(answers: [UInt8], for requests: [ESCPOSStatusRequest]) throws(ESCPOSStatusError) {
        self.init()
        for (byte, request) in zip(answers, requests) {
            try apply(byte, for: request)
        }
    }
}
