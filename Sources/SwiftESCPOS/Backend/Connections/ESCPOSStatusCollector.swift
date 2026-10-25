//
//  ESCPOSStatusCollector.swift
//  swift-escpos
//
//  Created by Damian Van de Kauter on 25/10/2026.
//

import NIOCore

/// Collects the one-byte answers to `DLE EOT` requests on a channel.
final class ESCPOSStatusCollector: ChannelInboundHandler {
    typealias InboundIn = ByteBuffer

    private let expectedCount: Int
    private let promise: EventLoopPromise<[UInt8]>
    private var received: [UInt8] = []
    private var isComplete = false

    init(expectedCount: Int, promise: EventLoopPromise<[UInt8]>) {
        self.expectedCount = expectedCount
        self.promise = promise
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        var buffer = unwrapInboundIn(data)
        if let bytes = buffer.readBytes(length: buffer.readableBytes) {
            received += bytes
        }
        if received.count >= expectedCount {
            complete(.success(Array(received.prefix(expectedCount))))
        }
    }

    func channelInactive(context: ChannelHandlerContext) {
        complete(.failure(ChannelError.ioOnClosedChannel))
        context.fireChannelInactive()
    }

    func errorCaught(context: ChannelHandlerContext, error: Error) {
        complete(.failure(error))
        context.close(promise: nil)
    }

    /// Completes the promise once; later reads and closes are ignored.
    private func complete(_ result: Result<[UInt8], Error>) {
        guard !isComplete else { return }
        isComplete = true
        promise.completeWith(result)
    }
}
