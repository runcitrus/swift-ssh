import Foundation
import SSH2

func exec(
    host: String,
    port: Int32 = 22,
    username: String,
    key: String,
    passphrase: String?,
    command: String
) throws {
    let ssh = try SSH2(
        host,
        port: port,
        username: username,
        key: key,
        passphrase: passphrase
    )

    let (stdout, _) = try ssh.exec(command)
    guard let stdout else {
        return
    }

    if let output = String(data: stdout, encoding: .utf8) {
        print(output)
    }
}

func requestPassphrase(_ msg: String) -> String? {
    if let passphrase = getpass(msg) {
        return String(cString: passphrase)
    }
    return nil
}

let passphrase = requestPassphrase("enter your passphrase: ")

SSH2.libInit()

do {
    let key = try String(
        contentsOfFile: "/Users/and/.ssh/cesbo_ed25519",
        encoding: .utf8
    )

    try exec(
        host: "bg.cesbo.com",
        port: 8022,
        username: "root",
        key: key,
        passphrase: passphrase,
        command: "ls -la"
    )
} catch {
    print("error: \(error)")
}

SSH2.libExit()
