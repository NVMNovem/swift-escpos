//
//  ESCPOSProfileTests.swift
//  swift-escpos
//
//  Created by Damian Van de Kauter on 25/10/2026.
//

import Testing
@testable import SwiftESCPOS

@Suite("Profiles")
struct ESCPOSProfileTests {
    @Test("Built-in identifiers are stable, because they are persisted")
    func identifiers() {
        #expect(ESCPOSProfile.builtin.map(\.id) == ["generic-escpos", "epson-tm", "durapos-dpt201"])
        #expect(ESCPOSProfile.builtin(id: "durapos-dpt201") == .duraposDPT201)
        #expect(ESCPOSProfile.builtin(id: "unknown") == nil)
    }

    @Test("Columns follow the paper, the font and the magnification")
    func columns() {
        #expect(ESCPOSProfile.epsonTM.columns(on: .millimeters80) == 48)
        #expect(ESCPOSProfile.epsonTM.columns(on: .millimeters80, font: .b) == 64)
        #expect(ESCPOSProfile.epsonTM.columns(on: .millimeters80, size: .double) == 24)
        #expect(ESCPOSProfile.generic.columns(on: .millimeters58) == 32)
        #expect(ESCPOSProfile.epsonTM.columns(on: .millimeters58) == nil)
        #expect(ESCPOSProfile.generic.columns(on: .millimeters80, font: .b) == nil)
    }

    @Test("The DPT201 claims nothing beyond the generic subset until it is validated")
    func dpt201IsConservative() {
        #expect(ESCPOSProfile.duraposDPT201.capabilities == ESCPOSProfile.generic.capabilities)
        #expect(ESCPOSProfile.duraposDPT201.codePages == ESCPOSProfile.generic.codePages)
        #expect(ESCPOSProfile.duraposDPT201.supports(.millimeters58))
        #expect(ESCPOSProfile.duraposDPT201.supports(.millimeters80))
    }
}
