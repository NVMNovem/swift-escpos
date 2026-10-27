//
//  ESCPOSConnection.swift
//  swift-escpos
//
//  Created by Damian Van de Kauter on 25/10/2026.
//

#if Network
import NIOConcurrencyHelpers
import NIOCore
import NIOPosix
import SwiftESCPOS

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#endif

/// Where a printer is reached, and how to hand it bytes.
///
/// Every call opens one connection, does its work and closes it again, so a printer shared with
/// another system is held for as short a time as possible. Calls are not serialised: sending two
/// jobs to one printer at once is the caller's to prevent.
public struct ESCPOSConnection: Sendable, Hashable {
    /// Per-step time limits.
    public struct Timeouts: Sendable, Hashable {
        public var connect: Duration
        /// For each chunk to be accepted. A printer that stops reading — out of paper, a full
        /// buffer — stalls the write rather than failing it, so this is what notices.
        public var write: Duration
        public var statusRead: Duration

        public init(
            connect: Duration = .seconds(5),
            write: Duration = .seconds(10),
            statusRead: Duration = .seconds(3)
        ) {
            self.connect = connect
            self.write = write
            self.statusRead = statusRead
        }
    }

    enum Endpoint: Sendable, Hashable {
        case tcp(host: String, port: Int)
    }

    let endpoint: Endpoint
    public var timeouts: Timeouts
    /// Bytes per write. Each chunk is confirmed before the next, which is what lets a failure say
    /// how much was accepted.
    public var chunkSize: Int

    /// A printer on the network, normally on raw port 9100.
    public static func tcp(
        host: String,
        port: Int = 9100,
        timeouts: Timeouts = Timeouts(),
        chunkSize: Int = 4096
    ) -> ESCPOSConnection {
        ESCPOSConnection(endpoint: .tcp(host: host, port: port), timeouts: timeouts, chunkSize: chunkSize)
    }

    // MARK: - Sending

    /// Sends a job and closes the connection.
    ///
    /// Success means every byte was accepted and the connection closed cleanly — not that the job
    /// printed. On failure, ``ESCPOSConnectionError/delivery`` says whether sending again could
    /// print it twice.
    public func send(_ bytes: [UInt8]) async throws(ESCPOSConnectionError) -> ESCPOSTransmission {
        let clock = ContinuousClock()
        let start = clock.now
        let progress = Progress()
        do {
            try Task.checkCancellation()
            let channel = try await connect(progress: progress)
            defer { channel.close(promise: nil) }
            try Task.checkCancellation()
            try await withTaskCancellationHandler {
                progress.phase = .writing
                var offset = 0
                while offset < bytes.count {
                    try Task.checkCancellation()
                    let end = min(offset + max(chunkSize, 1), bytes.count)
                    progress.hasStartedWriting = true
                    try await write(bytes[offset..<end], on: channel, progress: progress)
                    progress.confirmedBytes = end
                    offset = end
                }
                try await channel.close()
            } onCancel: {
                progress.wasCancelled = true
                channel.close(promise: nil)
            }
            return ESCPOSTransmission(bytesSent: bytes.count, duration: clock.now - start)
        } catch {
            throw progress.classify(error)
        }
    }

    /// Asks the printer for its real-time status and closes the connection.
    ///
    /// Only meaningful for a profile listing ``ESCPOSCapabilities/realtimeStatus``; a printer that
    /// does not answer fails with ``ESCPOSConnectionError/Reason/timedOut(_:)`` while reading.
    /// No job bytes are involved, so the delivery of a failure is always
    /// ``ESCPOSConnectionError/Delivery/notSent``.
    public func status(
        _ requests: [ESCPOSStatusRequest] = ESCPOSStatusRequest.allCases
    ) async throws(ESCPOSConnectionError) -> ESCPOSPrinterStatus {
        guard !requests.isEmpty else { return ESCPOSPrinterStatus() }
        let progress = Progress(countsDelivery: false)
        do {
            try Task.checkCancellation()
            let channel = try await connect(progress: progress)
            defer { channel.close(promise: nil) }
            try Task.checkCancellation()
            return try await withTaskCancellationHandler {
                let answers = channel.eventLoop.makePromise(of: [UInt8].self)
                try await channel.eventLoop.submit {
                    let collector = ESCPOSStatusCollector(expectedCount: requests.count, promise: answers)
                    try channel.pipeline.syncOperations.addHandler(collector)
                }.get()

                progress.phase = .writing
                try await write(requests.flatMap(\.bytes)[...], on: channel, progress: progress)

                progress.phase = .readingStatus
                let deadline = channel.eventLoop.scheduleTask(in: TimeAmount(timeouts.statusRead)) {
                    progress.hasTimedOut = true
                    answers.fail(ChannelError.ioOnClosedChannel)
                }
                defer { deadline.cancel() }
                let bytes = try await answers.futureResult.get()
                return try ESCPOSPrinterStatus(answers: bytes, for: requests)
            } onCancel: {
                progress.wasCancelled = true
                channel.close(promise: nil)
            }
        } catch {
            throw progress.classify(error)
        }
    }

