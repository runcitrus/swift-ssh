import CLibssh2

public class SSH2 {
    var sock: Socket
    var session: Session

    public static func libInit() {
        libssh2_init(0)
    }

    public static func libExit() {
        libssh2_exit()
    }

    public init(
        _ host: String,
        _ port: Int32 = 22,
        banner: String? = nil
    ) throws {
        sock = try Socket(host, port)
        session = try Session(
            sock.fd,
            banner: banner
        )
    }
}
