import Foundation
import CLibssh2

public class Channel {
    let rawPointer: OpaquePointer
    private let sessionRawPointer: OpaquePointer

    static let windowDefault: UInt32 = 2 * 1024 * 1024
    static let packetDefaultSize: UInt32 = 32768

    static let readBufferSize = 0x4000
    var readBuffer = [Int8](repeating: 0, count: readBufferSize)

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

    // read reads data from the channel.
    // 0 to read from stdout.
    // 1 to read from stderr.
    public func read(_ streamId: Int32) throws -> Data {
        let rc = readBuffer.withUnsafeMutableBufferPointer {
            guard let ptr = $0.baseAddress else {
                return 0
            }

            return libssh2_channel_read_ex(
                rawPointer,
                streamId,
                ptr,
                Channel.readBufferSize
            )
        }

        guard rc >= 0 else {
            let msg = getLastErrorMessage(sessionRawPointer)
            throw SSH2Error.channelReadFailed(msg)
        }

        return Data(bytes: readBuffer, count: rc)
    }

    public func readAll(_ stdout: Pipe, _ stderr: Pipe) throws {
        defer {
            stdout.fileHandleForWriting.closeFile()
            stderr.fileHandleForWriting.closeFile()
        }

        while true {
            var totalSize = 0

            let stdoutData = try read(0)
            if !stdoutData.isEmpty {
                totalSize += stdoutData.count
                stdout.fileHandleForWriting.write(stdoutData)
            }

            let stderrData = try read(1)
            if !stderrData.isEmpty {
                totalSize += stderrData.count
                stderr.fileHandleForWriting.write(stderrData)
            }

            if totalSize == 0 && libssh2_channel_eof(rawPointer) == 1 {
                break
            }
        }
    }

    public func readAll() throws -> (stdout: String, stderr: String) {
        let stdout = Pipe()
        let stderr = Pipe()

        try readAll(stdout, stderr)

        let stdoutData = stdout.fileHandleForReading.readDataToEndOfFile()
        let stderrData = stderr.fileHandleForReading.readDataToEndOfFile()

        return (
            stdout: String(data: stdoutData, encoding: .utf8)!,
            stderr: String(data: stderrData, encoding: .utf8)!
        )
    }

    public func write(_ data: Data) throws {
        if data.count == 0 {
            return
        }

        let rc = data.withUnsafeBytes {
            guard let ptr = $0.baseAddress else {
                return 0
            }

            var offset = 0

            repeat {
                let size = min(0x4000, data.count - offset)
                let rc = libssh2_channel_write_ex(
                    rawPointer,
                    0,
                    ptr.advanced(by: offset),
                    size
                )
                if rc == -1 {
                    return -1
                }

                offset += rc
            } while offset < data.count

            return offset
        }

        guard rc >= 0 else {
            let msg = getLastErrorMessage(sessionRawPointer)
            throw SSH2Error.channelWriteFailed(msg)
        }
    }

    public func sendEof() throws {
        let rc = libssh2_channel_send_eof(rawPointer)

        guard rc == LIBSSH2_ERROR_NONE else {
            let msg = getLastErrorMessage(sessionRawPointer)
            throw SSH2Error.channelWriteFailed(msg)
        }
    }
}
