//
//  ESCPOSCodePageTests.swift
//  swift-escpos
//
//  Created by Damian Van de Kauter on 25/10/2026.
//

import Testing
@testable import SwiftESCPOS

@Suite("Code pages")
struct ESCPOSCodePageTests {
    @Test("ASCII passes through unchanged in every table", arguments: ESCPOSCodePage.allCases)
    func ascii(codePage: ESCPOSCodePage) {
        let text = "Friet & co. 12,50 (groot) #42"
        let encoded = codePage.encode(text)
        #expect(encoded.bytes == Array(text.utf8))
        #expect(encoded.replacements.isEmpty)
    }

    @Test("Every defined byte decodes and encodes back to itself", arguments: ESCPOSCodePage.allCases)
    func roundTrip(codePage: ESCPOSCodePage) throws {
        for (offset, value) in codePage.upperHalf.enumerated() {
            guard let value else { continue }
            let scalar = try #require(Unicode.Scalar(value))
            #expect(codePage.encode(String(Character(scalar))).bytes == [UInt8(0x80 + offset)])
        }
    }

    @Test("Belgian letters are in the tables that hold them")
    func belgianLetters() {
        #expect(ESCPOSCodePage.pc437.encode("é è ë ç").bytes == [0x82, 0x20, 0x8A, 0x20, 0x89, 0x20, 0x87])
        #expect(ESCPOSCodePage.pc850.encode("É").bytes == [0x90])
        #expect(ESCPOSCodePage.windows1252.encode("é").bytes == [0xE9])
    }

    @Test("The euro sign is a byte where the table has it and EUR where it does not")
    func euro() {
        #expect(ESCPOSCodePage.pc858.encode("€").bytes == [0xD5])
        #expect(ESCPOSCodePage.windows1252.encode("€").bytes == [0x80])
        let fallback = ESCPOSCodePage.pc437.encode("€ 6,40")
        #expect(fallback.bytes == Array("EUR 6,40".utf8))
        #expect(fallback.replacements == [.init(character: "€", replacement: "EUR")])
        #expect(fallback.cellCount == 8)
    }

    @Test("Letters a table lacks fall back to their base letter")
    func transliteration() {
        let encoded = ESCPOSCodePage.pc437.encode("Őrs Ã")
        #expect(encoded.bytes == Array("Ors A".utf8))
        #expect(encoded.replacements.count == 2)
    }

    @Test("Typographic punctuation becomes ASCII")
    func punctuation() {
        #expect(ESCPOSCodePage.pc437.encode("‘a’ “b” c–d…").bytes == Array("'a' \"b\" c-d...".utf8))
    }

    @Test("A decomposed accent prints the base letter and reports it")
    func decomposed() {
        let encoded = ESCPOSCodePage.pc437.encode("e\u{0301}")
        #expect(encoded.bytes == [0x65])
        #expect(encoded.replacements.count == 1)
    }

    @Test("Line breaks become LF, tabs a space, other controls a question mark")
    func controls() {
        #expect(ESCPOSCodePage.pc437.encode("a\nb\r\nc\td\u{07}").bytes == [0x61, 0x0A, 0x62, 0x0A, 0x63, 0x20, 0x64, 0x3F])
    }

    @Test("Characters no table can print become a question mark")
    func unprintable() {
        let encoded = ESCPOSCodePage.pc858.encode("🍟")
        #expect(encoded.bytes == [0x3F])
        #expect(encoded.replacements == [.init(character: "🍟", replacement: "?")])
    }

    @Test("Raw values are stable identifiers")
    func identifiers() {
        #expect(ESCPOSCodePage.allCases.map(\.rawValue) == ["pc437", "pc850", "pc858", "windows1252"])
    }
}
