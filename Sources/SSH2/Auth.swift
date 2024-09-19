import CLibssh2

extension SSH2 {
    func authenticate(
        _ username: String,
        password: String? = nil,
        key: String? = nil,
        passphrase: String? = nil
    ) throws {
        if let value = key {
            let rc = libssh2_userauth_publickey_frommemory(
                session,
                username,
                Int(username.count),
                nil,
                0,
                value,
                value.count,
                passphrase
            )
            guard rc == 0 else {
                let msg = getLastErrorMessage()
                throw SSH2Error.authenticationFailed(msg)
            }
        } else if let value = password {
            let rc = libssh2_userauth_password_ex(
                session,
                username,
                UInt32(username.count),
                value,
                UInt32(value.count),
                nil
            )
            guard rc == 0 else {
                let msg = getLastErrorMessage()
                throw SSH2Error.authenticationFailed(msg)
            }
        } else {
            throw SSH2Error.authenticationFailed("unknown authentication method")
        }
    }
}
