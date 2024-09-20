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

    private func read(_ stream: Pipe, id: Int32) throws {
        let size = 0x4000
        var buffer = [Int8](repeating: 0, count: size)

        while true {
            let rc = libssh2_channel_read_ex(rawPointer, id, &buffer, size)

            if rc > 0 {
                let data = Data(bytes: &buffer, count: rc)
                stream.fileHandleForWriting.write(data)
            } else if rc == 0 {
                // EOF
                stream.fileHandleForWriting.closeFile()
                break
            } else {
                let msg = getLastErrorMessage(sessionRawPointer)
                throw SSH2Error.channelReadFailed(msg)
            }
        }
    }

    func readStdout(_ stream: Pipe) throws {
        try read(stream, id: 0)
    }

    func readStderr(_ stream: Pipe) throws {
        try read(stream, id: SSH_EXTENDED_DATA_STDERR)
    }

    func write(_ data: Data) throws {
        if data.count == 0 {
            return
        }

        var offset = 0

        while offset < data.count {
            let size = min(0x4000, data.count - offset)
            let chunk = data.subdata(in: offset..<offset+size)

            let result: Result<Int, SSH2Error> = chunk.withUnsafeBytes {
                guard let ptr = $0.bindMemory(to: Int8.self).baseAddress else {
                    let msg = "Failed to bind memory"
                    let err = SSH2Error.channelWriteFailed(msg)
                    return .failure(err)
                }

                let rc = libssh2_channel_write_ex(rawPointer, 0, ptr, chunk.count)
                if rc >= 0 {
                    return .success(rc)
                } else {
                    let msg = getLastErrorMessage(sessionRawPointer)
                    let err = SSH2Error.channelWriteFailed(msg)
                    return .failure(err)
                }
            }

            switch result {
            case .success(let rc):
                offset += rc
            case .failure(let err):
                throw err
            }
        }
    }

    func eof() throws {
        let rc = libssh2_channel_send_eof(rawPointer)

        guard rc == LIBSSH2_ERROR_NONE else {
            let msg = getLastErrorMessage(sessionRawPointer)
            throw SSH2Error.channelWriteFailed(msg)
        }
    }

    func writeStream(_ stream: Pipe) {
        stream.fileHandleForReading.readabilityHandler = {
            let data: Data = $0.availableData

            if data.count > 0 {
                do {
                    try self.write(data)
                } catch {
                    // TODO: handle write error
                    $0.readabilityHandler = nil
                }
            } else {
                // EOF
                do {
                    try self.eof()
                } catch {
                    // TODO: handle eof error
                }
                $0.readabilityHandler = nil
            }
        }
    }
}
