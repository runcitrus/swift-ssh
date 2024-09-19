import CLibssh2

class Session {
    public let rawPointer: OpaquePointer

    deinit {
        libssh2_session_disconnect_ex(rawPointer, SSH_DISCONNECT_BY_APPLICATION, "Bye", "")
        libssh2_session_free(rawPointer)
    }

    init(
        _ sockfd: Int32,
        banner: String? = nil,
        timeout: Int?
    ) throws {
        let session = libssh2_session_init_ex(nil, nil, nil, nil)
        guard let session else {
            throw SSH2Error.sessionInitFailed
        }

        if let timeout = timeout {
            libssh2_session_set_timeout(session, timeout * 1000)
        }

        if let banner = banner {
            libssh2_session_banner_set(session, banner)
        }

        let rc = libssh2_session_handshake(session, sockfd)
        guard rc == 0 else {
            throw SSH2Error.sessionInitFailed
        }

        self.rawPointer = session
    }
}
