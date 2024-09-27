import Clibssh2

public struct SSH2 {
    public static func connect(
        _ host: String,
        port: Int32 = 22,
        banner: String? = nil
    ) async throws -> Session {
        let session = try Session(
            host: host,
            port: port,
            banner: banner
        )

        try await session.handshake()

        return session
    }
}
