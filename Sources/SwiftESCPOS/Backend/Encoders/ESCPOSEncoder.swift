//
//  ESCPOSEncoder.swift
//  swift-escpos
//
//  Created by Damian Van de Kauter on 25/10/2026.
//

/// Turns commands into the bytes one printer model understands.
///
/// The encoder is strict: a command the ``ESCPOSProfile`` does not list is refused, never sent in
/// the hope that it works. Deciding what to do instead — print without underline, leave the QR code
/// off — is the caller's job, using the profile's capabilities.
public struct ESCPOSEncoder: Sendable {
    public let profile: ESCPOSProfile

    public init(profile: ESCPOSProfile) {
        self.profile = profile
    }

    /// Encodes a job.
    ///
    /// Text is encoded in the code page in effect at that point: the profile's default, until a
    /// ``ESCPOSCommand/codePage(_:)`` switches it, and again after ``ESCPOSCommand/initialize``.
    public func encode(_ commands: [ESCPOSCommand]) throws(ESCPOSEncodingError) -> [UInt8] {
        var bytes: [UInt8] = []
        var codePage = profile.defaultCodePage
        for command in commands {
            try encode(command, codePage: &codePage, into: &bytes)
        }
        return bytes
    }

    // MARK: - Commands

    private func encode(
        _ command: ESCPOSCommand,
        codePage: inout ESCPOSCodePage,
        into bytes: inout [UInt8]
    ) throws(ESCPOSEncodingError) {
        switch command {
        case .initialize:
            bytes += [0x1B, 0x40]
            codePage = profile.defaultCodePage

        case .text(let text):
            bytes += codePage.encode(text).bytes

        case .lineFeed:
            bytes.append(0x0A)

        case .feed(let lines):
            bytes += [0x1B, 0x64, lines]

        case .bold(let isOn):
            bytes += [0x1B, 0x45, isOn ? 1 : 0]

        case .underline(let underline):
            if underline != .none { try require(.underline, for: command) }
            bytes += [0x1B, 0x2D, underline.rawValue]

        case .inverted(let isOn):
            if isOn { try require(.inverted, for: command) }
            bytes += [0x1D, 0x42, isOn ? 1 : 0]

        case .size(let size):
            let range = 1...profile.maximumMagnification
            guard range.contains(size.width), range.contains(size.height) else {
                throw .textSizeOutOfRange(size)
            }
            bytes += [0x1D, 0x21, (size.width - 1) << 4 | (size.height - 1)]

        case .alignment(let alignment):
            bytes += [0x1B, 0x61, alignment.rawValue]

        case .font(let font):
            if font == .b { try require(.fontB, for: command) }
            bytes += [0x1B, 0x4D, font.rawValue]

        case .codePage(let table):
            guard let number = profile.codePages[table] else { throw .unsupportedCodePage(table) }
            bytes += [0x1B, 0x74, number]
            codePage = table

        case .rasterImage(let image):
            try require(.rasterImages, for: command)
            try encodeRaster(image, into: &bytes)

        case .qrCode(let code):
            try require(.qrCodes, for: command)
            try encodeQRCode(code, into: &bytes)

        case .cut(let mode, let feedLines):
            try require(mode == .full ? .fullCut : .partialCut, for: command)
            if feedLines > 0 { bytes += [0x1B, 0x64, feedLines] }
            bytes += [0x1D, 0x56, mode.rawValue]

        case .raw(let raw):
            bytes += raw
        }
    }

    private func require(
        _ capability: ESCPOSCapabilities,
        for command: ESCPOSCommand
    ) throws(ESCPOSEncodingError) {
        guard profile.capabilities.contains(capability) else {
            throw .unsupported(command, missing: capability)
        }
    }

    // MARK: - Raster

    /// `GS v 0 m xL xH yL yH d…`, one command per band of at most `rasterBandHeight` rows.
    private func encodeRaster(_ image: ESCPOSRasterImage, into bytes: inout [UInt8]) throws(ESCPOSEncodingError) {
        let bytesPerRow = image.bytesPerRow
        guard bytesPerRow <= 0xFFFF else { throw .rasterImageTooWide(image.width) }
        let bandHeight = max(1, min(profile.rasterBandHeight, 0xFFFF))
        var row = 0
        while row < image.height {
            let rows = min(bandHeight, image.height - row)
            bytes += [0x1D, 0x76, 0x30, 0x00]
            bytes += Self.littleEndian(bytesPerRow)
            bytes += Self.littleEndian(rows)
            bytes += image.packedRows[(row * bytesPerRow)..<((row + rows) * bytesPerRow)]
            row += rows
        }
    }

    // MARK: - QR code

    /// Model 2: select the model, the module size and the error correction, store the data, print.
    private func encodeQRCode(_ code: ESCPOSQRCode, into bytes: inout [UInt8]) throws(ESCPOSEncodingError) {
        guard (1...ESCPOSQRCode.maximumPayloadSize).contains(code.payload.count) else {
            throw .qrPayloadSizeOutOfRange(code.payload.count)
        }
        guard (1...16).contains(code.moduleSize) else { throw .qrModuleSizeOutOfRange(code.moduleSize) }

        bytes += [0x1D, 0x28, 0x6B, 0x04, 0x00, 0x31, 0x41, 0x32, 0x00]
        bytes += [0x1D, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x43, code.moduleSize]
        bytes += [0x1D, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x45, code.errorCorrection.rawValue]
        bytes += [0x1D, 0x28, 0x6B] + Self.littleEndian(code.payload.count + 3) + [0x31, 0x50, 0x30]
        bytes += code.payload
        bytes += [0x1D, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x51, 0x30]
    }

    private static func littleEndian(_ value: Int) -> [UInt8] {
        [UInt8(value & 0xFF), UInt8((value >> 8) & 0xFF)]
    }
}
