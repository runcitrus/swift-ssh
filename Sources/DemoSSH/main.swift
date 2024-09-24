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

    let stdin = Pipe()
    Task {
        let data = [
            "echo \"1\" >&1",
            "sleep 1",
            "echo \"2\" >&2",
            "sleep 1",
            "echo \"3\" >&1",
            "sleep 1",
            "echo \"4\" >&2"
        ].joined(separator: "\n").data(using: .utf8)!

        stdin.fileHandleForWriting.write(data)
        stdin.fileHandleForWriting.closeFile()
    }

    let channel = try await ssh.exec("/bin/sh -s")

    let tw = Task {
        try await channel.writeAll(stdin)
    }

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

    try await tw.value
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
