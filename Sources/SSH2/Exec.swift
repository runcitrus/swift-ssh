import Foundation
import CLibssh2

public extension SSH2 {
    func exec(_ command: String) throws -> (stdout: Data?, stderr: Data?) {
        let channel = try Channel(session.rawPointer)

        try channel.process(command, request: "exec")
        let stdout = try channel.read()

        return (stdout: stdout, stderr: nil)
    }
}
