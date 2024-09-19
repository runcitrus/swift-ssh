import Foundation
import CLibssh2

public extension SSH2 {
    func exec(
        _ command: String,
        stdin: Pipe? = nil,
        stdout: Pipe? = nil,
        stderr: Pipe? = nil
    ) throws {
        let channel = try Channel(session.rawPointer)
        try channel.process(command, request: "exec")

        let dispatchGroup = DispatchGroup()

        if let stdin = stdin {
            channel.writeStream(stdin)
        }

        if let stdout = stdout {
            dispatchGroup.enter()
            DispatchQueue.global().async {
                do {
                    try channel.readStdout(stdout)
                } catch {
                    // TODO: handle error
                    print(error)
                }
                dispatchGroup.leave()
            }
        }

        if let stderr = stderr {
            dispatchGroup.enter()
            DispatchQueue.global().async {
                do {
                    try channel.readStderr(stderr)
                } catch {
                    // TODO: handle error
                    print(error)
                }
                dispatchGroup.leave()
            }
        }

        dispatchGroup.wait()
    }
}
