//
//  ESCPOSCommand.swift
//  swift-escpos
//
//  Created by Damian Van de Kauter on 25/10/2026.
//

/// One ESC/POS instruction, as a value.
///
/// A job is an array of commands handed to ``ESCPOSEncoder``, which checks each against the
/// printer's ``ESCPOSProfile`` and produces the bytes.
public enum ESCPOSCommand: Sendable, Hashable {
    /// `ESC @` — clears the buffer and every mode, and selects the profile's default code page.
    case initialize
    /// Text in the active code page. Line breaks become `LF`; no other control character passes.
    case text(String)
    /// `LF` — prints the buffer and advances one line.
    case lineFeed
    /// `ESC d n` — prints the buffer and advances `lines` lines.
    case feed(lines: UInt8)
    /// `ESC E n`
    case bold(Bool)
    /// `ESC - n` — needs ``ESCPOSCapabilities/underline``.
    case underline(ESCPOSUnderline)
    /// `GS B n` — white on black; needs ``ESCPOSCapabilities/inverted``.
    case inverted(Bool)
    /// `GS ! n`
    case size(ESCPOSTextSize)
    /// `ESC a n`
    case alignment(ESCPOSAlignment)
    /// `ESC M n` — Font B needs ``ESCPOSCapabilities/fontB``.
    case font(ESCPOSFont)
    /// `ESC t n` with the profile's number for the table.
    case codePage(ESCPOSCodePage)
    /// `GS v 0`, split into bands; needs ``ESCPOSCapabilities/rasterImages``.
    case rasterImage(ESCPOSRasterImage)
    /// `GS ( k`, model 2; needs ``ESCPOSCapabilities/qrCodes``.
    case qrCode(ESCPOSQRCode)
    /// `ESC d n` followed by `GS V m`: feeds the last line past the cutter, then cuts.
    case cut(ESCPOSCutMode, feedLines: UInt8 = 0)
    /// Bytes sent exactly as given, for anything this library does not model.
    case raw([UInt8])
}
