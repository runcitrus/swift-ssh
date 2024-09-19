import CLibssh2

public class SSH2 {
    var sock: Int32 = -1
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
        socketClose()
    }

    public init(
        _ host: String,
        _ port: Int32 = 22
    ) throws {
        try socketConnect(host, port)
        try sessionOpen()
    }
}
