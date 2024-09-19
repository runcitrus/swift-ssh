import Foundation
import CLibssh2

public extension SSH2 {
    func exec(_ command: String) throws -> (stdout: Data?, stderr: Data?) {
        let channel = try channelOpen()
        defer {
            channelClose(channel)
        }

        let request = "exec"
        let rc = libssh2_channel_process_startup(
            channel,
            request,
            UInt32(request.count),
            command,
            UInt32(command.count)
        )
        guard rc == 0 else {
            let msg = getLastErrorMessage()
            throw SSH2Error.execFailed(msg)
        }

        var stdout = Data()

        let bufferSize = 0x4000
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer {
            buffer.deallocate()
        }

        while true {
            let stdoutSize = libssh2_channel_read_ex(channel, 0, buffer, bufferSize)

            if stdoutSize > 0 {
                stdout.append(buffer, count: stdoutSize)
            } else if stdoutSize == 0 {
                break // EOF
            } else if stdoutSize == LIBSSH2_ERROR_EAGAIN {
                continue
            } else {
                let msg = getLastErrorMessage()
                throw SSH2Error.execFailed(msg)
            }
        }

        return (stdout: stdout, stderr: nil)
    }
}
