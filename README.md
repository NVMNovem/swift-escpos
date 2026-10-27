# swift-escpos

A type-safe Swift library for ESC/POS receipt printers. You describe a job as an array of commands, the encoder turns it into deterministic bytes for one printer profile, and an optional TCP transport delivers them and asks the printer for its status.

`swift-escpos` stands alone. It does not depend on SwiftPrint, `swift-zpl` or any application. See [Architecture](Docs/Architecture.md) for how the package is split and why.

## Requirements

- Swift 6.2 tools or later, Swift 6 language mode (strict concurrency).
- iOS 17, macOS 14, tvOS 17, watchOS 10, visionOS 1, and Linux.
- `SwiftESCPOS` has no dependencies. `SwiftESCPOSNetwork` uses SwiftNIO.

## Installation

```swift
dependencies: [
    .package(url: "https://github.com/NVMNovem/swift-escpos.git", from: "0.1.0"),
],
targets: [
    .target(name: "App", dependencies: [
        .product(name: "SwiftESCPOS", package: "swift-escpos"),         // encoding
        .product(name: "SwiftESCPOSNetwork", package: "swift-escpos"),  // optional: TCP printing and status
    ]),
]
```

| Module | Import when you | Contains | Dependencies |
|---|---|---|---|
| `SwiftESCPOS` | build print jobs or parse status bytes | Commands, encoder, profiles, capabilities, code pages, raster images, QR codes, `ESCPOSPrinterStatus` | none |
| `SwiftESCPOSNetwork` | send jobs or query status over TCP | `ESCPOSConnection`, `ESCPOSTransmission`, `ESCPOSConnectionError` | SwiftNIO |

A target that depends only on `SwiftESCPOS` does not build or link SwiftNIO. SwiftPM still resolves swift-nio for every client of the package, because it is declared at package level.

Version numbers above are illustrative; use the release you need.

## Encoding

```swift
import SwiftESCPOS

let commands: [ESCPOSCommand] = [
    .initialize,
    .alignment(.center),
    .bold(true),
    .text("FrietHeus\n"),
    .bold(false),
    .alignment(.leading),
    .text("1 × Grote friet   € 4,20\n"),
    .qrCode(ESCPOSQRCode("https://example.com/order/1234")),
    .cut(.partial, feedLines: 3),
]

let bytes = try ESCPOSEncoder(profile: .epsonTM).encode(commands)
```

The encoder is deterministic and strict: the same commands and profile always give the same bytes, and a command the profile does not list among its `ESCPOSCapabilities` throws `ESCPOSEncodingError.unsupported` instead of reaching the printer.

- **Profiles.** `ESCPOSProfile.builtin` holds `.generic`, `.epsonTM` and `.duraposDPT201`. Their `id`s are stable and safe to persist; look one up again with `ESCPOSProfile.builtin(id:)`.
- **Columns.** `profile.columns(on: .millimeters80, font: .a, size: .normal)` gives the characters per line for a paper width, font and magnification.
- **Text.** Text is encoded in the code page in effect (`.codePage(_:)`, reset by `.initialize`). Characters the table lacks are transliterated (`€` → `EUR`) or replaced by `?`, and `ESCPOSCodePage.encode(_:)` reports every replacement. Control characters can never pass through as commands.
- **Images and QR codes.** `ESCPOSRasterImage` is sent as `GS v 0` in bands; `ESCPOSQRCode` as model 2 `GS ( k`.
- **Escape hatch.** `.raw([UInt8])` sends bytes unchecked.

## TCP printing

```swift
import SwiftESCPOS
import SwiftESCPOSNetwork

let printer = ESCPOSConnection.tcp(host: "192.168.1.100", port: 9100)
let bytes = try ESCPOSEncoder(profile: .epsonTM).encode(commands)

do {
    let transmission = try await printer.send(bytes)
    print("Handed over \(transmission.bytesSent) bytes in \(transmission.duration)")
} catch {
    switch error.delivery {
    case .notSent:
        break   // safe to retry: nothing reached the printer
    case .partiallySent(let confirmedBytes):
        break   // may already have printed: check before retrying
    }
}
```

- Each call opens one connection, does its work and closes it again, also after failures and cancellation.
- `Timeouts` sets separate limits for connecting, for each written chunk, and for reading status. A printer that stops reading (out of paper, full buffer) stalls a write instead of failing it; the write timeout is what notices.
- Cancelling the task cancels the call in whatever step it is in — connecting, writing or reading status — and reports `.cancelled(phase)`. Delivery accounting stays exact: a job cancelled mid-write is `.partiallySent`, never `.notSent`.
- Calls are not serialised. Preventing two simultaneous jobs to one printer is up to the caller.

**Sent is not printed.** `ESCPOSTransmission` means every byte was accepted by the operating system and the connection closed cleanly. It does not mean paper came out.

### Printer status

For profiles that list `.realtimeStatus`:

```swift
let status = try await printer.status()   // DLE EOT 1…4
if status.isReady == false { /* offline, cover open, paper out, error … */ }
if status.isPaperNearEnd == true { /* warn */ }
```

Every field is optional: `nil` means the printer was not asked or did not say. A printer that does not answer fails with `.timedOut(.readingStatus)`. Parsing lives in the core module, so `ESCPOSPrinterStatus(answers:for:)` also works on bytes obtained over another transport.

## Migrating from earlier versions

Earlier versions had a single `SwiftESCPOS` module that always depended on SwiftNIO. Encoding code needs no change. Code that sends or queries printers does:

1. Add the `SwiftESCPOSNetwork` product to the target.
2. Add `import SwiftESCPOSNetwork` next to `import SwiftESCPOS`.

`ESCPOSConnection`, `ESCPOSTransmission` and `ESCPOSConnectionError` keep their names and API; only their module changed. There is no re-export or alias for the old location: keeping one would have meant keeping SwiftNIO in the core module.

Cancellation is now reported as `.cancelled(phase)` where it was previously sometimes reported as `.disconnected(.writing)` or `.disconnected(.readingStatus)`, and cancelling while connecting now returns at once instead of after the connect timeout.

## Optional: SwiftPrint

`swift-escpos` is a standalone, low-level ESC/POS library. It can generate printer commands and communicate with compatible printers without requiring any additional printing framework.

For applications that need a higher-level, declarative API, SwiftPrint is intended to provide a unified way to build and print documents using SwiftUI-inspired components.

With SwiftPrint, applications will be able to describe receipts and labels using elements such as `Text`, `VStack`, `HStack`, `Divider` and `Barcode`, while dedicated layout engines handle positioning and formatting.

SwiftPrint is designed to support multiple printer protocols through optional adapters, including ESC/POS and ZPL.

SwiftPrint is entirely optional. Use `swift-escpos` directly when you need precise control over ESC/POS commands or want to avoid a higher-level abstraction.

SwiftPrint integration is planned. Its API and availability may change as development progresses.
