//
//  ESCPOSProfile.swift
//  swift-escpos
//
//  Created by Damian Van de Kauter on 25/10/2026.
//

/// What one printer model understands and how it measures.
///
/// A profile is data. The encoder refuses a command whose capability the profile does not list,
/// and a renderer reads the widths to lay text out. A profile is only as true as the hardware tests
/// behind it: ESC/POS is a vendor convention, not a standard, and no profile here claims more than
/// it says.
public struct ESCPOSProfile: Sendable, Hashable, Identifiable {
    /// A stable identifier, such as `durapos-dpt201`. It may be persisted; never rename one.
    public let id: String
    public let name: String
    public let capabilities: ESCPOSCapabilities
    /// Printable dots per line for each paper width the model takes.
    public let printableDots: [ESCPOSPaperWidth: Int]
    /// Dots per character cell, per font, at normal size.
    public let cellWidths: [ESCPOSFont: Int]
    /// The `n` of `ESC t n` for each table the model holds.
    public let codePages: [ESCPOSCodePage: UInt8]
    /// The table in effect after power-on and `ESC @`.
    public let defaultCodePage: ESCPOSCodePage
    /// The largest `GS !` factor, 1…8.
    public let maximumMagnification: UInt8
    /// The most rows sent in one `GS v 0` command; taller images are split into bands.
    public let rasterBandHeight: Int

    public init(
        id: String,
        name: String,
        capabilities: ESCPOSCapabilities,
        printableDots: [ESCPOSPaperWidth: Int],
        cellWidths: [ESCPOSFont: Int],
        codePages: [ESCPOSCodePage: UInt8],
        defaultCodePage: ESCPOSCodePage,
        maximumMagnification: UInt8 = 8,
        rasterBandHeight: Int = 255
    ) {
        self.id = id
        self.name = name
        self.capabilities = capabilities
        self.printableDots = printableDots
        self.cellWidths = cellWidths
        self.codePages = codePages
        self.defaultCodePage = defaultCodePage
        self.maximumMagnification = maximumMagnification
        self.rasterBandHeight = rasterBandHeight
    }

    /// Whether the model takes this paper width.
    public func supports(_ paperWidth: ESCPOSPaperWidth) -> Bool {
        printableDots[paperWidth] != nil
    }

    /// Whether the model holds this code page.
    public func supports(_ codePage: ESCPOSCodePage) -> Bool {
        codePages[codePage] != nil
    }

    /// Character cells per line, or `nil` when the model lacks the paper width or the font.
    public func columns(
        on paperWidth: ESCPOSPaperWidth,
        font: ESCPOSFont = .a,
        size: ESCPOSTextSize = .normal
    ) -> Int? {
        guard let dots = printableDots[paperWidth], let cell = cellWidths[font], size.width > 0 else {
            return nil
        }
        return dots / (cell * Int(size.width))
    }
}
