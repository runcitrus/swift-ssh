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
}
