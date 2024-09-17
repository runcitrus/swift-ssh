import Foundation
import SSH2
import CLibssh2

func performSSHCommandWithPrivateKey(
    host: String,
    username: String,
    privateKeyPath: String,
    privateKeyPass: String?,
    command: String
) throws {
    let ssh = try SSH2(host: host, port: 8022)
    try ssh.sessionInit(
        username: username,
        privateKeyPath: privateKeyPath,
        privateKeyPass: passphrase
    )

    let channel = try ssh.channelOpen()

    // Выполнение команды на сервере
    let commandCStr = command.cString(using: .utf8)
    let execResult = libssh2_channel_process_startup(channel, "exec", UInt32(strlen("exec")), commandCStr, UInt32(strlen(command)))
    guard execResult == 0 else {
        print("failed to execute command: \(execResult)")
        libssh2_channel_close(channel)
        libssh2_channel_free(channel)
        ssh.close()
        return
    }

    // Чтение результата выполнения команды
    var buffer = [CChar](repeating: 0, count: 0x4000)
    while true {
        let bytesRead = libssh2_channel_read_ex(channel, 0, &buffer, buffer.count)
        if bytesRead > 0 {
            let data = Data(buffer.prefix(bytesRead).map { UInt8(bitPattern: $0) })
            if let output = String(data: data, encoding: .utf8) {
                print(output)
            }
        } else if bytesRead == LIBSSH2_ERROR_EAGAIN {
            continue
        } else {
            break
        }
    }

    // Закрытие канала и завершение сессии
    ssh.channelClose(channel)
    ssh.close()
}

func requestPassphrase() -> String? {
    if let passphrase = getpass("enter your passphrase: ") {
        return String(cString: passphrase)
    }
    return nil
}

let passphrase = requestPassphrase()

libssh2_init(0)

do {
    try performSSHCommandWithPrivateKey(
        host: "78.128.94.138",
        username: "root",
        privateKeyPath: "/Users/and/.ssh/cesbo_ed25519",
        privateKeyPass: passphrase,
        command: "ls -la"
    )
} catch {
    print("error: \(error)")
}

libssh2_exit()
