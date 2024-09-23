import CLibssh2

public class Session {
    private let sock: Socket
    let rawPointer: OpaquePointer

    deinit {
        libssh2_session_disconnect_ex(rawPointer, SSH_DISCONNECT_BY_APPLICATION, "Bye", "")
        libssh2_session_free(rawPointer)
        libssh2_exit()
    }

    internal init(
        host: String,
        port: Int32 = 22,
        banner: String? = nil
    ) throws {
        sock = try Socket(host, port)

        libssh2_init(0)

        let session = libssh2_session_init_ex(nil, nil, nil, nil)
        guard let session else {
            throw SSH2Error.sessionInitFailed
        }

        if let banner = banner {
            libssh2_session_banner_set(session, banner)
        }

        let rc = libssh2_session_handshake(session, sock.fd)
        guard rc == LIBSSH2_ERROR_NONE else {
            throw SSH2Error.sessionInitFailed
        }

        self.rawPointer = session
    }

    func setTimeout(sec: Int) {
        libssh2_session_set_timeout(rawPointer, sec * 1000)
    }

    func getSock() -> Int32 {
        return sock.fd
    }
}
