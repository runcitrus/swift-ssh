import Foundation
import CLibssh2

class Channel {
    public let rawPointer: OpaquePointer
    private let sessionRawPointer: OpaquePointer

    static let windowDefault: UInt32 = 2 * 1024 * 1024
    static let packetDefaultSize: UInt32 = 32768

    deinit {
        libssh2_channel_close(rawPointer)
        libssh2_channel_free(rawPointer)
    }

    init(_ session: OpaquePointer) throws {
        let channelType = "session"

        let channel = libssh2_channel_open_ex(
            session,
            channelType,
            UInt32(channelType.count),
            Channel.windowDefault,
            Channel.packetDefaultSize,
            nil,
            0
        )
        guard let channel else {
            let msg = getLastErrorMessage(session)
            throw SSH2Error.channelOpenFailed(msg)
        }

        rawPointer = channel
        sessionRawPointer = session
    }

    func process(_ command: String, request: String) throws {
        let rc = libssh2_channel_process_startup(
            rawPointer,
            request,
            UInt32(request.count),
            command,
            UInt32(command.count)
        )

        guard rc == LIBSSH2_ERROR_NONE else {
            let msg = getLastErrorMessage(sessionRawPointer)
            throw SSH2Error.channelProcessFailed(msg)
        }
    }

    func read(_ stdout: Pipe, _ stderr: Pipe) throws {
        let size = 0x4000
        var buffer = [Int8](repeating: 0, count: size)

        defer {
            stdout.fileHandleForWriting.closeFile()
            stderr.fileHandleForWriting.closeFile()
        }

        while true {
            let stdoutResult: Int = buffer.withUnsafeMutableBufferPointer {
                return libssh2_channel_read_ex(
                    rawPointer,
                    0,
                    $0.baseAddress,
                    size
                )
            }

            if stdoutResult > 0 {
                let data = Data(bytes: buffer, count: stdoutResult)
                stdout.fileHandleForWriting.write(data)
            } else if stdoutResult < 0 {
                let msg = getLastErrorMessage(sessionRawPointer)
                throw SSH2Error.channelReadFailed(msg)
            }

            let stderrResult: Int = buffer.withUnsafeMutableBufferPointer {
                return libssh2_channel_read_ex(
                    rawPointer,
                    SSH_EXTENDED_DATA_STDERR,
                    $0.baseAddress,
                    size
                )
            }

            if stderrResult > 0 {
                let data = Data(bytes: buffer, count: stderrResult)
                stderr.fileHandleForWriting.write(data)
            } else if stderrResult < 0 {
                let msg = getLastErrorMessage(sessionRawPointer)
                throw SSH2Error.channelReadFailed(msg)
            }

            if stdoutResult == 0 && stderrResult == 0 && libssh2_channel_eof(rawPointer) == 1 {
                break
            }
        }
    }

    func writeData(_ data: Data) throws {
        if data.count == 0 {
            return
        }

        let result: Result<Int, SSH2Error> = data.withUnsafeBytes {
            guard let ptr = $0.baseAddress else {
                let msg = "Failed to bind memory"
                let err = SSH2Error.channelWriteFailed(msg)
                return .failure(err)
            }

            var offset = 0
            repeat {
                let size = min(0x4000, data.count - offset)
                let rc = libssh2_channel_write_ex(
                    rawPointer,
                    0, ptr.advanced(by: offset),
                    size
                )
                if rc == -1 {
                    let msg = getLastErrorMessage(sessionRawPointer)
                    let err = SSH2Error.channelWriteFailed(msg)
                    return .failure(err)
                }

                offset += rc
            } while offset < data.count

            return .success(offset)
        }

        if case let .failure(err) = result {
            throw err
        }
    }

    func sendEof() throws {
        let rc = libssh2_channel_send_eof(rawPointer)

        guard rc == LIBSSH2_ERROR_NONE else {
            let msg = getLastErrorMessage(sessionRawPointer)
            throw SSH2Error.channelWriteFailed(msg)
        }
    }
}
