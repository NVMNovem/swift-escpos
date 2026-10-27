# Architecture

`swift-escpos` is a protocol library: it turns ESC/POS commands into bytes and, optionally, delivers those bytes over TCP. This note records how the package is split, why, and where it stands relative to `swift-zpl` and the planned SwiftPrint.

## Two modules

```
swift-escpos
├── SwiftESCPOS          pure: commands → bytes, status bytes → status. No dependencies, no I/O.
└── SwiftESCPOSNetwork   TCP send and status queries on SwiftNIO. Depends on SwiftESCPOS.
```

The dependency runs one way only. `SwiftESCPOS` never imports SwiftNIO or `SwiftESCPOSNetwork`.

The split exists because most of the package's value does not need a network stack. An app may print over Bluetooth or USB through a platform API, hand bytes to another process, or only build jobs in tests. Until this split, all of these linked SwiftNIO. Separate modules also keep the encoder deterministic and easy to test: nothing in it can block, time out or depend on a socket.

| `SwiftESCPOS` | `SwiftESCPOSNetwork` |
|---|---|
| `ESCPOSCommand`, `ESCPOSEncoder` | `ESCPOSConnection` (+ `Timeouts`) |
| `ESCPOSProfile` (+ `builtin`), `ESCPOSCapabilities` | `ESCPOSTransmission` |
| `ESCPOSCodePage`, `ESCPOSEncodedText`, `ESCPOSTransliteration` | `ESCPOSConnectionError` (`Delivery`, `Phase`, `Reason`) |
| `ESCPOSAlignment`, `ESCPOSFont`, `ESCPOSTextSize`, `ESCPOSUnderline`, `ESCPOSCutMode`, `ESCPOSPaperWidth` | `ESCPOSStatusCollector` (internal NIO handler) |
| `ESCPOSRasterImage`, `ESCPOSQRCode` | `TimeAmount(Duration)` (internal) |
| `ESCPOSStatusRequest`, `ESCPOSPrinterStatus` and its parsing | |
| `ESCPOSEncodingError`, `ESCPOSStatusError` | |

Status follows the same line. Which bytes ask for status (`ESCPOSStatusRequest.bytes`) and what the answers mean (`ESCPOSPrinterStatus(answers:for:)`) are protocol facts and live in the core. Collecting answers from a socket, with a deadline, is transport and lives in the network module. Another transport can reuse the parsing unchanged.

## SwiftNIO

SwiftNIO is a regular package dependency, used by `SwiftESCPOSNetwork` and its tests only. A target that depends on `SwiftESCPOS` alone neither builds nor links it. SwiftPM still resolves swift-nio for every client, because package-level dependencies are resolved as a whole. swift-zpl works the same way.

A `Network` package trait was tried and removed. A trait can keep swift-nio out of resolution, but it cannot make a product or target conditional. `SwiftESCPOSNetwork` then had to exist as an empty module without the trait, every network file needed `#if Network`, and consumers had to configure the trait in addition to adding the product. One combination failed to resolve on the Swift 6.4 toolchain: an application that declared the package without the trait, next to a dependency that declared it with the trait. Separate modules already give the separation that matters, so the trait was not worth that complexity.

## Comparison with swift-zpl

`swift-zpl` was built using the earlier single-module `swift-escpos` as its reference, and already split core and network. This refactor brings `swift-escpos` back in line:

| | swift-escpos | swift-zpl |
|---|---|---|
| Core module | `SwiftESCPOS`, no dependencies | `SwiftZPL`, no dependencies |
| Network module | `SwiftESCPOSNetwork` | `SwiftZPLNetwork` |
| SwiftNIO | Resolved for every client; built only for the network module | Same |
| Connection model | One connection per call, `Delivery.notSent / .partiallySent` | Same |
| Cancellation | `wasCancelled` flag, cancellable connect | `wasCancelled` flag; connect waits for its timeout |
| Test targets | `SwiftESCPOSTests`, `SwiftESCPOSNetworkTests` (virtual printer) | `SwiftZPLTests`, `SwiftZPLNetworkTests` (virtual printer) |

The connection code is still duplicated between the two packages. Extracting a shared transport library is deliberately out of scope.

### Cancellation fix

The `swift-zpl` architecture note identified a problem in `ESCPOSConnection`: when a task was cancelled during a write, the cancellation handler closed the channel, the pending write then failed with a closed-channel error, and the call was reported as `.disconnected(.writing)` instead of `.cancelled(.writing)`. Status reads had the same problem.

`ESCPOSConnection` now does what `ZPLConnection` does: each cancellation handler sets `Progress.wasCancelled` before closing the channel, and classification checks that flag before timeouts or disconnects. Delivery is unaffected by the reason. A job cancelled after writing started is still `.partiallySent(confirmedBytes:)`.

Two further changes go beyond `ZPLConnection`:

- **Connecting is cancellable.** The channel being connected is recorded by the bootstrap's channel initializer, and cancellation closes it, which fails the pending connect at once. Previously a cancelled call waited for the connect to succeed or time out. If cancellation arrives before a channel exists, the initializer sees the flag and refuses the channel.
- **Cancellation right after connecting** is checked before the write phase starts, so it is reported as `.cancelled(.connecting)` with nothing sent, not as a write-phase failure.

Regression tests cover cancellation while connecting, during a stalled write and while waiting for status. All three fail against the previous implementation.

## Why ESC/POS keeps its own shape

ESC/POS is a sequential command stream: modes are switched on and off, text flows line by line, and the printer has no notion of a document. `swift-escpos` models exactly that, as an array of `ESCPOSCommand` values encoded in order. `swift-zpl` has `ZPLLabel` because ZPL formats are framed (`^XA … ^XZ`) and positioned in dots. ESC/POS has no equivalent, and forcing one on it would hide its real behavior: code page state, character columns, cutter feed.

So the refactor does not change command semantics, encoding, profiles, code pages, transliteration, raster or QR encoding, column calculations, cutting or status parsing. It only moves the transport.

## SwiftPrint

SwiftPrint is a planned, separate package for declarative receipts and labels. It does not exist as a dependency of this package, and `swift-escpos` must stay usable without it.

```
Application
    |
    +-- SwiftPrint (optional)
    |       |
    |       +-- SwiftESCPOS
    |
    +-- SwiftESCPOS (direct usage)
    |
    +-- SwiftESCPOSNetwork (optional)
            |
            +-- SwiftESCPOS
            +-- SwiftNIO
```

SwiftPrint would own the document model, layout components (`Text`, `VStack`, `HStack`, …), measurement and layout. An ESC/POS adapter would resolve a layout into `[ESCPOSCommand]` for a chosen `ESCPOSProfile`, using what this package already exposes: `profile.columns(on:font:size:)` for line widths, `ESCPOSCodePage.encode(_:)` for measuring text in cells, and `ESCPOSCapabilities` for what a printer can do. Delivery would go through `SwiftESCPOSNetwork` or any other transport.

None of that belongs here. `swift-escpos` contains no document model, layout engine or result builder.
