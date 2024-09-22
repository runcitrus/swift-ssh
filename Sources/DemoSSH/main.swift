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

    let stdout = Pipe()
    stdout.fileHandleForReading.readabilityHandler = {
        let data: Data = $0.availableData
        if data.count > 0 {
            print(String(data: data, encoding: .utf8)!, terminator: "")
        }
    }

    let stderr = Pipe()
    stderr.fileHandleForReading.readabilityHandler = {
        let data: Data = $0.availableData
        if data.count > 0 {
            print(String(data: data, encoding: .utf8)!, terminator: "")
        }
    }

    try ssh.exec(
        "/bin/sh -s",
        stdin: stdin,
        stdout: stdout,
        stderr: stderr
    )
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
