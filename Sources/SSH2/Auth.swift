import CLibssh2

public enum SSH2AuthMethod {
    case password(String)
    case privateKey(String, String? = nil)
}

public extension SSH2 {
    func auth(
        _ username: String,
        _ method: SSH2AuthMethod
    ) throws {
        switch method {
        case .privateKey(let key, let passphrase):
            let rc = libssh2_userauth_publickey_frommemory(
                session.rawPointer,
                username,
                Int(username.count),
                nil,
                0,
                key,
                key.count,
                passphrase
            )
            guard rc == 0 else {
                let msg = getLastErrorMessage()
                throw SSH2Error.authFailed(rc, msg)
            }
        case .password(let password):
            let rc = libssh2_userauth_password_ex(
                session.rawPointer,
                username,
                UInt32(username.count),
                password,
                UInt32(password.count),
                nil
            )
            guard rc == 0 else {
                let msg = getLastErrorMessage()
                throw SSH2Error.authFailed(rc, msg)
            }
        }
    }
}
