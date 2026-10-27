//
//  ESCPOSConnectionTests.swift
//  swift-escpos
//
//  Created by Damian Van de Kauter on 25/10/2026.
//

#if Network
@testable import SwiftESCPOS
import Testing
@testable import SwiftESCPOSNetwork

/// Against ``VirtualPrinter`` on 127.0.0.1. What these prove is the delivery accounting — whether a
/// failure may already have printed something — and that every connection is closed afterwards.
@Suite("TCP connection")
struct ESCPOSConnectionTests {
    private func connection(
        port: Int,
        write: Duration = .seconds(5),
        statusRead: Duration = .seconds(2),
        chunkSize: Int = 4096
    ) -> ESCPOSConnection {
        .tcp(
            host: "127.0.0.1",
            port: port,
            timeouts: .init(connect: .seconds(2), write: write, statusRead: statusRead),
            chunkSize: chunkSize
        )
    }

    // MARK: - Sending

    @Test("A job arrives byte for byte, and the connection is closed")
    func sendsEverything() async throws {
        let printer = try await VirtualPrinter.start(.accept)
        defer { Task { await printer.stop() } }
        let job = try ESCPOSEncoder(profile: .generic).encode([
            .initialize, .text("Ordessa\n"), .cut(.partial, feedLines: 3),
        ])

        let transmission = try await connection(port: printer.port, chunkSize: 4).send(job)

        #expect(transmission.bytesSent == job.count)
        #expect(await printer.received(atLeast: job.count) == job)
        #expect(await printer.allConnectionsClosed())
    }

    @Test("A refused connection sent nothing")
    func refused() async throws {
        let port = try await VirtualPrinter.closedPort()
        do {
            _ = try await connection(port: port).send([0x1B, 0x40])
            Issue.record("Expected the connection to be refused")
        } catch {
            #expect(error == ESCPOSConnectionError(delivery: .notSent, reason: .connectionRefused))
        }
    }

    @Test("A printer that closes mid-job leaves a partial delivery, and the connection is closed")
    func resetMidJob() async throws {
        let printer = try await VirtualPrinter.start(.resetAfter(bytes: 1024))
        defer { Task { await printer.stop() } }
        let job = [UInt8](repeating: 0x41, count: 16 * 1024 * 1024)
        do {
            _ = try await connection(port: printer.port, chunkSize: 64 * 1024).send(job)
            Issue.record("Expected the reset to fail the job")
        } catch {
            guard case .partiallySent(let confirmed) = error.delivery else {
                Issue.record("Expected a partial delivery, got \(error.delivery)")
                return
            }
            #expect(confirmed < job.count)
            #expect(error.reason == .disconnected(.writing))
        }
        #expect(await printer.allConnectionsClosed())
    }

    @Test("A printer that stops reading times the write out, partially delivered")
    func stalledPrinter() async throws {
        let printer = try await VirtualPrinter.start(.neverRead)
        defer { Task { await printer.stop() } }
        let job = [UInt8](repeating: 0x41, count: 32 * 1024 * 1024)
        do {
            _ = try await connection(port: printer.port, write: .milliseconds(500), chunkSize: 64 * 1024).send(job)
            Issue.record("Expected the write to time out")
        } catch {
            guard case .partiallySent = error.delivery else {
                Issue.record("Expected a partial delivery, got \(error.delivery)")
                return
            }
            #expect(error.reason == .timedOut(.writing))
        }
    }

