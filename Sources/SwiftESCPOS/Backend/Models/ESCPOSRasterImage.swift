//
//  ESCPOSRasterImage.swift
//  swift-escpos
//
//  Created by Damian Van de Kauter on 25/10/2026.
//

/// A 1-bit image in the printer's raster format: rows of packed bits, most significant bit first,
/// a set bit is a printed dot.
///
/// Scaling and dithering belong to whoever produced the pixels; this is what goes on the wire.
public struct ESCPOSRasterImage: Sendable, Hashable {
    public let width: Int
    public let height: Int
    public let packedRows: [UInt8]

    /// Bytes per row: the width rounded up to whole bytes.
    public var bytesPerRow: Int {
        (width + 7) / 8
    }

    /// Wraps rows that are already packed. Answers `nil` when the byte count does not match.
    public init?(width: Int, height: Int, packedRows: [UInt8]) {
        guard width > 0, height > 0, packedRows.count == (width + 7) / 8 * height else { return nil }
        self.width = width
        self.height = height
        self.packedRows = packedRows
    }

    /// Packs an image from a function answering whether a dot is printed.
    public init(width: Int, height: Int, isDot: (_ x: Int, _ y: Int) -> Bool) {
        precondition(width > 0 && height > 0, "A raster image needs at least one dot.")
        let bytesPerRow = (width + 7) / 8
        var packed = [UInt8](repeating: 0, count: bytesPerRow * height)
        for y in 0..<height {
            for x in 0..<width where isDot(x, y) {
                packed[y * bytesPerRow + x / 8] |= 0x80 >> UInt8(x % 8)
            }
        }
        self.width = width
        self.height = height
        self.packedRows = packed
    }
}
