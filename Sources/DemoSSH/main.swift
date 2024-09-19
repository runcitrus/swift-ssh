import Foundation
import SSH2

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
    auth: SSH2AuthMethod? = nil
) async throws {
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

    let stdin = Pipe()
    Task {
        let data = "date\n".data(using: .utf8)!
        for _ in 0..<5 {
            stdin.fileHandleForWriting.write(data)
            try await Task.sleep(for: .seconds(1))
        }
        stdin.fileHandleForWriting.closeFile()
    }

    let (stdout, _) = try ssh.exec("/bin/sh -s", stdin: stdin)
    guard let stdout else {
        return
    }

    if let output = String(data: stdout, encoding: .utf8) {
        print(output)
    }
}

func main() async {
    SSH2.libInit()

    defer {
        SSH2.libExit()
    }

    do {
        let key = try String(
            contentsOfFile: "/Users/and/.ssh/cesbo_ed25519",
            encoding: .utf8
        )

        try await exec(
            host: "bg.cesbo.com",
            port: 8022,
            username: "root",
            auth: SSH2AuthMethod.privateKey(key)
        )
    } catch {
        print("error: \(error)")
    }
}

Task {
    await main()
    exit(EXIT_SUCCESS)
}

RunLoop.main.run()
