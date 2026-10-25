//
//  ESCPOSTransliteration.swift
//  swift-escpos
//
//  Created by Damian Van de Kauter on 25/10/2026.
//

/// Plain-ASCII stand-ins for characters a code page cannot hold.
///
/// The table is generated (`Scripts/generate-code-pages.py`): accented Latin letters fall back to
/// their base letter, and a short list covers the euro sign, typographic quotes and dashes.
enum ESCPOSTransliteration {
    static func replacement(for scalar: Unicode.Scalar) -> String? {
        table[scalar.value]
    }
}