    // MARK: - Channel

    /// Connects, giving up as soon as the task is cancelled rather than when the connect timeout
    /// runs out.
    private func connect(progress: Progress) async throws -> Channel {
        // The channel being connected, so cancellation can close it. Whichever of the initializer
        // and the cancellation handler runs second sees what the first one left.
        let attempt = NIOLockedValueBox<Channel?>(nil)
        return try await withTaskCancellationHandler {
            switch endpoint {
            case .tcp(let host, let port):
                try await ClientBootstrap(group: MultiThreadedEventLoopGroup.singleton)
                    .connectTimeout(TimeAmount(timeouts.connect))
                    .channelOption(ChannelOptions.socketOption(.tcp_nodelay), value: 1)
                    .channelInitializer { channel in
                        attempt.withLockedValue { $0 = channel }
                        guard !progress.wasCancelled else {
                            return channel.eventLoop.makeFailedFuture(CancellationError())
                        }
                        return channel.eventLoop.makeSucceededVoidFuture()
                    }
                    .connect(host: host, port: port)
                    .get()
            }
        } onCancel: {
            progress.wasCancelled = true
            attempt.withLockedValue { $0 }?.close(promise: nil)
        }
    }

    private func write(_ chunk: ArraySlice<UInt8>, on channel: Channel, progress: Progress) async throws {
        let deadline = channel.eventLoop.scheduleTask(in: TimeAmount(timeouts.write)) {
            progress.hasTimedOut = true
            channel.close(promise: nil)
        }
        defer { deadline.cancel() }
        try await channel.writeAndFlush(ByteBuffer(bytes: chunk)).get()
    }
}

// MARK: - Progress

extension ESCPOSConnection {
    /// What a call had got to when it failed, shared with the event loop's timeout callbacks.
    final class Progress: Sendable {
        private struct State {
            var phase: ESCPOSConnectionError.Phase = .connecting
            var hasStartedWriting = false
            var confirmedBytes = 0
            var hasTimedOut = false
            /// Set by a cancellation handler, which closes the channel: the step then fails with a
            /// closed-channel error, not a `CancellationError`, and must still count as cancelled.
            var wasCancelled = false
        }

        private let state = NIOLockedValueBox(State())
        private let countsDelivery: Bool

        init(countsDelivery: Bool = true) {
            self.countsDelivery = countsDelivery
        }

        var phase: ESCPOSConnectionError.Phase {
            get { state.withLockedValue(\.phase) }
            set { state.withLockedValue { $0.phase = newValue } }
        }

        var hasStartedWriting: Bool {
            get { state.withLockedValue(\.hasStartedWriting) }
            set { state.withLockedValue { $0.hasStartedWriting = newValue } }
        }

        var confirmedBytes: Int {
            get { state.withLockedValue(\.confirmedBytes) }
            set { state.withLockedValue { $0.confirmedBytes = newValue } }
        }

        var hasTimedOut: Bool {
            get { state.withLockedValue(\.hasTimedOut) }
            set { state.withLockedValue { $0.hasTimedOut = newValue } }
        }

        var wasCancelled: Bool {
            get { state.withLockedValue(\.wasCancelled) }
            set { state.withLockedValue { $0.wasCancelled = newValue } }
        }

        /// Turns whatever was thrown into an ``ESCPOSConnectionError`` that is honest about delivery.
        ///
        /// Once a write has been issued, a failure is never ``ESCPOSConnectionError/Delivery/notSent``:
        /// the operating system may have sent part of a chunk whose write then failed.
        func classify(_ error: any Error) -> ESCPOSConnectionError {
            let state = state.withLockedValue { $0 }
            let delivery: ESCPOSConnectionError.Delivery =
                countsDelivery && state.hasStartedWriting
                ? .partiallySent(confirmedBytes: state.confirmedBytes)
                : .notSent
            return ESCPOSConnectionError(delivery: delivery, reason: reason(for: error, state: state))
        }

        private func reason(for error: any Error, state: State) -> ESCPOSConnectionError.Reason {
            if let error = error as? ESCPOSStatusError {
                return .malformedStatus(error)
            }
            if error is CancellationError || state.wasCancelled {
                return .cancelled(state.phase)
            }
            if state.hasTimedOut {
                return .timedOut(state.phase)
            }
            if case ChannelError.connectTimeout = error {
                return .timedOut(.connecting)
            }
            if state.phase == .connecting {
                return Self.isRefusal(error) ? .connectionRefused : .connectionFailed(String(describing: error))
            }
            return .disconnected(state.phase)
        }

        private static func isRefusal(_ error: any Error) -> Bool {
            if let error = error as? IOError {
                return error.errnoCode == ECONNREFUSED
            }
            if let error = error as? NIOConnectionError {
                return !error.connectionErrors.isEmpty
                    && error.connectionErrors.allSatisfy { isRefusal($0.error) }
            }
            return false
        }
    }
}
#endif
