import CLibssh2

public class SSH2 {
    var sock: Socket
    var session: OpaquePointer?
    var timeout: Int = 10

    public static func libInit() {
        libssh2_init(0)
    }

    public static func libExit() {
        libssh2_exit()
    }

    deinit {
        sessionClose()
    }

    public init(
        _ host: String,
        _ port: Int32 = 22
    ) throws {
        sock = try Socket(host, port, timeout: timeout)
        try sessionOpen()
    }
}
