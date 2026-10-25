//
//  ESCPOSPrinterStatusTests.swift
//  swift-escpos
//
//  Created by Damian Van de Kauter on 25/10/2026.
//

import Testing
@testable import SwiftESCPOS

@Suite("Printer status")
struct ESCPOSPrinterStatusTests {
    @Test("A printer with nothing to report is ready")
    func ready() throws {
        let status = try ESCPOSPrinterStatus(answers: [0x12, 0x12, 0x12, 0x12], for: ESCPOSStatusRequest.allCases)
        #expect(status.isOnline == true)
        #expect(status.isCoverOpen == false)
        #expect(status.isPaperOut == false)
        #expect(status.isReady == true)
    }

    @Test("Offline, cover open, paper out and near end are read from their bits")
    func faults() throws {
        let status = try ESCPOSPrinterStatus(answers: [0x1A, 0x16, 0x12, 0x7E], for: ESCPOSStatusRequest.allCases)
        #expect(status.isOnline == false)
        #expect(status.isCoverOpen == true)
        #expect(status.isPaperNearEnd == true)
        #expect(status.isPaperOut == true)
        #expect(status.isReady == false)
    }

    @Test("Error causes are read from their bits")
    func errorCauses() throws {
        var status = ESCPOSPrinterStatus()
        try status.apply(0x12 | 0x04 | 0x08 | 0x20 | 0x40, for: .errorCause)
        #expect(status.hasMechanicalError == true)
        #expect(status.hasAutocutterError == true)
        #expect(status.hasUnrecoverableError == true)
        #expect(status.hasAutomaticallyRecoverableError == true)
    }

    @Test("Nothing known means readiness is unknown")
    func unknown() {
        #expect(ESCPOSPrinterStatus().isReady == nil)
    }

    @Test("A byte without the status shape is refused")
    func malformed() {
        var status = ESCPOSPrinterStatus()
        #expect(throws: ESCPOSStatusError(byte: 0x00, request: .printer)) {
            try status.apply(0x00, for: .printer)
        }
    }

    @Test("Requests are DLE EOT n")
    func requestBytes() {
        #expect(ESCPOSStatusRequest.paperRollSensor.bytes == [0x10, 0x04, 0x04])
    }
}
