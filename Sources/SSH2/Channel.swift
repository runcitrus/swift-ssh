import Foundation
import CLibssh2

public class Channel {
    private let session: Session
    let rawPointer: OpaquePointer

    static let windowDefault: UInt32 = 2 * 1024 * 1024
    static let packetDefaultSize: UInt32 = 32768

    static let readBufferSize = 0x4000
    var readBuffer = [Int8](repeating: 0, count: readBufferSize)

    deinit {
        libssh2_channel_close(rawPointer)
        libssh2_channel_free(rawPointer)
    }

    internal init(_ session: Session) async throws {
        let channelType = "session"

        let result = await session.call {
            libssh2_channel_open_ex(
                session.rawPointer,
                channelType,
                UInt32(channelType.count),
                Channel.windowDefault,
                Channel.packetDefaultSize,
                nil,
                0
            )
        }

        switch result {
        case .success(let channel):
            self.rawPointer = channel
            self.session = session
        case .failure(_, let msg):
            throw SSH2Error.channelOpenFailed(msg)
        }
    }

    func process(_ command: String, request: String) async throws {
        let result = await session.call {
            libssh2_channel_process_startup(
                self.rawPointer,
                request,
                UInt32(request.count),
                command,
                UInt32(command.count)
            )
        }

        if case .failure(_, let msg) = result {
            throw SSH2Error.channelProcessFailed(msg)
        }
    }

    // read reads data from the channel.
    // streamId:
    // - 0 - read from stdout.
    // - 1 - read from stderr.
    public func read(_ streamId: Int32) async throws -> Data {
        let result = await session.call {
            self.readBuffer.withUnsafeMutableBufferPointer {
                libssh2_channel_read_ex(
                    self.rawPointer,
                    streamId,
                    $0.baseAddress,
                    Channel.readBufferSize
                )
            }
        }

        switch result {
        case .success(let size):
            return Data(bytes: readBuffer, count: size)
        case .failure(_, let msg):
            throw SSH2Error.channelReadFailed(msg)
        }
    }

    public func readAll(
        stdoutHandler: @escaping (Data) -> Void,
        stderrHandler: @escaping (Data) -> Void
    ) async throws {
        while true {
            var totalSize = 0

            let stdoutData = try await read(0)
            if !stdoutData.isEmpty {
                totalSize += stdoutData.count
                stdoutHandler(stdoutData)
            }

            let stderrData = try await read(1)
            if !stderrData.isEmpty {
                totalSize += stderrData.count
                stderrHandler(stderrData)
            }

            if totalSize == 0 && libssh2_channel_eof(rawPointer) == 1 {
                break
            }
        }
    }

    public func readAll() async throws -> (stdout: String, stderr: String) {
        var stdoutData = Data()
        var stderrData = Data()

        try await readAll(
            stdoutHandler: {
                stdoutData.append($0)
            },
            stderrHandler: {
                stderrData.append($0)
            }
        )

        let stdoutString = String(data: stdoutData, encoding: .utf8) ?? ""
        let stderrString = String(data: stderrData, encoding: .utf8) ?? ""

        return (stdout: stdoutString, stderr: stderrString)
    }

    // write writes data to the channel.
    // streamId:
    // - 0 - write to stdin/stdout.
    // - 1 - write to stderr.
    // returns the number of bytes written.
    public func write(_ data: Data, _ streamId: Int32) async throws -> Int {
        let result = await session.call {
            data.withUnsafeBytes {
                libssh2_channel_write_ex(
                    self.rawPointer,
                    streamId,
                    $0.baseAddress,
                    data.count
                )
            }
        }

        switch result {
        case .success(let size):
            return size
        case .failure(_, let msg):
            throw SSH2Error.channelReadFailed(msg)
        }
    }

    public func writeAll(_ data: Data) async throws {
        var block = data

        while !block.isEmpty {
            let chunkSize = min(0x4000, block.count)
            let chunk = block.prefix(chunkSize)
            let sent = try await write(chunk, 0)
            block = block.dropFirst(sent)
        }

        try await sendEof()
    }

    public func writeAll(_ stdin: FileHandle) async throws {
        let stream = AsyncStream {
            continuation in

            stdin.readabilityHandler = {
                let data = $0.availableData

                if !data.isEmpty {
                    continuation.yield(data)
                } else {
                    continuation.finish()
                    $0.readabilityHandler = nil
                }
            }
        }

        for try await data in stream {
            var block = data

            while !block.isEmpty {
                let chunkSize = min(0x4000, block.count)
                let chunk = block.prefix(chunkSize)
                let sent = try await write(chunk, 0)
                block = block.dropFirst(sent)
            }
        }

        try await sendEof()
    }

    // sendEof sends EOF to the channel.
    // if no data needs to be sent to the channel, call this function.
    public func sendEof() async throws {
        let result = await session.call {
            libssh2_channel_send_eof(self.rawPointer)
        }

        if case .failure(_, let msg) = result {
            throw SSH2Error.channelWriteFailed(msg)
        }
    }
}
