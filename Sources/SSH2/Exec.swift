import Foundation
import CLibssh2

public extension SSH2 {
    func exec(
        _ command: String,
        stdin: Pipe? = nil,
        stdout: Pipe? = nil,
        stderr: Pipe? = nil
    ) async throws {
        let channel = try Channel(session.rawPointer)
        try channel.process(command, request: "exec")

        if let stdin = stdin {
            channel.writeStream(stdin)
        }

        let stdoutTask = Task {
            if let stdout = stdout {
                try channel.readStdout(stdout)
            }
        }

        let stderrTask = Task {
            if let stderr = stderr {
                try channel.readStderr(stderr)
            }
        }

        try await stdoutTask.value
        try await stderrTask.value
    }
}
