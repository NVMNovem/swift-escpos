//
//  ESCPOSEncoderTests.swift
//  swift-escpos
//
//  Created by Damian Van de Kauter on 25/10/2026.
//

import Testing
@testable import SwiftESCPOS

/// Golden bytes: every expected array is written out from the ESC/POS command reference.
@Suite("ESC/POS encoder")
struct ESCPOSEncoderTests {
    private let epson = ESCPOSEncoder(profile: .epsonTM)
    private let generic = ESCPOSEncoder(profile: .generic)

    @Test("Each baseline command encodes to its documented bytes")
    func baselineCommands() throws {
        let cases: [(ESCPOSCommand, [UInt8])] = [
            (.initialize, [0x1B, 0x40]),
            (.lineFeed, [0x0A]),
            (.feed(lines: 3), [0x1B, 0x64, 0x03]),
            (.bold(true), [0x1B, 0x45, 0x01]),
            (.bold(false), [0x1B, 0x45, 0x00]),
            (.alignment(.leading), [0x1B, 0x61, 0x00]),
            (.alignment(.center), [0x1B, 0x61, 0x01]),
            (.alignment(.trailing), [0x1B, 0x61, 0x02]),
            (.size(.normal), [0x1D, 0x21, 0x00]),
            (.size(.doubleWidth), [0x1D, 0x21, 0x10]),
            (.size(.doubleHeight), [0x1D, 0x21, 0x01]),
            (.size(.double), [0x1D, 0x21, 0x11]),
            (.size(ESCPOSTextSize(width: 8, height: 8)), [0x1D, 0x21, 0x77]),
            (.font(.a), [0x1B, 0x4D, 0x00]),
            (.underline(.none), [0x1B, 0x2D, 0x00]),
            (.cut(.full), [0x1D, 0x56, 0x00]),
            (.cut(.partial), [0x1D, 0x56, 0x01]),
            (.cut(.partial, feedLines: 4), [0x1B, 0x64, 0x04, 0x1D, 0x56, 0x01]),
            (.raw([0x07, 0xFF]), [0x07, 0xFF]),
        ]
        for (command, expected) in cases {
            #expect(try generic.encode([command]) == expected, "\(command)")
        }
    }

    @Test("Capability commands encode on a profile that lists them")
    func capabilityCommands() throws {
        #expect(try epson.encode([.underline(.single)]) == [0x1B, 0x2D, 0x01])
        #expect(try epson.encode([.underline(.double)]) == [0x1B, 0x2D, 0x02])
        #expect(try epson.encode([.inverted(true)]) == [0x1D, 0x42, 0x01])
        #expect(try epson.encode([.font(.b)]) == [0x1B, 0x4D, 0x01])
    }

