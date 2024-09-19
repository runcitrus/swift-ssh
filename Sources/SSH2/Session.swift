import CLibssh2

extension SSH2 {
    func sessionOpen() throws {
        session = libssh2_session_init_ex(nil, nil, nil, nil)
        guard let session else {
            throw SSH2Error.sessionInitFailed
        }

        libssh2_session_set_timeout(session, timeout * 1000)
        libssh2_session_banner_set(session, "SSH-2.0-libssh2_Citrus.app")

        let rc = libssh2_session_handshake(session, sock)
        guard rc == 0 else {
            throw SSH2Error.sessionInitFailed
        }
    }

    func sessionClose() {
        if let session = self.session {
            libssh2_session_disconnect_ex(session, SSH_DISCONNECT_BY_APPLICATION, "Bye", "")
            libssh2_session_free(session)
            self.session = nil
        }
    }
}
