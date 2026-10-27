//
//  VirtualPrinter.swift
//  swift-escpos
//
//  Created by Damian Van de Kauter on 25/10/2026.
//

import NIOConcurrencyHelpers
import NIOCore
import NIOPosix

/// A TCP server on 127.0.0.1 that plays a network printer badly on purpose.
final class VirtualPrinter: Sendable {
    enum Behaviour: Sendable {
        /// Reads everything and records it.
        case accept
        /// Reads `bytes`, then closes the connection; further writes from the sender are refused.
        case resetAfter(bytes: Int)
        /// Accepts the connection and never reads, so the sender's buffers fill.
        case neverRead
        /// Answers each `DLE EOT n` with the byte given for `n`; records everything.
        case answerStatus([UInt8: UInt8])
    }

    let port: Int
    private let channel: Channel
    private let log: NIOLockedValueBox<[UInt8]>
    private let openConnections: NIOLockedValueBox<Int>

    private init(port: Int, channel: Channel, log: NIOLockedValueBox<[UInt8]>, openConnections: NIOLockedValueBox<Int>) {
        self.port = port
        self.channel = channel
        self.log = log
        self.openConnections = openConnections
    }

    static func start(_ behaviour: Behaviour) async throws -> VirtualPrinter {
        let log = NIOLockedValueBox<[UInt8]>([])
        let openConnections = NIOLockedValueBox(0)
        var bootstrap = ServerBootstrap(group: MultiThreadedEventLoopGroup.singleton)
            .serverChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
            .childChannelInitializer { child in
                child.eventLoop.makeCompletedFuture {
                    try child.pipeline.syncOperations.addHandler(
                        Handler(behaviour: behaviour, log: log, openConnections: openConnections)
                    )
                }
            }
        switch behaviour {
        case .neverRead:
            bootstrap = bootstrap
                .childChannelOption(ChannelOptions.autoRead, value: false)
                .childChannelOption(ChannelOptions.socketOption(.so_rcvbuf), value: 4096)
        case .accept, .answerStatus, .resetAfter:
            break
        }
        let channel = try await bootstrap.bind(host: "127.0.0.1", port: 0).get()
        guard let port = channel.localAddress?.port else { throw ChannelError.unknownLocalAddress }
        return VirtualPrinter(port: port, channel: channel, log: log, openConnections: openConnections)
    }

    /// A port on 127.0.0.1 that nothing listens on.
    static func closedPort() async throws -> Int {
        let channel = try await ServerBootstrap(group: MultiThreadedEventLoopGroup.singleton)
            .bind(host: "127.0.0.1", port: 0)
            .get()
        let port = channel.localAddress!.port!
        try await channel.close()
        return port
    }

    var received: [UInt8] {
        log.withLockedValue { $0 }
    }

    /// What arrived, once at least `count` bytes have, or after `timeout`.
    func received(atLeast count: Int, within timeout: Duration = .seconds(2)) async -> [UInt8] {
        let deadline = ContinuousClock.now + timeout
        while received.count < count, ContinuousClock.now < deadline {
            try? await Task.sleep(for: .milliseconds(10))
        }
        return received
    }

    /// Whether every connection the sender opened has been closed, waiting up to `timeout`.
    func allConnectionsClosed(within timeout: Duration = .seconds(2)) async -> Bool {
        let deadline = ContinuousClock.now + timeout
        while openConnections.withLockedValue({ $0 }) > 0, ContinuousClock.now < deadline {
            try? await Task.sleep(for: .milliseconds(10))
        }
        return openConnections.withLockedValue { $0 } == 0
    }

    func stop() async {
        try? await channel.close()
    }

    // MARK: - Handler

    private final class Handler: ChannelInboundHandler {
        typealias InboundIn = ByteBuffer
        typealias OutboundOut = ByteBuffer

        private let behaviour: Behaviour
        private let log: NIOLockedValueBox<[UInt8]>
        private let openConnections: NIOLockedValueBox<Int>
        private var count = 0
        private var pending: [UInt8] = []

        init(behaviour: Behaviour, log: NIOLockedValueBox<[UInt8]>, openConnections: NIOLockedValueBox<Int>) {
            self.behaviour = behaviour
            self.log = log
            self.openConnections = openConnections
        }

        func channelActive(context: ChannelHandlerContext) {
            openConnections.withLockedValue { $0 += 1 }
            context.fireChannelActive()
        }

        func channelInactive(context: ChannelHandlerContext) {
            openConnections.withLockedValue { $0 -= 1 }
            context.fireChannelInactive()
        }

        func channelRead(context: ChannelHandlerContext, data: NIOAny) {
            var buffer = unwrapInboundIn(data)
            let bytes = buffer.readBytes(length: buffer.readableBytes) ?? []
            log.withLockedValue { $0 += bytes }
            count += bytes.count

            switch behaviour {
            case .resetAfter(let limit) where count >= limit:
                context.close(promise: nil)
            case .answerStatus(let answers):
                pending += bytes
                while let start = pending.firstIndex(of: 0x10), pending.count >= start + 3 {
                    if pending[start + 1] == 0x04, let answer = answers[pending[start + 2]] {
                        context.writeAndFlush(wrapOutboundOut(ByteBuffer(bytes: [answer])), promise: nil)
                    }
                    pending.removeFirst(start + 3)
                }
            default:
                break
            }
        }

        func errorCaught(context: ChannelHandlerContext, error: Error) {
            context.close(promise: nil)
        }
    }
}