    @Test("A command the profile does not list is refused, not sent")
    func refusesUnsupported() {
        #expect(throws: ESCPOSEncodingError.unsupported(.underline(.single), missing: .underline)) {
            try generic.encode([.underline(.single)])
        }
        #expect(throws: ESCPOSEncodingError.unsupported(.font(.b), missing: .fontB)) {
            try generic.encode([.font(.b)])
        }
        let code = ESCPOSQRCode("https://example.org")
        #expect(throws: ESCPOSEncodingError.unsupported(.qrCode(code), missing: .qrCodes)) {
            try generic.encode([.qrCode(code)])
        }
    }

    @Test("Turning a capability off is always allowed")
    func turningOffIsBaseline() throws {
        #expect(try generic.encode([.inverted(false)]) == [0x1D, 0x42, 0x00])
    }

    @Test("Magnification outside 1…8 is refused")
    func refusesBadSizes() {
        #expect(throws: ESCPOSEncodingError.textSizeOutOfRange(ESCPOSTextSize(width: 0, height: 1))) {
            try epson.encode([.size(ESCPOSTextSize(width: 0, height: 1))])
        }
        #expect(throws: ESCPOSEncodingError.textSizeOutOfRange(ESCPOSTextSize(width: 1, height: 9))) {
            try epson.encode([.size(ESCPOSTextSize(width: 1, height: 9))])
        }
    }

    @Test("Text follows the code page in effect, and initialize restores the default")
    func codePageState() throws {
        let bytes = try epson.encode([
            .text("€"),
            .codePage(.pc858), .text("€"),
            .codePage(.windows1252), .text("€"),
            .initialize, .text("é"),
        ])
        #expect(bytes == [
            0x45, 0x55, 0x52,
            0x1B, 0x74, 19, 0xD5,
            0x1B, 0x74, 16, 0x80,
            0x1B, 0x40, 0x82,
        ])
    }

    @Test("A code page the profile does not hold is refused")
    func refusesUnknownCodePage() {
        #expect(throws: ESCPOSEncodingError.unsupportedCodePage(.pc858)) {
            try generic.encode([.codePage(.pc858)])
        }
    }

    @Test("Text cannot inject commands")
    func textCannotInject() throws {
        #expect(try generic.encode([.text("A\u{1B}@\u{1D}V\u{00}B")]) == [0x41, 0x3F, 0x40, 0x3F, 0x56, 0x3F, 0x42])
    }

    @Test("A QR code encodes model, module size, correction, data and print")
    func qrCode() throws {
        let bytes = try epson.encode([.qrCode(ESCPOSQRCode("AB", moduleSize: 4, errorCorrection: .quartile))])
        #expect(bytes == [
            0x1D, 0x28, 0x6B, 0x04, 0x00, 0x31, 0x41, 0x32, 0x00,
            0x1D, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x43, 0x04,
            0x1D, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x45, 0x32,
            0x1D, 0x28, 0x6B, 0x05, 0x00, 0x31, 0x50, 0x30, 0x41, 0x42,
            0x1D, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x51, 0x30,
        ])
    }

    @Test("QR payload and module size limits are enforced")
    func qrLimits() {
        let empty = ESCPOSQRCode(payload: [])
        #expect(throws: ESCPOSEncodingError.qrPayloadSizeOutOfRange(0)) { try epson.encode([.qrCode(empty)]) }
        let large = ESCPOSQRCode(payload: [UInt8](repeating: 0x41, count: 7090))
        #expect(throws: ESCPOSEncodingError.qrPayloadSizeOutOfRange(7090)) { try epson.encode([.qrCode(large)]) }
        let tiny = ESCPOSQRCode("A", moduleSize: 0)
        #expect(throws: ESCPOSEncodingError.qrModuleSizeOutOfRange(0)) { try epson.encode([.qrCode(tiny)]) }
    }

    @Test("A raster image is sent as GS v 0 with little-endian sizes")
    func rasterImage() throws {
        let image = try #require(ESCPOSRasterImage(width: 10, height: 2, packedRows: [0xFF, 0xC0, 0x80, 0x40]))
        #expect(try epson.encode([.rasterImage(image)]) == [
            0x1D, 0x76, 0x30, 0x00, 0x02, 0x00, 0x02, 0x00, 0xFF, 0xC0, 0x80, 0x40,
        ])
    }

    @Test("A tall raster image is split into bands")
    func rasterBands() throws {
        let profile = ESCPOSProfile(
            id: "test-bands", name: "Bands", capabilities: [.rasterImages],
            printableDots: [.millimeters80: 576], cellWidths: [.a: 12],
            codePages: [.pc437: 0], defaultCodePage: .pc437, rasterBandHeight: 2
        )
        let image = ESCPOSRasterImage(width: 8, height: 5) { _, y in y.isMultiple(of: 2) }
        #expect(try ESCPOSEncoder(profile: profile).encode([.rasterImage(image)]) == [
            0x1D, 0x76, 0x30, 0x00, 0x01, 0x00, 0x02, 0x00, 0xFF, 0x00,
            0x1D, 0x76, 0x30, 0x00, 0x01, 0x00, 0x02, 0x00, 0xFF, 0x00,
            0x1D, 0x76, 0x30, 0x00, 0x01, 0x00, 0x01, 0x00, 0xFF,
        ])
    }

    @Test("A ticket-shaped job encodes end to end")
    func ticket() throws {
        let bytes = try generic.encode([
            .initialize,
            .alignment(.center), .size(.double), .bold(true), .text("#42"), .lineFeed,
            .size(.normal), .bold(false), .alignment(.leading),
            .text("2× Friet groot   € 6,40\n"),
            .cut(.partial, feedLines: 3),
        ])
        #expect(bytes == [
            0x1B, 0x40,
            0x1B, 0x61, 0x01, 0x1D, 0x21, 0x11, 0x1B, 0x45, 0x01, 0x23, 0x34, 0x32, 0x0A,
            0x1D, 0x21, 0x00, 0x1B, 0x45, 0x00, 0x1B, 0x61, 0x00,
            0x32, 0x78, 0x20, 0x46, 0x72, 0x69, 0x65, 0x74, 0x20, 0x67, 0x72, 0x6F, 0x6F, 0x74,
            0x20, 0x20, 0x20, 0x45, 0x55, 0x52, 0x20, 0x36, 0x2C, 0x34, 0x30, 0x0A,
            0x1B, 0x64, 0x03, 0x1D, 0x56, 0x01,
        ])
    }
}