    @Test("Cancelling before connecting sends nothing")
    func cancelledBeforeSending() async throws {
        let printer = try await VirtualPrinter.start(.accept)
        defer { Task { await printer.stop() } }
        let connection = connection(port: printer.port)
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await connection.send([0x1B, 0x40])
        }
        do {
            _ = try await task.value
            Issue.record("Expected cancellation")
        } catch let error as ESCPOSConnectionError {
            #expect(error == ESCPOSConnectionError(delivery: .notSent, reason: .cancelled(.connecting)))
        } catch {
            Issue.record("Unexpected error \(error)")
        }
        #expect(printer.received.isEmpty)
    }

    @Test("Cancelling while connecting gives up at once and sends nothing")
    func cancelledWhileConnecting() async throws {
        // TEST-NET-1 is never routed, so the connect hangs until its timeout — unless this machine
        // has no route at all and fails straight away, which leaves nothing to cancel.
        let connection = ESCPOSConnection.tcp(host: "192.0.2.1", timeouts: .init(connect: .seconds(30)))
        let clock = ContinuousClock()
        let task = Task { try await connection.send([0x1B, 0x40]) }
        try await Task.sleep(for: .milliseconds(300))
        let cancelledAt = clock.now
        task.cancel()
        do {
            _ = try await task.value
            Issue.record("Expected cancellation")
        } catch let error as ESCPOSConnectionError {
            if error.reason != .cancelled(.connecting), case .connectionFailed = error.reason { return }
            #expect(error == ESCPOSConnectionError(delivery: .notSent, reason: .cancelled(.connecting)))
            #expect(clock.now - cancelledAt < .seconds(2))
        } catch {
            Issue.record("Unexpected error \(error)")
        }
    }

    /// The cancellation handler closes the channel, so the pending write fails with a closed-channel
    /// error rather than `CancellationError`. That must still read as cancelled, not disconnected.
    @Test("Cancelling a stalled write fails it as cancelled, partially delivered")
    func cancelledWhileWriting() async throws {
        let printer = try await VirtualPrinter.start(.neverRead)
        defer { Task { await printer.stop() } }
        let connection = connection(port: printer.port, write: .seconds(30), chunkSize: 64 * 1024)
        let job = [UInt8](repeating: 0x41, count: 32 * 1024 * 1024)
        let task = Task { try await connection.send(job) }
        try await Task.sleep(for: .milliseconds(300))
        task.cancel()
        do {
            _ = try await task.value
            Issue.record("Expected cancellation")
        } catch let error as ESCPOSConnectionError {
            guard case .partiallySent(let confirmed) = error.delivery else {
                Issue.record("Expected a partial delivery, got \(error.delivery)")
                return
            }
            #expect(confirmed < job.count)
            #expect(error.reason == .cancelled(.writing))
        } catch {
            Issue.record("Unexpected error \(error)")
        }
    }

    // MARK: - Status

    @Test("Status answers are read and parsed, and the connection is closed")
    func status() async throws {
        let printer = try await VirtualPrinter.start(.answerStatus([1: 0x12, 2: 0x16, 3: 0x12, 4: 0x1E]))
        defer { Task { await printer.stop() } }

        let status = try await connection(port: printer.port).status()

        #expect(status.isOnline == true)
        #expect(status.isCoverOpen == true)
        #expect(status.isPaperNearEnd == true)
        #expect(status.isPaperOut == false)
        #expect(status.isReady == false)
        #expect(await printer.received(atLeast: 12) == ESCPOSStatusRequest.allCases.flatMap(\.bytes))
        #expect(await printer.allConnectionsClosed())
    }

    @Test("No requests means no connection")
    func emptyStatus() async throws {
        let port = try await VirtualPrinter.closedPort()
        #expect(try await connection(port: port).status([]) == ESCPOSPrinterStatus())
    }

    @Test("A printer that never answers status times out while reading")
    func silentStatus() async throws {
        let printer = try await VirtualPrinter.start(.accept)
        defer { Task { await printer.stop() } }
        do {
            _ = try await connection(port: printer.port, statusRead: .milliseconds(300)).status([.printer])
            Issue.record("Expected a status timeout")
        } catch {
            #expect(error == ESCPOSConnectionError(delivery: .notSent, reason: .timedOut(.readingStatus)))
        }
        #expect(await printer.allConnectionsClosed())
    }

    @Test("Cancelling while waiting for status fails it as cancelled, not disconnected")
    func cancelledWhileReadingStatus() async throws {
        let printer = try await VirtualPrinter.start(.accept)
        defer { Task { await printer.stop() } }
        let connection = connection(port: printer.port, statusRead: .seconds(30))
        let task = Task { try await connection.status([.printer]) }
        _ = await printer.received(atLeast: 3)
        task.cancel()
        do {
            _ = try await task.value
            Issue.record("Expected cancellation")
        } catch let error as ESCPOSConnectionError {
            #expect(error == ESCPOSConnectionError(delivery: .notSent, reason: .cancelled(.readingStatus)))
        } catch {
            Issue.record("Unexpected error \(error)")
        }
        #expect(await printer.allConnectionsClosed())
    }

    @Test("A malformed status answer is refused, not misread")
    func malformedStatus() async throws {
        let printer = try await VirtualPrinter.start(.answerStatus([1: 0x00]))
        defer { Task { await printer.stop() } }
        do {
            _ = try await connection(port: printer.port).status([.printer])
            Issue.record("Expected a malformed status")
        } catch {
            let expected = ESCPOSStatusError(byte: 0x00, request: .printer)
            #expect(error == ESCPOSConnectionError(delivery: .notSent, reason: .malformedStatus(expected)))
        }
        #expect(await printer.allConnectionsClosed())
    }

    @Test("Asking a closed port for status sent nothing")
    func statusRefused() async throws {
        let port = try await VirtualPrinter.closedPort()
        do {
            _ = try await connection(port: port).status()
            Issue.record("Expected the connection to be refused")
        } catch {
            #expect(error == ESCPOSConnectionError(delivery: .notSent, reason: .connectionRefused))
        }
    }
}
#endif
