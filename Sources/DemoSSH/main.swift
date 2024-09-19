import Foundation
import SSH2

SSH2.libInit()

defer {
    SSH2.libExit()
}

func requestPassphrase(_ msg: String) -> String? {
    if let passphrase = getpass(msg) {
        return String(cString: passphrase)
    }
    return nil
}

func exec(
    host: String,
    port: Int32 = 22,
    username: String,
    auth: SSH2AuthMethod? = nil,
    command: String
) throws {
    let ssh = try SSH2(
        host,
        port,
        banner: "SSH-2.0-libssh2_Citrus.app"
    )

    if var auth = auth {
        while true {
            do {
                try ssh.auth(username, auth)
                break
            } catch SSH2Error.authFailed(let code, let msg) {
                switch auth {
                case .password:
                    throw SSH2Error.authFailed(code, msg)
                case .privateKey(let key, _):
                    if code == -16 {
                        let passphrase = requestPassphrase("enter your passphrase: ")
                        auth = .privateKey(key, passphrase)
                        continue
                    } else {
                        throw SSH2Error.authFailed(code, msg)
                    }
                }
            } catch {
                throw error
            }
        }
    }

    let (stdout, _) = try ssh.exec(command)
    guard let stdout else {
        return
    }

    if let output = String(data: stdout, encoding: .utf8) {
        print(output)
    }
}

do {
    let key = try String(
        contentsOfFile: "/Users/and/.ssh/cesbo_ed25519",
        encoding: .utf8
    )

    try exec(
        host: "bg.cesbo.com",
        port: 8022,
        username: "root",
        auth: SSH2AuthMethod.privateKey(key),
        command: "ls -la"
    )
} catch {
    print("error: \(error)")
}
