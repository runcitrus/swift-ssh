import Foundation
import CLibssh2

public extension SSH2 {
    func exec(
        _ command: String,
        stdin: Pipe? = nil,
        stdout: Pipe,
        stderr: Pipe
    ) throws {
        let channel = try Channel(session.rawPointer)
        try channel.process(command, request: "exec")

        if let stdin = stdin {
            stdin.fileHandleForReading.readabilityHandler = {
                let data: Data = $0.availableData

                do {
                    if !data.isEmpty {
                        try channel.writeData(data)
                    } else {
                        try channel.sendEof()
                        $0.readabilityHandler = nil
                    }
                } catch {
                    // TODO: handle write error
                    $0.readabilityHandler = nil
                }
            }
        } else {
            try channel.sendEof()
        }

        try channel.read(stdout, stderr)
    }

    func exec(
        _ command: String
    ) throws -> (stdout: String, stderr: String) {
        let stdout = Pipe()
        let stderr = Pipe()

        try exec(command, stdout: stdout, stderr: stderr)

        let stdoutData = stdout.fileHandleForReading.readDataToEndOfFile()
        let stderrData = stderr.fileHandleForReading.readDataToEndOfFile()

        return (
            stdout: String(data: stdoutData, encoding: .utf8)!,
            stderr: String(data: stderrData, encoding: .utf8)!
        )
    }
}
