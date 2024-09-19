import Foundation
import CLibssh2

public extension SSH2 {
    func exec(
        _ command: String,
        stdin: Pipe? = nil
    ) async throws -> (
        stdout: Data?,
        stderr: Data?
    ) {
        let channel = try Channel(session.rawPointer)
        try channel.process(command, request: "exec")

        if let stdin = stdin {
            Task {
                try await channel.writePipe(stdin)
            }
        }

        let stdout = try await channel.read()

        return (stdout: stdout, stderr: nil)
    }
}
