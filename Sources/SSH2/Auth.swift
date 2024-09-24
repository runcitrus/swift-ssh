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
    ) async throws {
        let result = await call {
            libssh2_userauth_publickey_frommemory(
                self.rawPointer,
                username,
                Int(username.count),
                nil,
                0,
                key,
                key.count,
                passphrase
            )
        }

        if case .failure(let rc, let msg) = result {
            throw SSH2Error.authFailed(rc, msg)
        }
    }

    private func passwordAuth(
        _ username: String,
        _ password: String
    ) async throws {
        let result = await call {
            libssh2_userauth_password_ex(
                self.rawPointer,
                username,
                UInt32(username.count),
                password,
                UInt32(password.count),
                nil
            )
        }

        if case .failure(let rc, let msg) = result {
            throw SSH2Error.authFailed(rc, msg)
        }
    }

    func auth(
        _ username: String,
        _ method: SSH2AuthMethod
    ) async throws {
        switch method {
        case .privateKey(let key, let passphrase):
            try await privateKeyAuth(username, key, passphrase)
        case .password(let password):
            try await passwordAuth(username, password)
        }
    }
}
