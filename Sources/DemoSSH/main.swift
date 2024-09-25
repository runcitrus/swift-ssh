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
    let ssh = try await SSH2.connect(
        host,
        port: port,
        banner: "SSH-2.0-libssh2_Citrus.app"
    )

    if var auth = auth {
        while true {
            do {
                try await ssh.auth(username, auth)
                break
            } catch {
                if case SSH2Error.authFailed(-16, _) = error {
                    if case .privateKey(let key, _) = auth {
                        let passphrase = requestPassphrase("enter your passphrase: ")
                        auth = .privateKey(key, passphrase)
                        continue
                    }
                }

                throw error
            }
        }
    }

    let channel = try await ssh.exec("/bin/sh -s")

    let script = """
        sleep 33
    """
    try await channel.writeAll(script.data(using: .utf8)!)

    let tr = Task {
        try await channel.readAll(
            stdoutHandler: {
                if let text = String(data: $0, encoding: .utf8) {
                    print(text, terminator: "")
                }
            },
            stderrHandler: {
                if let text = String(data: $0, encoding: .utf8) {
                    print(text, terminator: "")
                }
            }
        )
    }

    Task {
        try await Task.sleep(for: .seconds(3))
        print("cancel task")
        tr.cancel()
    }

    try await tr.value
}

func main() async {
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
