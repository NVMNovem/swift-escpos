//
//  ESCPOSCodePage.swift
//  swift-escpos
//
//  Created by Damian Van de Kauter on 25/10/2026.
//

/// A single-byte character table a printer can be switched to (`ESC t n`).
///
/// The lower half (0x20–0x7E) is ASCII in every table here. The upper half differs, and so does the
/// `n` that selects a table: that number is the printer's, so it lives in ``ESCPOSProfile``, never
/// here. The raw value is a stable identifier and may be persisted.
public enum ESCPOSCodePage: String, Sendable, Hashable, CaseIterable, Codable {
    /// IBM PC USA. What most printers select after `ESC @`. Has accented letters, no euro sign.
    case pc437
    /// IBM PC Multilingual Latin I. Western European letters, no euro sign.
    case pc850
    /// PC850 with the euro sign at 0xD5 in place of the dotless i.
    case pc858
    /// Windows Latin 1. The euro sign at 0x80; five bytes are undefined.
    case windows1252

    /// Encodes text for this table, one `Character` at a time.
    ///
    /// - A character the table holds becomes its byte.
    /// - A character it does not hold is transliterated (`€` → `EUR`, `ő` → `o`) and, failing that,
    ///   replaced by `?`. Every replacement is reported, so a caller can measure and warn.
    /// - A line break (`\n` or `\r\n`) becomes `LF`; a tab becomes a space.
    /// - Every other control character becomes `?`. Text can therefore never smuggle a command
    ///   into the byte stream, whoever wrote it.
    /// - A letter followed by combining accents is printed as its base letter when the table has no
    ///   precomposed form for the scalar as given; the accent is reported as a replacement.
    public func encode(_ text: String) -> ESCPOSEncodedText {
        var bytes: [UInt8] = []
        var replacements: [ESCPOSEncodedText.Replacement] = []
        bytes.reserveCapacity(text.utf8.count)
        for character in text {
            encode(character, into: &bytes, replacements: &replacements)
        }
        return ESCPOSEncodedText(bytes: bytes, replacements: replacements)
    }

    /// Whether the table holds this scalar as a single byte.
    public func contains(_ scalar: Unicode.Scalar) -> Bool {
        byte(for: scalar) != nil
    }

    // MARK: - Encoding

    private func encode(
        _ character: Character,
        into bytes: inout [UInt8],
        replacements: inout [ESCPOSEncodedText.Replacement]
    ) {
        if character == "\n" || character == "\r\n" {
            bytes.append(0x0A)
            return
        }
        let scalars = Array(character.unicodeScalars)
        guard let first = scalars.first else { return }
        let rest = scalars.dropFirst()

        if rest.isEmpty, let byte = byte(for: first) {
            bytes.append(byte)
            return
        }
        if rest.isEmpty, first == "\t" {
            bytes.append(0x20)
            return
        }
        if rest.allSatisfy(Self.isCombiningMark), let byte = byte(for: first) {
            bytes.append(byte)
            replacements.append(.init(character: character, replacement: String(first)))
            return
        }
        if rest.allSatisfy(Self.isCombiningMark),
           let transliteration = ESCPOSTransliteration.replacement(for: first),
           let encoded = encodeASCII(transliteration) {
            bytes.append(contentsOf: encoded)
            replacements.append(.init(character: character, replacement: transliteration))
            return
        }
        bytes.append(0x3F)
        replacements.append(.init(character: character, replacement: "?"))
    }

    private func encodeASCII(_ text: String) -> [UInt8]? {
        var result: [UInt8] = []
        for scalar in text.unicodeScalars {
            guard let byte = byte(for: scalar) else { return nil }
            result.append(byte)
        }
        return result
    }

    private func byte(for scalar: Unicode.Scalar) -> UInt8? {
        switch scalar.value {
        case 0x20...0x7E:
            return UInt8(scalar.value)
        case 0x00...0x1F, 0x7F:
            return nil
        default:
            return encodingTable[scalar.value]
        }
    }

    private static func isCombiningMark(_ scalar: Unicode.Scalar) -> Bool {
        (0x0300...0x036F).contains(scalar.value)
    }

    // MARK: - Tables

    /// The upper half as Unicode scalars, in byte order from 0x80.
    var upperHalf: [UInt32?] {
        switch self {
        case .pc437: Self.pc437UpperHalf
        case .pc850: Self.pc850UpperHalf
        case .pc858: Self.pc858UpperHalf
        case .windows1252: Self.windows1252UpperHalf
        }
    }

    private var encodingTable: [UInt32: UInt8] {
        switch self {
        case .pc437: Self.pc437Encoding
        case .pc850: Self.pc850Encoding
        case .pc858: Self.pc858Encoding
        case .windows1252: Self.windows1252Encoding
        }
    }

    private static let pc437Encoding = makeEncoding(pc437UpperHalf)
    private static let pc850Encoding = makeEncoding(pc850UpperHalf)
    private static let pc858Encoding = makeEncoding(pc858UpperHalf)
    private static let windows1252Encoding = makeEncoding(windows1252UpperHalf)

    private static func makeEncoding(_ upperHalf: [UInt32?]) -> [UInt32: UInt8] {
        var table: [UInt32: UInt8] = [:]
        for (offset, scalar) in upperHalf.enumerated() {
            guard let scalar, table[scalar] == nil else { continue }
            table[scalar] = UInt8(0x80 + offset)
        }
        return table
    }
}
