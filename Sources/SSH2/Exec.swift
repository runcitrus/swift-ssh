import Foundation
import CLibssh2

public extension SSH2 {
    func exec(
        _ command: String,
        stdin: Pipe? = nil,
        stdout: Pipe,
        stderr: Pipe
    ) async throws {
        let channel = try Channel(session.rawPointer)
        try channel.process(command, request: "exec")

        if let stdin = stdin {
            channel.writeStream(stdin)
        }

        try channel.read(stdout, stderr)
    }
}
