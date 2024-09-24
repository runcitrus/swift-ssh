import Foundation
import CLibssh2

public extension Session {
    func exec(_ command: String) async throws -> Channel {
        let channel = try await Channel(self)
        try await channel.process(command, request: "exec")

        return channel
    }
}
