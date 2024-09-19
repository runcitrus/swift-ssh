import Foundation
import CLibssh2

public extension SSH2 {
    func exec(
        _ command: String,
        stdin: Pipe? = nil,
        stdout: Pipe? = nil
    ) throws {
        let channel = try Channel(session.rawPointer)
        try channel.process(command, request: "exec")

        if let stdin = stdin {
            channel.writeStream(stdin)
        }

        if let stdout = stdout {
            try channel.read(stdout)
        }
    }
}
