//
//  ESCPOSEncodedText.swift
//  swift-escpos
//
//  Created by Damian Van de Kauter on 25/10/2026.
//

/// Text encoded for one code page, with every character that could not be printed as written.
public struct ESCPOSEncodedText: Sendable, Hashable {
    /// A character printed as something else.
    public struct Replacement: Sendable, Hashable {
        public let character: Character
        public let replacement: String
    }

    public let bytes: [UInt8]
    public let replacements: [Replacement]

    /// How many character cells the text occupies at normal size, line breaks excluded.
    ///
    /// Every printable byte of a single-byte code page is one cell, so `€` printed as `EUR`
    /// takes three.
    public var cellCount: Int {
        bytes.lazy.filter { $0 != 0x0A }.count
    }
}
