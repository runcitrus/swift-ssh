import CLibssh2

public enum SSH2AuthMethod {
    case password(String)
    case privateKey(String, String? = nil)
}

public extension Session {
    func auth(
        _ username: String,
        _ method: SSH2AuthMethod
    ) throws {
        switch method {
        case .privateKey(let key, let passphrase):
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
        case .password(let password):
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
    }
}
