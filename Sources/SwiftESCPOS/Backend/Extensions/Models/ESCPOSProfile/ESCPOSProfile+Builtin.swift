//
//  ESCPOSProfile+Builtin.swift
//  swift-escpos
//
//  Created by Damian Van de Kauter on 25/10/2026.
//

extension ESCPOSProfile {
    /// Every built-in profile, for looking one up by its persisted ``id``.
    public static let builtin: [ESCPOSProfile] = [.generic, .epsonTM, .duraposDPT201]

    /// The built-in profile with this identifier.
    public static func builtin(id: String) -> ESCPOSProfile? {
        builtin.first { $0.id == id }
    }

    /// A deliberately conservative subset for an unknown ESC/POS printer.
    ///
    /// Text, bold, alignment, magnification, feeds and cuts, in the table the printer starts in
    /// (PC437, so `€` prints as `EUR`). No code-page switching, status, raster or QR: their numbering
    /// and support vary too much between vendors to assume.
    public static let generic = ESCPOSProfile(
        id: "generic-escpos",
        name: "Generic ESC/POS",
        capabilities: [.fullCut, .partialCut],
        printableDots: [.millimeters58: 384, .millimeters80: 576],
        cellWidths: [.a: 12],
        codePages: [.pc437: 0],
        defaultCodePage: .pc437
    )

    /// Epson TM-series receipt printers on 80 mm paper (TM-m30III, TM-T20III and similar).
    ///
    /// Built from Epson's ESC/POS reference, not yet from a hardware test in this project.
    public static let epsonTM = ESCPOSProfile(
        id: "epson-tm",
        name: "Epson TM series",
        capabilities: [
            .underline, .inverted, .fontB, .fullCut, .partialCut,
            .realtimeStatus, .rasterImages, .qrCodes,
        ],
        printableDots: [.millimeters80: 576],
        cellWidths: [.a: 12, .b: 9],
        codePages: [.pc437: 0, .pc850: 2, .windows1252: 16, .pc858: 19],
        defaultCodePage: .pc437
    )

    /// DURAPOS DPT201-URE-BK, the first printer this library is validated against.
    ///
    /// **Unvalidated.** Until the hardware tests have run it claims exactly what ``generic`` claims,
    /// on both paper widths. The code page holding `€`, raster images, QR codes and status are added
    /// only once tested on the printer.
    public static let duraposDPT201 = ESCPOSProfile(
        id: "durapos-dpt201",
        name: "DURAPOS DPT201",
        capabilities: [.fullCut, .partialCut],
        printableDots: [.millimeters58: 384, .millimeters80: 576],
        cellWidths: [.a: 12],
        codePages: [.pc437: 0],
        defaultCodePage: .pc437
    )
}
