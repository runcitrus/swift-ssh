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

    func read(_ stream: Pipe) throws {
        let size = 0x4000
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: size)
        defer {
            buffer.deallocate()
        }

        while true {
            let rc = libssh2_channel_read_ex(rawPointer, 0, buffer, size)

            if rc > 0 {
                let data = Data(bytes: buffer, count: rc)
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

    func write(_ data: Data) throws {
        var offset = 0

        while offset < data.count {
            let size = min(0x4000, data.count - offset)
            let chunk = data.subdata(in: offset..<offset+size)

            let rc = chunk.withUnsafeBytes {
                guard let ptr = $0.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                    return -1
                }
                return libssh2_channel_write_ex(rawPointer, 0, ptr, chunk.count)
            }

            if rc > 0 {
                offset += rc
            } else {
                let msg = getLastErrorMessage(sessionRawPointer)
                throw SSH2Error.channelWriteFailed(msg)
            }
        }
    }

    func eof() throws {
        let rc = libssh2_channel_send_eof(rawPointer)

        if rc != 0 {
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
