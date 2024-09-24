import CLibssh2

public enum SSH2AuthMethod {
    case password(String)
    case privateKey(String, String? = nil)
}

public extension Session {
    private func privateKeyAuth(
        _ username: String,
        _ key: String,
        _ passphrase: String?
    ) throws {
        let rc = libssh2_userauth_publickey_frommemory(
            rawPointer,
            username,
            Int(username.count),
            nil,
            0,
            key,
            key.count,
            passphrase
        )
        guard rc == LIBSSH2_ERROR_NONE else {
            let msg = getLastErrorMessage()
            throw SSH2Error.authFailed(rc, msg)
        }
    }

    private func passwordAuth(
        _ username: String,
        _ password: String
    ) throws {
        let rc = libssh2_userauth_password_ex(
            rawPointer,
            username,
            UInt32(username.count),
            password,
            UInt32(password.count),
            nil
        )
        guard rc == LIBSSH2_ERROR_NONE else {
            let msg = getLastErrorMessage()
            throw SSH2Error.authFailed(rc, msg)
        }
    }

    func auth(
        _ username: String,
        _ method: SSH2AuthMethod
    ) throws {
        switch method {
        case .privateKey(let key, let passphrase):
            try privateKeyAuth(username, key, passphrase)
        case .password(let password):
            try passwordAuth(username, password)
        }
    }
}
