import CLibssh2

public struct SSH2 {
    public static func connect(
        _ host: String,
        port: Int32 = 22,
        banner: String? = nil
    ) throws -> Session {
        return try Session(
            host: host,
            port: port,
            banner: banner
        )
    }
}
