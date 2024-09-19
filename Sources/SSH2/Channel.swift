import Foundation
import CLibssh2

class Channel {
    public let rawPointer: OpaquePointer
    let sessionRawPointer: OpaquePointer

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
            2 * 1024 * 1024,
            32768,
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
        guard rc == 0 else {
            let msg = getLastErrorMessage(sessionRawPointer)
            throw SSH2Error.channelProcessFailed(msg)
        }
    }

    func read() throws -> Data {
        var out = Data()

        let size = 0x4000
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: size)
        defer {
            buffer.deallocate()
        }

        while true {
            let rc = libssh2_channel_read_ex(rawPointer, 0, buffer, size)

            if rc > 0 {
                out.append(buffer, count: rc)
            } else if rc == 0 {
                break // EOF
            } else {
                let msg = getLastErrorMessage(sessionRawPointer)
                throw SSH2Error.channelReadFailed(msg)
            }
        }

        return out
    }

    func eof() throws {
        let rc = libssh2_channel_send_eof(rawPointer)

        if rc != 0 {
            let msg = getLastErrorMessage(sessionRawPointer)
            throw SSH2Error.channelWriteFailed(msg)
        }
    }
}
